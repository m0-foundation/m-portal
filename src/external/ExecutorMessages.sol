// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

library ExecutorMessages {
    bytes4 private constant REQ_MM = "ERM1";
    bytes4 private constant REQ_VAA_V1 = "ERV1";
    bytes4 private constant REQ_NTT_V1 = "ERN1";
    bytes4 private constant REQ_CCTP_V1 = "ERC1";

    /// @notice Payload length will not fit in a uint32.
    /// @dev Selector: 492f620d.
    error PayloadTooLarge();

    /// @notice Encodes a modular messaging request payload.
    /// @param srcChain The source chain for the message (usually this chain).
    /// @param srcAddr The source address for the message.
    /// @param sequence The sequence number returned by `endpoint.sendMessage`.
    /// @param payload The full payload, the keccak of which was sent to `endpoint.sendMessage`.
    /// @return bytes The encoded request.
    function makeMMRequest(
        uint16 srcChain,
        address srcAddr,
        uint64 sequence,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        if (payload.length > type(uint32).max) {
            revert PayloadTooLarge();
        }
        return
            abi.encodePacked(
                REQ_MM,
                srcChain,
                bytes32(uint256(uint160(srcAddr))),
                sequence,
                uint32(payload.length),
                payload
            );
    }

    /// @notice Encodes a version 1 VAA request payload.
    /// @param emitterChain The emitter chain from the VAA.
    /// @param emitterAddress The emitter address from the VAA.
    /// @param sequence The sequence number from the VAA.
    /// @return bytes The encoded request.
    function makeVAAv1Request(
        uint16 emitterChain,
        bytes32 emitterAddress,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(REQ_VAA_V1, emitterChain, emitterAddress, sequence);
    }

    /// @notice Encodes a version 1 NTT request payload.
    /// @param srcChain The source chain for the NTT transfer.
    /// @param srcManager The source manager for the NTT transfer.
    /// @param messageId The manager message id for the NTT transfer.
    /// @return bytes The encoded request.
    function makeNTTv1Request(
        uint16 srcChain,
        bytes32 srcManager,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(REQ_NTT_V1, srcChain, srcManager, messageId);
    }

    /// @notice Encodes a version 1 CCTP request payload.
    /// @param sourceDomain The source chain for the CCTP transfer.
    /// @param nonce The nonce of the CCTP transfer.
    /// @return bytes The encoded request.
    function makeCCTPv1Request(uint32 sourceDomain, uint64 nonce) internal pure returns (bytes memory) {
        return abi.encodePacked(REQ_CCTP_V1, sourceDomain, nonce);
    }
}
