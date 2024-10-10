// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { UpgradeBase } from "../UpgradeBase.sol";

contract UpgradePortalDev is UpgradeBase {
    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));

        if (block.chainid == _SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();

            _upgradeHubPortal(
                deployer_,
                PortalUpgradeParams({
                    mToken: _SEPOLIA_M_TOKEN,
                    registrar: _SEPOLIA_REGISTRAR,
                    wormholeChainId: _SEPOLIA_WORMHOLE_CHAIN_ID
                })
            );

            vm.stopBroadcast();
        } else if (block.chainid == _BASE_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();
            _upgradeSpokePortal(
                deployer_,
                PortalUpgradeParams({
                    mToken: computeCreateAddress(deployer_, _SPOKE_M_TOKEN_NONCE),
                    registrar: computeCreateAddress(deployer_, _SPOKE_REGISTRAR_NONCE),
                    wormholeChainId: _BASE_SEPOLIA_WORMHOLE_CHAIN_ID
                })
            );

            vm.stopBroadcast();
        } else if (block.chainid == _OPTIMISM_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();

            _upgradeSpokePortal(
                deployer_,
                PortalUpgradeParams({
                    mToken: computeCreateAddress(deployer_, _SPOKE_M_TOKEN_NONCE),
                    registrar: computeCreateAddress(deployer_, _SPOKE_REGISTRAR_NONCE),
                    wormholeChainId: _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID
                })
            );

            vm.stopBroadcast();
        }
    }
}
