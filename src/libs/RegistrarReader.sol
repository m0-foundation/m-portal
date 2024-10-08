// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IRegistrarLike } from "../interfaces/Dependencies.sol";

/**
 * @title  Library to read Registrar contract parameters.
 * @author M^0 Labs
 */
library RegistrarReader {
    /* ============ Variables ============ */

    /// @notice The name of parameter that defines the Portal configurator address.
    bytes32 internal constant CONFIGURATOR_PREFIX = "configurator";

    /* ============ Internal View/Pure Functions ============ */

    /// @notice Gets the configurator address.
    function getConfigurator(address registrar_) internal view returns (address) {
        return toAddress(_get(registrar_, keccak256(abi.encode(CONFIGURATOR_PREFIX, block.chainid))));
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
