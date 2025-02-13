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

import { UpgradeBase } from "../../script/upgrade/UpgradeBase.sol";
import { ICreateXLike } from "../../script/deploy/interfaces/ICreateXLike.sol";

import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { HubPortal } from "../../src/HubPortal.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract Migrate is ForkTestBase, UpgradeBase {
    // TODO: replace by the actual multisig address.
    address internal _governorAdmin = makeAddr("governor-admin");

    // TODO: replace with actual vault address.
    address internal _spokeVault = makeAddr("spoke-vault");

    function testFork_migrate() external {
        vm.selectFork(_mainnetForkId);

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 300_000);

        string memory config_ = "test/fork/fixtures/upgrade-config.json";
        _upgradeWormholeTransceiver(_loadWormholeConfig(config_, block.chainid));

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 350_000);

        _upgradeHubPortal(_loadPortalConfig(config_, block.chainid));

        vm.stopPrank();
    }
}
