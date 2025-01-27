// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { MockSpokeMToken } from "../mocks/MockSpokeMToken.sol";
import { MockSpokePortal } from "../mocks/MockSpokePortal.sol";
import { MockSpokeRegistrar } from "../mocks/MockSpokeRegistrar.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";

contract MockNoFallbackContract {}

contract SpokeVaultV2 {
    function foo() external pure returns (uint256) {
        return 1;
    }
}

contract SpokeVaultMigratorV1 {
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public immutable implementationV2;

    constructor(address implementationV2_) {
        implementationV2 = implementationV2_;
    }

    fallback() external virtual {
        address implementationV2_ = implementationV2;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementationV2_)
        }
    }
}

contract SpokeVaultTests is UnitTestBase {
    using TypeConverter for *;

    address internal _hubVault = makeAddr("hubVault");
    address internal _migrationAdmin = makeAddr("migrationAdmin");

    bytes32 internal constant _MIGRATOR_KEY_PREFIX = "spoke_vault_migrator_v1";

    MockNoFallbackContract internal _noFallbackContract;
    MockSpokeMToken internal _mToken;
    MockSpokePortal internal _portal;
    MockSpokeRegistrar internal _registrar;

    SpokeVault internal _vault;

    function setUp() external {
        _noFallbackContract = new MockNoFallbackContract();
        _mToken = new MockSpokeMToken();
        _registrar = new MockSpokeRegistrar();
        _portal = new MockSpokePortal(address(_mToken), address(_registrar));

        _vault = SpokeVault(
            payable(
                _createProxy(address(new SpokeVault(address(_portal), _hubVault, _REMOTE_CHAIN_ID, _migrationAdmin)))
            )
        );
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_vault.MIGRATOR_KEY_PREFIX(), _MIGRATOR_KEY_PREFIX);

        assertEq(_vault.destinationChainId(), _REMOTE_CHAIN_ID);
        assertEq(_vault.migrationAdmin(), _migrationAdmin);
        assertEq(_vault.mToken(), address(_mToken));
        assertEq(_vault.hubVault(), _hubVault);
        assertEq(_vault.registrar(), address(_registrar));
        assertEq(_vault.spokePortal(), address(_portal));
    }

    /* ============ constructor ============ */

    function test_constructor_zeroSpokePortal() external {
        vm.expectRevert(ISpokeVault.ZeroSpokePortal.selector);
        new SpokeVault(address(0), _hubVault, _REMOTE_CHAIN_ID, _migrationAdmin);
    }

    function test_constructor_zeroHubVault() external {
        vm.expectRevert(ISpokeVault.ZeroHubVault.selector);
        new SpokeVault(address(_portal), address(0), _REMOTE_CHAIN_ID, _migrationAdmin);
    }

    function test_constructor_zeroDestinationChainId() external {
        vm.expectRevert(ISpokeVault.ZeroDestinationChainId.selector);
        new SpokeVault(address(_portal), _hubVault, 0, _migrationAdmin);
    }

    function test_constructor_zeroMigrationAdmin() external {
        vm.expectRevert(ISpokeVault.ZeroMigrationAdmin.selector);
        new SpokeVault(address(_portal), _hubVault, _REMOTE_CHAIN_ID, address(0));
    }

    /* ============ transferExcessM ============ */

    function test_transferExcessM_earlyReturn() external {
        assertEq(_vault.transferExcessM(_alice.toBytes32()), 0);
    }

    function test_transferExcessM_failedEthRefund() external {
        uint256 amount_ = 1_000e6;
        uint256 fee_ = 2;

        vm.deal(address(_noFallbackContract), fee_);
        _mToken.mint(address(_vault), amount_, _EXP_SCALED_ONE);

        vm.expectRevert(abi.encodeWithSelector(ISpokeVault.FailedEthRefund.selector, 1));

        vm.prank(address(_noFallbackContract));
        _vault.transferExcessM{ value: fee_ }(address(_noFallbackContract).toBytes32());
    }

    function test_transferExcessM() external {
        uint256 amount_ = 10_000e6;
        uint256 fee_ = 2;

        vm.deal(_alice, fee_);
        _mToken.mint(address(_vault), amount_, _EXP_SCALED_ONE);

        vm.expectCall(
            address(_portal),
            fee_,
            abi.encodeCall(
                _portal.transfer,
                (amount_, _REMOTE_CHAIN_ID, _hubVault.toBytes32(), _alice.toBytes32(), false, new bytes(1))
            )
        );

        vm.expectEmit();
        emit ISpokeVault.ExcessMTokenSent(_REMOTE_CHAIN_ID, 1, _alice.toBytes32(), _hubVault.toBytes32(), amount_);

        vm.prank(_alice);
        _vault.transferExcessM{ value: fee_ }(_alice.toBytes32());

        assertEq(_alice.balance, fee_ - 1);
    }

    /* ============ migrate ============ */
    function test_migrate_unauthorizedMigration() external {
        vm.expectRevert(ISpokeVault.UnauthorizedMigration.selector);

        vm.prank(_alice);
        _vault.migrate(address(0));
    }

    function test_migrate() external {
        SpokeVaultV2 implementationV2_ = new SpokeVaultV2();
        address migrator_ = address(new SpokeVaultMigratorV1(address(implementationV2_)));

        _registrar.setKey(
            keccak256(abi.encode(_MIGRATOR_KEY_PREFIX, address(_vault))),
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectRevert();
        SpokeVaultV2(address(_vault)).foo();

        _vault.migrate();

        assertEq(SpokeVaultV2(address(_vault)).foo(), 1);
    }

    function test_migrate_byAdmin() external {
        SpokeVaultV2 implementationV2_ = new SpokeVaultV2();
        address migrator_ = address(new SpokeVaultMigratorV1(address(implementationV2_)));

        vm.expectRevert();
        SpokeVaultV2(address(_vault)).foo();

        vm.prank(_migrationAdmin);
        _vault.migrate(migrator_);

        assertEq(SpokeVaultV2(address(_vault)).foo(), 1);
    }
}
