// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { TransceiverStructs } from "../../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";

import { PayloadEncoder } from "../../src/libs/PayloadEncoder.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";
import { MockSpokeMToken } from "../mocks/MockSpokeMToken.sol";
import { MockSpokePortal } from "../mocks/MockSpokePortal.sol";
import { MockSpokeRegistrar } from "../mocks/MockSpokeRegistrar.sol";

contract SpokeVaultTests is UnitTestBase {
    using TypeConverter for *;

    MockSpokeMToken internal _mToken;
    MockSpokePortal internal _portal;

    address internal _hubVault;
    SpokeVault internal _vault;

    function setUp() external {
        _mToken = new MockSpokeMToken();
        _portal = new MockSpokePortal(address(_mToken));

        _hubVault = makeAddr("hubVault");
        _vault = SpokeVault(_createProxy(address(new SpokeVault(address(_portal), _hubVault, _REMOTE_CHAIN_ID))));
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_vault.destinationChainId(), _REMOTE_CHAIN_ID);
        assertEq(_vault.mToken(), address(_mToken));
        assertEq(_vault.hubVault(), _hubVault);
        assertEq(_vault.spokePortal(), address(_portal));
    }

    /* ============ constructor ============ */

    function test_constructor_zeroSpokePortal() external {
        vm.expectRevert(ISpokeVault.ZeroSpokePortal.selector);
        new SpokeVault(address(0), _hubVault, _REMOTE_CHAIN_ID);
    }

    function test_constructor_zeroHubVault() external {
        vm.expectRevert(ISpokeVault.ZeroHubVault.selector);
        new SpokeVault(address(_portal), address(0), _REMOTE_CHAIN_ID);
    }

    function test_constructor_zeroDestinationChainId() external {
        vm.expectRevert(ISpokeVault.ZeroDestinationChainId.selector);
        new SpokeVault(address(_portal), _hubVault, 0);
    }

    function test_constructor_mTokenApproval() external {
        vm.expectCall(address(_mToken), abi.encodeCall(_mToken.approve, (address(_portal), type(uint256).max)));
        new SpokeVault(address(_portal), _hubVault, _REMOTE_CHAIN_ID);
    }

    /* ============ transferExcessM ============ */

    function test_transferExcessM_insufficientBalance() external {
        uint256 amount_ = 1_000e6;

        vm.expectRevert(abi.encodeWithSelector(ISpokeVault.InsufficientMTokenBalance.selector, 0, amount_));

        vm.prank(_alice);
        _vault.transferExcessM(amount_, _alice.toBytes32());
    }

    function test_transferExcessM() external {
        uint256 amount_ = 1_000e6;
        uint256 balance_ = 10_000e6;

        vm.mockCall(address(_mToken), abi.encodeCall(_mToken.balanceOf, (address(_vault))), abi.encode(balance_));

        vm.expectCall(
            address(_portal),
            abi.encodeCall(
                _portal.transfer,
                (amount_, _REMOTE_CHAIN_ID, _hubVault.toBytes32(), _alice.toBytes32(), false, new bytes(1))
            )
        );

        vm.expectEmit();
        emit ISpokeVault.ExcessMTokenSent(_REMOTE_CHAIN_ID, 0, _alice.toBytes32(), _hubVault.toBytes32(), amount_);

        vm.prank(_alice);
        _vault.transferExcessM(amount_, _alice.toBytes32());
    }
}
