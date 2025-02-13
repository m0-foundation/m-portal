// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    ERC1967Proxy
} from "../../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IWormholeTransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { ConfigureBase } from "../../script/configure/ConfigureBase.sol";
import { ICreateXLike } from "../../script/deploy/interfaces/ICreateXLike.sol";

import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { HubPortal } from "../../src/HubPortal.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract Configure is ForkTestBase {
    // TODO: replace by the actual multisig address.
    address internal _governorAdmin = makeAddr("governor-admin");

    function testFork_configure() external {
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
            _INSTANT_CONSISTENCY_LEVEL,
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

        ChainConfig[] memory chainsConfig_ = _loadChainConfig(
            "test/fork/fixtures/configure-config.json",
            block.chainid
        );

        uint256 chainsConfigLength_ = chainsConfig_.length;

        for (uint256 i_; i_ < chainsConfigLength_; ++i_) {
            ChainConfig memory chainConfig_ = chainsConfig_[i_];

            console.log("block.chainid: %s", block.chainid);

            if (chainConfig_.chainId == block.chainid) {
                _configureWormholeTransceiver(
                    IWormholeTransceiver(chainConfig_.wormholeTransceiver),
                    chainsConfig_,
                    chainConfig_.wormholeChainId
                );

                _configurePortal(INttManager(chainConfig_.portal), chainsConfig_, chainConfig_.wormholeChainId);
            }
        }

        bytes32 portalUniversalAddress_ = _toUniversalAddress(address(hubPortal_));
        bytes32 wormholeTransceiverUniversalAddress_ = _toUniversalAddress(address(wormholeTransceiver_));

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

        assertEq(hubPortal_.getPeer(_BASE_WORMHOLE_CHAIN_ID).peerAddress, portalUniversalAddress_);
        assertEq(hubPortal_.getPeer(_BASE_WORMHOLE_CHAIN_ID).tokenDecimals, _M_TOKEN_DECIMALS);
        assertEq(hubPortal_.getPeer(_OPTIMISM_WORMHOLE_CHAIN_ID).peerAddress, portalUniversalAddress_);
        assertEq(hubPortal_.getPeer(_OPTIMISM_WORMHOLE_CHAIN_ID).tokenDecimals, _M_TOKEN_DECIMALS);

        vm.stopPrank();
    }
}
