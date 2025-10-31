// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Safe } from "../../lib/safe-utils/src/Safe.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { TaskBase } from "./TaskBase.sol";
import { MultiSigBatchBase } from "../MultiSigBatchBase.sol";
import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";

contract ProposeSetBridgingPath is TaskBase, MultiSigBatchBase {
    using Safe for *;

    address constant _SAFE_MULTISIG = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    function run() public {
        address proposer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        (address mToken_, address portal_, , , , address wrappedMToken_) = _readDeployment(block.chainid);

        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        bytes32 destinationToken_ = vm.parseBytes32(vm.prompt("Enter destination token"));

        _addToBatch(
            portal_,
            abi.encodeCall(IPortal.setSupportedBridgingPath, (mToken_, destinationChainId_, destinationToken_, true))
        );
        _addToBatch(
            portal_,
            abi.encodeCall(
                IPortal.setSupportedBridgingPath,
                (wrappedMToken_, destinationChainId_, destinationToken_, true)
            )
        );

        _simulateBatch(_SAFE_MULTISIG);
        _proposeBatch(_SAFE_MULTISIG, proposer_);
    }
}
