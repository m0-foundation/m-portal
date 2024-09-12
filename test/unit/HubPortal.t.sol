// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { IBridge } from "../../src/bridges/interfaces/IBridge.sol";
import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IMTokenLike, IRegistrarLike } from "../../src/interfaces/Dependencies.sol";
import { ISpokePortal } from "../../src/interfaces/ISpokePortal.sol";

import { HubPortal } from "../../src/HubPortal.sol";

import { MockBridge, MockHubMToken, MockHubRegistrar } from "../utils/Mocks.sol";
import { Utils } from "../utils/Utils.sol";

contract HubPortalTests is Test {
    /* ============ Deployer ============ */

    address internal _deployer = makeAddr("deployer");

    /* ============ Users ============ */

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _david = makeAddr("david");

    /* ============ Variables ============ */

    MockBridge public bridge;
    MockHubMToken public mToken;
    MockHubRegistrar public registrar;

    HubPortal public portal;

    function setUp() external {
        bridge = new MockBridge();
        mToken = new MockHubMToken();
        registrar = new MockHubRegistrar();
        portal = new HubPortal(address(bridge), address(mToken), address(registrar));
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(portal.bridge(), address(bridge));
        assertEq(portal.mToken(), address(mToken));
        assertEq(portal.registrar(), address(registrar));
    }

    /* ============ currentIndex ============ */

    function test_currentIndex_initialState() external {
        assertEq(portal.currentIndex(), 0);
    }

    function test_currentIndex_earningEnabled() external {
        uint128 index_ = 1_100000068703;

        mToken.setCurrentIndex(index_);
        mToken.setIsEarning(address(portal), true);

        assertEq(portal.currentIndex(), index_);
    }

    function test_currentIndex_earningEnabledInThePast() external {
        uint128 index_ = 1_100000068703;
        uint128 latestIndex_ = 1_200000068703;

        mToken.setCurrentIndex(index_);
        mToken.setIsEarning(address(portal), true);

        assertEq(portal.currentIndex(), index_);

        mToken.setCurrentIndex(latestIndex_);

        vm.mockCall(address(mToken), abi.encodeWithSelector(IMTokenLike.stopEarning.selector), "");
        portal.disableEarning();

        mToken.setIsEarning(address(portal), false);
        mToken.setCurrentIndex(1_300000068703);

        assertEq(portal.currentIndex(), latestIndex_);
    }

    /* ============ isEarningEnabled ============ */

    function test_isEarningEnabled() external {
        assertFalse(portal.isEarningEnabled());

        mToken.setIsEarning(address(portal), true);
        assertTrue(portal.isEarningEnabled());
    }

    /* ============ enableEarning ============ */

    function test_enableEarning_notApprovedEarner() external {
        vm.expectRevert(abi.encodeWithSelector(IHubPortal.NotApprovedEarner.selector));
        portal.enableEarning();
    }

    function test_enableEarning_earningIsEnabled() external {
        registrar.setListContains(Utils.EARNERS_LIST, address(portal), true);
        mToken.setIsEarning(address(portal), true);

        vm.expectRevert(abi.encodeWithSelector(IHubPortal.EarningIsEnabled.selector));
        portal.enableEarning();
    }

    function test_enableEarning_earningCannotBeReenabled() external {
        registrar.setListContains(Utils.EARNERS_LIST, address(portal), true);

        vm.mockCall(address(mToken), abi.encodeWithSelector(IMTokenLike.startEarning.selector), "");
        portal.enableEarning();

        mToken.setIsEarning(address(portal), true);
        registrar.setListContains(Utils.EARNERS_LIST, address(portal), false);

        vm.mockCall(address(mToken), abi.encodeWithSelector(IMTokenLike.stopEarning.selector), "");
        portal.disableEarning();

        mToken.setIsEarning(address(portal), false);
        registrar.setListContains(Utils.EARNERS_LIST, address(portal), true);

        vm.expectRevert(abi.encodeWithSelector(IHubPortal.EarningCannotBeReenabled.selector));

        portal.enableEarning();
    }

    function test_enableEarning() external {
        uint128 currentMIndex_ = 1_100000068703;

        mToken.setCurrentIndex(currentMIndex_);
        registrar.set(Utils.EARNERS_LIST_IGNORED, bytes32("1"));

        vm.expectCall(address(mToken), abi.encodeCall(IMTokenLike(address(mToken)).startEarning, ()));

        vm.expectEmit();
        emit IHubPortal.EarningEnabled(currentMIndex_);

        vm.mockCall(address(mToken), abi.encodeWithSelector(IMTokenLike.startEarning.selector), "");

        portal.enableEarning();
    }

    /* ============ disableEarning ============ */

    function test_disableEarning_approvedEarner() external {
        registrar.set(Utils.EARNERS_LIST_IGNORED, bytes32("1"));

        vm.expectRevert(abi.encodeWithSelector(IHubPortal.IsApprovedEarner.selector));
        portal.disableEarning();
    }

    function test_disableEarning_earningIsDisabled() external {
        vm.expectRevert(abi.encodeWithSelector(IHubPortal.EarningIsDisabled.selector));
        portal.disableEarning();
    }

    function test_disableEarning() external {
        uint128 currentMIndex_ = 1_100000068703;

        mToken.setCurrentIndex(currentMIndex_);
        mToken.setIsEarning(address(portal), true);

        vm.expectEmit();
        emit IHubPortal.EarningDisabled(currentMIndex_);

        vm.mockCall(address(mToken), abi.encodeWithSelector(IMTokenLike.stopEarning.selector), "");

        portal.disableEarning();
    }

    /* ============ quoteSendMTokenIndex ============ */

    function test_quoteSendMTokenIndex() external {
        uint256 chainId_ = 10;
        uint128 index_ = 0;

        vm.expectCall(
            address(bridge),
            abi.encodeWithSelector(
                IBridge.quote.selector,
                chainId_,
                abi.encodeCall(ISpokePortal.updateMTokenIndex, (index_)),
                Utils.SEND_M_TOKEN_INDEX_GAS_LIMIT
            )
        );

        portal.quoteSendMTokenIndex(chainId_);
    }

    /* ============ sendMTokenIndex ============ */

    function test_sendMTokenIndex() external {
        uint256 chainId_ = 10;
        uint128 index_ = 0;
        uint256 msgValue_ = 1;

        vm.deal(_alice, msgValue_);

        vm.expectCall(
            address(bridge),
            msgValue_,
            abi.encodeWithSelector(
                IBridge.dispatch.selector,
                chainId_,
                abi.encodeCall(ISpokePortal.updateMTokenIndex, (index_)),
                Utils.SEND_M_TOKEN_INDEX_GAS_LIMIT,
                _alice
            )
        );

        vm.expectEmit();
        emit IHubPortal.MTokenIndexSent(chainId_, address(bridge), bytes32(""), index_);

        vm.prank(_alice);
        portal.sendMTokenIndex{ value: msgValue_ }(chainId_, _alice);
    }

    /* ============ quoteSendRegistrarKey ============ */

    function test_quoteSendRegistrarKey() external {
        uint256 chainId_ = 10;
        bytes32 key_ = bytes32("key");
        bytes32 value_ = bytes32("value");

        bytes memory getSelector_ = abi.encodeWithSelector(IRegistrarLike.get.selector, key_);

        vm.mockCall(address(registrar), getSelector_, abi.encode(value_));
        vm.expectCall(address(registrar), getSelector_);

        vm.expectCall(
            address(bridge),
            abi.encodeWithSelector(
                IBridge.quote.selector,
                chainId_,
                abi.encodeCall(ISpokePortal.setRegistrarKey, (key_, value_)),
                Utils.SEND_REGISTRAR_KEY_GAS_LIMIT
            )
        );

        portal.quoteSendRegistrarKey(chainId_, key_);
    }

    /* ============ sendRegistrarKey ============ */

    function test_sendRegistrarKey() external {
        uint256 chainId_ = 10;
        bytes32 key_ = bytes32("key");
        bytes32 value_ = bytes32("value");
        uint256 msgValue_ = 1;

        vm.deal(_alice, msgValue_);

        bytes memory getSelector_ = abi.encodeWithSelector(IRegistrarLike.get.selector, key_);

        vm.mockCall(address(registrar), getSelector_, abi.encode(value_));
        vm.expectCall(address(registrar), getSelector_);

        vm.expectCall(
            address(bridge),
            msgValue_,
            abi.encodeWithSelector(
                IBridge.dispatch.selector,
                chainId_,
                abi.encodeCall(ISpokePortal.setRegistrarKey, (key_, value_)),
                Utils.SEND_REGISTRAR_KEY_GAS_LIMIT,
                _alice
            )
        );

        vm.expectEmit();
        emit IHubPortal.RegistrarKeySent(chainId_, address(bridge), bytes32(""), key_, value_);

        vm.prank(_alice);
        portal.sendRegistrarKey{ value: msgValue_ }(chainId_, key_, _alice);
    }

    /* ============ quoteSendRegistrarListStatus ============ */

    function test_quoteSendRegistrarListStatus() external {
        uint256 chainId_ = 10;
        bytes32 listName_ = bytes32("listName");
        bool status_ = true;

        bytes memory listContainsSelector_ = abi.encodeWithSelector(
            IRegistrarLike.listContains.selector,
            listName_,
            _bob
        );

        vm.mockCall(address(registrar), listContainsSelector_, abi.encode(status_));
        vm.expectCall(address(registrar), listContainsSelector_);

        vm.expectCall(
            address(bridge),
            abi.encodeWithSelector(
                IBridge.quote.selector,
                chainId_,
                abi.encodeCall(ISpokePortal.setRegistrarListStatus, (listName_, _bob, status_)),
                Utils.SEND_REGISTRAR_LIST_STATUS_GAS_LIMIT
            )
        );

        portal.quoteSendRegistrarListStatus(chainId_, listName_, _bob);
    }

    /* ============ sendRegistrarListStatus ============ */

    function test_sendRegistrarListStatus() external {
        uint256 chainId_ = 10;
        bytes32 listName_ = bytes32("listName");
        bool status_ = true;
        uint256 msgValue_ = 1;

        vm.deal(_alice, msgValue_);

        bytes memory listContainsSelector_ = abi.encodeWithSelector(
            IRegistrarLike.listContains.selector,
            listName_,
            _bob
        );

        vm.mockCall(address(registrar), listContainsSelector_, abi.encode(status_));
        vm.expectCall(address(registrar), listContainsSelector_);

        vm.expectCall(
            address(bridge),
            msgValue_,
            abi.encodeWithSelector(
                IBridge.dispatch.selector,
                chainId_,
                abi.encodeCall(ISpokePortal.setRegistrarListStatus, (listName_, _bob, status_)),
                Utils.SEND_REGISTRAR_LIST_STATUS_GAS_LIMIT,
                _alice
            )
        );

        vm.expectEmit();
        emit IHubPortal.RegistrarListStatusSent(chainId_, address(bridge), bytes32(""), listName_, _bob, status_);

        vm.prank(_alice);
        portal.sendRegistrarListStatus{ value: msgValue_ }(chainId_, listName_, _bob, _alice);
    }

    /* ============ sendMToken ============ */

    function test_sendMToken() external {
        uint256 amount_ = 1_000e6;
        uint256 msgValue_ = 1;

        vm.expectCall(
            address(mToken),
            abi.encodeWithSelector(IERC20.transferFrom.selector, _alice, address(portal), amount_)
        );

        vm.deal(_alice, msgValue_);

        vm.prank(_alice);
        portal.sendMToken{ value: msgValue_ }(10, _alice, amount_, _alice);
    }

    /* ============ receiveMToken ============ */

    function test_receiveMToken_nonEarner() external {
        vm.expectCall(address(mToken), abi.encodeCall(mToken.transfer, (_alice, 1_000e6)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, Utils.EXP_SCALED_ONE);
    }

    function testFuzz_receiveMToken_nonEarner(uint240 amount_, uint128 localIndex_, uint128 incomingIndex_) external {
        // Mainnet index is always greater than spoke index.
        localIndex_ = uint128(bound(localIndex_, Utils.EXP_SCALED_ONE, 10 * Utils.EXP_SCALED_ONE));
        incomingIndex_ = uint128(bound(incomingIndex_, Utils.EXP_SCALED_ONE, localIndex_));

        mToken.setCurrentIndex(localIndex_);

        amount_ = uint240(bound(amount_, 1, Utils.getMaxEarningAmount(localIndex_)));
        vm.expectCall(address(mToken), abi.encodeCall(mToken.transfer, (_alice, amount_)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, amount_, incomingIndex_);
    }

    function test_receiveMToken_earner_lowerIncomingIndex() external {
        mToken.setCurrentIndex(1_100000068703);
        mToken.setIsEarning(address(portal), true);
        mToken.setIsEarning(_alice, true);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.transfer, (_alice, 1_000e6)));

        vm.expectCall(address(mToken), abi.encodeCall(mToken.transfer, (_alice, 100_000068)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, Utils.EXP_SCALED_ONE);
    }

    function test_receiveMToken_earner_sameIncomingIndex() external {
        mToken.setCurrentIndex(1_100000068703);
        mToken.setIsEarning(_alice, true);

        vm.expectCall(address(mToken), abi.encodeCall(mToken.transfer, (_alice, 1_000e6)));

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, 1_000e6, 1_100000068703);
    }

    function testFuzz_receiveMToken_earner(uint240 amount_, uint128 localIndex_, uint128 incomingIndex_) external {
        mToken.setIsEarning(address(portal), true);
        mToken.setIsEarning(_alice, true);

        // Mainnet index is always greater than spoke index.
        localIndex_ = uint128(bound(localIndex_, Utils.EXP_SCALED_ONE, 10 * Utils.EXP_SCALED_ONE));
        incomingIndex_ = uint128(bound(incomingIndex_, Utils.EXP_SCALED_ONE, localIndex_));

        mToken.setCurrentIndex(localIndex_);

        amount_ = uint240(bound(amount_, 1, Utils.getMaxEarningAmount(localIndex_)));

        vm.expectCall(address(mToken), abi.encodeCall(mToken.transfer, (_alice, amount_)));

        if (localIndex_ > incomingIndex_) {
            vm.expectCall(
                address(mToken),
                abi.encodeCall(
                    mToken.transfer,
                    (_alice, (amount_ * (localIndex_ - incomingIndex_)) / Utils.EXP_SCALED_ONE)
                )
            );
        }

        vm.prank(address(bridge));
        portal.receiveMToken(1, _alice, _alice, amount_, incomingIndex_);
    }
}
