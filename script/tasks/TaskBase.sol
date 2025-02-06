// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script } from "../../lib/forge-std/src/Script.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";

import { ScriptBase } from "../ScriptBase.sol";

contract TaskBase is ScriptBase {
    function _quoteDeliveryPrice(
        address hubPortal_,
        uint16 destinationChainId_
    ) internal view returns (uint256 deliveryPrice_) {
        (, deliveryPrice_) = IManagerBase(hubPortal_).quoteDeliveryPrice(destinationChainId_, new bytes(1));
    }

    function _sendMTokenIndex(
        address hubPortal_,
        uint16 destinationChainId_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (bytes32 messageId_) {
        return IHubPortal(hubPortal_).sendMTokenIndex{ value: value_ }(destinationChainId_, refundAddress_);
    }

    function _sendRegistrarKey(
        address hubPortal_,
        uint16 destinationChainId_,
        bytes32 key_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (bytes32 messageId_) {
        return IHubPortal(hubPortal_).sendRegistrarKey{ value: value_ }(destinationChainId_, key_, refundAddress_);
    }

    function _sendRegistrarListStatus(
        address hubPortal_,
        uint16 destinationChainId_,
        bytes32 listName_,
        address account_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (bytes32 messageId_) {
        return
            IHubPortal(hubPortal_).sendRegistrarListStatus{ value: value_ }(
                destinationChainId_,
                listName_,
                account_,
                refundAddress_
            );
    }

    function _transfer(
        address portal_,
        uint16 destinationChainId_,
        uint256 amount_,
        bytes32 recipient_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (uint64 messageSequence_) {
        return
            INttManager(portal_).transfer{ value: value_ }(
                amount_,
                destinationChainId_,
                recipient_,
                refundAddress_,
                false,
                new bytes(1)
            );
    }

    function _transferExcessM(
        address spokeVault_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (uint64 messageSequence_) {
        return ISpokeVault(spokeVault_).transferExcessM{ value: value_ }(refundAddress_);
    }

    function _verifyDeploymentExist() internal {
        if (!vm.isFile(_deployOutputPath())) {
            revert("Deployment artifacts not found");
        }
    }

    function _promptForDestinationChainId(address portal_) internal returns (uint16 destinationChainId_) {
        destinationChainId_ = uint16(vm.parseUint(vm.prompt("Enter Wormhole destination chain ID")));

        if (INttManager(portal_).getPeer(destinationChainId_).peerAddress == bytes32(0)) {
            revert("Unsupported destination chain");
        }
    }

    function _promptForTransferAmount(address mToken_, address account_) internal returns (uint256 amount_) {
        uint256 balance_ = IERC20(mToken_).balanceOf(account_);
        amount_ = vm.parseUint(vm.prompt("Enter amount to transfer"));

        if (amount_ > balance_) {
            revert("Insufficient balance");
        }
    }
}
