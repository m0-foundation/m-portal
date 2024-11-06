// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { UpgradeBase } from "./UpgradeBase.sol";

contract UpgradeSpokePortal is UpgradeBase {
    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        _upgradeSpokePortal(_loadPortalConfig(vm.envString("CONFIG"), block.chainid));

        vm.stopBroadcast();
    }
}
