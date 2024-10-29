// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IConfigurator } from "../../src/governance/interfaces/IConfigurator.sol";
import { IGovernor } from "../../src/governance/interfaces/IGovernor.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { IMigrator } from "../../src/governance/interfaces/IMigrator.sol";

import { Governor } from "../../src/governance/Governor.sol";

import { MockSpokeRegistrar } from "../mocks/MockSpokeRegistrar.sol";
import { MockSpokePortal } from "../mocks/MockSpokePortal.sol";

import { UnitTestBase } from "./UnitTestBase.t.sol";

contract GovernorTests is UnitTestBase {
    address internal _governorAdmin = makeAddr("governor-admin");

    Governor internal _governor;
    MockSpokeRegistrar internal _registrar;
    MockSpokePortal internal _portal;

    address internal _configurator = makeAddr("configurator");
    address internal _mToken = makeAddr("m-token");
    address internal _migrator = makeAddr("migrator");

    function setUp() external {
        _registrar = new MockSpokeRegistrar();
        _portal = new MockSpokePortal(_mToken, address(_registrar));
        _governor = new Governor(address(_portal), _governorAdmin);
    }

    /* ============ initialState ============ */

    function test_initialState() external view {
        assertEq(_governor.governorAdmin(), _governorAdmin);
        assertEq(_governor.portal(), address(_portal));
        assertEq(_governor.registrar(), address(_registrar));
    }

    /* ============ constructor ============ */

    function test_constructor_zeroPortal() external {
        vm.expectRevert(IGovernor.ZeroPortal.selector);
        new Governor(address(0), _governorAdmin);
    }

    function test_constructor_zeroGovernorAdmin() external {
        vm.expectRevert(IGovernor.ZeroGovernorAdmin.selector);
        new Governor(address(_portal), address(0));
    }

    /* ============ configure ============ */

    function test_configure_zeroConfigurator() external {
        vm.expectRevert(IGovernor.ZeroConfigurator.selector);
        _governor.configure();
    }

    function test_configure_delegatecallFailed() external {
        bytes memory delegatecallData_ = "Call failed.";

        vm.mockCall(
            address(_registrar),
            abi.encodeWithSelector(IRegistrarLike.get.selector, bytes32("portal_configurator")),
            abi.encode(_configurator)
        );

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.get, (bytes32("portal_configurator"))));

        vm.mockCallRevert(_configurator, abi.encodeWithSelector(IConfigurator.configure.selector), delegatecallData_);
        vm.expectCall(_configurator, abi.encodeWithSelector(IConfigurator.configure.selector));

        vm.expectRevert(abi.encodeWithSelector(IGovernor.DelegatecallFailed.selector, delegatecallData_));
        _governor.configure();
    }

    function test_configure() external {
        vm.mockCall(
            address(_registrar),
            abi.encodeWithSelector(IRegistrarLike.get.selector, bytes32("portal_configurator")),
            abi.encode(_configurator)
        );

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.get, (bytes32("portal_configurator"))));
        vm.expectCall(_configurator, abi.encodeWithSelector(IConfigurator.configure.selector));

        _governor.configure();
    }

    function test_configure_unauthorizedGovernorAdmin() external {
        vm.expectRevert(IGovernor.UnauthorizedGovernorAdmin.selector);
        _governor.configure(_configurator);
    }

    function test_configure_byGovernorAdmin() external {
        vm.expectCall(_configurator, abi.encodeWithSelector(IConfigurator.configure.selector));

        vm.prank(_governorAdmin);
        _governor.configure(_configurator);
    }

    /* ============ upgrade ============ */

    function test_upgrade_zeroMigrator() external {
        vm.expectRevert(IGovernor.ZeroMigrator.selector);
        _governor.upgrade();
    }

    function test_upgrade_delegatecallFailed() external {
        bytes memory delegatecallData_ = "Call failed.";

        vm.mockCall(
            address(_registrar),
            abi.encodeWithSelector(IRegistrarLike.get.selector, bytes32("portal_migrator")),
            abi.encode(_migrator)
        );

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.get, (bytes32("portal_migrator"))));

        vm.mockCallRevert(_migrator, abi.encodeWithSelector(IMigrator.migrate.selector), delegatecallData_);
        vm.expectCall(_migrator, abi.encodeWithSelector(IMigrator.migrate.selector));

        vm.expectRevert(abi.encodeWithSelector(IGovernor.DelegatecallFailed.selector, delegatecallData_));
        _governor.upgrade();
    }

    function test_upgrade() external {
        vm.mockCall(
            address(_registrar),
            abi.encodeWithSelector(IRegistrarLike.get.selector, bytes32("portal_migrator")),
            abi.encode(_migrator)
        );

        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.get, (bytes32("portal_migrator"))));
        vm.expectCall(_migrator, abi.encodeWithSelector(IMigrator.migrate.selector));

        _governor.upgrade();
    }

    function test_upgrade_unauthorizedGovernorAdmin() external {
        vm.expectRevert(IGovernor.UnauthorizedGovernorAdmin.selector);
        _governor.upgrade(_migrator);
    }

    function test_upgrade_byGovernorAdmin() external {
        vm.expectCall(_migrator, abi.encodeWithSelector(IMigrator.migrate.selector));

        vm.prank(_governorAdmin);
        _governor.upgrade(_migrator);
    }

    /* ============ ownership ============ */

    function test_transferOwnership_unauthorizedGovernorAdmin() external {
        vm.expectRevert(IGovernor.UnauthorizedGovernorAdmin.selector);
        _governor.transferOwnership(makeAddr("new-governor-admin"));
    }

    function test_transferOwnership_zeroGovernorAdmin() external {
        vm.expectRevert(IGovernor.ZeroGovernorAdmin.selector);

        vm.prank(_governorAdmin);
        _governor.transferOwnership(address(0));
    }

    function test_transferOwnership() external {
        address newGovernorAdmin_ = makeAddr("new-governor-admin");

        vm.expectEmit();
        emit IGovernor.GovernorAdminTransferred(_governorAdmin, newGovernorAdmin_);

        vm.prank(_governorAdmin);
        _governor.transferOwnership(newGovernorAdmin_);

        assertEq(_governor.governorAdmin(), newGovernorAdmin_);
    }

    function test_disableGovernorAdmin_unauthorizedGovernorAdmin() external {
        vm.expectRevert(IGovernor.UnauthorizedGovernorAdmin.selector);
        _governor.disableGovernorAdmin();
    }

    function test_disableGovernorAdmin() external {
        vm.expectEmit();
        emit IGovernor.GovernorAdminTransferred(_governorAdmin, address(0));

        vm.prank(_governorAdmin);
        _governor.disableGovernorAdmin();

        assertEq(_governor.governorAdmin(), address(0));

        vm.expectRevert(IGovernor.UnauthorizedGovernorAdmin.selector);
        _governor.transferOwnership(makeAddr("new-governor-admin"));
    }
}
