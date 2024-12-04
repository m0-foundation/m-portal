// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import { ContractHelper } from "../../lib/common/src/libs/ContractHelper.sol";

import { MToken as SpokeMToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar as SpokeRegistrar } from "../../lib/ttg/src/Registrar.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract Deploy is ForkTestBase {
    function setUp() public override {
        super.setUp();
        _configurePortals();
    }

    function testFork_deployHub() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        (address hubPortal_, address hubWormholeTransceiver_) = _deployHubComponents(
            _DEPLOYER,
            _loadHubConfig("test/fork/fixtures/deploy-config.json", block.chainid)
        );

        vm.stopPrank();

        address expectedHubPortal_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal"));
        assertEq(hubPortal_, expectedHubPortal_);

        address expectedWormholeTransceiver_ = _getCreate3Address(
            _DEPLOYER,
            _computeSalt(_DEPLOYER, "WormholeTransceiver")
        );

        assertEq(hubWormholeTransceiver_, expectedWormholeTransceiver_);
    }

    function testFork_deploySpoke() external {
        vm.createSelectFork(vm.rpcUrl("base"));

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        SpokeConfiguration memory spokeConfig_ = _loadSpokeConfig(
            "test/fork/fixtures/deploy-config.json",
            block.chainid
        );

        (
            address baseSpokePortal_,
            address baseSpokeWormholeTransceiver_,
            address baseSpokeRegistrar_,
            address baseSpokeMToken_
        ) = _deploySpokeComponents(_DEPLOYER, spokeConfig_, _burnNonces);

        (, address baseSpokeVault_) = _deploySpokeVault(
            _DEPLOYER,
            baseSpokePortal_,
            spokeConfig_.hubVault,
            spokeConfig_.hubVaultWormholechainId,
            _MIGRATION_ADMIN
        );

        (
            address baseSpokeSmartMTokenEarnerManagerImplementation_,
            address baseSpokeSmartMTokenEarnerManagerProxy_,
            address baseSpokeSmartMTokenImplementation_,
            address baseSpokeSmartMTokenProxy_
        ) = _deploySpokeSmartMToken(
                _DEPLOYER,
                baseSpokeMToken_,
                baseSpokeRegistrar_,
                baseSpokeVault_,
                _MIGRATION_ADMIN,
                _burnNonces
            );

        vm.stopPrank();

        // Contracts addresses should be the same across all networks.
        address expectedSpokePortal_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal"));
        address expectedSpokeWormholeTransceiver_ = _getCreate3Address(
            _DEPLOYER,
            _computeSalt(_DEPLOYER, "WormholeTransceiver")
        );

        address expectedSpokeVault_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Vault"));

        assertEq(baseSpokePortal_, expectedSpokePortal_);
        assertEq(baseSpokeWormholeTransceiver_, expectedSpokeWormholeTransceiver_);
        assertEq(baseSpokeRegistrar_, _MAINNET_REGISTRAR);
        assertEq(baseSpokeMToken_, _MAINNET_M_TOKEN);
        assertEq(baseSpokeVault_, expectedSpokeVault_);

        assertEq(baseSpokeSmartMTokenEarnerManagerImplementation_, ContractHelper.getContractFrom(_DEPLOYER, 37));
        assertEq(baseSpokeSmartMTokenEarnerManagerProxy_, ContractHelper.getContractFrom(_DEPLOYER, 38));
        assertEq(baseSpokeSmartMTokenImplementation_, ContractHelper.getContractFrom(_DEPLOYER, 39));
        assertEq(baseSpokeSmartMTokenProxy_, ContractHelper.getContractFrom(_DEPLOYER, 40));

        assertEq(SpokeMToken(baseSpokeMToken_).portal(), baseSpokePortal_);
        assertEq(SpokeMToken(baseSpokeMToken_).registrar(), baseSpokeRegistrar_);
        assertEq(SpokeRegistrar(baseSpokeRegistrar_).portal(), baseSpokePortal_);
    }
}
