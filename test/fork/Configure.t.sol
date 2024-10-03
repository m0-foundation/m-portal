// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    ERC1967Proxy
} from "../../lib/example-native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { ConfigureBase } from "../../script/configure/ConfigureBase.sol";
import { ICreateXLike } from "../../script/deploy/interfaces/ICreateXLike.sol";

import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";

contract Configure is ConfigureBase, Test {
    address internal constant _CONFIGURER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    function testFork_configure() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_CONFIGURER, 10 ether);

        vm.startPrank(_CONFIGURER);

        HubPortal hubPortalImplementation_ = new HubPortal(
            _MAINNET_M_TOKEN,
            _MAINNET_REGISTRAR,
            _MAINNET_WORMHOLE_CHAIN_ID
        );

        HubPortal hubPortal_ = HubPortal(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                _computeSalt(_CONFIGURER, "Portal"),
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(hubPortalImplementation_), ""))
            )
        );

        hubPortal_.initialize();

        WormholeTransceiver wormholeTransceiverImplementation_ = new WormholeTransceiver(
            address(hubPortal_),
            _MAINNET_WORMHOLE_CORE_BRIDGE,
            _MAINNET_WORMHOLE_RELAYER,
            address(0),
            _INSTANT_CONSISTENCY_LEVEL,
            _MIN_WORMHOLE_GAS_LIMIT
        );

        WormholeTransceiver wormholeTransceiver_ = WormholeTransceiver(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                _computeSalt(_CONFIGURER, "WormholeTransceiver"),
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(address(wormholeTransceiverImplementation_), "")
                )
            )
        );

        wormholeTransceiver_.initialize();

        bytes32 portalUniversalAddress_ = _toUniversalAddress(address(hubPortal_));
        bytes32 wormholeTransceiverUniversalAddress_ = _toUniversalAddress(address(wormholeTransceiver_));

        ChainConfig[] memory config_ = new ChainConfig[](3);
        ChainConfig memory mainnetConfig_ = ChainConfig({
            chainId: _MAINNET_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        config_[0] = mainnetConfig_;

        ChainConfig memory baseConfig_ = ChainConfig({
            chainId: _BASE_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        config_[1] = baseConfig_;

        ChainConfig memory optimismConfig_ = ChainConfig({
            chainId: _OPTIMISM_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        config_[2] = optimismConfig_;

        _configureWormholeTransceiver(IWormholeTransceiver(wormholeTransceiver_), config_, _MAINNET_WORMHOLE_CHAIN_ID);

        assertEq(wormholeTransceiver_.isWormholeRelayingEnabled(_BASE_WORMHOLE_CHAIN_ID), true);
        assertEq(wormholeTransceiver_.isWormholeRelayingEnabled(_OPTIMISM_WORMHOLE_CHAIN_ID), true);

        // Same address across all networks.
        assertEq(wormholeTransceiver_.getWormholePeer(_BASE_WORMHOLE_CHAIN_ID), wormholeTransceiverUniversalAddress_);

        assertEq(
            wormholeTransceiver_.getWormholePeer(_OPTIMISM_WORMHOLE_CHAIN_ID),
            wormholeTransceiverUniversalAddress_
        );

        assertEq(wormholeTransceiver_.isWormholeEvmChain(_BASE_WORMHOLE_CHAIN_ID), true);
        assertEq(wormholeTransceiver_.isWormholeEvmChain(_OPTIMISM_WORMHOLE_CHAIN_ID), true);

        _configurePortal(INttManager(hubPortal_), config_, _MAINNET_WORMHOLE_CHAIN_ID);

        assertEq(hubPortal_.getPeer(_BASE_WORMHOLE_CHAIN_ID).peerAddress, portalUniversalAddress_);
        assertEq(hubPortal_.getPeer(_BASE_WORMHOLE_CHAIN_ID).tokenDecimals, _M_TOKEN_DECIMALS);
        assertEq(hubPortal_.getPeer(_OPTIMISM_WORMHOLE_CHAIN_ID).peerAddress, portalUniversalAddress_);
        assertEq(hubPortal_.getPeer(_OPTIMISM_WORMHOLE_CHAIN_ID).tokenDecimals, _M_TOKEN_DECIMALS);

        vm.stopPrank();
    }
}
