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
        vm.selectFork(_forkIds[0]);

        assertEq(_hubPortal, _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal")));
        assertEq(
            _hubWormholeTransceiver,
            _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "WormholeTransceiver"))
        );
    }

    function testFork_deploySpoke() external {
        vm.selectFork(_forkIds[1]);

        // Contracts addresses should be the same across all networks.
        address expectedSpokePortal_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal"));
        address expectedSpokeVault_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Vault"));
        address expectedSpokeWormholeTransceiver_ = _getCreate3Address(
            _DEPLOYER,
            _computeSalt(_DEPLOYER, "WormholeTransceiver")
        );

        address _expectedSpokeWrappedMTokenImplementation = ContractHelper.getContractFrom(_DEPLOYER, 37);
        address _expectedSpokeWrappedMTokenProxy = ContractHelper.getContractFrom(_DEPLOYER, 38);

        assertEq(_baseSpokePortal, expectedSpokePortal_);
        assertEq(_baseSpokeWormholeTransceiver, expectedSpokeWormholeTransceiver_);
        assertEq(_baseSpokeRegistrar, _MAINNET_REGISTRAR);
        assertEq(_baseSpokeMToken, _MAINNET_M_TOKEN);
        assertEq(_baseSpokeVault, expectedSpokeVault_);

        assertEq(_baseSpokeWrappedMTokenProxy, _expectedSpokeWrappedMTokenProxy);

        assertEq(SpokeMToken(_baseSpokeMToken).portal(), _baseSpokePortal);
        assertEq(SpokeMToken(_baseSpokeMToken).registrar(), _baseSpokeRegistrar);
        assertEq(SpokeRegistrar(_baseSpokeRegistrar).portal(), _baseSpokePortal);

        vm.selectFork(_forkIds[2]);

        assertEq(_optimismSpokePortal, expectedSpokePortal_);
        assertEq(_optimismSpokeWormholeTransceiver, expectedSpokeWormholeTransceiver_);
        assertEq(_optimismSpokeRegistrar, _MAINNET_REGISTRAR);
        assertEq(_optimismSpokeMToken, _MAINNET_M_TOKEN);
        assertEq(_optimismSpokeVault, expectedSpokeVault_);

        assertEq(_optimismSpokeWrappedMTokenImplementation, _expectedSpokeWrappedMTokenImplementation);
        assertEq(_optimismSpokeWrappedMTokenProxy, _expectedSpokeWrappedMTokenProxy);

        assertEq(SpokeMToken(_optimismSpokeMToken).portal(), _optimismSpokePortal);
        assertEq(SpokeMToken(_optimismSpokeMToken).registrar(), _optimismSpokeRegistrar);
        assertEq(SpokeRegistrar(_optimismSpokeRegistrar).portal(), _optimismSpokePortal);
    }
}
