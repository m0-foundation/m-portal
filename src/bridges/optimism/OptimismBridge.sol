// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IBridge } from "../interfaces/IBridge.sol";

import { IOptimismBridge } from "./interfaces/IOptimismBridge.sol";
import { ICrossDomainMessenger } from "./interfaces/Dependencies.sol";

import { Bridge } from "../Bridge.sol";
import { MessageUtils } from "../../libs/MessageUtils.sol";

/**
 * @title  Optimism Bridge.
 * @author M^0 Labs.
 * @notice A bridge to send data from Ethereum to OP Stack L2 chains.
 * @dev    The same contract must be deployed on Ethereum and L2 chains.
 *         For each L2 bridge a separate Ethereum bridge must be deployed
 *         since CrossChainMessenger is different for every L2.
 */
contract OptimismBridge is IOptimismBridge, Bridge {
    /// @inheritdoc IOptimismBridge
    address public immutable crossChainMessenger;

    /// @inheritdoc IOptimismBridge
    address public immutable remoteBridge;

    /// @inheritdoc IOptimismBridge
    uint256 public immutable remoteChainId;

    /// @inheritdoc IOptimismBridge
    uint256 public nonce;

    /**
     * @notice Constructor.
     * @param  portal_              The address of the Portal contract on this chain.
     * @param  crossChainMessenger_ An address of the Optimism CrossChainMessenger contract on this chain.
     * @param  remoteChainId_       The EVM chain Id of the remote chain (i.e. L2 if the current chain is Ethereum).
     * @param  remoteBridge_        The address of the OptimismBridge on the remote chain.
     */
    constructor(
        address portal_,
        address crossChainMessenger_,
        uint256 remoteChainId_,
        address remoteBridge_
    ) Bridge(portal_) {
        if ((crossChainMessenger = crossChainMessenger_) == address(0)) revert ZeroCrossChainMessenger();
        if ((remoteChainId = remoteChainId_) == 0) revert ZeroChainId();
        if ((remoteBridge = remoteBridge_) == address(0)) revert ZeroRemoteBridge();
    }

    /**
     * @notice Dispatches messages from L1 to L2 chain.
     * @dev    Must be called only from L1 chain.
     * @param  chainId_   EVM Id of the receiving L2 chain. Reverts if incorrect id is passed.
     * @param  message_   Data dispatched to the receiving chain's Portal.
     * @param  gasLimit_  Gas limit to be used for executing the message on L2 chain.
     * @return messageId_ Id that uniquely identifies the message.
     */
    function dispatch(
        uint256 chainId_,
        bytes calldata message_,
        uint32 gasLimit_,
        address /* refundAddress */
    ) external payable onlyPortal returns (bytes32 messageId_) {
        if (chainId_ != remoteChainId) revert UnsupportedChain();

        // TODO: In multi-bridge environment nonces must be managed in the Portal or  other higher
        //       level-contract (e.g., BridgeController) to ensure that nonces on the same chain are unique
        //       regardless of the bridge.
        messageId_ = MessageUtils.generateMessageId(block.chainid, remoteChainId, nonce++, message_);

        ICrossDomainMessenger(crossChainMessenger).sendMessage(
            remoteBridge,
            abi.encodeCall(IOptimismBridge.receiveMessage, (messageId_, message_)),
            gasLimit_
        );

        emit MessageDispatched(chainId_, messageId_, message_);
    }

    /// @inheritdoc IOptimismBridge
    function receiveMessage(bytes32 messageId_, bytes calldata message_) external {
        // TODO: Check and store the incoming messageId to prevent duplicates. It must be done in the Portal or other
        //       higher-level contract.

        // Validate sender
        if (
            msg.sender != crossChainMessenger ||
            ICrossDomainMessenger(crossChainMessenger).xDomainMessageSender() != remoteBridge
        ) revert UnauthorizedCaller();

        (bool success_, bytes memory returnData_) = portal.call(message_);

        if (!success_) revert MessageFailure(messageId_, returnData_);

        emit MessageExecuted(messageId_);
    }

    /// @inheritdoc IBridge
    function quote(uint256, bytes calldata, uint32) external pure returns (uint256 nativeFee_) {
        // Zero as Optimism `CrossDomainMessenger` doesn't charge a fee.
        return 0;
    }
}
