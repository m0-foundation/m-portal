// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

interface ITransceiverRegistry {
    /// @notice Returns the Transceiver contracts that have been enabled via governance.
    function getTransceivers() external returns (address[] memory result);
}
