// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IWormholeTransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { Chains } from "../../script/config/Chains.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract Configure is ForkTestBase {
    using TypeConverter for *;

    function setUp() public override {
        super.setUp();
    }

    /// @dev Checks that peers were configured correctly for Hub
    function testFork_configure_hub() external {
        vm.selectFork(_mainnetForkId);

        IWormholeTransceiver transceiver_ = IWormholeTransceiver(_hubWormholeTransceiver);
        INttManager ntt_ = INttManager(_hubPortal);
        IPortal portal_ = IPortal(_hubPortal);

        assertEq(transceiver_.isWormholeEvmChain(Chains.WORMHOLE_ARBITRUM), true);
        assertEq(transceiver_.isWormholeEvmChain(Chains.WORMHOLE_OPTIMISM), true);

        assertEq(transceiver_.isWormholeRelayingEnabled(Chains.WORMHOLE_ARBITRUM), true);
        assertEq(transceiver_.isWormholeRelayingEnabled(Chains.WORMHOLE_OPTIMISM), true);

        assertEq(transceiver_.isSpecialRelayingEnabled(Chains.WORMHOLE_ARBITRUM), false);
        assertEq(transceiver_.isSpecialRelayingEnabled(Chains.WORMHOLE_OPTIMISM), false);

        assertEq(transceiver_.getWormholePeer(Chains.WORMHOLE_ARBITRUM), _arbitrumSpokeWormholeTransceiver.toBytes32());
        assertEq(transceiver_.getWormholePeer(Chains.WORMHOLE_OPTIMISM), _optimismSpokeWormholeTransceiver.toBytes32());

        assertEq(ntt_.getPeer(Chains.WORMHOLE_ARBITRUM).peerAddress, _arbitrumSpokePortal.toBytes32());
        assertEq(ntt_.getPeer(Chains.WORMHOLE_OPTIMISM).peerAddress, _optimismSpokePortal.toBytes32());

        assertEq(ntt_.getPeer(Chains.WORMHOLE_ARBITRUM).tokenDecimals, _M_TOKEN_DECIMALS);
        assertEq(ntt_.getPeer(Chains.WORMHOLE_OPTIMISM).tokenDecimals, _M_TOKEN_DECIMALS);

        assertEq(portal_.destinationMToken(Chains.WORMHOLE_ARBITRUM), _arbitrumSpokeMToken.toBytes32());
        assertEq(portal_.destinationMToken(Chains.WORMHOLE_OPTIMISM), _optimismSpokeMToken.toBytes32());

        assertEq(
            portal_.supportedBridgingPath(_MAINNET_M_TOKEN, Chains.WORMHOLE_ARBITRUM, _arbitrumSpokeMToken.toBytes32()),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _MAINNET_WRAPPED_M_TOKEN,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeMToken.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _MAINNET_M_TOKEN,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _MAINNET_WRAPPED_M_TOKEN,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );

        assertEq(
            portal_.supportedBridgingPath(_MAINNET_M_TOKEN, Chains.WORMHOLE_OPTIMISM, _optimismSpokeMToken.toBytes32()),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _MAINNET_WRAPPED_M_TOKEN,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeMToken.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _MAINNET_M_TOKEN,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _MAINNET_WRAPPED_M_TOKEN,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
    }

    /// @dev Checks that peers were configured correctly for Arbitrum Spoke
    function testFork_configure_arbitrumSpoke() external {
        vm.selectFork(_arbitrumForkId);

        IWormholeTransceiver transceiver_ = IWormholeTransceiver(_arbitrumSpokeWormholeTransceiver);
        INttManager ntt_ = INttManager(_arbitrumSpokePortal);
        IPortal portal_ = IPortal(_arbitrumSpokePortal);

        assertEq(transceiver_.isWormholeEvmChain(Chains.WORMHOLE_ETHEREUM), true);
        assertEq(transceiver_.isWormholeEvmChain(Chains.WORMHOLE_OPTIMISM), true);

        assertEq(transceiver_.isWormholeRelayingEnabled(Chains.WORMHOLE_ETHEREUM), true);
        assertEq(transceiver_.isWormholeRelayingEnabled(Chains.WORMHOLE_OPTIMISM), true);

        assertEq(transceiver_.isSpecialRelayingEnabled(Chains.WORMHOLE_ETHEREUM), false);
        assertEq(transceiver_.isSpecialRelayingEnabled(Chains.WORMHOLE_OPTIMISM), false);

        assertEq(transceiver_.getWormholePeer(Chains.WORMHOLE_ETHEREUM), _hubWormholeTransceiver.toBytes32());
        assertEq(transceiver_.getWormholePeer(Chains.WORMHOLE_OPTIMISM), _optimismSpokeWormholeTransceiver.toBytes32());

        assertEq(ntt_.getPeer(Chains.WORMHOLE_ETHEREUM).peerAddress, _hubPortal.toBytes32());
        assertEq(ntt_.getPeer(Chains.WORMHOLE_OPTIMISM).peerAddress, _optimismSpokePortal.toBytes32());

        assertEq(ntt_.getPeer(Chains.WORMHOLE_ETHEREUM).tokenDecimals, _M_TOKEN_DECIMALS);
        assertEq(ntt_.getPeer(Chains.WORMHOLE_OPTIMISM).tokenDecimals, _M_TOKEN_DECIMALS);

        assertEq(portal_.destinationMToken(Chains.WORMHOLE_ETHEREUM), _MAINNET_M_TOKEN.toBytes32());
        assertEq(portal_.destinationMToken(Chains.WORMHOLE_OPTIMISM), _optimismSpokeMToken.toBytes32());

        assertEq(
            portal_.supportedBridgingPath(_arbitrumSpokeMToken, Chains.WORMHOLE_ETHEREUM, _MAINNET_M_TOKEN.toBytes32()),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_ETHEREUM,
                _MAINNET_M_TOKEN.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeMToken,
                Chains.WORMHOLE_ETHEREUM,
                _MAINNET_WRAPPED_M_TOKEN.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_ETHEREUM,
                _MAINNET_WRAPPED_M_TOKEN.toBytes32()
            ),
            true
        );

        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeMToken,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeMToken.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeMToken.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeMToken,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_OPTIMISM,
                _optimismSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
    }

    /// @dev Checks that peers were configured correctly for Optimism Spoke
    function testFork_configure_optimismSpoke() external {
        vm.selectFork(_optimismForkId);

        IWormholeTransceiver transceiver_ = IWormholeTransceiver(_optimismSpokeWormholeTransceiver);
        INttManager ntt_ = INttManager(_optimismSpokePortal);
        IPortal portal_ = IPortal(_optimismSpokePortal);

        assertEq(transceiver_.isWormholeEvmChain(Chains.WORMHOLE_ETHEREUM), true);
        assertEq(transceiver_.isWormholeEvmChain(Chains.WORMHOLE_ARBITRUM), true);

        assertEq(transceiver_.isWormholeRelayingEnabled(Chains.WORMHOLE_ETHEREUM), true);
        assertEq(transceiver_.isWormholeRelayingEnabled(Chains.WORMHOLE_ARBITRUM), true);

        assertEq(transceiver_.isSpecialRelayingEnabled(Chains.WORMHOLE_ETHEREUM), false);
        assertEq(transceiver_.isSpecialRelayingEnabled(Chains.WORMHOLE_ARBITRUM), false);

        assertEq(transceiver_.getWormholePeer(Chains.WORMHOLE_ETHEREUM), _hubWormholeTransceiver.toBytes32());
        assertEq(transceiver_.getWormholePeer(Chains.WORMHOLE_ARBITRUM), _arbitrumSpokeWormholeTransceiver.toBytes32());

        assertEq(ntt_.getPeer(Chains.WORMHOLE_ETHEREUM).peerAddress, _hubPortal.toBytes32());
        assertEq(ntt_.getPeer(Chains.WORMHOLE_ARBITRUM).peerAddress, _arbitrumSpokePortal.toBytes32());

        assertEq(ntt_.getPeer(Chains.WORMHOLE_ETHEREUM).tokenDecimals, _M_TOKEN_DECIMALS);
        assertEq(ntt_.getPeer(Chains.WORMHOLE_ARBITRUM).tokenDecimals, _M_TOKEN_DECIMALS);

        assertEq(portal_.destinationMToken(Chains.WORMHOLE_ETHEREUM), _MAINNET_M_TOKEN.toBytes32());
        assertEq(portal_.destinationMToken(Chains.WORMHOLE_ARBITRUM), _arbitrumSpokeMToken.toBytes32());

        assertEq(
            portal_.supportedBridgingPath(_optimismSpokeMToken, Chains.WORMHOLE_ETHEREUM, _MAINNET_M_TOKEN.toBytes32()),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _optimismSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_ETHEREUM,
                _MAINNET_M_TOKEN.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _optimismSpokeMToken,
                Chains.WORMHOLE_ETHEREUM,
                _MAINNET_WRAPPED_M_TOKEN.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _optimismSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_ETHEREUM,
                _MAINNET_WRAPPED_M_TOKEN.toBytes32()
            ),
            true
        );

        assertEq(
            portal_.supportedBridgingPath(
                _optimismSpokeMToken,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeMToken.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeMToken.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _optimismSpokeMToken,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
        assertEq(
            portal_.supportedBridgingPath(
                _arbitrumSpokeWrappedMTokenProxy,
                Chains.WORMHOLE_ARBITRUM,
                _arbitrumSpokeWrappedMTokenProxy.toBytes32()
            ),
            true
        );
    }
}
