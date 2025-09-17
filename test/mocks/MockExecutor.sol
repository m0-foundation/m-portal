// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import { IExecutor } from "../../src/external/IExecutor.sol";

contract MockExecutor is IExecutor {
    function requestExecution(
        uint16 dstChain,
        bytes32 dstAddr,
        address refundAddr,
        bytes calldata signedQuote,
        bytes calldata requestBytes,
        bytes calldata relayInstructions
    ) external payable {}
}
