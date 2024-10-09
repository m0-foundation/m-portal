// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { MToken as SpokeMToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar as SpokeRegistrar } from "../../lib/ttg/src/Registrar.sol";

import { DeployBase } from "../../script/deploy/DeployBase.sol";

contract Deploy is DeployBase, Test {
    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    function testFork_deployHub() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_DEPLOYER, 10 ether);

        vm.startPrank(_DEPLOYER);

        (address hubPortal_, address hubWormholeTransceiver_) = _deployHubComponents(
            _DEPLOYER,
            _MAINNET_REGISTRAR,
            _MAINNET_M_TOKEN,
            _MAINNET_WORMHOLE_CHAIN_ID,
            _MAINNET_WORMHOLE_CORE_BRIDGE,
            _MAINNET_WORMHOLE_RELAYER,
            address(0)
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

        (
            address baseSpokePortal_,
            address baseSpokeWormholeTransceiver_,
            address baseSpokeRegistrar_,
            address baseSpokeMToken_
        ) = _deploySpokeComponents(
                _DEPLOYER,
                _BASE_WORMHOLE_CHAIN_ID,
                _BASE_WORMHOLE_CORE_BRIDGE,
                _BASE_WORMHOLE_RELAYER,
                address(0),
                _burnNonces
            );

        vm.stopPrank();

        // Contracts addresses should be the same across all networks.
        address expectedSpokePortal_ = _getCreate3Address(_DEPLOYER, _computeSalt(_DEPLOYER, "Portal"));
        address expectedSpokeWormholeTransceiver_ = _getCreate3Address(
            _DEPLOYER,
            _computeSalt(_DEPLOYER, "WormholeTransceiver")
        );

        assertEq(baseSpokePortal_, expectedSpokePortal_);
        assertEq(baseSpokeWormholeTransceiver_, expectedSpokeWormholeTransceiver_);
        assertEq(baseSpokeRegistrar_, _MAINNET_REGISTRAR);
        assertEq(baseSpokeMToken_, _MAINNET_M_TOKEN);

        assertEq(SpokeMToken(baseSpokeMToken_).portal(), baseSpokePortal_);
        assertEq(SpokeMToken(baseSpokeMToken_).registrar(), baseSpokeRegistrar_);
        assertEq(SpokeRegistrar(baseSpokeRegistrar_).portal(), baseSpokePortal_);
    }

    function _burnNonces(address account_, uint64 startingNonce_, uint64 targetNonce_) internal {
        vm.setNonce(account_, targetNonce_);
    }
}
