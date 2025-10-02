// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { TransceiverStructs } from "../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { HubPortal } from "../../src/HubPortal.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { ExecutorArgs } from "../../src/interfaces/IHubExecutorEntryPoint.sol";
import { ExecutorMessages } from "../../src/external/ExecutorMessages.sol";
import { HubExecutorEntryPoint } from "../../src/HubExecutorEntryPoint.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";
import { MockHubMToken } from "../mocks/MockHubMToken.sol";
import { MockWrappedMToken } from "../mocks/MockWrappedMToken.sol";
import { MockHubRegistrar } from "../mocks/MockHubRegistrar.sol";
import { MockTransceiverPrice } from "../mocks/MockTransceiver.sol";
import { MockMerkleTreeBuilder } from "../mocks/MockMerkleTreeBuilder.sol";
import { MockExecutor } from "../mocks/MockExecutor.sol";
import { MockWormhole } from "../mocks/MockWormhole.sol";
import { MockSwapFacility } from "../mocks/MockSwapFacility.sol";

contract HubExecutorEntryPointTest is UnitTestBase {
    using TypeConverter for *;

    uint16 internal constant _SOLANA_WORMHOLE_CHAIN_ID = 1;
    bytes32 internal constant _SOLANA_EARNER_LIST = bytes32("solana-earners");
    bytes32 internal constant _SOLANA_EARN_MANAGER_LIST = bytes32("solana-earn-managers");

    TransceiverStructs.TransceiverInstruction internal _executorTransceiverInstruction;
    bytes internal _executorTransceiverInstructionBytes;

    MockHubMToken internal _mToken;
    MockWrappedMToken internal _wrappedMToken;
    MockHubRegistrar internal _registrar;
    MockMerkleTreeBuilder internal _merkleTreeBuilder;
    MockExecutor internal _executor;
    MockWormhole internal _wormhole;
    MockTransceiverPrice internal _transceiverWithPrice;
    MockSwapFacility internal _swapFacility;

    HubPortal internal _portal;
    HubExecutorEntryPoint internal _executorEntryPoint;

    uint256 internal constant _INITIAL_MINT_AMOUNT = 1_000_000e6;
    uint256 internal constant _EXECUTOR_QUOTE_VALUE = 0.01 ether;
    uint256 internal constant _TRANSCEIVER_QUOTE_VALUE = 0.005 ether;

    bytes32 _solanaPeer = bytes32("solana-peer");
    bytes32 _solanaToken = bytes32("solana-token");

    constructor() UnitTestBase() {
        _executorTransceiverInstruction = TransceiverStructs.TransceiverInstruction({ index: 0, payload: hex"01" });
        TransceiverStructs.TransceiverInstruction[]
            memory instructions = new TransceiverStructs.TransceiverInstruction[](1);
        instructions[0] = _executorTransceiverInstruction;
        _executorTransceiverInstructionBytes = TransceiverStructs.encodeTransceiverInstructions(instructions);
        (instructions);
    }

    function setUp() external {
        _mToken = new MockHubMToken();
        _wrappedMToken = new MockWrappedMToken(address(_mToken));

        _tokenDecimals = _mToken.decimals();
        _tokenAddress = address(_mToken);

        _registrar = new MockHubRegistrar();
        _transceiverWithPrice = new MockTransceiverPrice();
        _transceiverWithPrice.setQuotePrice(_SOLANA_WORMHOLE_CHAIN_ID, _TRANSCEIVER_QUOTE_VALUE);
        _merkleTreeBuilder = new MockMerkleTreeBuilder();
        _executor = new MockExecutor();
        _wormhole = new MockWormhole(_LOCAL_CHAIN_ID);
        _swapFacility = new MockSwapFacility(address(_mToken));

        HubPortal portalImplementation_ = new HubPortal(
            address(_mToken),
            address(_registrar),
            address(_swapFacility),
            _LOCAL_CHAIN_ID
        );
        _portal = HubPortal(_createProxy(address(portalImplementation_)));

        HubExecutorEntryPoint executorEntryPointImplementation_ = new HubExecutorEntryPoint(
            address(_executor),
            address(_portal),
            address(_wormhole)
        );
        _executorEntryPoint = HubExecutorEntryPoint(payable(_createProxy(address(executorEntryPointImplementation_))));

        _portal.initialize();
        _portal.setTransceiver(address(_transceiverWithPrice));
        _portal.setMerkleTreeBuilder(address(_merkleTreeBuilder));
        _portal.setPeer(_SOLANA_WORMHOLE_CHAIN_ID, _solanaPeer, _tokenDecimals, type(uint64).max);
        _portal.setDestinationMToken(_SOLANA_WORMHOLE_CHAIN_ID, _solanaToken);
        _portal.setSupportedBridgingPath(address(_mToken), _SOLANA_WORMHOLE_CHAIN_ID, _solanaToken, true);
        _portal.setSupportedBridgingPath(address(_wrappedMToken), _SOLANA_WORMHOLE_CHAIN_ID, _solanaToken, true);

        // Mint tokens for testing.
        _mToken.mint(address(this), _INITIAL_MINT_AMOUNT * 2);
        _mToken.approve(address(_wrappedMToken), _INITIAL_MINT_AMOUNT);
        _wrappedMToken.wrap(address(this), _INITIAL_MINT_AMOUNT);
        vm.deal(address(this), 10e18);
    }

    // necessary for receiving native assets, e.g. refunds
    receive() external payable {}

    /* ============ constructor ============ */

    function test_constructor() external view {
        // Check that immutable variables are set correctly in the constructor of the implementation contract
        // and are preserved in the proxy contract.
        assertEq(_executorEntryPoint.chainId(), _LOCAL_CHAIN_ID);
        assertEq(_executorEntryPoint.executor(), address(_executor));
        assertEq(_executorEntryPoint.portal(), address(_portal));
        assertEq(address(_executorEntryPoint.wormhole()), address(_wormhole));
    }

    /* ============ transferMLikeToken ============ */

    function test_transferMLikeToken_missingAllowance_reverts() external {
        // Attempt to transfer without sufficient allowance
        vm.expectRevert();
        _executorEntryPoint.transferMLikeToken{ value: _EXECUTOR_QUOTE_VALUE }(
            1e6,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );
    }

    function test_transferMLikeToken_insufficientBalance_reverts() external {
        vm.deal(_alice, 1e18);

        // Approve the entry point to spend m tokens on behalf of Alice
        vm.prank(_alice);
        _mToken.approve(address(_executorEntryPoint), 1e6);

        // Expect a revert due to insufficient balance
        vm.prank(_alice);
        vm.expectRevert();
        _executorEntryPoint.transferMLikeToken{ value: _EXECUTOR_QUOTE_VALUE }(
            1e6,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            _alice.toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: _alice,
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );
    }

    function test_transferMLikeToken_msgValueLessThanExecArgsValue_reverts() external {
        // Approve the entry point to spend m tokens on behalf of this contract
        _mToken.approve(address(_executorEntryPoint), 1e6);

        // Expect a revert due to insufficient msg.value
        vm.expectRevert();
        _executorEntryPoint.transferMLikeToken{ value: _EXECUTOR_QUOTE_VALUE - 1 }(
            1e6,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );
    }

    function test_transferMLikeToken_M_success() external {
        uint256 amount = 1e6;

        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Approve the entry point to spend m tokens on behalf of this contract
        _mToken.approve(address(_executorEntryPoint), amount);

        // Capture the initial balance of this contract
        uint256 initialBalance = _mToken.balanceOf(address(this));

        // Verify that the entry point doesn't have any tokens
        assertEq(_mToken.balanceOf(address(_executorEntryPoint)), 0);

        // Perform the transfer
        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            0,
            abi.encodeWithSelector(
                IPortal.transferMLikeToken.selector,
                amount,
                address(_mToken),
                _SOLANA_WORMHOLE_CHAIN_ID,
                _solanaToken,
                bytes32("recipient"),
                address(this).toBytes32(),
                _executorTransceiverInstructionBytes
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.transferMLikeToken{ value: _EXECUTOR_QUOTE_VALUE }(
            amount,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);

        // Verify that the balance of this contract has decreased by the transferred amount
        uint256 finalBalance = _mToken.balanceOf(address(this));
        assertEq(finalBalance, initialBalance - amount);

        // Verify that the entry point doesn't have any tokens
        assertEq(_mToken.balanceOf(address(_executorEntryPoint)), 0);
    }

    function test_transferMLikeToken_wM_success() external {
        uint256 amount = 1e6;

        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Approve the entry point to spend m tokens on behalf of this contract
        _wrappedMToken.approve(address(_executorEntryPoint), amount);

        // Capture the initial balance of this contract
        uint256 initialBalance = _wrappedMToken.balanceOf(address(this));

        // Verify that the entry point doesn't have any tokens
        assertEq(_wrappedMToken.balanceOf(address(_executorEntryPoint)), 0);

        // Perform the transfer
        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            0,
            abi.encodeWithSelector(
                IPortal.transferMLikeToken.selector,
                amount,
                address(_wrappedMToken),
                _SOLANA_WORMHOLE_CHAIN_ID,
                _solanaToken,
                bytes32("recipient"),
                address(this).toBytes32(),
                _executorTransceiverInstructionBytes
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.transferMLikeToken{ value: _EXECUTOR_QUOTE_VALUE }(
            amount,
            address(_wrappedMToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);

        // Verify that the balance of this contract has decreased by the transferred amount
        uint256 finalBalance = _wrappedMToken.balanceOf(address(this));
        assertEq(finalBalance, initialBalance - amount);

        // Verify that the entry point doesn't have any tokens
        assertEq(_wrappedMToken.balanceOf(address(_executorEntryPoint)), 0);
    }

    function test_transferMLikeToken_standardRelayingNotDisabled_feeCausesRevert() external {
        // Approve the entry point to spend m tokens on behalf of this contract
        _mToken.approve(address(_executorEntryPoint), 1e6);

        // Expect a revert due to standard relaying not being disabled and having to pay fee on portal
        vm.expectRevert();
        _executorEntryPoint.transferMLikeToken{ value: _EXECUTOR_QUOTE_VALUE }(
            1e6,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            hex"00"
        );
    }

    function test_transferMLikeToken_standardRelayingNotDisabled_payExtraFee_success() external {
        // Approve the entry point to spend m tokens on behalf of this contract
        _mToken.approve(address(_executorEntryPoint), 1e6);

        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Perform the transfer with extra fee to allow standard relaying
        // Expect call to portal with the transceiver quote value
        vm.expectCall(
            address(_portal),
            _TRANSCEIVER_QUOTE_VALUE,
            abi.encodeWithSelector(
                IPortal.transferMLikeToken.selector,
                1e6,
                address(_mToken),
                _SOLANA_WORMHOLE_CHAIN_ID,
                _solanaToken,
                bytes32("recipient"),
                address(this).toBytes32(),
                hex"00"
            )
        );
        // Expect call to executor with the executor quote value
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.transferMLikeToken{
            value: _EXECUTOR_QUOTE_VALUE + _TRANSCEIVER_QUOTE_VALUE
        }(
            1e6,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            hex"00"
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);
    }

    function test_transferMLikeToken_excessRefunded_success() public {
        uint256 amount = 1e6;

        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Approve the entry point to spend m tokens on behalf of this contract
        _mToken.approve(address(_executorEntryPoint), amount);

        // Capture the initial balance of this contract
        uint256 initialBalance = _mToken.balanceOf(address(this));

        // Verify that the entry point doesn't have any tokens
        assertEq(_mToken.balanceOf(address(_executorEntryPoint)), 0);

        uint256 initialEthBalance = address(this).balance;

        // Verify that the entry point doesn't have any ETH
        assertEq(address(_executorEntryPoint).balance, 0);

        // Verify that the portal doesn't have any ETH
        assertEq(address(_portal).balance, 0);

        uint256 ethToSend = _EXECUTOR_QUOTE_VALUE + 1 ether;

        // Perform the transfer
        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            1 ether,
            abi.encodeWithSelector(
                IPortal.transferMLikeToken.selector,
                amount,
                address(_mToken),
                _SOLANA_WORMHOLE_CHAIN_ID,
                _solanaToken,
                bytes32("recipient"),
                address(this).toBytes32(),
                _executorTransceiverInstructionBytes
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.transferMLikeToken{ value: ethToSend }(
            amount,
            address(_mToken),
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            bytes32("recipient"),
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);

        // Verify that the balance of this contract has decreased by the transferred amount
        uint256 finalBalance = _mToken.balanceOf(address(this));
        assertEq(finalBalance, initialBalance - amount);

        // Verify that the entry point doesn't have any tokens
        assertEq(_mToken.balanceOf(address(_executorEntryPoint)), 0);

        // Verify that the balance of this contract has only decreased by the executor quote value
        assertEq(address(this).balance, initialEthBalance - _EXECUTOR_QUOTE_VALUE);

        // Verify that the entry point doesn't have any ETH
        assertEq(address(_executorEntryPoint).balance, 0);

        // Verify that the portal doesn't have any ETH
        assertEq(address(_portal).balance, 0);
    }

    /* ============ sendMTokenIndex ============ */

    function test_sendMTokenIndex_msgValueLessThanExecArgsValue_reverts() external {
        // Expect a revert due to insufficient msg.value
        vm.expectRevert();
        _executorEntryPoint.sendMTokenIndex{ value: _EXECUTOR_QUOTE_VALUE - 1 }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );
    }

    function test_sendMTokenIndex_success() external {
        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            0,
            abi.encodeWithSelector(
                IHubPortal.sendMTokenIndex.selector,
                _SOLANA_WORMHOLE_CHAIN_ID,
                address(this).toBytes32(),
                _executorTransceiverInstructionBytes
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.sendMTokenIndex{ value: _EXECUTOR_QUOTE_VALUE }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);
    }

    function test_sendMTokenIndex_standardRelayingNotDisabled_feeCausesRevert() external {
        // Expect a revert due to standard relaying not being disabled and having to pay fee on portal
        vm.expectRevert();
        _executorEntryPoint.sendMTokenIndex{ value: _EXECUTOR_QUOTE_VALUE }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            hex"00"
        );
    }

    function test_sendMTokenIndex_standardRelayingNotDisabled_payExtraFee_success() external {
        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            _TRANSCEIVER_QUOTE_VALUE,
            abi.encodeWithSelector(
                IHubPortal.sendMTokenIndex.selector,
                _SOLANA_WORMHOLE_CHAIN_ID,
                address(this).toBytes32(),
                hex"00"
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.sendMTokenIndex{
            value: _EXECUTOR_QUOTE_VALUE + _TRANSCEIVER_QUOTE_VALUE
        }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            hex"00"
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);
    }

    /* ============ sendEarnersMerkleRoot ============ */

    function test_sendEarnersMerkleRoot_msgValueLessThanExecArgsValue_reverts() external {
        // Expect a revert due to insufficient msg.value
        vm.expectRevert();
        _executorEntryPoint.sendEarnersMerkleRoot{ value: _EXECUTOR_QUOTE_VALUE - 1 }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );
    }

    function test_sendEarnersMerkleRoot_success() external {
        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            0,
            abi.encodeWithSelector(
                IHubPortal.sendEarnersMerkleRoot.selector,
                _SOLANA_WORMHOLE_CHAIN_ID,
                address(this).toBytes32(),
                _executorTransceiverInstructionBytes
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.sendEarnersMerkleRoot{ value: _EXECUTOR_QUOTE_VALUE }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            _executorTransceiverInstructionBytes
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);
    }

    function test_sendEarnersMerkleRoot_standardRelayingNotDisabled_feeCausesRevert() external {
        // Expect a revert due to standard relaying not being disabled and having to pay fee on portal
        vm.expectRevert();
        _executorEntryPoint.sendEarnersMerkleRoot{ value: _EXECUTOR_QUOTE_VALUE }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            hex"00"
        );
    }

    function test_sendEarnersMerkleRoot_standardRelayingNotDisabled_payExtraFee_success() external {
        // Move the sequence forward to 1 for this emitter so it's not zero
        _wormhole.useSequence(address(_transceiverWithPrice));

        // Expect a call to the portal with the correct parameters
        vm.expectCall(
            address(_portal),
            _TRANSCEIVER_QUOTE_VALUE,
            abi.encodeWithSelector(
                IHubPortal.sendEarnersMerkleRoot.selector,
                _SOLANA_WORMHOLE_CHAIN_ID,
                address(this).toBytes32(),
                hex"00"
            )
        );
        // Expect a call to the executor with the correct parameters
        vm.expectCall(
            address(_executor),
            _EXECUTOR_QUOTE_VALUE,
            abi.encodeWithSelector(
                MockExecutor.requestExecution.selector, //
                _SOLANA_WORMHOLE_CHAIN_ID, // destination chain
                _solanaPeer, // peer on destination
                address(this), // refund address
                hex"",
                ExecutorMessages.makeVAAv1Request(_LOCAL_CHAIN_ID, address(_transceiverWithPrice).toBytes32(), 1),
                hex""
            )
        );
        uint64 sequence = _executorEntryPoint.sendEarnersMerkleRoot{
            value: _EXECUTOR_QUOTE_VALUE + _TRANSCEIVER_QUOTE_VALUE
        }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            address(this).toBytes32(),
            ExecutorArgs({
                value: _EXECUTOR_QUOTE_VALUE,
                refundAddress: address(this),
                signedQuote: hex"",
                instructions: hex""
            }),
            hex"00"
        );

        // Verify that the sequence number is as expected (1 in this case)
        assertEq(sequence, 1);
    }
}
