// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";

import { CastBase } from "./CastBase.sol";

contract CastTransferExcessM is CastBase {
    function run() public {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address spokeVault_ = vm.parseAddress(vm.prompt("Enter SpokeVault address"));

        uint256 deliveryPrice_ = _quoteDeliveryPrice(
            ISpokeVault(spokeVault_).spokePortal(),
            ISpokeVault(spokeVault_).destinationChainId()
        );

        console.log("Delivery price:", deliveryPrice_);

        vm.startBroadcast(signer_);

        _transferExcessM(spokeVault_, _toUniversalAddress(signer_), deliveryPrice_);
        console.log("Excess M transferred to Hub Vault.");

        vm.stopBroadcast();
    }
}
