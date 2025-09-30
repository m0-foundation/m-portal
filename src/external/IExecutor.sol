// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

interface IExecutor {
    struct SignedQuoteHeader {
        bytes4 prefix;
        address quoterAddress;
        bytes32 payeeAddress;
        uint16 srcChain;
        uint16 dstChain;
        uint64 expiryTime;
    }

    event RequestForExecution(
        address indexed quoterAddress,
        uint256 amtPaid,
        uint16 dstChain,
        bytes32 dstAddr,
        address refundAddr,
        bytes signedQuote,
        bytes requestBytes,
        bytes relayInstructions
    );

    function requestExecution(
        uint16 dstChain,
        bytes32 dstAddr,
        address refundAddr,
        bytes calldata signedQuote,
        bytes calldata requestBytes,
        bytes calldata relayInstructions
    ) external payable;
}
