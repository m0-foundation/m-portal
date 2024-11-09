// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { UpgradeBase } from "./UpgradeBase.sol";

contract UpgradeWormholeTransceiver is UpgradeBase {
    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        _upgradeWormholeTransceiver(_loadWormholeConfig(vm.envString("CONFIG"), block.chainid));

        vm.stopBroadcast();
    }
}
