// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { TransceiverStructs } from "../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadEncoder } from "./libs/PayloadEncoder.sol";
import { TypeConverter } from "./libs/TypeConverter.sol";

/**
 * @title  Portal residing on Ethereum Mainnet handling sending/receiving M and pushing the M index and Registrar keys.
 * @author M^0 Labs
 */
contract HubPortal is IHubPortal, Portal {
    using TypeConverter for address;

    /// @dev Use only standard WormholeTransceiver with relaying enabled
    bytes public constant DEFAULT_TRANSCEIVER_INSTRUCTIONS = new bytes(1);

    /* ============ Variables ============ */

    /// @inheritdoc IHubPortal
    bool public wasEarningEnabled;

    /// @inheritdoc IHubPortal
    uint128 public disableEarningIndex;

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
        bytes memory payload_ = PayloadEncoder.encodeIndex(index_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, _useMessageSequence(), payload_);

        emit MTokenIndexSent(destinationChainId_, messageId_, index_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint16 destinationChainId_,
        bytes32 key_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        bytes32 value_ = IRegistrarLike(registrar).get(key_);
        uint64 sequence_ = _useMessageSequence();
        bytes memory payload_ = PayloadEncoder.encodeKey(key_, value_, sequence_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, sequence_, payload_);

        emit RegistrarKeySent(destinationChainId_, messageId_, key_, value_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarListStatus(
        uint16 destinationChainId_,
        bytes32 listName_,
        address account_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        bool status_ = IRegistrarLike(registrar).listContains(listName_, account_);
        uint64 sequence_ = _useMessageSequence();
        bytes memory payload_ = PayloadEncoder.encodeListUpdate(
            listName_,
            account_,
            status_,
            sequence_,
            destinationChainId_
        );
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, sequence_, payload_);

        emit RegistrarListStatusSent(destinationChainId_, messageId_, listName_, account_, status_);
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
        IERC20(mToken()).transfer(recipient_, amount_);
    }

    /// @notice Sends a generic message to the destination chain.
    /// @dev    The implementation is adapted from `NttManager` `_transfer` function.
    function _sendMessage(
        uint16 destinationChainId_,
        bytes32 refundAddress_,
        uint64 _sequence,
        bytes memory payload_
    ) private returns (bytes32 messageId_) {
        if (refundAddress_ == bytes32(0)) revert InvalidRefundAddress();

        (
            address[] memory enabledTransceivers_,
            TransceiverStructs.TransceiverInstruction[] memory instructions_,
            uint256[] memory priceQuotes_,

        ) = _prepareForTransfer(destinationChainId_, DEFAULT_TRANSCEIVER_INSTRUCTIONS);

        TransceiverStructs.NttManagerMessage memory message_ = TransceiverStructs.NttManagerMessage(
            bytes32(uint256(_sequence)),
            msg.sender.toBytes32(),
            payload_
        );

        // send the message
        _sendMessageToTransceivers(
            destinationChainId_,
            refundAddress_,
            _getPeersStorage()[destinationChainId_].peerAddress,
            priceQuotes_,
            instructions_,
            enabledTransceivers_,
            TransceiverStructs.encodeNttManagerMessage(message_)
        );

        return TransceiverStructs.nttManagerMessageDigest(chainId, message_);
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
