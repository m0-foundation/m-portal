// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import { ContractHelper } from "../../lib/common/src/libs/ContractHelper.sol";

import { MToken as SpokeMToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar as SpokeRegistrar } from "../../lib/ttg/src/Registrar.sol";

import { Chains } from "../../script/config/Chains.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract Deploy is ForkTestBase {
    function setUp() public override {
        super.setUp();
    }

    function testFork_deployHub() external {
        vm.selectFork(_mainnetForkId);

        assertEq(_hubPortal, _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal")));
        assertEq(
            _hubWormholeTransceiver,
            _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "WormholeTransceiver"))
        );
    }

    function testFork_deployArbitrumSpoke() external {
        vm.selectFork(_arbitrumForkId);

        // Contracts addresses should be the same across all networks.
        address expectedSpokePortal_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal"));
        address expectedSpokeVault_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Vault"));
        address expectedSpokeWormholeTransceiver_ = _getCreate3Address(
            _DEPLOYER,
            _computeSalt(_DEPLOYER, "WormholeTransceiver")
        );

        address _expectedSpokeWrappedMTokenImplementation = ContractHelper.getContractFrom(_DEPLOYER, 39);
        address _expectedSpokeWrappedMTokenProxy = ContractHelper.getContractFrom(_DEPLOYER, 40);

        assertEq(_arbitrumSpokePortal, expectedSpokePortal_);
        assertEq(_arbitrumSpokeWormholeTransceiver, expectedSpokeWormholeTransceiver_);
        assertEq(_arbitrumSpokeRegistrar, _MAINNET_REGISTRAR);
        assertEq(_arbitrumSpokeMToken, _MAINNET_M_TOKEN);
        assertEq(_arbitrumSpokeVault, expectedSpokeVault_);

        assertEq(_arbitrumSpokeWrappedMTokenProxy, _expectedSpokeWrappedMTokenProxy);

        assertEq(SpokeMToken(_arbitrumSpokeMToken).portal(), _arbitrumSpokePortal);
        assertEq(SpokeMToken(_arbitrumSpokeMToken).registrar(), _arbitrumSpokeRegistrar);
        assertEq(SpokeRegistrar(_arbitrumSpokeRegistrar).portal(), _arbitrumSpokePortal);
    }

    function testFork_deployOptimismSpoke() external {
        vm.selectFork(_optimismForkId);

        // Contracts addresses should be the same across all networks.
        address expectedSpokePortal_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal"));
        address expectedSpokeVault_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Vault"));
        address expectedSpokeWormholeTransceiver_ = _getCreate3Address(
            _DEPLOYER,
            _computeSalt(_DEPLOYER, "WormholeTransceiver")
        );

        address _expectedSpokeWrappedMTokenImplementation = ContractHelper.getContractFrom(_DEPLOYER, 39);
        address _expectedSpokeWrappedMTokenProxy = ContractHelper.getContractFrom(_DEPLOYER, 40);

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
