// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { CastBase } from "./CastBase.sol";

contract CastSendRegistrarKey is CastBase {
    function run() public {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address hubPortal_ = vm.parseAddress(vm.prompt("Enter HubPortal address"));
        uint16 destinationChainId_ = _getWormholeChainId(vm.parseUint(vm.prompt("Enter destination chain ID")));
        bytes32 key_ = vm.parseBytes32(vm.prompt("Enter Registrar key"));

        uint256 deliveryPrice_ = _quoteDeliveryPrice(hubPortal_, destinationChainId_);
        console.log("Delivery price:", deliveryPrice_);

        vm.startBroadcast(signer_);

        _sendRegistrarKey(hubPortal_, destinationChainId_, key_, _toUniversalAddress(signer_), deliveryPrice_);
        console.log("Registrar key sent to Wormhole chain ID:", destinationChainId_);

        vm.stopBroadcast();
    }
}
