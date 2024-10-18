// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IRegistrarLike } from "../interfaces/IRegistrarLike.sol";

/**
 * @title  Library to read Registrar contract parameters.
 * @author M^0 Labs
 */
library RegistrarReader {
    /* ============ Variables ============ */

    /// @notice The name of parameter that defines the Portal configurator address.
    bytes32 internal constant PORTAL_CONFIGURATOR = "portal_configurator";

    /// @notice The name of parameter that defines the Portal upgrader address.
    bytes32 internal constant PORTAL_UPGRADER = "portal_upgrader";

    /* ============ Internal View/Pure Functions ============ */

    /// @notice Gets the Portal configurator address.
    function getPortalConfigurator(address registrar_) internal view returns (address) {
        return toAddress(_get(registrar_, PORTAL_CONFIGURATOR));
    }

    /// @notice Gets the Portal upgrader address.
    function getPortalUpgrader(address registrar_) internal view returns (address) {
        return toAddress(_get(registrar_, PORTAL_UPGRADER));
    }

    /// @notice Converts given bytes32 to address.
    function toAddress(bytes32 input_) internal pure returns (address) {
        return address(uint160(uint256(input_)));
    }

    /// @notice Gets the value of the given key.
    function _get(address registrar_, bytes32 key_) private view returns (bytes32) {
        return IRegistrarLike(registrar_).get(key_);
    }
}
