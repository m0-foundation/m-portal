// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { TransceiverStructs } from "../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

contract MockTransceiver {
    function quoteDeliveryPrice(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction
    ) external view returns (uint256) {}

    function sendMessage(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction,
        bytes memory nttManagerMessage,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress
    ) external payable {}
}
