// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IManagerBase } from "lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { TransceiverStructs } from "lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { HubPortal } from "../../src/HubPortal.sol";
import { PayloadEncoder } from "../../src/libs/PayloadEncoder.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";
import { MockHubMToken } from "../mocks/MockHubMToken.sol";
import { MockHubRegistrar } from "../mocks/MockHubRegistrar.sol";
import { MockTransceiver } from "../mocks/MockTransceiver.sol";

contract HubPortalTests is UnitTestBase {
    using TypeConverter for *;

    MockHubMToken internal _mToken;
    MockHubRegistrar internal _registrar;

    HubPortal internal _portal;

    function setUp() external {
        _mToken = new MockHubMToken();

        _tokenDecimals = _mToken.decimals();
        _tokenAddress = address(_mToken);

        _registrar = new MockHubRegistrar();
        _transceiver = new MockTransceiver();

        HubPortal implementation_ = new HubPortal(address(_mToken), address(_registrar), _LOCAL_CHAIN_ID);
        _portal = HubPortal(_createProxy(address(implementation_)));

        _initializePortal(_portal);
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_portal.mToken(), address(_mToken));
        assertEq(_portal.registrar(), address(_registrar));
        assertEq(uint8(_portal.mode()), uint8(IManagerBase.Mode.LOCKING));
        assertEq(_portal.chainId(), _LOCAL_CHAIN_ID);
    }

    /* ============ currentIndex ============ */

    function test_currentIndex_initialState() external {
        assertEq(_portal.currentIndex(), 0);
    }

    function test_currentIndex_earningEnabled() external {
        uint128 index_ = 1_100000068703;

        _mToken.setCurrentIndex(index_);
        _mToken.setIsEarning(address(_portal), true);

        assertEq(_portal.currentIndex(), index_);
    }

    function test_currentIndex_earningEnabledInThePast() external {
        uint128 index_ = 1_100000068703;
        uint128 latestIndex_ = 1_200000068703;

        _mToken.setCurrentIndex(index_);
        _mToken.setIsEarning(address(_portal), true);

        assertEq(_portal.currentIndex(), index_);

        _mToken.setCurrentIndex(latestIndex_);

        _portal.disableEarning();

        _mToken.setIsEarning(address(_portal), false);
        _mToken.setCurrentIndex(1_300000068703);

        assertEq(_portal.currentIndex(), latestIndex_);
    }

    /* ============ isEarningEnabled ============ */

    function test_isEarningEnabled() external {
        assertFalse(_portal.isEarningEnabled());

        _mToken.setIsEarning(address(_portal), true);
        assertTrue(_portal.isEarningEnabled());
    }

    /* ============ enableEarning ============ */

    function test_enableEarning_notApprovedEarner() external {
        vm.expectRevert(abi.encodeWithSelector(IHubPortal.NotApprovedEarner.selector));
        _portal.enableEarning();
    }

    function test_enableEarning_earningIsEnabled() external {
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _mToken.setIsEarning(address(_portal), true);

        vm.expectRevert(IHubPortal.EarningIsEnabled.selector);
        _portal.enableEarning();
    }

    function test_enableEarning_earningCannotBeReenabled() external {
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);

        _portal.enableEarning();

        _mToken.setIsEarning(address(_portal), true);
        _registrar.setListContains(_EARNERS_LIST, address(_portal), false);

        _portal.disableEarning();

        _mToken.setIsEarning(address(_portal), false);
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);

        vm.expectRevert(IHubPortal.EarningCannotBeReenabled.selector);
        _portal.enableEarning();
    }

    function test_enableEarning() external {
        uint128 currentMIndex_ = 1_100000068703;

        _mToken.setCurrentIndex(currentMIndex_);
        _registrar.set(_EARNERS_LIST_IGNORED, bytes32("1"));

        vm.expectEmit();
        emit IHubPortal.EarningEnabled(currentMIndex_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.startEarning, ()));
        _portal.enableEarning();
    }

    /* ============ disableEarning ============ */

    function test_disableEarning_approvedEarner() external {
        _registrar.set(_EARNERS_LIST_IGNORED, bytes32("1"));

        vm.expectRevert(IHubPortal.IsApprovedEarner.selector);
        _portal.disableEarning();
    }

    function test_disableEarning_earningIsDisabled() external {
        vm.expectRevert(IHubPortal.EarningIsDisabled.selector);
        _portal.disableEarning();
    }

    function test_disableEarning() external {
        uint128 currentMIndex_ = 1_100000068703;

        _mToken.setCurrentIndex(currentMIndex_);
        _mToken.setIsEarning(address(_portal), true);

        vm.expectEmit();
        emit IHubPortal.EarningDisabled(currentMIndex_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.stopEarning, ()));
        _portal.disableEarning();
    }

    /* ============ sendMTokenIndex ============ */

    function test_sendMTokenIndex() external {
        uint128 index_ = 1_100000068703;
        uint256 fee_ = 1;
        bytes32 refundAddress_ = _alice.toBytes32();

        _mToken.setCurrentIndex(index_);
        _mToken.setIsEarning(address(_portal), true);
        vm.deal(_alice, fee_);

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeIndex(index_, _REMOTE_CHAIN_ID),
            _LOCAL_CHAIN_ID
        );

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
                    refundAddress_
                )
            )
        );

        vm.expectEmit();
        emit IHubPortal.MTokenIndexSent(_REMOTE_CHAIN_ID, messageId_, index_);

        vm.prank(_alice);
        _portal.sendMTokenIndex{ value: fee_ }(_REMOTE_CHAIN_ID, refundAddress_, _encodedEmptyTransceiverInstructions);
    }

    /* ============ sendRegistrarKey ============ */

    function test_sendRegistrarKey() external {
        bytes32 key_ = bytes32("key");
        bytes32 value_ = bytes32("value");
        bytes32 refundAddress_ = _alice.toBytes32();
        uint256 fee_ = 1;

        _registrar.set(key_, value_);
        vm.deal(_alice, fee_);

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeKey(key_, value_, _REMOTE_CHAIN_ID),
            _LOCAL_CHAIN_ID
        );

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
                    refundAddress_
                )
            )
        );

        vm.expectEmit();
        emit IHubPortal.RegistrarKeySent(_REMOTE_CHAIN_ID, messageId_, key_, value_);

        vm.prank(_alice);
        _portal.sendRegistrarKey{ value: fee_ }(
            _REMOTE_CHAIN_ID,
            key_,
            refundAddress_,
            _encodedEmptyTransceiverInstructions
        );
    }

    /* ============ sendRegistrarListStatus ============ */

    function test_sendRegistrarListStatus() external {
        bytes32 listName_ = bytes32("listName");
        bool status_ = true;
        address account_ = _bob;
        bytes32 refundAddress_ = _alice.toBytes32();
        uint256 fee_ = 1;

        vm.deal(_alice, fee_);
        _registrar.setListContains(listName_, account_, status_);

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMessage(
            PayloadEncoder.encodeListUpdate(listName_, account_, status_, _REMOTE_CHAIN_ID),
            _LOCAL_CHAIN_ID
        );

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
                    refundAddress_
                )
            )
        );

        vm.expectEmit();
        emit IHubPortal.RegistrarListStatusSent(_REMOTE_CHAIN_ID, messageId_, listName_, account_, status_);

        vm.prank(_alice);
        _portal.sendRegistrarListStatus{ value: fee_ }(
            _REMOTE_CHAIN_ID,
            listName_,
            account_,
            refundAddress_,
            _encodedEmptyTransceiverInstructions
        );
    }

    /* ============ transfer ============ */

    function test_transfer() external {
        uint256 amount_ = 1_000e6;
        uint256 fee_ = 1;

        vm.deal(_alice, fee_);
        _mToken.mintTo(_alice, amount_);

        vm.startPrank(_alice);
        _mToken.approve(address(_portal), amount_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transferFrom, (_alice, address(_portal), amount_)));

        _portal.transfer{ value: fee_ }(amount_, _REMOTE_CHAIN_ID, _alice.toBytes32());
    }

    /* ============ receiveMToken ============ */

    function test_receiveMToken_nonEarner() external {
        uint256 amount_ = 1_000e6;
        uint128 remoteIndex_ = _EXP_SCALED_ONE;

        _mToken.mintTo(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function testFuzz_receiveMToken_nonEarner(uint240 amount_, uint128 localIndex_, uint128 remoteIndex_) external {
        // Mainnet index is always greater than a spoke index.
        localIndex_ = uint128(bound(localIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        remoteIndex_ = uint128(bound(remoteIndex_, _EXP_SCALED_ONE, localIndex_));
        amount_ = uint240(bound(amount_, 1, _getMaxTransferAmount(_tokenDecimals)));

        _mToken.setCurrentIndex(localIndex_);
        _mToken.mintTo(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_earner_lowerIncomingIndex() external {
        uint256 amount_ = 1_000e6;
        uint256 excess_ = 100_000068;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = _EXP_SCALED_ONE;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);
        _mToken.setIsEarning(address(_portal), true);
        _mToken.mintTo(address(_portal), amount_ + excess_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));
        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, excess_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_earner_sameIncomingIndex() external {
        uint256 amount_ = 1_000e6;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = localIndex_;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);
        _mToken.setIsEarning(address(_portal), true);
        _mToken.mintTo(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function testFuzz_receiveMToken_earner(uint240 amount_, uint128 localIndex_, uint128 remoteIndex_) external {
        // Mainnet index is always greater than spoke index.
        localIndex_ = uint128(bound(localIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        remoteIndex_ = uint128(bound(remoteIndex_, _EXP_SCALED_ONE, localIndex_));
        amount_ = uint240(bound(amount_, 1, _getMaxTransferAmount(_tokenDecimals)));
        uint240 excess_ = localIndex_ > remoteIndex_ ? (amount_ * (localIndex_ - remoteIndex_)) / _EXP_SCALED_ONE : 0;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(address(_portal), true);
        _mToken.setIsEarning(_alice, true);
        _mToken.mintTo(address(_portal), amount_ + excess_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        if (localIndex_ > remoteIndex_) {
            vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, excess_)));
        }

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }
}
