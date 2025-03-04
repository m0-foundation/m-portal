// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IContinuousIndexing } from "../../lib/protocol/src/interfaces/IContinuousIndexing.sol";
import { IMToken } from "../../lib/protocol/src/interfaces/IMToken.sol";

import { Chains } from "../../script/config/Chains.sol";
import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract HubPortalForkTests is ForkTestBase {
    using TypeConverter for *;

    /* ============ transfer ============ */

    function testFork_transferToSpokePortal() external {
        vm.selectFork(_arbitrumForkId);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), 0);

        vm.selectFork(_mainnetForkId);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.startPrank(_mHolder);
        vm.recordLogs();

        uint256 amount_ = 1_000e6;

        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, amount_);

        _transfer(
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM,
            amount_,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM)
        );

        vm.stopPrank();

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_ = amount_ - 1);

        bytes memory signedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);

        vm.selectFork(_arbitrumForkId);
        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), amount_);
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), mainnetIndex_);
    }

    /* ============ transferMLikeToken ============ */

    /// @dev From $M on Hub to $M on Spoke
    function testFork_transferMLikeToken_M_to_M() external {
        _transferMLikeTokenToSpoke(_MAINNET_M_TOKEN, _arbitrumSpokeMToken, _mHolder);
    }

    /// @dev From $M on Hub to Wrapped $M on Spoke
    function testFork_transferMLikeToken_M_to_wrappedM() external {
        _transferMLikeTokenToSpoke(_MAINNET_M_TOKEN, _arbitrumSpokeWrappedMTokenProxy, _mHolder);
    }

    /// @dev From Wrapped $M on Hub to $M on Spoke
    function testFork_transferMLikeToken_wrappedM_to_M() external {
        _transferMLikeTokenToSpoke(_MAINNET_WRAPPED_M_TOKEN, _arbitrumSpokeMToken, _wrappedMHolder);
    }

    /// @dev From Wrapped $M on Hub to Wrapped $M on Spoke
    function testFork_transferMLikeToken_wrappedM_to_wrappedM() external {
        _transferMLikeTokenToSpoke(_MAINNET_WRAPPED_M_TOKEN, _arbitrumSpokeWrappedMTokenProxy, _wrappedMHolder);
    }

    function _transferMLikeTokenToSpoke(address sourceToken_, address destinationToken_, address user_) private {
        deal(user_, 1 ether);
        // User doesn't have destination token
        vm.selectFork(_arbitrumForkId);
        assertEq(IERC20(destinationToken_).balanceOf(user_), 0);

        // Hub portal doesn't have $M locked
        vm.selectFork(_mainnetForkId);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();
        uint256 amount_ = 1e6;

        // Deployer sets supported path
        vm.prank(_DEPLOYER);
        IPortal(_hubPortal).setSupportedBridgingPath(
            sourceToken_,
            Chains.WORMHOLE_ARBITRUM,
            destinationToken_.toBytes32(),
            true
        );

        // Recording logs for Wormhole simulation
        vm.recordLogs();

        // User approves source token and calls transferMLikeToken
        vm.startPrank(user_);
        IERC20(sourceToken_).approve(_hubPortal, amount_);
        IPortal(_hubPortal).transferMLikeToken{ value: _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM) }(
            amount_,
            sourceToken_,
            Chains.WORMHOLE_ARBITRUM,
            destinationToken_.toBytes32(),
            user_.toBytes32(),
            user_.toBytes32()
        );
        vm.stopPrank();

        // amount is decreased due to the rounding errors when transferring M from non-earner
        amount_ = amount_ - 1;
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_);

        // Wormhole delivers message
        bytes memory signedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);
        vm.selectFork(_arbitrumForkId);
        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, signedMessage_);

        // User receives destination token
        assertEq(IERC20(destinationToken_).balanceOf(user_), amount_);

        // Spoke M index updated
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), mainnetIndex_);
    }

    /* ============ sendMTokenIndex ============ */

    function testFork_sendMTokenIndex() external {
        vm.selectFork(_arbitrumForkId);

        assertEq(IPortal(_arbitrumSpokePortal).currentIndex(), _EXP_SCALED_ONE);
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), _EXP_SCALED_ONE);

        vm.selectFork(_mainnetForkId);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.startPrank(_alice);
        vm.recordLogs();

        _sendMTokenIndex(
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM,
            _toUniversalAddress(_alice),
            _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM)
        );

        bytes memory signedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);

        vm.selectFork(_arbitrumForkId);

        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IPortal(_arbitrumSpokePortal).currentIndex(), mainnetIndex_);
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), mainnetIndex_);

        vm.stopPrank();
    }

    /* ============ sendRegistrarKey ============ */

    function testFork_sendRegistrarKey() external {
        vm.selectFork(_arbitrumForkId);

        bytes32 key_ = bytes32(0xc98ccddb058ab286ae57df069c393149cce713df77fa4173b0a20cef40771dfb);
        assertEq(IRegistrarLike(_arbitrumSpokeRegistrar).get(key_), bytes32(0));

        vm.selectFork(_mainnetForkId);

        bytes32 value_ = IRegistrarLike(_MAINNET_REGISTRAR).get(key_);

        vm.startPrank(_alice);
        vm.recordLogs();

        _sendRegistrarKey(
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM,
            key_,
            _toUniversalAddress(_alice),
            _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM)
        );

        bytes memory signedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);

        vm.selectFork(_arbitrumForkId);

        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IRegistrarLike(_arbitrumSpokeRegistrar).get(key_), value_);

        vm.stopPrank();
    }

    /* ============ sendRegistrarListStatus ============ */

    function testFork_sendRegistrarListStatus() external {
        vm.selectFork(_arbitrumForkId);

        bytes32 list_ = bytes32("earners");
        address earner_ = 0x9106CBf2C882340b23cC40985c05648173E359e7;

        assertEq(IRegistrarLike(_arbitrumSpokeRegistrar).listContains(list_, earner_), false);

        vm.selectFork(_mainnetForkId);

        vm.startPrank(_alice);
        vm.recordLogs();

        _sendRegistrarListStatus(
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM,
            list_,
            earner_,
            _toUniversalAddress(_alice),
            _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM)
        );

        bytes memory signedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);

        vm.selectFork(_arbitrumForkId);

        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IRegistrarLike(_arbitrumSpokeRegistrar).listContains(list_, earner_), true);

        vm.stopPrank();
    }

    /* ============ disableEarning ============ */

    function testFork_disableEarning() external {
        vm.selectFork(_mainnetForkId);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();
        assertEq(IHubPortal(_hubPortal).currentIndex(), mainnetIndex_);

        // Disable earning for the Hub Portal
        vm.mockCall(
            _MAINNET_REGISTRAR,
            abi.encodeWithSelector(IRegistrarLike.listContains.selector, bytes32("earners"), _hubPortal),
            abi.encode(false)
        );

        IHubPortal(_hubPortal).disableEarning();

        // Move forward by 7 days
        vm.warp(block.timestamp + 604800);

        assertEq(IHubPortal(_hubPortal).currentIndex(), mainnetIndex_);
        assertGt(IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex(), IHubPortal(_hubPortal).currentIndex());
    }

    function testFork_disableEarning_approvedEarner() external {
        vm.selectFork(_mainnetForkId);

        vm.expectRevert(abi.encodeWithSelector(IMToken.IsApprovedEarner.selector));

        IHubPortal(_hubPortal).disableEarning();
    }
}
