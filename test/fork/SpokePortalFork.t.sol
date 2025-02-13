// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IContinuousIndexing } from "../../lib/protocol/src/interfaces/IContinuousIndexing.sol";

import { Chains } from "../../script/config/Chains.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { ISpokePortal } from "../../src/interfaces/ISpokePortal.sol";
import { IWrappedMTokenLike } from "../../src/interfaces/IWrappedMTokenLike.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract SpokePortalForkTests is ForkTestBase {
    using TypeConverter for *;
    uint256 internal _amount;
    uint128 internal _mainnetIndex;

    function setUp() public override {
        super.setUp();
    }

    /* ============ transfer ============ */

    function testFork_transferToHubPortal() external {
        _beforeTest();

        vm.prank(_DEPLOYER);
        IPortal(_arbitrumSpokePortal).setDestinationMToken(Chains.WORMHOLE_ETHEREUM, _MAINNET_M_TOKEN.toBytes32());

        vm.startPrank(_mHolder);

        IERC20(_arbitrumSpokeMToken).approve(_arbitrumSpokePortal, _amount);

        // Then, transfer M tokens back to the Hub chain.
        _transfer(
            _arbitrumSpokePortal,
            Chains.WORMHOLE_ETHEREUM,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_arbitrumSpokePortal, Chains.WORMHOLE_ETHEREUM)
        );

        vm.stopPrank();

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), 0);

        bytes memory spokeSignedMessage_ = _signMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM);

        vm.selectFork(_mainnetForkId);

        uint256 balanceOfBefore_ = IERC20(_MAINNET_M_TOKEN).balanceOf(_mHolder);

        _deliverMessage(_MAINNET_WORMHOLE_RELAYER, spokeSignedMessage_);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_mHolder), balanceOfBefore_ + _amount);
    }

    function testFork_transferBetweenSpokePortals() external {
        _beforeTest();

        vm.prank(_DEPLOYER);
        IPortal(_arbitrumSpokePortal).setDestinationMToken(Chains.WORMHOLE_OPTIMISM, _optimismSpokeMToken.toBytes32());

        vm.startPrank(_mHolder);

        IERC20(_arbitrumSpokeMToken).approve(_arbitrumSpokePortal, _amount);

        // Then, transfer M tokens to the other Spoke chain.
        _transfer(
            _arbitrumSpokePortal,
            Chains.WORMHOLE_OPTIMISM,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_optimismSpokePortal, Chains.WORMHOLE_OPTIMISM)
        );

        vm.stopPrank();

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), 0);

        bytes memory spokeSignedMessage_ = _signMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM);

        vm.selectFork(_optimismForkId);

        _deliverMessage(_OPTIMISM_WORMHOLE_RELAYER, spokeSignedMessage_);

        assertEq(IERC20(_optimismSpokeMToken).balanceOf(_mHolder), _amount);
        assertEq(IContinuousIndexing(_optimismSpokeMToken).currentIndex(), _mainnetIndex);
    }

    /* ============ transferMLikeToken ============ */

    /// @dev From $M on Spoke to $M on Hub
    function testFork_transferMLikeToken_M_to_M() external {
        _beforeTest();
        _transferMLikeTokenToHub(_arbitrumSpokeMToken, _MAINNET_M_TOKEN, _mHolder);
    }

    /// @dev From $M on Spoke to wrapped $M on Hub
    function testFork_transferMLikeToken_M_to_wrappedM() external {
        _beforeTest();
        _transferMLikeTokenToHub(_arbitrumSpokeMToken, _MAINNET_WRAPPED_M_TOKEN, _mHolder);
    }

    /// @dev From wrapped $M on Spoke to $M on Hub
    function testFork_transferMLikeToken_wrappedM_to_M() external {
        _beforeTest();
        _amount = _wrapSpokeM(_mHolder, _amount);
        _transferMLikeTokenToHub(_arbitrumSpokeWrappedMTokenProxy, _MAINNET_M_TOKEN, _mHolder);
    }

    /// @dev From wrapped $M on Spoke to wrapped $M on Hub
    function testFork_transferMLikeToken_wrappedM_to_wrappedM() external {
        _beforeTest();
        _amount = _wrapSpokeM(_mHolder, _amount);
        _transferMLikeTokenToHub(_arbitrumSpokeWrappedMTokenProxy, _MAINNET_WRAPPED_M_TOKEN, _mHolder);
    }

    function _wrapSpokeM(address recipient_, uint256 amount_) private returns (uint256 wrappedAmount_) {
        vm.startPrank(recipient_);
        IERC20(_arbitrumSpokeMToken).approve(_arbitrumSpokeWrappedMTokenProxy, amount_);
        IWrappedMTokenLike(_arbitrumSpokeWrappedMTokenProxy).wrap(recipient_, amount_);
        vm.stopPrank();
        wrappedAmount_ = IERC20(_arbitrumSpokeWrappedMTokenProxy).balanceOf(recipient_);
    }

    function _transferMLikeTokenToHub(address sourceToken_, address destinationToken_, address user_) private {
        // Deployer sets supported path
        vm.prank(_DEPLOYER);
        IPortal(_arbitrumSpokePortal).setSupportedBridgingPath(
            sourceToken_,
            Chains.WORMHOLE_ETHEREUM,
            destinationToken_.toBytes32(),
            true
        );

        // User approves source token and calls transferMLikeToken
        vm.startPrank(user_);
        IERC20(sourceToken_).approve(_arbitrumSpokePortal, _amount);
        IPortal(_arbitrumSpokePortal).transferMLikeToken{
            value: _quoteDeliveryPrice(_arbitrumSpokePortal, Chains.WORMHOLE_ETHEREUM)
        }(
            _amount,
            sourceToken_,
            Chains.WORMHOLE_ETHEREUM,
            destinationToken_.toBytes32(),
            user_.toBytes32(),
            user_.toBytes32()
        );
        vm.stopPrank();

        // User's source token balance is 0
        assertEq(IERC20(sourceToken_).balanceOf(user_), 0);

        bytes memory signedMessage_ = _signMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM);

        vm.selectFork(_mainnetForkId);

        uint256 balanceOfBefore_ = IERC20(destinationToken_).balanceOf(user_);

        _deliverMessage(_MAINNET_WORMHOLE_RELAYER, signedMessage_);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);
        assertEq(IERC20(destinationToken_).balanceOf(user_), balanceOfBefore_ + _amount);
    }

    function _beforeTest() internal {
        _amount = 1_000e6;

        // First, transfer M tokens to the Spoke chain.
        vm.selectFork(_mainnetForkId);

        vm.prank(_DEPLOYER);
        IPortal(_hubPortal).setDestinationMToken(Chains.WORMHOLE_ARBITRUM, _arbitrumSpokeMToken.toBytes32());

        _mainnetIndex = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        vm.startPrank(_mHolder);
        vm.recordLogs();

        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, _amount);

        _transfer(
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM)
        );

        vm.stopPrank();

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), _amount = _amount - 1);

        bytes memory hubSignedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);

        vm.selectFork(_arbitrumForkId);

        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, hubSignedMessage_);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), _amount);
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), _mainnetIndex);
    }
}
