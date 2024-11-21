// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import { TransceiverStructs } from "../../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";
import { TrimmedAmountLib } from "../../lib/example-native-token-transfers/evm/src/libraries/TrimmedAmount.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { PayloadEncoder } from "../../src/libs/PayloadEncoder.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";
import { MockSpokeMToken } from "../mocks/MockSpokeMToken.sol";
import { MockTransceiver } from "../mocks/MockTransceiver.sol";
import { MockSpokeRegistrar } from "../mocks/MockSpokeRegistrar.sol";
import { PortalHarness } from "../harnesses/PortalHarness.sol";

contract PortalTests is UnitTestBase {
    using TypeConverter for *;
    using TrimmedAmountLib for *;

    MockSpokeMToken internal _mToken;
    MockSpokeRegistrar internal _registrar;

    PortalHarness internal _portal;

    function setUp() external {
        _mToken = new MockSpokeMToken();

        _tokenDecimals = _mToken.decimals();
        _tokenAddress = address(_mToken);

        _registrar = new MockSpokeRegistrar();
        _transceiver = new MockTransceiver();

        PortalHarness implementation_ = new PortalHarness(
            address(_mToken),
            address(_registrar),
            IManagerBase.Mode.BURNING,
            _LOCAL_CHAIN_ID
        );
        _portal = PortalHarness(_createProxy(address(implementation_)));
        _initializePortal(_portal);
    }

    /* ============ constructor ============ */

    function test_constructor_zeroMToken() external {
        vm.expectRevert(IPortal.ZeroMToken.selector);
        new PortalHarness(address(0), address(_registrar), IManagerBase.Mode.BURNING, _LOCAL_CHAIN_ID);
    }

    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(IPortal.ZeroRegistrar.selector);
        new PortalHarness(address(_mToken), address(0), IManagerBase.Mode.BURNING, _LOCAL_CHAIN_ID);
    }

    /* ============ transfer ============ */

    function test_transfer_insufficientAmount() external {
        vm.expectRevert(INttManager.ZeroAmount.selector);

        vm.prank(_alice);
        _portal.transfer(0, _REMOTE_CHAIN_ID, _alice.toBytes32());
    }

    function test_transfer_invalidRecipient() external {
        vm.expectRevert(INttManager.InvalidRecipient.selector);

        vm.prank(_alice);
        _portal.transfer(1_000e6, _REMOTE_CHAIN_ID, bytes32(0));
    }

    function test_transfer_indexOverflow() external {
        vm.expectRevert(TypeConverter.Uint64Overflow.selector);

        _createTransferMessage(
            1_000e6,
            uint128(type(uint64).max) + 1,
            _alice.toBytes32(),
            _LOCAL_CHAIN_ID,
            _REMOTE_CHAIN_ID
        );
    }

    function test_transfer() external {
        uint256 amount_ = 1_000e6;
        uint128 index_ = 0;
        uint256 msgValue_ = 2;
        bytes32 recipient_ = _alice.toBytes32();

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createTransferMessage(
            amount_,
            index_,
            recipient_,
            _LOCAL_CHAIN_ID,
            _REMOTE_CHAIN_ID
        );

        vm.deal(_alice, msgValue_);
        _mToken.mint(_alice, amount_);

        vm.startPrank(_alice);
        _mToken.approve(address(_portal), amount_);

        vm.expectCall(
            address(_transceiver),
            0,
            abi.encodeCall(
                _transceiver.sendMessage,
                (
                    _REMOTE_CHAIN_ID,
                    _emptyTransceiverInstruction,
                    TransceiverStructs.encodeNttManagerMessage(message_),
                    _PEER,
                    recipient_
                )
            )
        );

        vm.expectEmit();
        emit IPortal.MTokenSent(_REMOTE_CHAIN_ID, messageId_, _alice, recipient_, amount_, index_);

        _portal.transfer{ value: msgValue_ }(amount_, _REMOTE_CHAIN_ID, recipient_);
    }

    /* ============ _handleMsg ============ */

    function test_handleMsg_invalidFork() external {
        uint256 amount_ = 1_000e6;
        uint128 index_ = 0;
        bytes32 recipient_ = _alice.toBytes32();

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            index_,
            recipient_,
            _LOCAL_CHAIN_ID,
            _REMOTE_CHAIN_ID
        );

        vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidFork.selector, 31337, 1));

        vm.chainId(1);
        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_handleMsg_invalidPayloadLength() external {
        TransceiverStructs.NttManagerMessage memory message_ = TransceiverStructs.NttManagerMessage(
            bytes32(0),
            _alice.toBytes32(),
            "a"
        );

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadLength.selector, 1));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_handleMsg_invalidPayloadType() external {
        TransceiverStructs.NttManagerMessage memory message_ = TransceiverStructs.NttManagerMessage(
            bytes32(0),
            _alice.toBytes32(),
            hex"AAAAAAAA"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PayloadEncoder.InvalidPayloadPrefix.selector,
                0xaaaaaaaa00000000000000000000000000000000000000000000000000000000
            )
        );

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }
}
