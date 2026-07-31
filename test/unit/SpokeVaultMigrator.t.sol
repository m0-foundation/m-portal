// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IMigratable } from "../../lib/common/src/interfaces/IMigratable.sol";

import { SpokeVault } from "../../src/SpokeVault.sol";
import { SpokeVaultMigrator } from "../../src/SpokeVaultMigrator.sol";

import { MockSpokeMToken } from "../mocks/MockSpokeMToken.sol";
import { MockSpokeVaultV2 } from "../mocks/MockSpokeVaultV2.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";

contract SpokeVaultMigratorTests is UnitTestBase {
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address internal _excessDestination = makeAddr("excessDestination");
    address internal _migrationAdmin = makeAddr("migrationAdmin");

    MockSpokeMToken internal _mToken;

    address internal _implementationV1;
    SpokeVault internal _vault;

    function setUp() external {
        _mToken = new MockSpokeMToken();
        _implementationV1 = address(new SpokeVault(address(_mToken), _excessDestination, _migrationAdmin));

        _vault = SpokeVault(_createProxy(_implementationV1));
    }

    function _readImplementationSlot(address proxy_) internal view returns (address implementation_) {
        return address(uint160(uint256(vm.load(proxy_, _IMPLEMENTATION_SLOT))));
    }

    /* ============ constructor ============ */

    function test_constructor_zeroImplementation() external {
        vm.expectRevert(SpokeVaultMigrator.ZeroImplementation.selector);
        new SpokeVaultMigrator(address(0));
    }

    /* ============ initialState ============ */

    function test_initialState() external {
        address implementationV2_ = address(new MockSpokeVaultV2());

        assertEq(new SpokeVaultMigrator(implementationV2_).implementation(), implementationV2_);
    }

    /* ============ fallback ============ */

    function test_fallback_setsImplementationSlot() external {
        address implementationV2_ = address(new MockSpokeVaultV2());
        address migrator_ = address(new SpokeVaultMigrator(implementationV2_));

        assertEq(_readImplementationSlot(address(_vault)), _implementationV1);

        vm.prank(_migrationAdmin);
        _vault.migrate(migrator_);

        assertEq(_readImplementationSlot(address(_vault)), implementationV2_);
    }

    function test_fallback_leavesRemainingStorageUntouched() external {
        address migrator_ = address(new SpokeVaultMigrator(address(new MockSpokeVaultV2())));

        vm.prank(_migrationAdmin);
        _vault.migrate(migrator_);

        assertEq(vm.load(address(_vault), bytes32(0)), bytes32(0));
        assertEq(vm.load(address(_vault), bytes32(uint256(1))), bytes32(0));
    }

    function test_fallback_emitsMigrationEvents() external {
        address implementationV2_ = address(new MockSpokeVaultV2());
        address migrator_ = address(new SpokeVaultMigrator(implementationV2_));

        vm.expectEmit();
        emit IMigratable.Migrated(migrator_, _implementationV1, implementationV2_);

        vm.expectEmit();
        emit IMigratable.Upgraded(implementationV2_);

        vm.prank(_migrationAdmin);
        _vault.migrate(migrator_);
    }
}
