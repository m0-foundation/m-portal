// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    ERC1967Proxy
} from "../../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { Chains } from "../../script/config/Chains.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../../script/config/WormholeConfig.sol";
import { UpgradeBase } from "../../script/upgrade/UpgradeBase.sol";
import { ICreateXLike } from "../../script/deploy/interfaces/ICreateXLike.sol";

import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { HubPortal } from "../../src/HubPortal.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract Migrate is ForkTestBase, UpgradeBase {
    function testFork_migrate_hubPortal() external {
        vm.selectFork(_mainnetForkId);

        vm.startPrank(_DEPLOYER);

        _upgradeHubPortal(_hubPortal, _MAINNET_M_TOKEN, _MAINNET_REGISTRAR, Chains.WORMHOLE_ETHEREUM);

        vm.stopPrank();
    }

    function testFork_migrate_spokePortal() external {
        vm.selectFork(_arbitrumForkId);

        vm.startPrank(_DEPLOYER);

        _upgradeSpokePortal(
            _arbitrumSpokePortal,
            _arbitrumSpokeMToken,
            _arbitrumSpokeRegistrar,
            Chains.WORMHOLE_ARBITRUM
        );

        vm.stopPrank();
    }

    function testFork_migrate_wormholeTransceiver() external {
        vm.selectFork(_mainnetForkId);

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 300_000);

        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(
            block.chainid
        );
        transceiverConfig_.gasLimit = 350_000;

        vm.startPrank(_DEPLOYER);
        _upgradeWormholeTransceiver(_hubPortal, _hubWormholeTransceiver, transceiverConfig_);
        vm.stopPrank();

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 350_000);
    }
}
