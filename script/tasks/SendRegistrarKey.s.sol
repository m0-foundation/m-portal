// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { TaskBase } from "./TaskBase.sol";

contract SendRegistrarKey is TaskBase {
    function run() public {
        (, address portal_, , , , ) = _readDeployment(block.chainid);
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        bytes32 key_ = vm.parseBytes32(vm.prompt("Enter Registrar key"));
        uint256 deliveryPrice_ = _quoteDeliveryPrice(portal_, destinationChainId_);

        vm.startBroadcast(signer_);

        _sendRegistrarKey(portal_, destinationChainId_, key_, _toUniversalAddress(signer_), deliveryPrice_);
        console.log("Registrar key sent to Wormhole chain ID:", destinationChainId_);

        vm.stopBroadcast();
    }
}
