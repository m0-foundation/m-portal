// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { TrimmedAmount } from "../../lib/example-native-token-transfers/evm/src/libraries/TrimmedAmount.sol";
import { TransceiverStructs } from "../../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";
import {
    BytesParsing
} from "../../lib/example-native-token-transfers/evm/lib/wormhole-solidity-sdk/src/libraries/BytesParsing.sol";

import { TypeConverter } from "./TypeConverter.sol";

enum PayloadType {
    Token,
    Index,
    Key,
    List
}

library PayloadEncoder {
    using BytesParsing for bytes;
    using TypeConverter for *;

    uint256 internal constant PAYLOAD_PREFIX_LENGTH = 4;
    bytes4 internal constant INDEX_TRANSFER_PREFIX = 0x4d304954; // M0IT - M0 Index Transfer
    bytes4 internal constant KEY_TRANSFER_PREFIX = 0x4d304b54; // M0KT - M0 Key Transfer
    bytes4 internal constant LIST_UPDATE_PREFIX = 0x4d304c55; // M0LU - M0 List Update

    error InvalidPayloadLength(uint256 length);
    error InvalidPayloadPrefix(bytes4 prefix);

    function getPayloadType(bytes memory payload_) internal pure returns (PayloadType payloadType_) {
        if (payload_.length < PAYLOAD_PREFIX_LENGTH) revert InvalidPayloadLength(payload_.length);

        (bytes4 prefix, ) = payload_.asBytes4Unchecked(0);

        if (prefix == TransceiverStructs.NTT_PREFIX) return PayloadType.Token;
        if (prefix == INDEX_TRANSFER_PREFIX) return PayloadType.Index;
        if (prefix == KEY_TRANSFER_PREFIX) return PayloadType.Key;
        if (prefix == LIST_UPDATE_PREFIX) return PayloadType.List;

        revert InvalidPayloadPrefix(prefix);
    }

    function decodeTokenTransfer(
        bytes memory payload_
    )
        internal
        pure
        returns (TrimmedAmount trimmedAmount_, uint128 index_, address recipient_, uint16 destinationChainId_)
    {
        TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_ = TransceiverStructs
            .parseNativeTokenTransfer(payload_);

        uint256 offset_ = 0;
        (index_, offset_) = nativeTokenTransfer_.additionalPayload.asUint64Unchecked(offset_);
        nativeTokenTransfer_.additionalPayload.checkLength(offset_);

        trimmedAmount_ = nativeTokenTransfer_.amount;
        recipient_ = nativeTokenTransfer_.to.toAddress();
        destinationChainId_ = nativeTokenTransfer_.toChain;
    }

    function encodeIndex(uint128 index_, uint16 destinationChainId_) internal pure returns (bytes memory encoded_) {
        return abi.encodePacked(INDEX_TRANSFER_PREFIX, index_.toUint64(), destinationChainId_);
    }

    function decodeIndex(bytes memory payload_) internal pure returns (uint128 index_, uint16 destinationChainId_) {
        uint256 offset_ = PAYLOAD_PREFIX_LENGTH;

        (index_, offset_) = payload_.asUint64Unchecked(offset_);
        (destinationChainId_, offset_) = payload_.asUint16Unchecked(offset_);

        payload_.checkLength(offset_);
    }

    function encodeKey(
        bytes32 key_,
        bytes32 value_,
        uint64 sequence_,
        uint16 destinationChainId_
    ) internal pure returns (bytes memory encoded_) {
        return abi.encodePacked(KEY_TRANSFER_PREFIX, key_, value_, sequence_, destinationChainId_);
    }

    function decodeKey(
        bytes memory payload_
    ) internal pure returns (bytes32 key_, bytes32 value_, uint64 sequence_, uint16 destinationChainId_) {
        uint256 offset_ = PAYLOAD_PREFIX_LENGTH;

        (key_, offset_) = payload_.asBytes32Unchecked(offset_);
        (value_, offset_) = payload_.asBytes32Unchecked(offset_);
        (sequence_, offset_) = payload_.asUint64Unchecked(offset_);
        (destinationChainId_, offset_) = payload_.asUint16Unchecked(offset_);

        payload_.checkLength(offset_);
    }

    function encodeListUpdate(
        bytes32 listName_,
        address account_,
        bool add_,
        uint64 sequence_,
        uint16 destinationChainId_
    ) internal pure returns (bytes memory encoded_) {
        return abi.encodePacked(LIST_UPDATE_PREFIX, listName_, account_, add_, sequence_, destinationChainId_);
    }

    function decodeListUpdate(
        bytes memory payload_
    )
        internal
        pure
        returns (bytes32 listName_, address account_, bool add_, uint64 sequence_, uint16 destinationChainId_)
    {
        uint256 offset_ = PAYLOAD_PREFIX_LENGTH;

        (listName_, offset_) = payload_.asBytes32Unchecked(offset_);
        (account_, offset_) = payload_.asAddressUnchecked(offset_);
        (add_, offset_) = payload_.asBoolUnchecked(offset_);
        (sequence_, offset_) = payload_.asUint64Unchecked(offset_);
        (destinationChainId_, offset_) = payload_.asUint16Unchecked(offset_);

        payload_.checkLength(offset_);
    }
}
