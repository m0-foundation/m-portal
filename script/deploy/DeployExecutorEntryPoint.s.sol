// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { DeployBase } from "./DeployBase.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract DeployExecutorEntryPoint is DeployBase {
    using WormholeConfig for uint256;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address admin_ = vm.rememberKey(vm.envUint("ADMIN"));

        uint256 chainId_ = block.chainid;

        WormholeTransceiverConfig memory config_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);
        (, address portal_, , , , ) = _readDeployment(chainId_);

        vm.startBroadcast(deployer_);

        (address implementation_, address proxy_) = _deployExecutorEntryPoint(deployer_, admin_, config_, portal_);

        vm.stopBroadcast();

        console.log("ExecutorEntryPoint Proxy:         ", proxy_);
        console.log("ExecutorEntryPoint Implementation:", implementation_);
    }
}
