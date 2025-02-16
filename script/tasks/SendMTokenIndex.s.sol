// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { TaskBase } from "./TaskBase.sol";

contract SendMTokenIndex is TaskBase {
    using TypeConverter for address;

    function run() public {
        (, address portal_, , , , ) = _readDeployment(block.chainid);
        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        uint256 deliveryPrice_ = _quoteDeliveryPrice(portal_, destinationChainId_);
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(signer_);

        _sendMTokenIndex(portal_, destinationChainId_, signer_.toBytes32(), deliveryPrice_);
        console.log("M token index sent to Wormhole chain ID:", destinationChainId_);

        vm.stopBroadcast();
    }
}
