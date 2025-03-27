// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IndexingMath } from "../../lib/common/src/libs/IndexingMath.sol";
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

        uint256 amount_ = 1_000e6;
        _transfer(amount_, _mHolder, _mHolder, _hubPortal, Chains.WORMHOLE_ARBITRUM);

        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, amount_);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_ = amount_ - 1);

        // Deliver message
        _deliverMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM, _arbitrumForkId, _ARBITRUM_WORMHOLE_RELAYER);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder), amount_);
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), mainnetIndex_);
    }

    /// @dev Sender is non-earner, recipient is non-earner
    ///      The transferred amount is rounded down on the source, recipient gets less
    function testFork_transfer_senderNonEarner_recipientNonEarner() external {
        uint256 amount_ = 15_399_539_920;
        _testTransferScenario({
            isSenderEarner_: false,
            isRecipientEarner_: false,
            amount_: amount_,
            expectedHubBalance_: amount_ - 2,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    /// @dev Sender is earner, recipient is non-earner
    ///      The transferred amount is exact or rounded up on the source
    function testFork_transfer_senderEarner_recipientNonEarner() external {
        uint256 amount_ = 38_962_247;
        _testTransferScenario({
            isSenderEarner_: true,
            isRecipientEarner_: false,
            amount_: amount_,
            expectedHubBalance_: amount_ + 1,
            expectedRecipientBalance_: amount_ + 1
        });
    }

    /// @dev Sender is non-earner, recipient is earner
    ///      The transferred amount is rounded down twice, recipient gets less
    function testFork_transfer_senderNonEarner_recipientEarner() external {
        uint256 amount_ = 1_000e6;
        // Amount locked in HubPortal is less than the transfer amount due to the rounding
        // when transferring $M from a non-earner sender to the earner HubPortal.
        // Recipient's balance is less than the transfer amount due to the rounding
        // when minting $M to an earner recipient.
        _testTransferScenario({
            isSenderEarner_: false,
            isRecipientEarner_: true,
            amount_: amount_,
            expectedHubBalance_: amount_ - 1,
            expectedRecipientBalance_: amount_ - 1
        });
    }

    /// @dev Sender is earner, recipient is earner
    ///      The transferred amount is rounded down on the destination, recipient gets less
    function testFork_transfer_senderEarner_recipientEarner() external {
        uint256 amount_ = 1_000e6;
        _testTransferScenario({
            isSenderEarner_: true,
            isRecipientEarner_: true,
            amount_: amount_,
            expectedHubBalance_: amount_,
            expectedRecipientBalance_: amount_
        });
    }

    /// @dev Using lower fuzz runs and depth to avoid burning through RPC requests in CI
    /// forge-config: default.fuzz.runs = 100
    /// forge-config: default.fuzz.depth = 20
    /// forge-config: ci.fuzz.runs = 10
    /// forge-config: ci.fuzz.depth = 2
    function testFuzz_transfer_earningStatusScenarios(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        uint256 amount_
    ) external {
        vm.assume(amount_ > 1e6 && amount_ <= 100_000e6);

        uint256 expectedHubBalance_ = amount_;
        uint256 expectedRecipientBalance_ = amount_;

        vm.selectFork(_mainnetForkId);
        uint128 index_ = IContinuousIndexing(_MAINNET_M_TOKEN).currentIndex();

        // Adjust expected balances based on earning scenarios

        uint112 principalAmount_ = isSenderEarner_
            ? IndexingMath.getPrincipalAmountRoundedUp(uint240(amount_), index_)
            : IndexingMath.getPrincipalAmountRoundedDown(uint240(amount_), index_);
        expectedHubBalance_ = IndexingMath.getPresentAmountRoundedDown(principalAmount_, index_);
        expectedRecipientBalance_ = amount_;

        // SpokePortal is always non-earner
        // Transferring to earner results in rounding down
        if (isRecipientEarner_) {
            uint112 principalAmount_ = IndexingMath.getPrincipalAmountRoundedDown(
                uint240(expectedRecipientBalance_),
                index_
            );
            expectedRecipientBalance_ = IndexingMath.getPresentAmountRoundedDown(principalAmount_, index_);
        }

        _testTransferScenario(
            isSenderEarner_,
            isRecipientEarner_,
            amount_,
            expectedHubBalance_,
            expectedRecipientBalance_
        );
    }

    function _testTransferScenario(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        uint256 amount_,
        uint256 expectedHubBalance_,
        uint256 expectedRecipientBalance_
    ) private {
        address sender_ = _mHolder;
        address recipient_ = _mHolder;

        if (isRecipientEarner_) {
            vm.selectFork(_mainnetForkId);
            // Propagate index
            _propagateMIndex(Chains.WORMHOLE_ARBITRUM, _arbitrumForkId, _ARBITRUM_WORMHOLE_RELAYER);

            vm.selectFork(_arbitrumForkId);
            // Recipient is earning on Spoke
            _enableUserEarning(_arbitrumSpokeMToken, _arbitrumSpokeRegistrar, recipient_);
        }
        assertEq(IMToken(_arbitrumSpokeMToken).isEarning(recipient_), isRecipientEarner_);

        vm.selectFork(_mainnetForkId);
        if (isSenderEarner_) {
            // Sender is earning on Hub
            _enableUserEarning(_MAINNET_M_TOKEN, _MAINNET_REGISTRAR, sender_);
        }

        assertEq(IMToken(_MAINNET_M_TOKEN).isEarning(sender_), isSenderEarner_);

        // Execute transfer
        _transfer(amount_, sender_, recipient_, _hubPortal, Chains.WORMHOLE_ARBITRUM);

        // Verify hub balance
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), expectedHubBalance_);

        // Deliver message
        _deliverMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM, _arbitrumForkId, _ARBITRUM_WORMHOLE_RELAYER);

        // Verify recipient balance
        vm.selectFork(_arbitrumForkId);
        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(recipient_), expectedRecipientBalance_);
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

        _transferMLikeToken(
            sourceToken_,
            destinationToken_,
            amount_,
            user_,
            user_,
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM
        );

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), amount_ - 1);

        // Wormhole delivers message
        bytes memory signedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);
        vm.selectFork(_arbitrumForkId);
        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, signedMessage_);

        // User receives destination token
        assertEq(IERC20(destinationToken_).balanceOf(user_), amount_);

        // Spoke M index updated
        assertEq(IContinuousIndexing(_arbitrumSpokeMToken).currentIndex(), mainnetIndex_);
    }

    /// @dev Transferring WrappedM to M
    ///      Sender is non-earner, recipient is non-earner
    ///      The transferred amount is rounded down, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_M_senderNonEarner_recipientNonEarner() external {
        uint256 amount_ = 23_242_957_645;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: false,
            isRecipientEarner_: false,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeMToken,
            amount_: amount_,
            expectedHubBalance_: amount_ - 2,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    /// @dev Transferring WrappedM to M
    ///      Sender is earner, recipient is non-earner
    ///      The transferred amount is rounded down on source during unwrap(), recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_M_senderEarner_recipientNonEarner() external {
        uint256 amount_ = 23_242_957_645;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: true,
            isRecipientEarner_: false,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeMToken,
            amount_: amount_,
            expectedHubBalance_: amount_ - 2,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    /// @dev Transferring WrappedM to M
    ///      Sender is non-earner, recipient is earner
    ///      The transferred amount is rounded down twice, on source and destination, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_M_senderNonEarner_recipientEarner() external {
        uint256 amount_ = 23_242_957_645;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: false,
            isRecipientEarner_: true,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeMToken,
            amount_: amount_,
            expectedHubBalance_: amount_ - 2,
            expectedRecipientBalance_: amount_ - 3
        });
    }

    /// @dev Transferring WrappedM to M
    ///      Sender is earner, recipient is earner
    ///      The transferred amount is rounded down twice, on source and destination, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_M_senderEarner_recipientEarner() external {
        uint256 amount_ = 23_242_957_645;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: true,
            isRecipientEarner_: true,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeMToken,
            amount_: amount_,
            expectedHubBalance_: amount_ - 2,
            expectedRecipientBalance_: amount_ - 3
        });
    }

    /// @dev Transferring WrappedM to WrappedM
    ///      Sender is non-earner, recipient is non-earner
    ///      The transferred amount is rounded down twice, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_wrappedM_senderNonEarner_recipientNonEarner() external {
        uint256 amount_ = 1e6;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: false,
            isRecipientEarner_: false,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeWrappedMTokenProxy,
            amount_: amount_,
            expectedHubBalance_: amount_ - 1,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    /// @dev Transferring WrappedM to WrappedM
    ///      Sender is earner, recipient is non-earner
    ///      The transferred amount is rounded down twice, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_wrappedM_senderEarner_recipientNonEarner() external {
        uint256 amount_ = 1e6;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: true,
            isRecipientEarner_: false,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeWrappedMTokenProxy,
            amount_: amount_,
            expectedHubBalance_: amount_ - 1,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    /// @dev Transferring WrappedM to WrappedM
    ///      Sender is non-earner, recipient is earner
    ///      The transferred amount is rounded down twice, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_wrappedM_senderNonEarner_recipientEarner() external {
        uint256 amount_ = 1e6;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: false,
            isRecipientEarner_: true,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeWrappedMTokenProxy,
            amount_: amount_,
            expectedHubBalance_: amount_ - 1,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    /// @dev Transferring WrappedM to WrappedM
    ///      Sender is earner, recipient is earner
    ///      The transferred amount is rounded down twice, recipient gets less
    function testFork_transferMLikeToken_wrappedM_to_wrappedM_senderEarner_recipientEarner() external {
        uint256 amount_ = 1e6;
        _testTransferMLikeTokenScenario({
            isSenderEarner_: true,
            isRecipientEarner_: true,
            sender_: _wrappedMHolder,
            sourceToken_: _MAINNET_WRAPPED_M_TOKEN,
            destinationToken_: _arbitrumSpokeWrappedMTokenProxy,
            amount_: amount_,
            expectedHubBalance_: amount_ - 1,
            expectedRecipientBalance_: amount_ - 2
        });
    }

    function _testTransferMLikeTokenScenario(
        bool isSenderEarner_,
        bool isRecipientEarner_,
        address sender_,
        address sourceToken_,
        address destinationToken_,
        uint256 amount_,
        uint256 expectedHubBalance_,
        uint256 expectedRecipientBalance_
    ) private {
        address recipient_ = _alice;

        vm.selectFork(_mainnetForkId);
        // Propagate index
        _propagateMIndex(Chains.WORMHOLE_ARBITRUM, _arbitrumForkId, _ARBITRUM_WORMHOLE_RELAYER);

        vm.selectFork(_arbitrumForkId);
        // Wrapped M is earning on Spoke
        _enableWrappedMEarning(_arbitrumSpokeWrappedMTokenProxy, _arbitrumSpokeRegistrar);
        assertEq(IMToken(_arbitrumSpokeMToken).isEarning(_arbitrumSpokeWrappedMTokenProxy), true);

        if (isRecipientEarner_) {
            // Recipient is earning on Spoke
            _enableUserEarning(_arbitrumSpokeMToken, _arbitrumSpokeRegistrar, recipient_);
        }
        assertEq(IMToken(_arbitrumSpokeMToken).isEarning(recipient_), isRecipientEarner_);

        vm.selectFork(_mainnetForkId);
        if (isSenderEarner_) {
            // Sender is earning on Hub
            _enableUserEarning(_MAINNET_M_TOKEN, _MAINNET_REGISTRAR, sender_);
        }

        assertEq(IMToken(_MAINNET_M_TOKEN).isEarning(sender_), isSenderEarner_);

        // Execute transfer
        _transferMLikeToken(
            sourceToken_,
            destinationToken_,
            amount_,
            sender_,
            recipient_,
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM
        );

        // Verify hub balance
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), expectedHubBalance_);

        // Deliver message
        _deliverMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM, _arbitrumForkId, _ARBITRUM_WORMHOLE_RELAYER);

        // Verify recipient balance
        vm.selectFork(_arbitrumForkId);
        assertEq(IERC20(destinationToken_).balanceOf(recipient_), expectedRecipientBalance_);
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
