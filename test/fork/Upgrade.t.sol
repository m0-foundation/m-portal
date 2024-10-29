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

contract Upgrade is UpgradeBase, Test {
    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    // TODO: replace by the actual multisig address.
    address internal _governorAdmin = makeAddr("governor-admin");

    function testFork_upgrade() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        HubPortal hubPortalImplementation_ = new HubPortal(
            _MAINNET_M_TOKEN,
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

        assertEq(wormholeTransceiver_.gasLimit(), _WORMHOLE_GAS_LIMIT);

        _upgradeWormholeTransceiver(
            _DEPLOYER,
            WormholeTransceiverUpgradeParams({
                wormholeChainId: _MAINNET_WORMHOLE_CHAIN_ID,
                wormholeCoreBridge: _MAINNET_WORMHOLE_CORE_BRIDGE,
                wormholeRelayerAddr: _MAINNET_WORMHOLE_RELAYER,
                specialRelayerAddr: address(0),
                consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                gasLimit: 250_000
            })
        );

        assertEq(wormholeTransceiver_.gasLimit(), 250_000);

        _upgradeHubPortal(
            _DEPLOYER,
            PortalUpgradeParams({
                mToken: _MAINNET_M_TOKEN,
                registrar: _MAINNET_REGISTRAR,
                wormholeChainId: _MAINNET_WORMHOLE_CHAIN_ID
            })
        );

        vm.stopPrank();
    }

    function testFork_upgradeViaGovernance() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        HubPortal hubPortalImplementation_ = new HubPortal(
            _MAINNET_M_TOKEN,
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
            _MIN_WORMHOLE_GAS_LIMIT
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
        address migrator_ = address(new MainnetMigrator(address(hubPortal_), address(wormholeTransceiver_)));

        hubPortal_.transferOwnership(address(governor_));

        vm.stopPrank();

        assertEq(wormholeTransceiver_.gasLimit(), _MIN_WORMHOLE_GAS_LIMIT);

        vm.mockCall(
            _MAINNET_REGISTRAR,
            abi.encodeWithSelector(IRegistrarLike.get.selector, bytes32("portal_migrator")),
            abi.encode(bytes32(uint256(uint160(migrator_))))
        );

        // Anyone can call upgrade().
        governor_.upgrade();

        assertEq(wormholeTransceiver_.gasLimit(), _WORMHOLE_GAS_LIMIT);
    }
}
