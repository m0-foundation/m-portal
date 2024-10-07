// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { TransceiverStructs } from "lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IMTokenLike, IRegistrarLike } from "./interfaces/Dependencies.sol";
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
    /* ============ Variables ============ */

    /// @dev Registrar key holding value of whether the earners list can be ignored or not.
    bytes32 internal constant _EARNERS_LIST_IGNORED = "earners_list_ignored";

    /// @dev Registrar key of earners list.
    bytes32 internal constant _EARNERS_LIST = "earners";

    /// @dev Array of indices at which earning was enabled or disabled.
    uint128[] internal _enableDisableEarningIndices;

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
        bytes32 refundAddress_,
        bytes memory transceiverInstructions_
    ) external payable returns (bytes32 messageId_) {
        uint128 index_ = _currentIndex();
        bytes memory payload_ = PayloadEncoder.encodeIndex(index_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, transceiverInstructions_, payload_);

        emit MTokenIndexSent(destinationChainId_, messageId_, index_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint16 destinationChainId_,
        bytes32 key_,
        bytes32 refundAddress_,
        bytes memory transceiverInstructions_
    ) external payable returns (bytes32 messageId_) {
        bytes32 value_ = IRegistrarLike(registrar).get(key_);
        bytes memory payload_ = PayloadEncoder.encodeKey(key_, value_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, payload_, transceiverInstructions_);

        emit RegistrarKeySent(destinationChainId_, messageId_, key_, value_);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarListStatus(
        uint16 destinationChainId_,
        bytes32 listName_,
        address account_,
        bytes32 refundAddress_,
        bytes memory transceiverInstructions_
    ) external payable returns (bytes32 messageId_) {
        bool status_ = IRegistrarLike(registrar).listContains(listName_, account_);
        bytes memory payload_ = PayloadEncoder.encodeListUpdate(listName_, account_, status_, destinationChainId_);
        messageId_ = _sendMessage(destinationChainId_, refundAddress_, payload_, transceiverInstructions_);

        emit RegistrarListStatusSent(destinationChainId_, messageId_, listName_, account_, status_);
    }

    /// @inheritdoc IHubPortal
    function enableEarning() external {
        if (!_isApprovedEarner()) revert NotApprovedEarner();
        if (isEarningEnabled()) revert EarningIsEnabled();

        // NOTE: This is a temporary measure to prevent re-enabling earning after it has been disabled.
        //       This line will be removed in the future.
        if (_enableDisableEarningIndices.length != 0) revert EarningCannotBeReenabled();

        IMTokenLike mToken_ = IMTokenLike(mToken());
        uint128 currentMIndex_ = mToken_.currentIndex();
        _enableDisableEarningIndices.push(currentMIndex_);

        mToken_.startEarning();

        emit EarningEnabled(currentMIndex_);
    }

    /// @inheritdoc IHubPortal
    function disableEarning() external {
        if (_isApprovedEarner()) revert IsApprovedEarner();
        if (!isEarningEnabled()) revert EarningIsDisabled();

        IMTokenLike mToken_ = IMTokenLike(mToken());
        uint128 currentMIndex_ = mToken_.currentIndex();
        _enableDisableEarningIndices.push(currentMIndex_);

        mToken_.stopEarning();

        emit EarningDisabled(currentMIndex_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IHubPortal
    function isEarningEnabled() public view returns (bool) {
        return IMTokenLike(mToken()).isEarning(address(this));
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
        bytes memory payload_,
        bytes memory transceiverInstructions_
    ) private returns (bytes32 messageId_) {
        if (refundAddress_ == bytes32(0)) revert InvalidRefundAddress();

        (
            address[] memory enabledTransceivers_,
            TransceiverStructs.TransceiverInstruction[] memory instructions_,
            uint256[] memory priceQuotes_,

        ) = _prepareForTransfer(destinationChainId_, transceiverInstructions_);

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

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current M token index used by the Hub Portal.
    function _currentIndex() internal view override returns (uint128) {
        if (isEarningEnabled()) {
            return IMTokenLike(mToken()).currentIndex();
        }

        // If earning has been enabled in the past, return the latest recorded index when it was disabled.
        // Otherwise, return the starting index.
        return
            _enableDisableEarningIndices.length != 0
                ? _enableDisableEarningIndices[_enableDisableEarningIndices.length - 1]
                : 0;
    }

    /// @dev Returns whether the Hub Portal is a TTG-approved earner or not.
    function _isApprovedEarner() internal view returns (bool) {
        IRegistrarLike registrar_ = IRegistrarLike(registrar);

        return
            registrar_.get(_EARNERS_LIST_IGNORED) != bytes32(0) ||
            registrar_.listContains(_EARNERS_LIST, address(this));
    }
}
