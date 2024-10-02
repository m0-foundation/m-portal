// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IManagerBase } from "lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";

import { MockSpokeMToken, MockSpokeRegistrar } from "../utils/Mocks.sol";
import { PortalHarness } from "../utils/PortalHarness.sol";
import { Utils } from "../utils/Utils.sol";

contract PortalTests is Test {
    uint16 internal _WORMHOLE_CHAIN_ID = 2;

    /* ============ Deployer ============ */

    address internal _deployer = makeAddr("deployer");

    /* ============ Users ============ */

    address internal _alice = makeAddr("alice");

    /* ============ Variables ============ */

    MockSpokeMToken public mToken;
    MockSpokeRegistrar public registrar;

    PortalHarness public portal;

    function setUp() external {
        mToken = new MockSpokeMToken();
        registrar = new MockSpokeRegistrar();
        portal = new PortalHarness(address(mToken), address(registrar), IManagerBase.Mode.BURNING, _WORMHOLE_CHAIN_ID);
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(portal.mToken(), address(mToken));
        assertEq(portal.registrar(), address(registrar));
        assertEq(uint8(portal.mode()), uint8(IManagerBase.Mode.BURNING));
        assertEq(portal.chainId(), _WORMHOLE_CHAIN_ID);
    }

    /* ============ constructor ============ */
    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.ZeroRegistrar.selector));
        new PortalHarness(address(mToken), address(0), IManagerBase.Mode.BURNING, _WORMHOLE_CHAIN_ID);
    }

    // /* ============ quoteSendMToken ============ */

    // function test_quoteSendMToken() external {
    //     uint256 amount_ = 1_000e6;
    //     uint256 chainId_ = Utils.LOCAL_CHAIN_ID;
    //     uint128 index_ = Utils.EXP_SCALED_ONE;

    //     mToken.setCurrentIndex(index_);

    //     vm.expectCall(
    //         address(bridge),
    //         abi.encodeWithSelector(
    //             IBridge.quote.selector,
    //             chainId_,
    //             abi.encodeCall(IPortal.receiveMToken, (Utils.LOCAL_CHAIN_ID, _alice, _alice, amount_, index_)),
    //             Utils.SEND_M_TOKEN_GAS_LIMIT
    //         )
    //     );

    //     vm.prank(_alice);
    //     portal.quoteSendMToken(chainId_, _alice, amount_);
    // }

    // /* ============ sendMToken ============ */

    // function test_sendMToken_insufficientAmount() external {
    //     vm.expectRevert(abi.encodeWithSelector(IPortal.InsufficientAmount.selector, 0));

    //     vm.prank(_alice);
    //     portal.sendMToken(1, _alice, 0, _alice);
    // }

    // function test_sendMToken_invalidRecipient() external {
    //     vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidRecipient.selector, address(0)));

    //     vm.prank(_alice);
    //     portal.sendMToken(1, address(0), 1_000e6, _alice);
    // }

    // function test_sendMToken() external {
    //     uint256 chainId_ = 1;
    //     uint256 amount_ = 1_000e6;
    //     uint128 index_ = 0;
    //     uint256 msgValue_ = 1;

    //     vm.expectCall(
    //         address(bridge),
    //         msgValue_,
    //         abi.encodeWithSelector(
    //             IBridge.dispatch.selector,
    //             chainId_,
    //             abi.encodeCall(IPortal.receiveMToken, (Utils.LOCAL_CHAIN_ID, _alice, _alice, amount_, index_)),
    //             Utils.SEND_M_TOKEN_GAS_LIMIT,
    //             _alice
    //         )
    //     );

    //     vm.expectEmit();
    //     emit IPortal.MTokenSent(chainId_, address(bridge), 0, _alice, _alice, amount_, index_);

    //     vm.deal(_alice, msgValue_);

    //     vm.prank(_alice);
    //     portal.sendMToken{ value: msgValue_ }(chainId_, _alice, amount_, _alice);
    // }

    // /* ============ receiveMToken ============ */

    // function test_receiveMToken_notBridge() external {
    //     vm.expectRevert(abi.encodeWithSelector(IPortal.NotBridge.selector, _alice));
    //     vm.prank(_alice);
    //     portal.receiveMToken(1, _alice, _alice, 0, 0);
    // }

    // function test_receiveMToken() external {
    //     uint256 amount_ = 1_000e6;
    //     uint256 fromChainId_ = 1;
    //     uint128 index_ = Utils.EXP_SCALED_ONE;

    //     vm.expectEmit();
    //     emit IPortal.MTokenReceived(fromChainId_, address(bridge), _alice, _alice, amount_, index_);

    //     vm.prank(address(bridge));
    //     portal.receiveMToken(fromChainId_, _alice, _alice, amount_, index_);
    // }
}
