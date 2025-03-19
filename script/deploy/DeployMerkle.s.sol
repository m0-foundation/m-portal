// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { DeployBase } from "./DeployBase.sol";
import { DeployConfig, HubDeployConfig } from "../config/DeployConfig.sol";

contract DeployMerkleTreeBuilder is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        uint256 chainId = block.chainid;
        HubDeployConfig memory hubDeployConfig = DeployConfig.getHubDeployConfig(chainId);

        vm.startBroadcast(deployer_);

        address merkleTreeBuilder = _deployMerkleTreeBuilder(deployer_, hubDeployConfig.registrar);

        vm.stopBroadcast();

        console.log("Merkle Tree Builder: ", merkleTreeBuilder);

        _serializeMerkleTreeBuilderDeployment(chainId, merkleTreeBuilder);
    }

    function _serializeMerkleTreeBuilderDeployment(uint256 chainId_, address merkleTreeBuilder_) internal {
        string memory root = "";

        vm.writeJson(vm.serializeAddress(root, "merkleTreeBuilder", merkleTreeBuilder_), _deployOutputPath(chainId_));
    }
}
