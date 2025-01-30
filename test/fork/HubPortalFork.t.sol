// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IContinuousIndexing } from "../../lib/protocol/src/interfaces/IContinuousIndexing.sol";
import { IMToken } from "../../lib/protocol/src/interfaces/IMToken.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract HubPortalForkTests is ForkTestBase {
    using TypeConverter for *;

    function setUp() public override {
        super.setUp();
        _configurePortals();
    }

    /* ============ transfer ============ */

    function testFork_transferToSpokePortal() external {
        vm.selectFork(_baseForkId);

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), 0);

        vm.selectFork(_mainnetForkId);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.prank(_DEPLOYER);
        IPortal(_hubPortal).setDestinationMToken(_BASE_WORMHOLE_CHAIN_ID, _baseSpokeMToken.toBytes32());

        vm.startPrank(_mHolder);
        vm.recordLogs();

        uint256 amount_ = 1_000e6;

        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, amount_);

        _transfer(
            _hubPortal,
            _BASE_WORMHOLE_CHAIN_ID,
            amount_,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID)
        );

        vm.stopPrank();

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_ = amount_ - 1);

        bytes memory signedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);
        _deliverMessage(_BASE_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), amount_);
        assertEq(IContinuousIndexing(_baseSpokeMToken).currentIndex(), mainnetIndex_);
    }

    /* ============ transferMLikeToken ============ */

    function testFork_transferMLikeToken_mTokenToMToken() external {
        vm.selectFork(_baseForkId);
        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), 0);

        vm.selectFork(_mainnetForkId);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.prank(_DEPLOYER);
        IPortal(_hubPortal).setSupportedBridgingPath(
            _MAINNET_M_TOKEN,
            _BASE_WORMHOLE_CHAIN_ID,
            _baseSpokeMToken.toBytes32(),
            true
        );

        vm.startPrank(_mHolder);
        vm.recordLogs();

        uint256 amount_ = 1_000e6;

        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, amount_);
        IPortal(_hubPortal).transferMLikeToken{ value: _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID) }(
            amount_,
            _MAINNET_M_TOKEN,
            _BASE_WORMHOLE_CHAIN_ID,
            _baseSpokeMToken.toBytes32(),
            _mHolder.toBytes32(),
            _mHolder.toBytes32()
        );

        vm.stopPrank();

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_ = amount_ - 1);
        bytes memory signedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);
        _deliverMessage(_BASE_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), amount_);
        assertEq(IContinuousIndexing(_baseSpokeMToken).currentIndex(), mainnetIndex_);
    }

    function testFork_transferMLikeToken_wrappedMTokenToMToken() external {
        vm.selectFork(_baseForkId);
        assertEq(IERC20(_baseSpokeMToken).balanceOf(_wrappedMHolder), 0);

        vm.selectFork(_mainnetForkId);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.prank(_DEPLOYER);
        IPortal(_hubPortal).setSupportedBridgingPath(
            _MAINNET_WRAPPED_M_TOKEN,
            _BASE_WORMHOLE_CHAIN_ID,
            _baseSpokeMToken.toBytes32(),
            true
        );

        vm.startPrank(_wrappedMHolder);
        vm.recordLogs();

        uint256 amount_ = 1e6;
        uint256 balanceBefore_ = IERC20(_MAINNET_WRAPPED_M_TOKEN).balanceOf(_wrappedMHolder);

        IERC20(_MAINNET_WRAPPED_M_TOKEN).approve(_hubPortal, amount_);
        IPortal(_hubPortal).transferMLikeToken{ value: _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID) }(
            amount_,
            _MAINNET_WRAPPED_M_TOKEN,
            _BASE_WORMHOLE_CHAIN_ID,
            _baseSpokeMToken.toBytes32(),
            _wrappedMHolder.toBytes32(),
            _wrappedMHolder.toBytes32()
        );

        vm.stopPrank();

        assertEq(IERC20(_MAINNET_WRAPPED_M_TOKEN).balanceOf(_wrappedMHolder), balanceBefore_ - amount_);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_ = amount_ - 1);
        bytes memory signedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);
        _deliverMessage(_BASE_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_wrappedMHolder), amount_);
        assertEq(IContinuousIndexing(_baseSpokeMToken).currentIndex(), mainnetIndex_);
    }

    /* ============ sendMTokenIndex ============ */

    function testFork_sendMTokenIndex() external {
        vm.selectFork(_baseForkId);

        assertEq(IPortal(_baseSpokePortal).currentIndex(), _EXP_SCALED_ONE);
        assertEq(IContinuousIndexing(_baseSpokeMToken).currentIndex(), _EXP_SCALED_ONE);

        vm.selectFork(_mainnetForkId);

        uint128 mainnetIndex_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.startPrank(_alice);
        vm.recordLogs();

        _sendMTokenIndex(
            _hubPortal,
            _BASE_WORMHOLE_CHAIN_ID,
            _toUniversalAddress(_alice),
            _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID)
        );

        bytes memory signedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);

        _deliverMessage(_BASE_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IPortal(_baseSpokePortal).currentIndex(), mainnetIndex_);
        assertEq(IContinuousIndexing(_baseSpokeMToken).currentIndex(), mainnetIndex_);

        vm.stopPrank();
    }

    /* ============ sendRegistrarKey ============ */

    function testFork_sendRegistrarKey() external {
        vm.selectFork(_baseForkId);

        bytes32 key_ = bytes32(0xc98ccddb058ab286ae57df069c393149cce713df77fa4173b0a20cef40771dfb);
        assertEq(IRegistrarLike(_baseSpokeRegistrar).get(key_), bytes32(0));

        vm.selectFork(_mainnetForkId);

        bytes32 value_ = IRegistrarLike(_MAINNET_REGISTRAR).get(key_);

        vm.startPrank(_alice);
        vm.recordLogs();

        _sendRegistrarKey(
            _hubPortal,
            _BASE_WORMHOLE_CHAIN_ID,
            key_,
            _toUniversalAddress(_alice),
            _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID)
        );

        bytes memory signedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);

        _deliverMessage(_BASE_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IRegistrarLike(_baseSpokeRegistrar).get(key_), value_);

        vm.stopPrank();
    }

    /* ============ sendRegistrarListStatus ============ */

    function testFork_sendRegistrarListStatus() external {
        vm.selectFork(_baseForkId);

        bytes32 list_ = bytes32("earners");
        address earner_ = 0x9106CBf2C882340b23cC40985c05648173E359e7;

        assertEq(IRegistrarLike(_baseSpokeRegistrar).listContains(list_, earner_), false);

        vm.selectFork(_mainnetForkId);

        vm.startPrank(_alice);
        vm.recordLogs();

        _sendRegistrarListStatus(
            _hubPortal,
            _BASE_WORMHOLE_CHAIN_ID,
            list_,
            earner_,
            _toUniversalAddress(_alice),
            _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID)
        );

        bytes memory signedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);

        _deliverMessage(_BASE_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IRegistrarLike(_baseSpokeRegistrar).listContains(list_, earner_), true);

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
