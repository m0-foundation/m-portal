// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";
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

    /// @dev The Hub Portal's index when earning was most recently disabled
    uint128 private _disablePortalIndex;

    /// @dev The M token's index when earning was most recently enabled
    uint128 private _enableMTokenIndex;

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

    function _initialize() internal override {
        super._initialize();

        // set _disablePortalIndex to the default value on first deployment
        if (_disablePortalIndex == 0) {
            _disablePortalIndex = IndexingMath.EXP_SCALED_ONE;
        }
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IHubPortal
    function sendMTokenIndex(
        uint16 destinationChainId_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        uint128 index_ = _currentIndex();
        bytes memory payload_ = PayloadEncoder.encodeIndex(index_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, payload_);

        emit MTokenIndexSent(destinationChainId_, messageId_, index_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint16 destinationChainId_,
        bytes32 key_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        bytes32 value_ = IRegistrarLike(registrar).get(key_);
        bytes memory payload_ = PayloadEncoder.encodeKey(key_, value_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, payload_);

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
        bytes memory payload_ = PayloadEncoder.encodeListUpdate(listName_, account_, status_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, payload_);

        emit RegistrarListStatusSent(destinationChainId_, messageId_, listName_, account_, status_);
    }

    /// @inheritdoc IHubPortal
    function enableEarning() external {
        if (_isEarningEnabled()) revert EarningIsEnabled();

        uint128 mTokenIndex_ = _currentMTokenIndex();
        _enableMTokenIndex = mTokenIndex_;

        IMTokenLike(mToken()).startEarning();

        emit EarningEnabled(mTokenIndex_);
    }

    /// @inheritdoc IHubPortal
    function disableEarning() external {
        if (!_isEarningEnabled()) revert EarningIsDisabled();

        uint128 portalIndex_ = _currentIndex();
        _disablePortalIndex = portalIndex_;
        _enableMTokenIndex = 0;

        IMTokenLike(mToken()).stopEarning(address(this));

        emit EarningDisabled(portalIndex_);
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
        bytes memory payload_
    ) private returns (bytes32 messageId_) {
        if (refundAddress_ == bytes32(0)) revert InvalidRefundAddress();

        (
            address[] memory enabledTransceivers_,
            TransceiverStructs.TransceiverInstruction[] memory instructions_,
            uint256[] memory priceQuotes_,

        ) = _prepareForTransfer(destinationChainId_, DEFAULT_TRANSCEIVER_INSTRUCTIONS);

        TransceiverStructs.NttManagerMessage memory message_ = TransceiverStructs.NttManagerMessage(
            bytes32(uint256(_useMessageSequence())),
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

    /* ============ Internal/Private View Functions ============ */

    /// @dev Returns the current Hub Portal index
    function _currentIndex() internal view override returns (uint128) {
        return
            _isEarningEnabled()
                ? uint128(uint256(_disablePortalIndex) * _currentMTokenIndex()) / _enableMTokenIndex
                : _disablePortalIndex;
    }

    function _currentMTokenIndex() private view returns (uint128 index_) {
        return IMTokenLike(mToken()).currentIndex();
    }

    /// @dev Returns whether earning was enabled for HubPortal or not.
    function _isEarningEnabled() private view returns (bool) {
        return _enableMTokenIndex != 0;
    }
}
