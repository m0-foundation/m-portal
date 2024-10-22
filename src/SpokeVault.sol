// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";

import { TypeConverter } from "./libs/TypeConverter.sol";

import { IPortal } from "./interfaces/IPortal.sol";
import { ISpokeVault } from "./interfaces/ISpokeVault.sol";

/**
 * @title  Vault residing on L2s and receiving excess M from Smart M.
 * @author M^0 Labs
 */
contract SpokeVault is ISpokeVault {
    using TypeConverter for address;

    /* ============ Variables ============ */

    /// @inheritdoc ISpokeVault
    uint16 public immutable destinationChainId;

    /// @inheritdoc ISpokeVault
    address public immutable mToken;

    /// @inheritdoc ISpokeVault
    address public immutable hubVault;

    /// @inheritdoc ISpokeVault
    address public immutable spokePortal;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the SpokeVault contract.
     * @param  spokePortal_      The address of the SpokePortal contract.
     * @param  hubVault_         The address of the HubVault contract.
     * @param  destinationChainId_ The Wormhole chain id of the destination chain.
     */
    constructor(address spokePortal_, address hubVault_, uint16 destinationChainId_) {
        if ((spokePortal = spokePortal_) == address(0)) revert ZeroSpokePortal();
        if ((hubVault = hubVault_) == address(0)) revert ZeroHubVault();
        if ((destinationChainId = destinationChainId_) == 0) revert ZeroDestinationChainId();

        mToken = IPortal(spokePortal).mToken();

        // Approve the SpokePortal to transfer M tokens.
        IERC20(mToken).approve(spokePortal_, type(uint256).max);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISpokeVault
    function transferExcessM(
        uint256 amount_,
        bytes32 refundAddress_
    ) external payable returns (uint64 messageSequence_) {
        if (IERC20(mToken).balanceOf(address(this)) < amount_)
            revert InsufficientMTokenBalance(IERC20(mToken).balanceOf(address(this)), amount_);

        bytes32 hubVault_ = hubVault.toBytes32();

        messageSequence_ = INttManager(spokePortal).transfer(
            amount_,
            destinationChainId,
            hubVault_,
            refundAddress_,
            false,
            new bytes(1)
        );

        emit ExcessMTokenSent(destinationChainId, messageSequence_, msg.sender.toBytes32(), hubVault_, amount_);
    }
}
