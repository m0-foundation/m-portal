// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { TransceiverStructs } from "../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IMerkleTreeBuilder } from "../../src/interfaces/IMerkleTreeBuilder.sol";
import { HubPortal } from "../../src/HubPortal.sol";
import { PayloadEncoder } from "../../src/libs/PayloadEncoder.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";
import { MockHubMToken } from "../mocks/MockHubMToken.sol";
import { MockWrappedMToken } from "../mocks/MockWrappedMToken.sol";
import { MockHubRegistrar } from "../mocks/MockHubRegistrar.sol";
import { MockSwapFacility } from "../mocks/MockSwapFacility.sol";
import { MockTransceiver } from "../mocks/MockTransceiver.sol";
import { MockMerkleTreeBuilder } from "../mocks/MockMerkleTreeBuilder.sol";

contract HubPortalTests is UnitTestBase {
    using TypeConverter for *;

    uint16 internal constant _SOLANA_WORMHOLE_CHAIN_ID = 1;
    bytes32 internal constant _SOLANA_EARNER_LIST = bytes32("solana-earners");
    bytes32 internal constant _SOLANA_EARN_MANAGER_LIST = bytes32("solana-earn-managers");

    TransceiverStructs.TransceiverInstruction internal _executorTransceiverInstruction;

    MockHubMToken internal _mToken;
    MockWrappedMToken internal _wrappedMToken;
    bytes32 internal _remoteMToken;
    bytes32 internal _remoteWrappedMToken;
    MockHubRegistrar internal _registrar;
    MockSwapFacility internal _swapFacility;
    MockMerkleTreeBuilder internal _merkleTreeBuilder;

    HubPortal internal _portal;

    bytes32 _solanaPeer = bytes32("solana-peer");
    bytes32 _solanaToken = bytes32("solana-token");

    constructor() UnitTestBase() {
        _executorTransceiverInstruction = TransceiverStructs.TransceiverInstruction({ index: 0, payload: hex"01" });
    }

    function setUp() external {
        _mToken = new MockHubMToken();
        _wrappedMToken = new MockWrappedMToken(address(_mToken));
        _remoteMToken = address(_mToken).toBytes32();
        _remoteWrappedMToken = address(_wrappedMToken).toBytes32();

        _tokenDecimals = _mToken.decimals();
        _tokenAddress = address(_mToken);

        _registrar = new MockHubRegistrar();
        _transceiver = new MockTransceiver();
        _merkleTreeBuilder = new MockMerkleTreeBuilder();
        _swapFacility = new MockSwapFacility(address(_mToken));

        HubPortal implementation_ = new HubPortal(
            address(_mToken),
            address(_registrar),
            address(_swapFacility),
            _LOCAL_CHAIN_ID
        );
        _portal = HubPortal(_createProxy(address(implementation_)));

        _initializePortal(_portal);
        _portal.setDestinationMToken(_REMOTE_CHAIN_ID, _remoteMToken);
        _portal.setSupportedBridgingPath(address(_mToken), _REMOTE_CHAIN_ID, _remoteMToken, true);
        _portal.setSupportedBridgingPath(address(_mToken), _REMOTE_CHAIN_ID, _remoteWrappedMToken, true);
        _portal.setSupportedBridgingPath(address(_wrappedMToken), _REMOTE_CHAIN_ID, _remoteMToken, true);
        _portal.setSupportedBridgingPath(address(_wrappedMToken), _REMOTE_CHAIN_ID, _remoteWrappedMToken, true);

        _portal.setMerkleTreeBuilder(address(_merkleTreeBuilder));
        _portal.setPeer(_SOLANA_WORMHOLE_CHAIN_ID, _solanaPeer, _tokenDecimals, type(uint64).max);
        _portal.setDestinationMToken(_SOLANA_WORMHOLE_CHAIN_ID, _solanaToken);
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_portal.mToken(), address(_mToken));
        assertEq(_portal.registrar(), address(_registrar));
        assertEq(_portal.swapFacility(), address(_swapFacility));
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
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();

        assertEq(_portal.currentIndex(), index_);
    }

    function test_currentIndex_earningEnabledInThePast() external {
        uint128 index_ = 1_100000068703;
        uint128 latestIndex_ = 1_200000068703;

        _mToken.setCurrentIndex(index_);
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();

        assertEq(_portal.currentIndex(), index_);

        _mToken.setCurrentIndex(latestIndex_);

        _registrar.setListContains(_EARNERS_LIST, address(_portal), false);
        _portal.disableEarning();

        _mToken.setCurrentIndex(1_300000068703);

        assertEq(_portal.currentIndex(), latestIndex_);
    }

    /* ============ enableEarning ============ */

    function test_enableEarning_earningIsEnabled() external {
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();

        vm.expectRevert(IHubPortal.EarningIsEnabled.selector);
        _portal.enableEarning();
    }

    function test_enableEarning_earningCannotBeReenabled() external {
        _mToken.setCurrentIndex(1_100000068703);

        // enable
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();

        // disable
        _registrar.setListContains(_EARNERS_LIST, address(_portal), false);
        _portal.disableEarning();

        // fail to re-enable
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

    function test_disableEarning_earningIsDisabled() external {
        vm.expectRevert(IHubPortal.EarningIsDisabled.selector);
        _portal.disableEarning();
    }

    function test_disableEarning() external {
        uint128 currentMIndex_ = 1_100000068703;

        _mToken.setCurrentIndex(currentMIndex_);

        // enable
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();

        // disable
        _registrar.setListContains(_EARNERS_LIST, address(_portal), false);

        vm.expectEmit();
        emit IHubPortal.EarningDisabled(currentMIndex_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.stopEarning, (address(_portal))));

        _portal.disableEarning();
    }

    /* ============ sendMTokenIndex ============ */

    function test_sendMTokenIndex_zeroRefundAddress() external {
        vm.expectRevert(INttManager.InvalidRefundAddress.selector);

        vm.prank(_alice);
        _portal.sendMTokenIndex(_REMOTE_CHAIN_ID, address(0).toBytes32(), RELAYER_TRANSCEIVER_INSTRUCTIONS);
    }

    function test_sendMTokenIndex() external {
        uint128 index_ = 1_100000068703;
        uint256 fee_ = 1;
        bytes32 refundAddress_ = _alice.toBytes32();

        _mToken.setCurrentIndex(index_);
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();
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
        _portal.sendMTokenIndex{ value: fee_ }(_REMOTE_CHAIN_ID, refundAddress_, RELAYER_TRANSCEIVER_INSTRUCTIONS);
    }

    function test_sendMTokenIndex_solana() external {
        uint128 index_ = 1_100000068703;
        uint256 fee_ = 1;
        bytes32 refundAddress_ = _alice.toBytes32();
        bytes32 recipient_ = refundAddress_;

        _mToken.setCurrentIndex(index_);
        _registrar.setListContains(_EARNERS_LIST, address(_portal), true);
        _portal.enableEarning();
        vm.deal(_alice, fee_);

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createTransferMessage(
            0,
            index_,
            recipient_,
            _LOCAL_CHAIN_ID,
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken
        );

        vm.expectCall(
            address(_transceiver),
            0,
            abi.encodeCall(
                _transceiver.sendMessage,
                (
                    _SOLANA_WORMHOLE_CHAIN_ID,
                    _executorTransceiverInstruction,
                    TransceiverStructs.encodeNttManagerMessage(message_),
                    _solanaPeer,
                    refundAddress_
                )
            )
        );

        vm.expectEmit();
        emit IHubPortal.MTokenIndexSent(_SOLANA_WORMHOLE_CHAIN_ID, messageId_, index_);

        vm.prank(_alice);
        _portal.sendMTokenIndex{ value: fee_ }(
            _SOLANA_WORMHOLE_CHAIN_ID,
            refundAddress_,
            EXECUTOR_TRANSCEIVER_INSTRUCTIONS
        );
    }

    /* ============ sendRegistrarKey ============ */

    function test_sendRegistrarKey_zeroRefundAddress() external {
        vm.expectRevert(INttManager.InvalidRefundAddress.selector);

        vm.prank(_alice);
        _portal.sendRegistrarKey(
            _REMOTE_CHAIN_ID,
            bytes32("key"),
            address(0).toBytes32(),
            RELAYER_TRANSCEIVER_INSTRUCTIONS
        );
    }

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
            RELAYER_TRANSCEIVER_INSTRUCTIONS
        );
    }

    /* ============ sendRegistrarListStatus ============ */

    function test_sendRegistrarListStatus_zeroRefundAddress() external {
        vm.expectRevert(INttManager.InvalidRefundAddress.selector);

        vm.prank(_alice);
        _portal.sendRegistrarListStatus(
            _REMOTE_CHAIN_ID,
            bytes32("listName"),
            _bob,
            address(0).toBytes32(),
            RELAYER_TRANSCEIVER_INSTRUCTIONS
        );
    }

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
            RELAYER_TRANSCEIVER_INSTRUCTIONS
        );
    }

    /* ============ sendMerkleRoots ============ */

    function test_sendEarnersMerkleRoot() external {
        bytes32 refundAddress_ = _alice.toBytes32();
        bytes32 earnersMerkleRoot_ = bytes32("solana-earners-root");
        uint128 index_ = 0;

        _mToken.setCurrentIndex(index_);

        // Mock MerkleTreeBuilder to return roots
        vm.mockCall(
            address(_merkleTreeBuilder),
            abi.encodeWithSelector(IMerkleTreeBuilder.getRoot.selector, _SOLANA_EARNER_LIST),
            abi.encode(earnersMerkleRoot_)
        );

        // Expected NTT message
        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createMerkleRootTransferMessage(
            index_,
            refundAddress_,
            _LOCAL_CHAIN_ID,
            _SOLANA_WORMHOLE_CHAIN_ID,
            _solanaToken,
            earnersMerkleRoot_
        );

        // expect to call sendMessage in Transceiver
        vm.expectCall(
            address(_transceiver),
            0,
            abi.encodeCall(
                _transceiver.sendMessage,
                (
                    _SOLANA_WORMHOLE_CHAIN_ID,
                    _executorTransceiverInstruction,
                    TransceiverStructs.encodeNttManagerMessage(message_),
                    _solanaPeer,
                    refundAddress_
                )
            )
        );

        vm.expectEmit();
        emit IHubPortal.EarnersMerkleRootSent(_SOLANA_WORMHOLE_CHAIN_ID, messageId_, earnersMerkleRoot_);

        vm.prank(_alice);
        _portal.sendEarnersMerkleRoot(_SOLANA_WORMHOLE_CHAIN_ID, refundAddress_, EXECUTOR_TRANSCEIVER_INSTRUCTIONS);
    }

    /* ============ transfer ============ */

    function test_transfer() external {
        uint256 amount_ = 1_000e6;
        uint256 fee_ = 1;

        vm.deal(_alice, fee_);
        _mToken.mint(_alice, amount_);

        vm.startPrank(_alice);
        _mToken.approve(address(_portal), amount_);

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transferFrom, (_alice, address(_portal), amount_)));

        _portal.transfer{ value: fee_ }(amount_, _REMOTE_CHAIN_ID, _alice.toBytes32());
    }

    /* ============ transferMLikeToken ============ */

    function test_transferMLikeToken_sourceTokenWrappedM() external {
        uint256 amount_ = 1_000e6;
        uint128 index_ = 0;
        bytes32 recipient_ = _alice.toBytes32();
        bytes32 refundAddress_ = recipient_;

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createTransferMessage(
            amount_,
            index_,
            recipient_,
            _LOCAL_CHAIN_ID,
            _REMOTE_CHAIN_ID,
            _remoteWrappedMToken
        );

        _mToken.mint(_alice, amount_);

        vm.startPrank(_alice);
        _mToken.approve(address(_wrappedMToken), amount_);
        amount_ = _wrappedMToken.wrap(_alice, amount_);
        _wrappedMToken.approve(address(_portal), amount_);

        // expect to call sendMessage in Transceiver
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
        emit IPortal.MTokenSent(
            address(_wrappedMToken),
            _REMOTE_CHAIN_ID,
            _remoteWrappedMToken,
            _alice,
            recipient_,
            amount_,
            index_,
            messageId_
        );

        vm.expectEmit();
        emit INttManager.TransferSent(messageId_);

        _portal.transferMLikeToken(
            amount_,
            address(_wrappedMToken),
            _REMOTE_CHAIN_ID,
            _remoteWrappedMToken,
            recipient_,
            refundAddress_,
            RELAYER_TRANSCEIVER_INSTRUCTIONS
        );

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_wrappedMToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(address(_portal)), amount_);
        assertEq(_wrappedMToken.balanceOf(address(_portal)), 0);
    }

    function test_transferMLikeToken_sourceTokenM() external {
        uint256 amount_ = 1_000e6;
        uint128 index_ = 0;
        bytes32 recipient_ = _alice.toBytes32();
        bytes32 refundAddress_ = recipient_;

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createTransferMessage(
            amount_,
            index_,
            recipient_,
            _LOCAL_CHAIN_ID,
            _REMOTE_CHAIN_ID,
            _remoteWrappedMToken
        );

        _mToken.mint(_alice, amount_);

        vm.startPrank(_alice);
        _mToken.approve(address(_portal), amount_);

        // expect to call sendMessage in Transceiver
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
        emit IPortal.MTokenSent(
            address(_mToken),
            _REMOTE_CHAIN_ID,
            _remoteWrappedMToken,
            _alice,
            recipient_,
            amount_,
            index_,
            messageId_
        );

        vm.expectEmit();
        emit INttManager.TransferSent(messageId_);

        _portal.transferMLikeToken(
            amount_,
            address(_mToken),
            _REMOTE_CHAIN_ID,
            _remoteWrappedMToken,
            recipient_,
            refundAddress_,
            RELAYER_TRANSCEIVER_INSTRUCTIONS
        );

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_mToken.balanceOf(address(_portal)), amount_);
    }

    /* ============ receiveMToken ============ */

    function test_receiveMToken_invalidTargetChain() external {
        uint16 invalidChainId = 1111;

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            1_000e6,
            _EXP_SCALED_ONE,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            invalidChainId,
            address(_mToken).toBytes32()
        );

        vm.expectRevert(
            abi.encodeWithSelector(INttManager.InvalidTargetChain.selector, invalidChainId, _LOCAL_CHAIN_ID)
        );

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_nonEarner() external {
        uint256 amount_ = 1_000e6;
        uint128 remoteIndex_ = _EXP_SCALED_ONE;

        _mToken.mint(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID,
            _remoteMToken
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        vm.expectEmit();
        emit IPortal.MTokenReceived(
            _REMOTE_CHAIN_ID,
            _remoteMToken.toAddress(),
            _alice.toBytes32(),
            _alice,
            amount_,
            remoteIndex_,
            messageId_
        );

        vm.expectEmit();
        emit INttManager.TransferRedeemed(messageId_);

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function testFuzz_receiveMToken_nonEarner(uint240 amount_, uint128 localIndex_, uint128 remoteIndex_) external {
        // Mainnet index is always greater than a spoke index.
        localIndex_ = uint128(bound(localIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        remoteIndex_ = uint128(bound(remoteIndex_, _EXP_SCALED_ONE, localIndex_));
        amount_ = uint240(bound(amount_, 1, _getMaxTransferAmount(_tokenDecimals)));

        _mToken.setCurrentIndex(localIndex_);
        _mToken.mint(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID,
            address(_mToken).toBytes32()
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }

    function test_receiveMToken_earner_lowerIncomingIndex() external {
        uint256 amount_ = 1_000e6;
        uint128 localIndex_ = 1_100000068703;
        uint128 remoteIndex_ = _EXP_SCALED_ONE;

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(_alice, true);
        _mToken.setIsEarning(address(_portal), true);
        _mToken.mint(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID,
            address(_mToken).toBytes32()
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

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
        _mToken.mint(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID,
            address(_mToken).toBytes32()
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

        _mToken.setCurrentIndex(localIndex_);
        _mToken.setIsEarning(address(_portal), true);
        _mToken.setIsEarning(_alice, true);
        _mToken.mint(address(_portal), amount_);

        (TransceiverStructs.NttManagerMessage memory message_, ) = _createTransferMessage(
            amount_,
            remoteIndex_,
            _alice.toBytes32(),
            _REMOTE_CHAIN_ID,
            _LOCAL_CHAIN_ID,
            address(_mToken).toBytes32()
        );

        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.transfer, (_alice, amount_)));

        vm.prank(address(_transceiver));
        _portal.attestationReceived(_REMOTE_CHAIN_ID, _PEER, message_);
    }
}
