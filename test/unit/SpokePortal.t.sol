// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { ISpokePortal } from "../../src/interfaces/ISpokePortal.sol";

import { SpokePortal } from "../../src/SpokePortal.sol";

import { MockBridge, MockSpokeMToken, MockSpokeRegistrar } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract SpokePortalTests is Test {
    /* ============ Deployer ============ */

    address internal _deployer = makeAddr("deployer");

    /* ============ Users ============ */

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _david = makeAddr("david");

    /* ============ Variables ============ */

    MockBridge public bridge;
    MockSpokeMToken public mToken;
    MockSpokeRegistrar public registrar;

    SpokePortal public portal;

    function setUp() external {
        bridge = new MockBridge();
        mToken = new MockSpokeMToken();
        registrar = new MockSpokeRegistrar();
        portal = new SpokePortal(address(bridge), address(mToken), address(registrar));
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(portal.bridge(), address(bridge));
        assertEq(portal.mToken(), address(mToken));
        assertEq(portal.registrar(), address(registrar));
    }

    /* ============ currentIndex ============ */

    function test_currentIndex() external {
        uint128 index_ = 1_100000068703;
        mToken.setCurrentIndex(index_);

        assertEq(portal.currentIndex(), index_);
    }

    /* ============ updateMTokenIndex ============ */

    function test_updateMTokenIndex_onlyBridge() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.NotBridge.selector, _alice));

        vm.prank(_alice);
        portal.updateMTokenIndex(1_100000068703);
    }

    function test_updateMTokenIndex() external {
        uint128 index_ = 1_100000068703;

        vm.expectEmit();
        emit ISpokePortal.MTokenIndexReceived(address(bridge), index_);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.updateIndex, (index_)));

        vm.prank(address(bridge));
        portal.updateMTokenIndex(index_);
    }

    /* ============ setRegistrarKey ============ */

    function test_setRegistrarKey_onlyBridge() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.NotBridge.selector, _alice));

        vm.prank(_alice);
        portal.setRegistrarKey(bytes32("key"), bytes32("value"));
    }

    function test_setRegistrarKey() external {
        bytes32 key_ = bytes32("key");
        bytes32 value_ = bytes32("value");

        vm.expectEmit();
        emit ISpokePortal.RegistrarKeyReceived(address(bridge), key_, value_);

        vm.expectCall(address(registrar), abi.encodeCall(registrar.setKey, (key_, value_)));

        vm.prank(address(bridge));
        portal.setRegistrarKey(key_, value_);
    }

    /* ============ setRegistrarListStatus ============ */

    function test_setRegistrarListStatus_onlyBridge() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.NotBridge.selector, _alice));

        vm.prank(_alice);
        portal.setRegistrarListStatus(bytes32("listName"), _bob, true);
    }

    function test_setRegistrarListStatus_addToList() external {
        bytes32 listName_ = bytes32("listName");
        bool status_ = true;

        vm.expectEmit();
        emit ISpokePortal.RegistrarListStatusReceived(address(bridge), listName_, _bob, status_);

        vm.expectCall(address(registrar), abi.encodeCall(registrar.addToList, (listName_, _bob)));

        vm.prank(address(bridge));
        portal.setRegistrarListStatus(listName_, _bob, status_);
    }

    function test_setRegistrarListStatus_removeFromList() external {
        bytes32 listName_ = bytes32("listName");
        bool status_ = false;

        vm.expectEmit();
        emit ISpokePortal.RegistrarListStatusReceived(address(bridge), listName_, _bob, status_);

        vm.expectCall(address(registrar), abi.encodeCall(registrar.removeFromList, (listName_, _bob)));

        vm.prank(address(bridge));
        portal.setRegistrarListStatus(listName_, _bob, status_);
    }

    /* ============ sendMToken ============ */

    function test_sendMToken() external {
        uint256 amount_ = 1_000e6;

        vm.expectCall(address(mToken), abi.encodeCall(mToken.burn, (_alice, amount_)));

        vm.prank(_alice);
        portal.sendMToken(1, _alice, amount_, _alice);
    }

    /* ============ receiveMToken ============ */

    function test_receiveMToken_nonEarner() external {
        mToken.setCurrentIndex(1_100000068703);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, 1_000e6, Utils.EXP_SCALED_ONE)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, Utils.EXP_SCALED_ONE);
    }

    function testFuzz_receiveMToken_nonEarner(uint240 amount_, uint128 localIndex_, uint128 incomingIndex_) external {
        localIndex_ = uint128(bound(localIndex_, Utils.EXP_SCALED_ONE, 10 * Utils.EXP_SCALED_ONE));
        incomingIndex_ = uint128(bound(incomingIndex_, Utils.EXP_SCALED_ONE, 10 * Utils.EXP_SCALED_ONE));

        mToken.setCurrentIndex(localIndex_);

        amount_ = uint240(bound(amount_, 1, Utils.getMaxEarningAmount(localIndex_)));

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, amount_, incomingIndex_)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, amount_, incomingIndex_);
    }

    function test_receiveMToken_earner_lowerIncomingIndex() external {
        mToken.setCurrentIndex(1_100000068703);
        mToken.setIsEarning(_alice, true);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, 100_000068, Utils.EXP_SCALED_ONE)));

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, 1_000e6, Utils.EXP_SCALED_ONE)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, Utils.EXP_SCALED_ONE);
    }

    function test_receiveMToken_earner_sameIncomingIndex() external {
        mToken.setCurrentIndex(1_100000068703);
        mToken.setIsEarning(_alice, true);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, 1_000e6, 1_100000068703)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, 1_100000068703);
    }

    function test_receiveMToken_earner_higherIncomingIndex() external {
        mToken.setCurrentIndex(1_100000068703);
        mToken.setIsEarning(_alice, true);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, 1_000e6, 1_200000068703)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, 1_200000068703);
    }

    function testFuzz_receiveMToken_earner(uint240 amount_, uint128 localIndex_, uint128 incomingIndex_) external {
        mToken.setIsEarning(_alice, true);

        localIndex_ = uint128(bound(localIndex_, Utils.EXP_SCALED_ONE, 10 * Utils.EXP_SCALED_ONE));
        incomingIndex_ = uint128(bound(incomingIndex_, Utils.EXP_SCALED_ONE, 10 * Utils.EXP_SCALED_ONE));

        mToken.setCurrentIndex(localIndex_);

        amount_ = uint240(bound(amount_, 1, Utils.getMaxEarningAmount(localIndex_)));

        vm.expectCall(address(mToken), abi.encodeCall(mToken.mint, (_alice, amount_, incomingIndex_)));
        if (localIndex_ > incomingIndex_) {
            vm.expectCall(
                address(mToken),
                abi.encodeCall(
                    mToken.mint,
                    (_alice, (amount_ * (localIndex_ - incomingIndex_)) / Utils.EXP_SCALED_ONE, incomingIndex_)
                )
            );
        }

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, amount_, incomingIndex_);
    }
}
