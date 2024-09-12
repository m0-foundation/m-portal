// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { IPortal } from "../../../../src/interfaces/IPortal.sol";
import { IBridge } from "../../../../src/bridges/interfaces/IBridge.sol";
import { ICrossDomainMessenger } from "../../../../src/bridges/optimism/interfaces/Dependencies.sol";
import { IOptimismBridge } from "../../../../src/bridges/optimism/interfaces/IOptimismBridge.sol";

import { MessageUtils } from "../../../../src/libs/MessageUtils.sol";

import { OptimismBridge } from "../../../../src/bridges/optimism/OptimismBridge.sol";

import {
    MockHubPortal,
    MockSpokePortal,
    MockOptimismCrossDomainMessenger,
    MockOptimismBridge
} from "../../../utils/Mocks.sol";

contract OptimismBridgeTest is Test {
    uint256 internal constant _HUB_CHAIN_ID = 1;
    uint256 internal constant _SPOKE_CHAIN_ID = 2;
    uint32 internal constant _GAS_LIMIT = 200_000;

    address internal _alice = makeAddr("alice");

    MockHubPortal internal _hubPortal;
    MockSpokePortal internal _spokePortal;
    MockOptimismCrossDomainMessenger internal _hubMessenger;
    MockOptimismCrossDomainMessenger internal _spokeMessenger;

    OptimismBridge internal _hubBridge;
    OptimismBridge internal _spokeBridge;

    function setUp() external {
        _hubPortal = new MockHubPortal();
        _spokePortal = new MockSpokePortal();
        _hubMessenger = new MockOptimismCrossDomainMessenger();
        _spokeMessenger = new MockOptimismCrossDomainMessenger();

        _hubBridge = new OptimismBridge(
            address(_hubPortal),
            address(_hubMessenger),
            _SPOKE_CHAIN_ID,
            address(new MockOptimismBridge())
        );

        _spokeBridge = new OptimismBridge(
            address(_spokePortal),
            address(_spokeMessenger),
            _HUB_CHAIN_ID,
            address(new MockOptimismBridge())
        );
    }

    function test_quote_returnsZero() external view {
        uint256 fee = _hubBridge.quote(_SPOKE_CHAIN_ID, hex"", _GAS_LIMIT);

        assertEq(fee, 0);
    }

    function test_send_revertsIfNotPortal() external {
        vm.expectRevert(IBridge.NotPortal.selector);
        _hubBridge.dispatch(_SPOKE_CHAIN_ID, hex"", _GAS_LIMIT, _alice);
    }

    function test_send() external {
        bytes memory message_ = abi.encodeCall(IPortal.receiveMToken, (_HUB_CHAIN_ID, _alice, _alice, 10, 1));
        bytes32 expectedMessageId_ = MessageUtils.generateMessageId(_HUB_CHAIN_ID, _SPOKE_CHAIN_ID, 0, message_);

        bytes memory receiveMessageCall_ = abi.encodeCall(
            IOptimismBridge.receiveMessage,
            (expectedMessageId_, message_)
        );

        vm.chainId(_HUB_CHAIN_ID);

        // `ICrossDomainMessenger.sendMessage` must be called
        vm.expectCall(
            address(_hubMessenger),
            abi.encodeCall(
                ICrossDomainMessenger.sendMessage,
                (_hubBridge.remoteBridge(), receiveMessageCall_, _GAS_LIMIT)
            )
        );

        // Must emit MessageDispatched event
        vm.expectEmit();
        emit IBridge.MessageDispatched(_SPOKE_CHAIN_ID, expectedMessageId_, message_);

        vm.prank(address(_hubPortal));
        bytes32 actualMessageId = _hubBridge.dispatch(_SPOKE_CHAIN_ID, message_, _GAS_LIMIT, _alice);

        assertEq(expectedMessageId_, actualMessageId);
    }

    function test_receiveMessage_revertsIfUnauthorizedCaller() external {
        // msg.sender isn't CrossDomainMessenger
        vm.expectRevert(IOptimismBridge.UnauthorizedCaller.selector);
        _spokeBridge.receiveMessage(bytes32(0), hex"");

        // ICrossDomainMessenger.xDomainMessageSender isn't remote bridge
        vm.expectRevert(IOptimismBridge.UnauthorizedCaller.selector);
        vm.prank(address(_spokeMessenger));
        _spokeBridge.receiveMessage(bytes32(0), hex"");
    }

    function test_receiveMessage() external {
        bytes memory message_ = abi.encodeCall(IPortal.receiveMToken, (_HUB_CHAIN_ID, _alice, _alice, 10, 1));
        bytes32 messageId_ = MessageUtils.generateMessageId(_HUB_CHAIN_ID, _SPOKE_CHAIN_ID, 0, message_);

        vm.mockCall(
            address(_spokeMessenger),
            abi.encodeCall(ICrossDomainMessenger.xDomainMessageSender, ()),
            abi.encode(_spokeBridge.remoteBridge())
        );

        // `IPortal.receiveMToken` must be called
        vm.expectCall(address(_spokePortal), message_);

        // Must emit MessageDispatched event
        vm.expectEmit();
        emit IBridge.MessageExecuted(messageId_);

        vm.prank(address(_spokeMessenger));
        _spokeBridge.receiveMessage(messageId_, message_);
    }
}
