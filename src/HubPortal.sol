// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { TransceiverStructs } from "../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";
import { IMerkleTreeBuilder } from "./interfaces/IMerkleTreeBuilder.sol";

import { Portal } from "./Portal.sol";
import { PayloadEncoder } from "./libs/PayloadEncoder.sol";
import { TypeConverter } from "./libs/TypeConverter.sol";

/**
 * @title  Portal residing on Ethereum Mainnet handling sending/receiving M and pushing the M index and Registrar keys.
 * @author M^0 Labs
 */
contract HubPortal is IHubPortal, Portal {
    using TypeConverter for address;

    /* ============ Variables ============ */

    /// @inheritdoc IHubPortal
    bool public wasEarningEnabled;

    /// @inheritdoc IHubPortal
    uint128 public disableEarningIndex;

    /// @inheritdoc IHubPortal
    address public merkleTreeBuilder;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the contract.
     * @param  mToken_    The address of the M token to bridge.
     * @param  registrar_ The address of the Registrar.
     * @param  chainId_   Wormhole chain id.
     */
    constructor(
        address mToken_,
        address registrar_,
        uint16 chainId_
    ) Portal(mToken_, registrar_, Mode.LOCKING, chainId_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IHubPortal
    function sendMTokenIndex(
        uint16 destinationChainId_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        uint128 index_ = _currentIndex();
        messageId_ = destinationChainId_ == _SOLANA_WORMHOLE_CHAIN_ID
            ? _sendMTokenIndexToSolana(index_, refundAddress_)
            : _sendCustomMessage(
                destinationChainId_,
                refundAddress_,
                PayloadEncoder.encodeIndex(index_, destinationChainId_)
            );

        emit MTokenIndexSent(destinationChainId_, messageId_, index_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint16 destinationChainId_,
        bytes32 key_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        // Sending Registrar key to Solana is not supported at this time.
        // To propagate earners to Solana call `sendEarnersMerkleRoot`.
        if (destinationChainId_ == _SOLANA_WORMHOLE_CHAIN_ID) revert UnsupportedDestinationChain(destinationChainId_);

        bytes32 value_ = IRegistrarLike(registrar).get(key_);
        bytes memory payload_ = PayloadEncoder.encodeKey(key_, value_, destinationChainId_);
        messageId_ = _sendCustomMessage(destinationChainId_, refundAddress_, payload_);

        emit RegistrarKeySent(destinationChainId_, messageId_, key_, value_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarListStatus(
        uint16 destinationChainId_,
        bytes32 listName_,
        address account_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        // Sending Registrar key status to Solana is not supported at this time.
        // To propagate earners to Solana call `sendEarnersMerkleRoot`.
        if (destinationChainId_ == _SOLANA_WORMHOLE_CHAIN_ID) revert UnsupportedDestinationChain(destinationChainId_);

        bool status_ = IRegistrarLike(registrar).listContains(listName_, account_);
        bytes memory payload_ = PayloadEncoder.encodeListUpdate(listName_, account_, status_, destinationChainId_);
        messageId_ = _sendCustomMessage(destinationChainId_, refundAddress_, payload_);

        emit RegistrarListStatusSent(destinationChainId_, messageId_, listName_, account_, status_);
    }

    /// @inheritdoc IHubPortal
    function sendEarnersMerkleRoot(bytes32 refundAddress_) external payable returns (bytes32 messageId_) {
        bytes32 destinationToken_ = destinationMToken[_SOLANA_WORMHOLE_CHAIN_ID];
        bytes32 earnersMerkleRoot_ = IMerkleTreeBuilder(merkleTreeBuilder).getRoot(_SOLANA_EARNER_LIST);

        bytes memory additionalPayload_ = PayloadEncoder.encodeAdditionalPayload(
            _currentIndex(),
            destinationToken_,
            earnersMerkleRoot_
        );

        (, messageId_) = _transferNativeToken(
            0,
            token,
            _SOLANA_WORMHOLE_CHAIN_ID,
            destinationToken_,
            refundAddress_, // recipient doesn't matter since transfer amount is 0
            refundAddress_,
            additionalPayload_
        );

        emit EarnersMerkleRootSent(messageId_, earnersMerkleRoot_);
    }

    /// @inheritdoc IHubPortal
    function setMerkleTreeBuilder(address merkleTreeBuilder_) external onlyOwner {
        if ((merkleTreeBuilder = merkleTreeBuilder_) == address(0)) revert ZeroMerkleTreeBuilder();

        emit MerkleTreeBuilderSet(merkleTreeBuilder_);
    }

    /// @inheritdoc IHubPortal
    function enableEarning() external {
        if (_isEarningEnabled()) revert EarningIsEnabled();
        if (wasEarningEnabled) revert EarningCannotBeReenabled();

        wasEarningEnabled = true;

        IMTokenLike(mToken()).startEarning();

        emit EarningEnabled(IMTokenLike(mToken()).currentIndex());
    }

    /// @inheritdoc IHubPortal
    function disableEarning() external {
        if (!_isEarningEnabled()) revert EarningIsDisabled();

        uint128 currentMIndex_ = IMTokenLike(mToken()).currentIndex();
        disableEarningIndex = currentMIndex_;

        IMTokenLike(mToken()).stopEarning(address(this));

        emit EarningDisabled(currentMIndex_);
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Unlocks M tokens to `recipient_`.
     * @param recipient_ The account to unlock/transfer M tokens to.
     * @param amount_    The amount of M Token to unlock to the recipient.
     */
    function _mintOrUnlock(address recipient_, uint256 amount_, uint128) internal override {
        if (recipient_ != address(this)) {
            IERC20(mToken()).transfer(recipient_, amount_);
        }
    }

    /// @dev Sends a custom (not a transfer) message to the destination chain.
    function _sendCustomMessage(
        uint16 destinationChainId_,
        bytes32 refundAddress_,
        bytes memory payload_
    ) private returns (bytes32 messageId_) {
        if (refundAddress_ == bytes32(0)) revert InvalidRefundAddress();

        TransceiverStructs.NttManagerMessage memory message_ = TransceiverStructs.NttManagerMessage(
            bytes32(uint256(_useMessageSequence())),
            msg.sender.toBytes32(),
            payload_
        );

        _sendMessage(destinationChainId_, refundAddress_, message_);

        messageId_ = TransceiverStructs.nttManagerMessageDigest(chainId, message_);
    }

    /// @dev A workaround to send M Token Index to Solana as an additional payload with zero token transfer
    function _sendMTokenIndexToSolana(uint128 index_, bytes32 refundAddress_) private returns (bytes32 messageId_) {
        bytes32 destinationToken_ = destinationMToken[_SOLANA_WORMHOLE_CHAIN_ID];
        bytes memory additionalPayload_ = PayloadEncoder.encodeAdditionalPayload(index_, destinationToken_);

        (, messageId_) = _transferNativeToken(
            0,
            token,
            _SOLANA_WORMHOLE_CHAIN_ID,
            destinationToken_,
            refundAddress_, // recipient doesn't matter since transfer amount is 0
            refundAddress_,
            additionalPayload_
        );
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev If earning is enabled returns the current M token index,
    ///      otherwise, returns the index at the time when earning was disabled.
    function _currentIndex() internal view override returns (uint128) {
        return _isEarningEnabled() ? IMTokenLike(mToken()).currentIndex() : disableEarningIndex;
    }

    /// @dev Returns whether earning was enabled for HubPortal or not.
    function _isEarningEnabled() internal view returns (bool) {
        return wasEarningEnabled && disableEarningIndex == 0;
    }
}
