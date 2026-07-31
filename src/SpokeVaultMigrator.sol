// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Migrator setting the SpokeVault implementation.
 * @author M0 Labs
 * @dev    Delegatecalled by `SpokeVault.migrate(address)`, hence running in the context of the SpokeVault proxy.
 */
contract SpokeVaultMigrator {
    /* ============ Variables ============ */

    /// @dev Storage slot with the implementation address. `keccak256('eip1967.proxy.implementation') - 1`.
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice The address of the implementation to migrate the SpokeVault to.
    address public immutable implementation;

    /* ============ Custom Errors ============ */

    /// @notice Emitted in constructor if the implementation address is 0x0.
    error ZeroImplementation();

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the SpokeVaultMigrator contract.
     * @param  implementation_ The address of the implementation to migrate the SpokeVault to.
     */
    constructor(address implementation_) {
        if ((implementation = implementation_) == address(0)) revert ZeroImplementation();
    }

    /* ============ Fallback Function ============ */

    fallback() external {
        address implementation_ = implementation;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }
}
