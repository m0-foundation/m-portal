// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

library MessageUtils {
    function generateMessageId(
        uint256 sourceChainId,
        uint256 destinationChainId,
        uint256 nonce,
        bytes memory data
    ) internal pure returns (bytes32 id) {
        id = keccak256(abi.encode(sourceChainId, destinationChainId, nonce, data));
    }
}
