// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../../lib/forge-std/src/console.sol";

import { CastBase } from "./CastBase.sol";

contract CastSendRegistrarListStatusDev is CastBase {
    function run() public {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        address hubPortal_ = vm.parseAddress(vm.prompt("Enter HubPortal address"));
        uint16 destinationChainId_ = _getWormholeChainId(vm.parseUint(vm.prompt("Enter destination chain ID")));
        bytes32 listName_ = vm.parseBytes32(vm.prompt("Enter Registrar list name"));
        address account_ = vm.parseAddress(vm.prompt("Enter account address"));

        uint256 deliveryPrice_ = _quoteDeliveryPrice(hubPortal_, destinationChainId_);
        console.log("Delivery price: {}", deliveryPrice_);

        vm.startBroadcast(signer_);

        _sendRegistrarListStatus(
            hubPortal_,
            destinationChainId_,
            listName_,
            account_,
            _toUniversalAddress(signer_),
            deliveryPrice_
        );

        console.log("Registrar key sent to Wormhole chain ID {}", destinationChainId_);

        vm.stopBroadcast();
    }
}
