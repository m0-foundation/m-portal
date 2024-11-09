// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { UpgradeBase } from "./UpgradeBase.sol";

contract UpgradeHubPortal is UpgradeBase {
    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        _upgradeHubPortal(_loadPortalConfig(vm.envString("CONFIG"), block.chainid));

        vm.stopBroadcast();
    }
}
