// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

/// @notice Optimism CrossDomainMessenger
/// @dev    https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/src/universal/CrossDomainMessenger.sol
interface ICrossDomainMessenger {
    /// @notice Retrieves the address of the contract or wallet that initiated the currently
    ///         executing message on the other chain. Will throw an error if there is no message
    ///         currently being executed. Allows the recipient of a call to see who triggered it.
    /// @return address of the sender of the currently executing message on the other chain.
    function xDomainMessageSender() external view returns (address);

    /// @notice Sends a message to some target address on the other chain. Note that if the call
    ///         always reverts, then the message will be unrelayable, and any ETH sent will be
    ///         permanently locked. The same will occur if the target on the other chain is
    ///         considered unsafe (see the _isUnsafeTarget() function).
    /// @param target Target contract or wallet address.
    /// @param message Message to trigger the target address with.
    /// @param minGasLimit Minimum gas limit that the message can be executed with.
    function sendMessage(address target, bytes calldata message, uint32 minGasLimit) external;
}
