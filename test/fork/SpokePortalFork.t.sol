// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IContinuousIndexing } from "../../lib/protocol/src/interfaces/IContinuousIndexing.sol";

import { ISpokePortal } from "../../src/interfaces/ISpokePortal.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract SpokePortalForkTests is ForkTestBase {
    uint256 internal _amount;
    uint128 internal _mainnetIndex;

    function setUp() public override {
        super.setUp();
        _configurePortals();
    }

    /* ============ transfer ============ */

    function testFork_transferToHubPortal() external {
        _beforeTest();

        vm.startPrank(_mHolder);

        IERC20(_baseSpokeMToken).approve(_baseSpokePortal, _amount);

        // Then, transfer M tokens back to the Hub chain.
        _transfer(
            _baseSpokePortal,
            _MAINNET_WORMHOLE_CHAIN_ID,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_baseSpokePortal, _MAINNET_WORMHOLE_CHAIN_ID)
        );

        vm.stopPrank();

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), 0);

        bytes memory spokeSignedMessage_ = _signMessage(_baseSpokeGuardian, _BASE_WORMHOLE_CHAIN_ID);

        vm.selectFork(_mainnetForkId);

        uint256 balanceOfBefore_ = IERC20(_MAINNET_M_TOKEN).balanceOf(_mHolder);

        _deliverMessage(_MAINNET_WORMHOLE_RELAYER, spokeSignedMessage_);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_mHolder), balanceOfBefore_ + _amount);
    }

    function testFork_transferBetweenSpokePortals() external {
        _beforeTest();

        vm.startPrank(_mHolder);

        IERC20(_baseSpokeMToken).approve(_baseSpokePortal, _amount);

        // Then, transfer M tokens to the other Spoke chain.
        _transfer(
            _baseSpokePortal,
            _OPTIMISM_WORMHOLE_CHAIN_ID,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_optimismSpokePortal, _OPTIMISM_WORMHOLE_CHAIN_ID)
        );

        vm.stopPrank();

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), 0);

        bytes memory spokeSignedMessage_ = _signMessage(_baseSpokeGuardian, _BASE_WORMHOLE_CHAIN_ID);

        vm.selectFork(_optimismForkId);

        _deliverMessage(_OPTIMISM_WORMHOLE_RELAYER, spokeSignedMessage_);

        assertEq(IERC20(_optimismSpokeMToken).balanceOf(_mHolder), _amount);
        assertEq(IContinuousIndexing(_optimismSpokeMToken).currentIndex(), _mainnetIndex);
    }

    function _beforeTest() internal {
        _amount = 1_000e6;

        // First, transfer M tokens to the Spoke chain.
        vm.selectFork(_mainnetForkId);

        _mainnetIndex = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.startPrank(_mHolder);
        vm.recordLogs();

        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, _amount);

        _transfer(
            _hubPortal,
            _BASE_WORMHOLE_CHAIN_ID,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_hubPortal, _BASE_WORMHOLE_CHAIN_ID)
        );

        vm.stopPrank();

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), _amount = _amount - 1);

        bytes memory hubSignedMessage_ = _signMessage(_hubGuardian, _MAINNET_WORMHOLE_CHAIN_ID);

        vm.selectFork(_baseForkId);

        _deliverMessage(_BASE_WORMHOLE_RELAYER, hubSignedMessage_);

        assertEq(IERC20(_baseSpokeMToken).balanceOf(_mHolder), _amount);
        assertEq(IContinuousIndexing(_baseSpokeMToken).currentIndex(), _mainnetIndex);
        assertEq(ISpokePortal(_baseSpokePortal).excess(), 0);
    }
}
