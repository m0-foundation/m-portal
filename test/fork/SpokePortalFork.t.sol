// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IMToken } from "../../lib/protocol/src/interfaces/IMToken.sol";
import { IndexingMath } from "../../lib/common/src/libs/IndexingMath.sol";

import { Chains } from "../../script/config/Chains.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { ISpokePortal } from "../../src/interfaces/ISpokePortal.sol";
import { IWrappedMTokenLike } from "../../src/interfaces/IWrappedMTokenLike.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract SpokePortalForkTests is ForkTestBase {
    using TypeConverter for *;

    uint256 internal _amount = 1000e6;
    uint128 internal _mainnetIndex;

    /* ============ transfer ============ */

    function testFork_transferToHubPortal2() external {
        // seed sender's balance on Spoke by transferring from Hub first
        _transferFromHub(_amount + 1);

        vm.selectFork(_mainnetForkId);
        // amount is rounded down
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), _amount);

        uint256 balanceOfBefore_ = IERC20(_MAINNET_M_TOKEN).balanceOf(_mHolder);

        vm.selectFork(_arbitrumForkId);
        // Execute transfer
        _transfer(_amount, _mHolder, _mHolder, _arbitrumSpokePortal, Chains.WORMHOLE_ETHEREUM);

        // Deliver message
        _deliverMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM, _mainnetForkId, _MAINNET_WORMHOLE_RELAYER);

        vm.selectFork(_mainnetForkId);
        // Verify balances
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_mHolder), balanceOfBefore_ + _amount);
    }

    function testFork_transferBetweenSpokePortals() external {
        _transferFromHub(_amount);

        vm.selectFork(_optimismForkId);
        assertEq(IMToken(_optimismSpokeMToken).currentIndex(), _EXP_SCALED_ONE);

        vm.selectFork(_arbitrumForkId);
        uint128 arbitrumIndex = IMToken(_arbitrumSpokeMToken).currentIndex();
        assertGt(arbitrumIndex, _EXP_SCALED_ONE);

        _transfer(_amount, _mHolder, _mHolder, _arbitrumSpokePortal, Chains.WORMHOLE_OPTIMISM);

        vm.startPrank(_mHolder);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), 0);

        bytes memory spokeSignedMessage_ = _signMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM);

        vm.selectFork(_optimismForkId);

        _deliverMessage(_OPTIMISM_WORMHOLE_RELAYER, spokeSignedMessage_);

        assertEq(IERC20(_optimismSpokeMToken).balanceOf(_mHolder), _amount);
        assertEq(IMToken(_optimismSpokeMToken).currentIndex(), arbitrumIndex);
    }

    /// @dev Sender is non-earner, recipient is non-earner
    ///      The transferred amount is exact, no rounding errors
    function testFork_transferToHub_senderNonEarner_recipientNonEarner() external {
        uint256 amount_ = 1e6;
        _testTransferToHubScenario({
            isSenderEarner_: false,
            isRecipientEarner_: false,
            amount_: amount_,
            expectedRecipientBalance_: amount_
        });
    }

    /// @dev Sender is earner, recipient is non-earner
    ///      The transferred amount is exact, no rounding errors
    function testFork_transferToHub_senderEarner_recipientNonEarner() external {
        uint256 amount_ = 45_269_208;
        _testTransferToHubScenario({
            isSenderEarner_: true,
            isRecipientEarner_: false,
            amount_: amount_,
            expectedRecipientBalance_: amount_
        });
    }

    /// @dev Sender is non-earner, recipient is earner
    ///      The transferred amount is exact or rounded up
    function testFork_transferToHub_senderNonEarner_recipientEarner() external {
        uint256 amount_ = 45_269_208;
        _testTransferToHubScenario({
            isSenderEarner_: false,
            isRecipientEarner_: true,
            amount_: amount_,
            expectedRecipientBalance_: amount_ + 1
        });
    }

    /// @dev Sender is earner, recipient is earner
    ///      The transferred amount is exact or rounded up
    function testFork_transferToHub_senderEarner_recipientEarner() external {
        uint256 amount_ = 45_269_208;
        _testTransferToHubScenario({
            isSenderEarner_: true,
            isRecipientEarner_: true,
            amount_: amount_,
            expectedRecipientBalance_: amount_ + 1
        });
    }

    /// @dev Using lower fuzz runs and depth to avoid burning through RPC requests in CI
    /// forge-config: default.fuzz.runs = 10
    /// forge-config: default.fuzz.depth = 20
    /// forge-config: ci.fuzz.runs = 10
    /// forge-config: ci.fuzz.depth = 2
    function testFuzz_transferToHub_earningStatusScenarios(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        uint256 amount_
    ) external {
        vm.assume(amount_ > 1e6 && amount_ <= 100_000e6);

        uint256 expectedRecipientBalance_ = amount_;

        vm.selectFork(_mainnetForkId);
        uint128 index_ = IMToken(_MAINNET_M_TOKEN).currentIndex();

        // Adjust expected balance based on earning scenarios
        if (isRecipientEarner_) {
            uint112 principalAmount_ = IndexingMath.getPrincipalAmountRoundedUp(uint240(amount_), index_);
            expectedRecipientBalance_ = IndexingMath.getPresentAmountRoundedDown(principalAmount_, index_);
        }

        _testTransferToHubScenario(isSenderEarner_, isRecipientEarner_, amount_, expectedRecipientBalance_);
    }

    function _testTransferToHubScenario(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        uint256 amount_,
        uint256 expectedRecipientBalance_
    ) private {
        address sender_ = _mHolder;
        address recipient_ = _alice;

        // seed sender's balance on Spoke by transferring from Hub first
        _transferFromHub(1_000_000e6);

        // sender has enough $M on spoke to perform transfer
        vm.selectFork(_arbitrumForkId);
        assertGt(IERC20(_arbitrumSpokeMToken).balanceOf(sender_), amount_);

        // Hub has enough $M locked to perform transfer
        vm.selectFork(_arbitrumForkId);
        assertGt(IERC20(_arbitrumSpokeMToken).balanceOf(sender_), amount_);

        if (isSenderEarner_) {
            vm.selectFork(_arbitrumForkId);
            // Sender is earning on Spoke
            _enableUserEarning(_arbitrumSpokeMToken, _arbitrumSpokeRegistrar, sender_);
        }

        vm.selectFork(_arbitrumForkId);
        assertEq(IMToken(_arbitrumSpokeMToken).isEarning(sender_), isSenderEarner_);

        vm.selectFork(_mainnetForkId);
        if (isRecipientEarner_) {
            // Recipient is earning on Hub
            _enableUserEarning(_MAINNET_M_TOKEN, _MAINNET_REGISTRAR, recipient_);
        }

        assertEq(IMToken(_MAINNET_M_TOKEN).isEarning(recipient_), isRecipientEarner_);

        vm.selectFork(_arbitrumForkId);
        // Execute transfer
        _transfer(amount_, sender_, recipient_, _arbitrumSpokePortal, Chains.WORMHOLE_ETHEREUM);

        // Deliver message
        _deliverMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM, _mainnetForkId, _MAINNET_WORMHOLE_RELAYER);

        // Verify recipient balance
        vm.selectFork(_mainnetForkId);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(recipient_), expectedRecipientBalance_);
    }

    /// @dev Sender is non-earner, recipient is non-earner
    ///      The transferred amount is exact, no rounding errors
    function testFork_transferToSpoke_senderNonEarner_recipientNonEarner() external {
        uint256 amount_ = 1e6;
        _testTransferToSpokeScenario({
            isSenderEarner_: false,
            isRecipientEarner_: false,
            amount_: amount_,
            expectedRecipientBalance_: amount_
        });
    }

    /// @dev Sender is earner, recipient is non-earner
    ///      The transferred amount is exact, no rounding errors
    function testFork_transferToSpoke_senderEarner_recipientNonEarner(uint256 amount_) external {
        uint256 amount_ = 1e6;
        _testTransferToSpokeScenario({
            isSenderEarner_: true,
            isRecipientEarner_: false,
            amount_: amount_,
            expectedRecipientBalance_: amount_
        });
    }

    /// @dev Sender is non-earner, recipient is earner
    ///      The transferred amount is rounded down, recipient gets less
    function testFork_transferToSpoke_senderNonEarner_recipientEarner() external {
        uint256 amount_ = 1e6;
        _testTransferToSpokeScenario({
            isSenderEarner_: false,
            isRecipientEarner_: true,
            amount_: amount_,
            expectedRecipientBalance_: amount_ - 1
        });
    }

    /// @dev Sender is earner, recipient is earner
    ///      The transferred amount is rounded down, recipient gets less
    function testFork_transferToSpoke_senderEarner_recipientEarner() external {
        uint256 amount_ = 1e6;
        _testTransferToSpokeScenario({
            isSenderEarner_: true,
            isRecipientEarner_: true,
            amount_: amount_,
            expectedRecipientBalance_: amount_ - 1
        });
    }

    /// @dev Using lower fuzz runs and depth to avoid burning through RPC requests in CI
    /// forge-config: default.fuzz.runs = 10
    /// forge-config: default.fuzz.depth = 2
    /// forge-config: ci.fuzz.runs = 10
    /// forge-config: ci.fuzz.depth = 2
    function testFuzz_transferToSpoke_earningStatusScenarios(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        uint256 amount_
    ) external {
        vm.assume(amount_ > 1e6 && amount_ <= 100_000e6);

        uint256 expectedRecipientBalance_ = amount_;

        vm.selectFork(_mainnetForkId);
        uint128 index_ = IMToken(_MAINNET_M_TOKEN).currentIndex();

        // Adjust expected balance based on earning scenarios
        if (isRecipientEarner_) {
            uint112 principalAmount_ = IndexingMath.getPrincipalAmountRoundedDown(uint240(amount_), index_);
            expectedRecipientBalance_ = IndexingMath.getPresentAmountRoundedDown(principalAmount_, index_);
        }

        _testTransferToSpokeScenario(isSenderEarner_, isRecipientEarner_, amount_, expectedRecipientBalance_);
    }

    function _testTransferToSpokeScenario(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        uint256 amount_,
        uint256 expectedRecipientBalance_
    ) private {
        address sender_ = _mHolder;
        address recipient_ = _alice;

        // seed sender's balance on Spoke by transferring from Hub first
        _transferFromHub(1_000_000e6);

        // sender has enough $M on spoke to perform transfer
        vm.selectFork(_arbitrumForkId);
        assertGt(IERC20(_arbitrumSpokeMToken).balanceOf(sender_), amount_);

        if (isSenderEarner_) {
            // Sender is earning on Arbitrum
            _enableUserEarning(_arbitrumSpokeMToken, _arbitrumSpokeRegistrar, sender_);
        }
        assertEq(IMToken(_arbitrumSpokeMToken).isEarning(sender_), isSenderEarner_);

        vm.selectFork(_optimismForkId);
        if (isRecipientEarner_) {
            vm.selectFork(_mainnetForkId);
            // Propagate index
            _propagateMIndex(Chains.WORMHOLE_OPTIMISM, _optimismForkId, _OPTIMISM_WORMHOLE_RELAYER);

            vm.selectFork(_optimismForkId);
            // Recipient is earning on Optimism
            _enableUserEarning(_optimismSpokeMToken, _optimismSpokeRegistrar, recipient_);
        }
        assertEq(IMToken(_optimismSpokeMToken).isEarning(recipient_), isRecipientEarner_);

        vm.selectFork(_arbitrumForkId);
        // Execute transfer
        _transfer(amount_, sender_, recipient_, _arbitrumSpokePortal, Chains.WORMHOLE_OPTIMISM);

        // Deliver message
        _deliverMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM, _optimismForkId, _OPTIMISM_WORMHOLE_RELAYER);

        // Verify recipient balance
        vm.selectFork(_optimismForkId);
        assertEq(IERC20(_optimismSpokeMToken).balanceOf(recipient_), expectedRecipientBalance_);
    }

    /* ============ transferMLikeToken ============ */

    /// @dev From $M on Spoke to $M on Hub
    function testFork_transferMLikeToken_M_to_M() external {
        _transferFromHub(_amount);
        _transferMLikeTokenToHub(_arbitrumSpokeMToken, _MAINNET_M_TOKEN, _mHolder);
    }

    /// @dev From $M on Spoke to wrapped $M on Hub
    function testFork_transferMLikeToken_M_to_wrappedM() external {
        _transferFromHub(_amount);
        _transferMLikeTokenToHub(_arbitrumSpokeMToken, _MAINNET_WRAPPED_M_TOKEN, _mHolder);
    }

    /// @dev From wrapped $M on Spoke to $M on Hub
    function testFork_transferMLikeToken_wrappedM_to_M() external {
        _transferFromHub(_amount);
        _amount = _wrapSpokeM(_mHolder, _amount);
        _transferMLikeTokenToHub(_arbitrumSpokeWrappedMTokenProxy, _MAINNET_M_TOKEN, _mHolder);
    }

    /// @dev From wrapped $M on Spoke to wrapped $M on Hub
    function testFork_transferMLikeToken_wrappedM_to_wrappedM() external {
        _transferFromHub(_amount);
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
        // User approves source token and calls transferMLikeToken
        vm.selectFork(_arbitrumForkId);
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

        // Advance time to simulate yield earning by HubPortal
        vm.warp(block.timestamp + 10 seconds);

        uint256 balanceBefore_ = IERC20(destinationToken_).balanceOf(user_);

        _deliverMessage(_MAINNET_WORMHOLE_RELAYER, signedMessage_);

        assertGe(IERC20(destinationToken_).balanceOf(user_), balanceBefore_ + _amount);
    }

    /// @dev Setup Spoke with $M from Hub
    function _transferFromHub(uint256 amount_) internal {
        vm.selectFork(_mainnetForkId);
        _transfer(amount_, _mHolder, _mHolder, _hubPortal, Chains.WORMHOLE_ARBITRUM);

        // Deliver message
        _deliverMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM, _arbitrumForkId, _ARBITRUM_WORMHOLE_RELAYER);
    }
}
