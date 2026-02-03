// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";

import { TaskBase } from "./TaskBase.sol";

/**
 * @title  SetBridgingPath
 * @notice Sets a supported bridging path for a source token.
 * @dev    Requires the caller to be the Portal owner.
 *         For multisig-owned portals, use ProposeSetBridgingPath instead.
 */
contract SetBridgingPath is TaskBase {
    function run() public {
        (, address portal_, , , , ) = _readDeployment(block.chainid);

        address sourceToken_ = vm.parseAddress(vm.prompt("Enter source token address"));
        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        bytes32 destinationToken_ = vm.parseBytes32(vm.prompt("Enter destination token (bytes32)"));

        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(signer_);

        IPortal(portal_).setSupportedBridgingPath(sourceToken_, destinationChainId_, destinationToken_, true);

        console.log("Set bridging path:");
        console.log("  Source token:", sourceToken_);
        console.log("  Destination chain:", destinationChainId_);

        vm.stopBroadcast();
    }
}
