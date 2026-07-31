// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IMigratable } from "../../lib/common/src/interfaces/IMigratable.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";
import { SpokeVaultMigrator } from "../../src/SpokeVaultMigrator.sol";

import { MockSpokeMToken } from "../mocks/MockSpokeMToken.sol";
import { MockSpokeVaultV2 } from "../mocks/MockSpokeVaultV2.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";

contract SpokeVaultTests is UnitTestBase {
    address internal _excessDestination = makeAddr("excessDestination");
    address internal _migrationAdmin = makeAddr("migrationAdmin");

    MockSpokeMToken internal _mToken;

    SpokeVault internal _vault;

    function setUp() external {
        _mToken = new MockSpokeMToken();

        _vault = SpokeVault(
            _createProxy(address(new SpokeVault(address(_mToken), _excessDestination, _migrationAdmin)))
        );
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_vault.mToken(), address(_mToken));
        assertEq(_vault.excessDestination(), _excessDestination);
        assertEq(_vault.migrationAdmin(), _migrationAdmin);
    }

    /* ============ constructor ============ */

    function test_constructor_zeroMToken() external {
        vm.expectRevert(ISpokeVault.ZeroMToken.selector);
        new SpokeVault(address(0), _excessDestination, _migrationAdmin);
    }

    function test_constructor_zeroExcessDestination() external {
        vm.expectRevert(ISpokeVault.ZeroExcessDestination.selector);
        new SpokeVault(address(_mToken), address(0), _migrationAdmin);
    }

    function test_constructor_zeroMigrationAdmin() external {
        vm.expectRevert(ISpokeVault.ZeroMigrationAdmin.selector);
        new SpokeVault(address(_mToken), _excessDestination, address(0));
    }

    /* ============ transferExcessM ============ */

    function test_transferExcessM_earlyReturn() external {
        vm.recordLogs();

        vm.prank(_alice);
        _vault.transferExcessM();

        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(IERC20(address(_mToken)).balanceOf(_excessDestination), 0);
    }

    function test_transferExcessM() external {
        uint256 amount_ = 10_000e6;

        _mToken.mint(address(_vault), amount_, _EXP_SCALED_ONE);

        vm.expectEmit();
        emit ISpokeVault.ExcessMTokenSent(_excessDestination, amount_);

        vm.prank(_alice);
        _vault.transferExcessM();

        assertEq(IERC20(address(_mToken)).balanceOf(address(_vault)), 0);
        assertEq(IERC20(address(_mToken)).balanceOf(_excessDestination), amount_);
    }

    function test_transferExcessM_repeated() external {
        uint256 amount_ = 10_000e6;

        _mToken.mint(address(_vault), amount_, _EXP_SCALED_ONE);

        vm.prank(_alice);
        _vault.transferExcessM();

        _mToken.mint(address(_vault), amount_, _EXP_SCALED_ONE);

        vm.prank(_bob);
        _vault.transferExcessM();

        assertEq(IERC20(address(_mToken)).balanceOf(address(_vault)), 0);
        assertEq(IERC20(address(_mToken)).balanceOf(_excessDestination), amount_ * 2);
    }

    /* ============ migrate ============ */

    function test_migrate_unauthorizedMigration() external {
        address migrator_ = address(new SpokeVaultMigrator(address(new MockSpokeVaultV2())));

        vm.expectRevert(ISpokeVault.UnauthorizedMigration.selector);

        vm.prank(_alice);
        _vault.migrate(migrator_);
    }

    function test_migrate_zeroMigrator() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);

        vm.prank(_migrationAdmin);
        _vault.migrate(address(0));
    }

    function test_migrate_byAdmin() external {
        address migrator_ = address(new SpokeVaultMigrator(address(new MockSpokeVaultV2())));

        vm.expectRevert();
        MockSpokeVaultV2(address(_vault)).foo();

        vm.prank(_migrationAdmin);
        _vault.migrate(migrator_);

        assertEq(MockSpokeVaultV2(address(_vault)).foo(), 1);
    }

    /* ============ migrate (Registrar path) ============ */

    function test_migrate_registrarPathDisabled() external {
        vm.expectRevert(IMigratable.ZeroMigrator.selector);
        _vault.migrate();
    }
}
