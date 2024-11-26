// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    ERC1967Proxy
} from "../../lib/example-native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { UpgradeBase } from "../../script/upgrade/UpgradeBase.sol";
import { ICreateXLike } from "../../script/deploy/interfaces/ICreateXLike.sol";

import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { Governor } from "../../src/governance/Governor.sol";
import { HubPortal } from "../../src/HubPortal.sol";

import { MainnetMigrator } from "./fixtures/migrator/MainnetMigrator.sol";

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

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 250_000);

        string memory config_ = "test/fork/fixtures/upgrade-config.json";
        _upgradeWormholeTransceiver(_loadWormholeConfig(config_, block.chainid));

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 300_000);

        _upgradeHubPortal(_loadPortalConfig(config_, block.chainid));

        vm.stopPrank();
    }

    function testFork_migrateViaGovernance() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        HubPortal hubPortalImplementation_ = new HubPortal(
            _MAINNET_M_TOKEN,
            _MAINNET_SMART_M_TOKEN,
            _MAINNET_REGISTRAR,
            _MAINNET_WORMHOLE_CHAIN_ID
        );

        HubPortal hubPortal_ = HubPortal(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                _computeSalt(_DEPLOYER, "Portal"),
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(hubPortalImplementation_), ""))
            )
        );

        hubPortal_.initialize();

        WormholeTransceiver wormholeTransceiverImplementation_ = new WormholeTransceiver(
            address(hubPortal_),
            _MAINNET_WORMHOLE_CORE_BRIDGE,
            _MAINNET_WORMHOLE_RELAYER,
            address(0),
            _FINALIZED_CONSISTENCY_LEVEL,
            _WORMHOLE_GAS_LIMIT
        );

        WormholeTransceiver wormholeTransceiver_ = WormholeTransceiver(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                _computeSalt(_DEPLOYER, "WormholeTransceiver"),
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(address(wormholeTransceiverImplementation_), "")
                )
            )
        );

        wormholeTransceiver_.initialize();

        IManagerBase(hubPortal_).setTransceiver(address(wormholeTransceiver_));
        INttManager(hubPortal_).setThreshold(1);

        Governor governor_ = new Governor(address(hubPortal_), _governorAdmin);
        address migrator_ = address(
            new MainnetMigrator(address(hubPortal_), address(wormholeTransceiver_), address(_spokeVault))
        );

        hubPortal_.transferOwnership(address(governor_));

        vm.stopPrank();

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 250_000);

        vm.mockCall(
            _MAINNET_REGISTRAR,
            abi.encodeWithSelector(IRegistrarLike.get.selector, bytes32("portal_migrator")),
            abi.encode(bytes32(uint256(uint160(migrator_))))
        );

        // Anyone can call migrate().
        governor_.migrate();

        assertEq(WormholeTransceiver(_hubWormholeTransceiver).gasLimit(), 300_000);
    }
}
