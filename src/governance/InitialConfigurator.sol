// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IConfigurator } from "./interfaces/IConfigurator.sol";

import { Configurator } from "./Configurator.sol";

/**
 * @title  Initial configurator contract.
 * @author M^0 Labs
 */
contract InitialConfigurator is Configurator {
    constructor(address portal_) Configurator(portal_) {}

    /// @inheritdoc IConfigurator
    function execute() external override {}
}
