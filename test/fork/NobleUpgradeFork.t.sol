// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    IAccessControl
} from "../../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { TrimmedAmountLib } from "../../lib/native-token-transfers/evm/src/libraries/TrimmedAmount.sol";
import { TransceiverStructs } from "../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { ISwapFacilityLike } from "../../src/interfaces/ISwapFacilityLike.sol";
import { PayloadEncoder } from "../../src/libs/PayloadEncoder.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

/**
 * @title  Mainnet fork tests for the Noble Portal SwapFacility upgrade.
 * @dev    Simulates the real upgrade: deploys the new HubPortal implementation,
 *         upgrades the Noble Portal proxy from its owner Safe, grants M_SWAPPER_ROLE
 *         on the real SwapFacility, then exercises both bridging directions.
 */
contract NobleUpgradeForkTests is Test {
    using TypeConverter for *;
    using TrimmedAmountLib for *;

    uint256 internal constant _MAINNET_FORK_BLOCK = 25_727_900;

    address internal constant _M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;
    address internal constant _REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant _SWAP_FACILITY = 0xB6807116b3B1B321a390594e31ECD6e0076f6278;
    address internal constant _SWAP_FACILITY_ADMIN = 0x48670B46380FE1645f0E3e821a25162dB2589D19;

    address internal constant _NOBLE_PORTAL = 0x83Ae82Bd4054e815fB7B189C39D9CE670369ea16;
    address internal constant _NOBLE_TRANSCEIVER = 0xc7Dd372c39E38BF11451ab4A8427B4Ae38ceF644;
    address internal constant _NOBLE_PORTAL_OWNER = 0x7176665e336e8692e9b265aB6290934C93F99cCf;

    uint16 internal constant _ETHEREUM_WORMHOLE_CHAIN_ID = 2;
    uint16 internal constant _NOBLE_WORMHOLE_CHAIN_ID = 4009;

    /// @dev Noble Portal peer on Noble chain, `getPeer(4009)` of the live Noble Portal.
    bytes32 internal constant _NOBLE_PEER = 0x0000000000000000000000002e859506ba229c183f8985d54fe7210923fb9bca;

    /// @dev $M token denom on Noble ("uusdn"), `destinationMToken(4009)` of the live Noble Portal.
    bytes32 internal constant _NOBLE_M_TOKEN = 0x000000000000000000000000000000000000000000000000000000757573646e;

    bytes32 internal constant _M_SWAPPER_ROLE = keccak256("M_SWAPPER_ROLE");

    address internal immutable _alice = makeAddr("alice");

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), _MAINNET_FORK_BLOCK);

        // Deploy the new implementation with the same immutables as the live one
        HubPortal implementation_ = new HubPortal(_M_TOKEN, _REGISTRAR, _ETHEREUM_WORMHOLE_CHAIN_ID);

        // Upgrade the Noble Portal proxy from its owner Safe
        vm.prank(_NOBLE_PORTAL_OWNER);
        IManagerBase(_NOBLE_PORTAL).upgrade(address(implementation_));

        // Grant M_SWAPPER_ROLE to the Noble Portal on SwapFacility
        vm.prank(_SWAP_FACILITY_ADMIN);
        IAccessControl(_SWAP_FACILITY).grantRole(_M_SWAPPER_ROLE, _NOBLE_PORTAL);
    }

    /* ============ upgrade ============ */

    function testFork_upgrade_state() external view {
        assertEq(HubPortal(_NOBLE_PORTAL).SWAP_FACILITY(), _SWAP_FACILITY);
        assertEq(HubPortal(_NOBLE_PORTAL).registrar(), _REGISTRAR);
        assertEq(INttManager(_NOBLE_PORTAL).token(), _M_TOKEN);
        assertEq(HubPortal(_NOBLE_PORTAL).destinationMToken(_NOBLE_WORMHOLE_CHAIN_ID), _NOBLE_M_TOKEN);
        assertTrue(
            HubPortal(_NOBLE_PORTAL).supportedBridgingPath(_WRAPPED_M_TOKEN, _NOBLE_WORMHOLE_CHAIN_ID, _NOBLE_M_TOKEN)
        );
    }

    /* ============ receive from Noble ============ */

    function testFork_receiveMToken() external {
        uint256 amount_ = 1_000e6;
        uint256 balanceBefore_ = IERC20(_M_TOKEN).balanceOf(_alice);

        _receiveFromNoble(amount_, _M_TOKEN.toBytes32(), _alice.toBytes32());

        assertApproxEqAbs(IERC20(_M_TOKEN).balanceOf(_alice) - balanceBefore_, amount_, 2);
    }

    function testFork_receiveWrappedMToken_wrapsViaSwapFacility() external {
        uint256 amount_ = 1_000e6;

        assertEq(IERC20(_WRAPPED_M_TOKEN).balanceOf(_alice), 0);

        // Expect the Portal to wrap via SwapFacility
        vm.expectCall(_SWAP_FACILITY, abi.encodeCall(ISwapFacilityLike.swapInM, (_WRAPPED_M_TOKEN, amount_, _alice)));

        _receiveFromNoble(amount_, _WRAPPED_M_TOKEN.toBytes32(), _alice.toBytes32());

        assertApproxEqAbs(IERC20(_WRAPPED_M_TOKEN).balanceOf(_alice), amount_, 2);
        assertEq(IERC20(_M_TOKEN).balanceOf(_alice), 0);
    }

    function testFork_receiveWrappedMToken_invalidWrappedToken_fallsBackToMToken() external {
        uint256 amount_ = 1_000e6;
        address invalidToken_ = makeAddr("invalid");

        // SwapFacility reverts for a non-approved extension, the Portal transfers $M instead
        _receiveFromNoble(amount_, invalidToken_.toBytes32(), _alice.toBytes32());

        assertApproxEqAbs(IERC20(_M_TOKEN).balanceOf(_alice), amount_, 2);
    }

    /* ============ send to Noble ============ */

    function testFork_transferMToken() external {
        uint256 amount_ = 1_000e6;
        uint256 portalBalanceBefore_ = IERC20(_M_TOKEN).balanceOf(_NOBLE_PORTAL);

        _fundAliceWithMToken(amount_);

        vm.startPrank(_alice);
        IERC20(_M_TOKEN).approve(_NOBLE_PORTAL, amount_);
        IPortal(_NOBLE_PORTAL).transferMLikeToken(
            amount_,
            _M_TOKEN,
            _NOBLE_WORMHOLE_CHAIN_ID,
            _NOBLE_M_TOKEN,
            _alice.toBytes32(),
            _alice.toBytes32()
        );
        vm.stopPrank();

        assertApproxEqAbs(IERC20(_M_TOKEN).balanceOf(_NOBLE_PORTAL) - portalBalanceBefore_, amount_, 2);
        assertEq(IERC20(_M_TOKEN).balanceOf(_alice), 0);
    }

    function testFork_transferWrappedMToken_unwrapsViaSwapFacility() external {
        uint256 amount_ = 1_000e6;
        uint256 portalBalanceBefore_ = IERC20(_M_TOKEN).balanceOf(_NOBLE_PORTAL);

        _fundAliceWithWrappedMToken(amount_);
        amount_ = IERC20(_WRAPPED_M_TOKEN).balanceOf(_alice);

        // Expect the Portal to unwrap via SwapFacility
        vm.expectCall(
            _SWAP_FACILITY,
            abi.encodeCall(ISwapFacilityLike.swapOutM, (_WRAPPED_M_TOKEN, amount_, _NOBLE_PORTAL))
        );

        vm.startPrank(_alice);
        IERC20(_WRAPPED_M_TOKEN).approve(_NOBLE_PORTAL, amount_);
        IPortal(_NOBLE_PORTAL).transferMLikeToken(
            amount_,
            _WRAPPED_M_TOKEN,
            _NOBLE_WORMHOLE_CHAIN_ID,
            _NOBLE_M_TOKEN,
            _alice.toBytes32(),
            _alice.toBytes32()
        );
        vm.stopPrank();

        assertApproxEqAbs(IERC20(_M_TOKEN).balanceOf(_NOBLE_PORTAL) - portalBalanceBefore_, amount_, 2);
        assertEq(IERC20(_WRAPPED_M_TOKEN).balanceOf(_alice), 0);
    }

    /* ============ helpers ============ */

    /// @dev Delivers a token transfer message from Noble by pranking the Noble Wormhole transceiver.
    function _receiveFromNoble(uint256 amount_, bytes32 destinationToken_, bytes32 recipient_) internal {
        uint8 decimals_ = IERC20(_M_TOKEN).decimals();

        TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_ = TransceiverStructs.NativeTokenTransfer(
            amount_.trim(decimals_, decimals_),
            _NOBLE_M_TOKEN,
            recipient_,
            _ETHEREUM_WORMHOLE_CHAIN_ID,
            PayloadEncoder.encodeAdditionalPayload(0, destinationToken_)
        );

        TransceiverStructs.NttManagerMessage memory message_ = TransceiverStructs.NttManagerMessage(
            bytes32(uint256(1)),
            recipient_,
            TransceiverStructs.encodeNativeTokenTransfer(nativeTokenTransfer_)
        );

        vm.prank(_NOBLE_TRANSCEIVER);
        INttManager(_NOBLE_PORTAL).attestationReceived(_NOBLE_WORMHOLE_CHAIN_ID, _NOBLE_PEER, message_);
    }

    /// @dev Funds `_alice` with $M token from the Wrapped M contract's backing balance.
    function _fundAliceWithMToken(uint256 amount_) internal {
        vm.prank(_WRAPPED_M_TOKEN);
        IERC20(_M_TOKEN).transfer(_alice, amount_);
    }

    /// @dev Funds `_alice` with Wrapped M by swapping $M via the real SwapFacility.
    function _fundAliceWithWrappedMToken(uint256 amount_) internal {
        _fundAliceWithMToken(amount_);

        vm.prank(_SWAP_FACILITY_ADMIN);
        IAccessControl(_SWAP_FACILITY).grantRole(_M_SWAPPER_ROLE, _alice);

        vm.startPrank(_alice);
        IERC20(_M_TOKEN).approve(_SWAP_FACILITY, amount_);
        ISwapFacilityLike(_SWAP_FACILITY).swapInM(_WRAPPED_M_TOKEN, amount_, _alice);
        vm.stopPrank();
    }
}
