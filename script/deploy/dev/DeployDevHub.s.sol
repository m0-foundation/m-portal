// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Script.sol";

import { DeployBase } from "../DeployBase.sol";

contract DeployDevHub is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        (address hubNTTManager_, address hubWormholeTransceiver_) = _deployHubComponents(
            deployer_,
            _SEPOLIA_REGISTRAR,
            _SEPOLIA_M_TOKEN,
            _SEPOLIA_WORMHOLE_CHAIN_ID,
            _SEPOLIA_WORMHOLE_CORE_BRIDGE,
            _SEPOLIA_WORMHOLE_RELAYER,
            address(0)
        );

        vm.stopBroadcast();

        console2.log("Sepolia Hub NTT Manager address:", hubNTTManager_);
        console2.log("Sepolia Hub Wormhole Transceiver address:", hubWormholeTransceiver_);
    }
}
