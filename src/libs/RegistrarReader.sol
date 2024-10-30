// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IRegistrarLike } from "../interfaces/IRegistrarLike.sol";

import { TypeConverter } from "./TypeConverter.sol";

/**
 * @title  Library to read Registrar contract parameters.
 * @author M^0 Labs
 */
library RegistrarReader {
    using TypeConverter for bytes32;

    /* ============ Variables ============ */

    /// @notice The name of parameter that defines the Portal configurator address.
    bytes32 internal constant PORTAL_CONFIGURATOR = "portal_configurator";

    /// @notice The name of parameter that defines the Portal migrator address.
    bytes32 internal constant PORTAL_MIGRATOR = "portal_migrator";

    /* ============ Internal View/Pure Functions ============ */

    /// @notice Gets the Portal configurator address.
    function getPortalConfigurator(address registrar_) internal view returns (address) {
        return _get(registrar_, PORTAL_CONFIGURATOR).toAddress();
    }

    /// @notice Gets the Portal migrator address.
    function getPortalMigrator(address registrar_) internal view returns (address) {
        return _get(registrar_, PORTAL_MIGRATOR).toAddress();
    }

    /// @notice Gets the value of the given key.
    function _get(address registrar_, bytes32 key_) private view returns (bytes32) {
        return IRegistrarLike(registrar_).get(key_);
    }
}
