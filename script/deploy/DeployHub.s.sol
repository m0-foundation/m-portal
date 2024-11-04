// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { DeployBase } from "./DeployBase.sol";

contract DeployHub is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        _deployHubComponents(deployer_, _loadHubConfig(vm.envString("CONFIG"), block.chainid));

        vm.stopBroadcast();
    }
}
