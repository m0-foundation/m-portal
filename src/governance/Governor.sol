// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { RegistrarReader } from "../libs/RegistrarReader.sol";

import { IPortal } from "../interfaces/IPortal.sol";

import { IGovernor } from "./interfaces/IGovernor.sol";

/**
 * @title  Base governor contract.
 * @author M^0 Labs
 */
contract Governor is IGovernor {
    /// @inheritdoc IGovernor
    address public immutable portal;

    /// @inheritdoc IGovernor
    address public immutable registrar;

    constructor(address portal_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();

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
}
