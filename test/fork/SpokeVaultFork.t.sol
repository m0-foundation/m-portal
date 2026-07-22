// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";
import { SpokeVaultMigrator } from "../../src/SpokeVaultMigrator.sol";

contract SpokeVaultForkTests is Test {
    uint256 internal constant _ARBITRUM_FORK_BLOCK = 486_540_000;
    uint256 internal constant _BASE_FORK_BLOCK = 48_950_000;

    address internal constant _VAULT = 0x3349e443068F76666789C4f76F00D9c4F38A4DdE;
    address internal constant _M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _MIGRATION_ADMIN = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    address internal immutable _alice = makeAddr("alice");
    address internal immutable _excessDestination = makeAddr("excessDestination");

    /* ============ deprecate ============ */

    function testFork_deprecate_arbitrum() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: _ARBITRUM_FORK_BLOCK });
        _testDeprecate();
    }

    function testFork_deprecate_base() external {
        vm.createSelectFork({ urlOrAlias: "base", blockNumber: _BASE_FORK_BLOCK });
        _testDeprecate();
    }

    function _testDeprecate() internal {
        assertEq(ISpokeVault(_VAULT).migrationAdmin(), _MIGRATION_ADMIN);

        uint256 rescuedAmount_ = IERC20(_M_TOKEN).balanceOf(_VAULT);
        assertGt(rescuedAmount_, 0);

        address migrator_ = _migrate();

        assertEq(ISpokeVault(_VAULT).implementation(), SpokeVaultMigrator(migrator_).implementation());
        assertEq(ISpokeVault(_VAULT).mToken(), _M_TOKEN);
        assertEq(ISpokeVault(_VAULT).excessDestination(), _excessDestination);

        vm.expectEmit();
        emit ISpokeVault.ExcessMTokenSent(_excessDestination, rescuedAmount_);

        vm.prank(_alice);
        ISpokeVault(_VAULT).transferExcessM();

        assertEq(IERC20(_M_TOKEN).balanceOf(_VAULT), 0);
        assertEq(IERC20(_M_TOKEN).balanceOf(_excessDestination), rescuedAmount_);
    }

    /* ============ transferExcessM ============ */

    function testFork_transferExcessM_accruedAfterDeprecation_arbitrum() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: _ARBITRUM_FORK_BLOCK });
        _testTransferExcessMAccruedAfterDeprecation();
    }

    function testFork_transferExcessM_accruedAfterDeprecation_base() external {
        vm.createSelectFork({ urlOrAlias: "base", blockNumber: _BASE_FORK_BLOCK });
        _testTransferExcessMAccruedAfterDeprecation();
    }

    /// @dev The excess destination of Wrapped M is immutable and set to the Vault, so M keeps accruing after the
    ///      deprecation and must remain sweepable.
    function _testTransferExcessMAccruedAfterDeprecation() internal {
        uint256 rescuedAmount_ = IERC20(_M_TOKEN).balanceOf(_VAULT);

        _migrate();

        vm.prank(_alice);
        ISpokeVault(_VAULT).transferExcessM();

        uint256 accruedAmount_ = rescuedAmount_ / 2;

        vm.prank(_excessDestination);
        IERC20(_M_TOKEN).transfer(_VAULT, accruedAmount_);

        vm.prank(_alice);
        ISpokeVault(_VAULT).transferExcessM();

        assertEq(IERC20(_M_TOKEN).balanceOf(_VAULT), 0);
        assertEq(IERC20(_M_TOKEN).balanceOf(_excessDestination), rescuedAmount_);
    }

    function testFork_transferExcessM_bridgingDisabled_arbitrum() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: _ARBITRUM_FORK_BLOCK });
        _testTransferExcessMBridgingDisabled();
    }

    function testFork_transferExcessM_bridgingDisabled_base() external {
        vm.createSelectFork({ urlOrAlias: "base", blockNumber: _BASE_FORK_BLOCK });
        _testTransferExcessMBridgingDisabled();
    }

    function _testTransferExcessMBridgingDisabled() internal {
        _migrate();

        (bool success_, ) = _VAULT.call(
            abi.encodeWithSignature("transferExcessM(bytes32)", bytes32(uint256(uint160(_alice))))
        );

        assertFalse(success_);
    }

    /* ============ migrate ============ */

    function testFork_migrate_unauthorizedMigration_arbitrum() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: _ARBITRUM_FORK_BLOCK });

        address implementation_ = address(new SpokeVault(_M_TOKEN, _excessDestination, _MIGRATION_ADMIN));
        address migrator_ = address(new SpokeVaultMigrator(implementation_));

        vm.expectRevert(ISpokeVault.UnauthorizedMigration.selector);

        vm.prank(_alice);
        ISpokeVault(_VAULT).migrate(migrator_);
    }

    function _migrate() internal returns (address migrator_) {
        address implementation_ = address(new SpokeVault(_M_TOKEN, _excessDestination, _MIGRATION_ADMIN));
        migrator_ = address(new SpokeVaultMigrator(implementation_));

        vm.prank(_MIGRATION_ADMIN);
        ISpokeVault(_VAULT).migrate(migrator_);
    }
}
