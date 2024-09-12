// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ISpokeMTokenLike, IRegistrarLike } from "./interfaces/Dependencies.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";

import { Portal } from "./Portal.sol";

/**
 * @title  Portal residing on L2s handling sending/receiving M, update the M index and Registrar keys.
 * @author M^0 Labs
 */
contract SpokePortal is ISpokePortal, Portal {
    /* ============ Constructor ============ */

    /**
     * @notice Constructs the contract.
     * @param  bridge_    The address of the bridge that will dispatch and receive messages.
     * @param  mToken_    The address of the bridged M token contract.
     * @param  registrar_ The address of the Registrar.
     */
    constructor(address bridge_, address mToken_, address registrar_) Portal(bridge_, mToken_, registrar_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISpokePortal
    function updateMTokenIndex(uint128 index_) external onlyBridge {
        emit MTokenIndexReceived(msg.sender, index_);

        ISpokeMTokenLike(mToken).updateIndex(index_);
    }

    /// @inheritdoc ISpokePortal
    function setRegistrarKey(bytes32 key_, bytes32 value_) external onlyBridge {
        emit RegistrarKeyReceived(msg.sender, key_, value_);

        IRegistrarLike(registrar).setKey(key_, value_);
    }

    /// @inheritdoc ISpokePortal
    function setRegistrarListStatus(bytes32 listName_, address account_, bool status_) external onlyBridge {
        emit RegistrarListStatusReceived(msg.sender, listName_, account_, status_);

        if (status_) {
            IRegistrarLike(registrar).addToList(listName_, account_);
        } else {
            IRegistrarLike(registrar).removeFromList(listName_, account_);
        }
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Burns M tokens from the caller before sending them to the destination chain.
     * @param amount_ The amount of M tokens to burn from the caller.
     */
    function _sendMToken(uint256 amount_) internal override {
        ISpokeMTokenLike(mToken).burn(msg.sender, amount_);
    }

    /**
     * @dev   Receive M tokens from the source chain.
     * @param recipient_ The account to mint M tokens to.
     * @param amount_    The amount of M Token to mint to the recipient.
     * @param index_     The index from the source chain.
     */
    function _receiveMToken(address recipient_, uint256 amount_, uint128 index_) internal override {
        ISpokeMTokenLike(mToken).mint(recipient_, amount_, index_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current M token index used by the Spoke Portal.
    function _currentIndex() internal view override returns (uint128) {
        return ISpokeMTokenLike(mToken).currentIndex();
    }
}
