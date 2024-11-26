// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import { TransceiverStructs } from "../../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { ISpokePortal } from "../../src/interfaces/ISpokePortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";
import { PayloadEncoder } from "../../src/libs/PayloadEncoder.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";
import { MockWrappedMToken } from "../mocks/MockWrappedMToken.sol";
import { MockSpokeMToken } from "../mocks/MockSpokeMToken.sol";
import { MockSpokeRegistrar } from "../mocks/MockSpokeRegistrar.sol";
import { MockTransceiver } from "../mocks/MockTransceiver.sol";

contract SpokePortalTests is UnitTestBase {
    using TypeConverter for *;

    MockSpokeMToken internal _mToken;
    MockWrappedMToken internal _smartMToken;
    MockSpokeRegistrar internal _registrar;

    SpokePortal internal _portal;

    function setUp() external {
        _mToken = new MockSpokeMToken();
        _smartMToken = new MockWrappedMToken(address(_mToken));

        _tokenDecimals = _mToken.decimals();
        _tokenAddress = address(_mToken);

        _registrar = new MockSpokeRegistrar();
        _transceiver = new MockTransceiver();

        SpokePortal implementation_ = new SpokePortal(
            address(_mToken),
            address(_smartMToken),
            address(_registrar),
            _LOCAL_CHAIN_ID
        );
        _portal = SpokePortal(_createProxy(address(implementation_)));

        _initializePortal(_portal);
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_portal.mToken(), address(_mToken));
        assertEq(_portal.registrar(), address(_registrar));
        assertEq(uint8(_portal.mode()), uint8(IManagerBase.Mode.BURNING));
        assertEq(_portal.chainId(), _LOCAL_CHAIN_ID);
    }

    /* ============ currentIndex ============ */

    function test_currentIndex() external {
        uint128 index_ = 1_100000068703;
        _mToken.setCurrentIndex(index_);
        assertEq(_portal.currentIndex(), index_);
    }

    /* ============ _updateMTokenIndex ============ */

    function test_updateMTokenIndex() external {
        uint128 index_ = 1_100000068703;

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeIndex(index_, _LOCAL_CHAIN_ID),
            _REMOTE_CHAIN_ID
        );

        vm.expectEmit();
        emit ISpokePortal.MTokenIndexReceived(messageId_, index_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.updateIndex, (index_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    /* ============ _setRegistrarKey ============ */

    function test_setRegistrarKey() external {
        bytes32 key_ = bytes32("key");
        bytes32 value_ = bytes32("value");

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeKey(key_, value_, _LOCAL_CHAIN_ID),
            _REMOTE_CHAIN_ID
        );

        vm.expectEmit();
        emit ISpokePortal.RegistrarKeyReceived(messageId_, key_, value_);

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.setKey, (key_, value_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    /* ============ setRegistrarListStatus ============ */

    function test_setRegistrarListStatus_addToList() external {
        bytes32 listName_ = bytes32("listName");
        bool status_ = true;

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeListUpdate(listName_, _bob, status_, _LOCAL_CHAIN_ID),
            _REMOTE_CHAIN_ID
        );

        vm.expectEmit();
        emit ISpokePortal.RegistrarListStatusReceived(messageId_, listName_, _bob, status_);

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.addToList, (listName_, _bob)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_setRegistrarListStatus_removeFromList() external {
        bytes32 listName_ = bytes32("listName");
        bool status_ = false;

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeListUpdate(listName_, _bob, status_, _LOCAL_CHAIN_ID),
            _REMOTE_CHAIN_ID
        );

        vm.expectEmit();
        emit ISpokePortal.RegistrarListStatusReceived(messageId_, listName_, _bob, status_);

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.removeFromList, (listName_, _bob)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    /* ============ transfer ============ */

    function test_sendMToken() external {
        uint256 amount_ = 1_000e6;

        _mToken.setCurrentIndex(_EXP_SCALED_ONE);
        _mToken.mint(_alice, amount_);

        vm.startPrank(_alice);
        _mToken.approve(address(_portal), amount_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.burn, (amount_)));

        _portal.transfer(amount_, _REMOTE_CHAIN_ID, _alice.toBytes32());
    }

    /* ============ _receiveMToken ============ */

    function test_receiveMToken_invalidTargetChain() external {
        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            1_000e6,
            _EXP_SCALED_ONE,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _REMOTE_CHAIN_ID
        );

        vm.expectRevert(
            abi.encodeWithSelector(INttManager.InvalidTargetChain.selector, _REMOTE_CHAIN_ID, _LOCAL_CHAIN_ID)
        );

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_nonEarner() external {
        uint256 amount_ = 1_000e6;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = _EXP_SCALED_ONE;

        _mToken.setCurrentIndex(localIndex_);

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeWithSignature("mint(address,uint256)", _alice, amount_));

        vm.expectEmit();
        emit IPortal.MTokenReceived(_REMOTE_CHAIN_ID, messageId_, _alice.toBytes32(), _alice, amount_, remoteIndex_);

        vm.expectEmit();
        emit INttManager.TransferRedeemed(messageId_);

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function testFuzz_receiveMToken_nonEarner(uint240 amount_, uint128 localIndex_, uint128 remoteIndex_) external {
        localIndex_ = uint128(bound(localIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        remoteIndex_ = uint128(bound(remoteIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        amount_ = uint240(bound(amount_, 1, _getMaxTransferAmount(_tokenDecimals)));

        _mToken.setCurrentIndex(localIndex_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        bytes memory call = remoteIndex_ > localIndex_
            ? abi.encodeWithSignature("mint(address,uint256,uint128)", _alice, amount_, remoteIndex_)
            : abi.encodeWithSignature("mint(address,uint256)", _alice, amount_);

        vm.expectCall(address(_mToken), call);

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_earner_lowerRemoteIndex() external {
        uint256 amount_ = 1_000e6;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = _EXP_SCALED_ONE;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeWithSignature("mint(address,uint256)", _alice, amount_));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_earner_sameRemoteIndex() external {
        uint256 amount_ = 1_000e6;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = localIndex_;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeWithSignature("mint(address,uint256)", _alice, amount_));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_earner_higherRemoteIndex() external {
        uint256 amount_ = 1_000e6;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = 1_200000068703;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(
            address(_mToken),
            abi.encodeWithSignature("mint(address,uint256,uint128)", _alice, amount_, remoteIndex_)
        );

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function testFuzz_receiveMToken_earner(uint240 amount_, uint128 localIndex_, uint128 remoteIndex_) external {
        localIndex_ = uint128(bound(localIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        remoteIndex_ = uint128(bound(remoteIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        amount_ = uint240(bound(amount_, 1, _getMaxTransferAmount(_tokenDecimals)));

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        bytes memory call = remoteIndex_ > localIndex_
            ? abi.encodeWithSignature("mint(address,uint256,uint128)", _alice, amount_, remoteIndex_)
            : abi.encodeWithSignature("mint(address,uint256)", _alice, amount_);

        vm.expectCall(address(_mToken), call);

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }
}
