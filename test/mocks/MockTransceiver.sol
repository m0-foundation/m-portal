// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { TransceiverStructs } from "../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

contract MockTransceiver {
    function quoteDeliveryPrice(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction
    ) external view virtual returns (uint256) {}

    function sendMessage(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction,
        bytes memory nttManagerMessage,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress
    ) external payable {}
}

contract MockTransceiverPrice is MockTransceiver {
    mapping(uint16 => uint256) internal _quotePrices;

    function setQuotePrice(uint16 chainId, uint256 price) external {
        _quotePrices[chainId] = price;
    }

    function quoteDeliveryPrice(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction
    ) external view override returns (uint256) {
        // We assume no base fee here, but wormhole has one on production networks

        if (instruction.payload.length == 1 && instruction.payload[0] == hex"01") {
            // Equivalent to expected executor transceiver instructions that skip relaying
            return 0;
        } else {
            return _quotePrices[recipientChain];
        }
    }
}
