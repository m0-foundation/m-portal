// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { DeployBase } from "./DeployBase.sol";
import { ExecutorEntryPoint } from "../../src/ExecutorEntryPoint.sol";
import { WormholeConfig } from "../config/WormholeConfig.sol";

contract DeployExecutorEntryPoint is DeployBase {
    using WormholeConfig for uint256;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        uint256 chainId = block.chainid;
        address executor = 0xD0fb39f5a3361F21457653cB70F9D0C9bD86B66B;
        address portal = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;
        address wormhole = 0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78;

        vm.startBroadcast(deployer_);

        address executorEntryPoint = address(new ExecutorEntryPoint(chainId.toWormholeChainId(), executor, portal));

        vm.stopBroadcast();

        console.log("Executor Entry Point: ", executorEntryPoint);
    }
}
