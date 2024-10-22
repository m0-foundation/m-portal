// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  SpokeVault interface.
 * @author M^0 Labs
 */
interface ISpokeVault {
    /* ============ Events ============ */

    /**
     * @notice Emitted when excess M token are sent to the Vault on Ethereum Mainnet.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  messageSequence The message sequence ID of the transfer.
     * @param  sender          The address that bridged the M tokens via the Portal.
     * @param  vault           The address of the Vault receiving the M tokens on the destination chain.
     * @param  amount          The amount of tokens.
     */
    event ExcessMTokenSent(
        uint16 indexed destinationChainId,
        uint64 messageSequence,
        bytes32 indexed sender,
        bytes32 vault,
        uint256 amount
    );

    /* ============ Custom Errors ============ */

    /**
     * @notice Emitted when the amount of M token being sent is greater than the balance of the Vault.
     * @param balance The M token balance of the Vault.
     * @param amount  The amount of M token being sent.
     */
    error InsufficientMTokenBalance(uint256 balance, uint256 amount);

    /// @notice Emitted when the HubVault address is 0x0.
    error ZeroHubVault();

    /// @notice Emitted when the SpokePortal address is 0x0.
    error ZeroSpokePortal();

    /// @notice Emitted when the destination chain id is 0.
    error ZeroDestinationChainId();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Transfers excess `amount` of M to the HubVault on Ethereum Mainnet.
     * @param  amount          The excess amount of M to transfer.
     * @param  refundAddress   The address to which a refund for unussed gas is issued on the destination chain.
     * @return messageSequence The message sequence ID of the transfer.
     */
    function transferExcessM(uint256 amount, bytes32 refundAddress) external payable returns (uint64 messageSequence);

    /* ============ View/Pure Functions ============ */

    /// @notice The Wormhole destination chain ID.
    function destinationChainId() external view returns (uint16);

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice Address of the Vault on Ethereum Mainnet that will receive the excess M.
    function hubVault() external view returns (address);

    /// @notice Address of the SpokePortal being used to bridge M back to Ethereum Mainnet.
    function spokePortal() external view returns (address);
}
