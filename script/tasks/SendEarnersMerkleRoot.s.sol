// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { TaskBase } from "./TaskBase.sol";

contract SendEarnersMerkleRoot is TaskBase {
    using TypeConverter for address;

    function run() public {
        (, address portal_, , , , ) = _readDeployment(block.chainid);
        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        uint256 value_ = vm.parseUint(vm.prompt("Enter executor cost (in wei)"));
        bytes memory signedQuote_ = vm.parseBytes(vm.prompt("Enter executor signed quote (as hex)"));
        bytes32 refundAddress_ = vm.parseBytes32(vm.prompt("Enter refund address (as hex)"));
        address signer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));

        // TODO hardcoded testnet address, update config to include this entrypoint?
        address executorEntryPoint = 0x8518040A9Cf9DFb55A4f099BB0EaAbeEfEB03643;

        vm.startBroadcast(signer_);

        _sendEarnersMerkleRoot(executorEntryPoint, destinationChainId_, refundAddress_, value_, signedQuote_);

        console.log("Earners Merkle Root sent to Wormhole chain ID:", destinationChainId_);

        vm.stopBroadcast();
    }
}
