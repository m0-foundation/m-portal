// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";

import { TypeConverter } from "./libs/TypeConverter.sol";

import { Migratable } from "./proxy/Migratable.sol";

import { IPortal } from "./interfaces/IPortal.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { ISpokeVault } from "./interfaces/ISpokeVault.sol";

/**
 * @title  Vault residing on L2s and receiving excess M from Smart M.
 * @author M^0 Labs
 */
contract SpokeVault is ISpokeVault, Migratable {
    using TypeConverter for address;

    /* ============ Variables ============ */

    /// @inheritdoc ISpokeVault
    bytes32 public constant MIGRATOR_KEY_PREFIX = "spoke_vault_migrator_v1";

    /// @inheritdoc ISpokeVault
    address public immutable migrationAdmin;

    /// @inheritdoc ISpokeVault
    uint16 public immutable destinationChainId;

    /// @inheritdoc ISpokeVault
    address public immutable mToken;

    /// @inheritdoc ISpokeVault
    address public immutable hubVault;

    /// @inheritdoc ISpokeVault
    address public immutable registrar;

    /// @inheritdoc ISpokeVault
    address public immutable spokePortal;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the SpokeVault contract.
     * @param  spokePortal_        The address of the SpokePortal contract.
     * @param  hubVault_           The address of the Vault contract on the destination chain.
     * @param  destinationChainId_ The Wormhole chain id of the destination chain.
     * @param  migrationAdmin_     The address of a migration admin.
     */
    constructor(address spokePortal_, address hubVault_, uint16 destinationChainId_, address migrationAdmin_) {
        if ((spokePortal = spokePortal_) == address(0)) revert ZeroSpokePortal();
        if ((hubVault = hubVault_) == address(0)) revert ZeroHubVault();
        if ((destinationChainId = destinationChainId_) == 0) revert ZeroDestinationChainId();
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();

        mToken = IPortal(spokePortal).mToken();
        registrar = IPortal(spokePortal).registrar();

        // Approve the SpokePortal to transfer M tokens.
        IERC20(mToken).approve(spokePortal_, type(uint256).max);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISpokeVault
    function transferExcessM(
        uint256 amount_,
        bytes32 refundAddress_
    ) external payable returns (uint64 messageSequence_) {
        uint256 mTokenBalance_ = IERC20(mToken).balanceOf(address(this));
        if (mTokenBalance_ < amount_) revert InsufficientMTokenBalance(mTokenBalance_, amount_);

        bytes32 hubVault_ = hubVault.toBytes32();

        messageSequence_ = INttManager(spokePortal).transfer{ value: msg.value }(
            amount_,
            destinationChainId,
            hubVault_,
            refundAddress_,
            false,
            new bytes(1)
        );

        emit ExcessMTokenSent(destinationChainId, messageSequence_, msg.sender.toBytes32(), hubVault_, amount_);
    }

    /* ============ Temporary Admin Migration ============ */

    /// @inheritdoc ISpokeVault
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the address of the contract to use as a migrator, if any.
    function _getMigrator() internal view override returns (address migrator_) {
        return
            address(
                uint160(
                    // NOTE: A subsequent implementation should use a unique migrator prefix.
                    uint256(IRegistrarLike(registrar).get(keccak256(abi.encode(MIGRATOR_KEY_PREFIX, address(this)))))
                )
            );
    }
}