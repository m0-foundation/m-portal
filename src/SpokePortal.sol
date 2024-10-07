// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { ISpokeMTokenLike, IRegistrarLike } from "./interfaces/Dependencies.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libs/PayloadEncoder.sol";

/**
 * @title  Portal residing on L2s handling sending/receiving M, update the M index and Registrar keys.
 * @author M^0 Labs
 */
contract SpokePortal is ISpokePortal, Portal {
    using PayloadEncoder for bytes;

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
    ) Portal(mToken_, registrar_, Mode.BURNING, chainId_) {}

    function _handleCustomPayload(
        bytes32 messageId_,
        PayloadType payloadType_,
        bytes memory payload_
    ) internal override {
        if (payloadType_ == PayloadType.Index) {
            _setIndex(messageId_, payload_);
        } else if (payloadType_ == PayloadType.Key) {
            _setKey(messageId_, payload_);
        } else if (payloadType_ == PayloadType.List) {
            _updateRegistrarList(messageId_, payload_);
        }
    }

    /// @notice Updates M Token index to the index received from the remote chain.
    function _setIndex(bytes32 messageId_, bytes memory payload_) private {
        (uint128 index_, uint16 destinationChainId_) = payload_.decodeIndex();

        _verifyDestinationChain(destinationChainId_);
        ISpokeMTokenLike(mToken()).updateIndex(index_);

        emit MTokenIndexReceived(messageId_, index_);
    }

    /// @notice Sets a Registrar key received from the Hub chain.
    function _setKey(bytes32 messageId_, bytes memory payload_) private {
        (bytes32 key_, bytes32 value_, uint16 destinationChainId_) = payload_.decodeKey();

        _verifyDestinationChain(destinationChainId_);
        IRegistrarLike(registrar).setKey(key_, value_);

        emit RegistrarKeyReceived(messageId_, key_, value_);
    }

    /// @notice Adds or removes an account from the Registrar List based on the message from the Hub chain.
    function _updateRegistrarList(bytes32 messageId_, bytes memory payload_) private {
        (bytes32 listName_, address account_, bool add_, uint16 destinationChainId_) = payload_.decodeListUpdate();

        _verifyDestinationChain(destinationChainId_);

        if (add_) {
            IRegistrarLike(registrar).addToList(listName_, account_);
        } else {
            IRegistrarLike(registrar).removeFromList(listName_, account_);
        }

        emit RegistrarListStatusReceived(messageId_, listName_, account_, add_);
    }

    /**
     * @dev Mints M Token to the `recipient_`.
     * @param recipient_ The account to mint M tokens to.
     * @param amount_    The amount of M Token to mint to the recipient.
     * @param index_     The index from the source chain.
     */
    function _mintOrUnlock(address recipient_, uint256 amount_, uint128 index_) internal override {
        ISpokeMTokenLike(mToken()).mint(recipient_, amount_, index_);
    }

    /// @dev Returns the current M token index used by the Spoke Portal.
    function _currentIndex() internal view override returns (uint128) {
        return ISpokeMTokenLike(mToken()).currentIndex();
    }
}
