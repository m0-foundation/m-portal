// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { RegistrarReader } from "../libs/RegistrarReader.sol";

import { IPortal } from "../interfaces/IPortal.sol";

import { IGovernor } from "./interfaces/IGovernor.sol";

// TODO: add events

/**
 * @title  Governor contract used to perform governance operations on the Portal.
 * @author M^0 Labs
 */
contract Governor is IGovernor {
    /// @inheritdoc IGovernor
    address public immutable portal;

    /// @inheritdoc IGovernor
    address public immutable registrar;

    /// @inheritdoc IGovernor
    address public governorAdmin;

    modifier onlyGovernorAdmin() {
        if (msg.sender != governorAdmin) revert UnauthorizedGovernorAdmin();
        _;
    }

    /**
     * @dev   Constructs the Governor contract.
     * @param portal_        Address of the Portal being governed.
     * @param governorAdmin_ Address of the Governor Admin.
     */
    constructor(address portal_, address governorAdmin_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        if ((governorAdmin = governorAdmin_) == address(0)) revert ZeroGovernorAdmin();

        registrar = IPortal(portal_).registrar();
    }

    /// @inheritdoc IGovernor
    function configure() external {
        address configurator_ = RegistrarReader.getPortalConfigurator(registrar);
        if (configurator_ == address(0)) revert ZeroConfigurator();

        configurator_.delegatecall(abi.encodeWithSignature("execute()"));
    }

    /// @inheritdoc IGovernor
    function upgrade() external {
        address upgrader_ = RegistrarReader.getPortalUpgrader(registrar);
        if (upgrader_ == address(0)) revert ZeroUpgrader();

        upgrader_.delegatecall(abi.encodeWithSignature("execute()"));
    }

    /// @inheritdoc IGovernor
    function configure(address configurator_) external onlyGovernorAdmin {
        if (configurator_ == address(0)) revert ZeroConfigurator();

        configurator_.delegatecall(abi.encodeWithSignature("execute()"));
    }

    /// @inheritdoc IGovernor
    function upgrade(address upgrader_) external onlyGovernorAdmin {
        if (upgrader_ == address(0)) revert ZeroUpgrader();

        upgrader_.delegatecall(abi.encodeWithSignature("execute()"));
    }

    /// @inheritdoc IGovernor
    function transferOwnership(address newGovernorAdmin_) external onlyGovernorAdmin {
        if (newGovernorAdmin_ == address(0)) revert ZeroGovernorAdmin();

        _transferOwnership(newGovernorAdmin_);
    }

    /// @inheritdoc IGovernor
    function disableGovernorAdmin() external onlyGovernorAdmin {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newGovernorAdmin_) internal {
        governorAdmin = newGovernorAdmin_;
    }
}

