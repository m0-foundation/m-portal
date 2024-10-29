// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { RegistrarReader } from "../libs/RegistrarReader.sol";

import { IPortal } from "../interfaces/IPortal.sol";
import { IGovernor } from "./interfaces/IGovernor.sol";

/**
 * @title  Governor contract used to perform governance operations on the Portal.
 * @author M^0 Labs
 */
contract Governor is IGovernor {
    /* ============ Variables ============ */

    /// @inheritdoc IGovernor
    address public governorAdmin;

    /// @inheritdoc IGovernor
    address public immutable portal;

    /// @inheritdoc IGovernor
    address public immutable registrar;

    /* ============ Modifiers ============ */

    /// @notice Reverts if the caller is not the Governor admin.
    modifier onlyGovernorAdmin() {
        if (msg.sender != governorAdmin) revert UnauthorizedGovernorAdmin();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @dev   Constructs the Governor contract.
     * @param portal_ Address of the Portal being governed.
     * @param governorAdmin_ Address of the Governor admin.
     */
    constructor(address portal_, address governorAdmin_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        registrar = IPortal(portal_).registrar();

        _setGovernorAdmin(governorAdmin_);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IGovernor
    function configure() external {
        _configure(RegistrarReader.getPortalConfigurator(registrar));
    }

    /// @inheritdoc IGovernor
    function configure(address configurator_) external onlyGovernorAdmin {
        _configure(configurator_);
    }

    /// @inheritdoc IGovernor
    function upgrade() external {
        _upgrade(RegistrarReader.getPortalUpgrader(registrar));
    }

    /// @inheritdoc IGovernor
    function upgrade(address upgrader_) external onlyGovernorAdmin {
        _upgrade(upgrader_);
    }

    /// @inheritdoc IGovernor
    function transferOwnership(address newGovernorAdmin_) external onlyGovernorAdmin {
        _setGovernorAdmin(newGovernorAdmin_);
    }

    /// @inheritdoc IGovernor
    function disableGovernorAdmin() external onlyGovernorAdmin {
        emit GovernorAdminTransferred(governorAdmin, address(0));
        delete governorAdmin;
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev Executes the configuration in `configurator_`.
     * @param configurator_ The address of the Configurator contract.
     */
    function _configure(address configurator_) internal {
        if (configurator_ == address(0)) revert ZeroConfigurator();

        (bool success_, bytes memory data_) = configurator_.delegatecall(abi.encodeWithSignature("configure()"));

        if (!success_) {
            revert DelegatecallFailed(data_);
        }
    }

    /**
     * @dev Executes the upgrade in `upgrader_`.
     * @param  upgrader_ The address of the Upgrader contract.
     */
    function _upgrade(address upgrader_) internal {
        if (upgrader_ == address(0)) revert ZeroUpgrader();

        (bool success_, bytes memory data_) = upgrader_.delegatecall(abi.encodeWithSignature("execute()"));

        if (!success_) {
            revert DelegatecallFailed(data_);
        }
    }

    /**
     * @dev   Sets the address of the Governor Admin.
     * @param newGovernorAdmin_ The address of the new Governor Admin.
     */
    function _setGovernorAdmin(address newGovernorAdmin_) internal {
        if (newGovernorAdmin_ == address(0)) revert ZeroGovernorAdmin();

        emit GovernorAdminTransferred(governorAdmin, newGovernorAdmin_);

        governorAdmin = newGovernorAdmin_;
    }
}
