// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../../lib/forge-std/src/Test.sol";

import {
    BytesParsing
} from "../../../lib/native-token-transfers/evm/lib/wormhole-solidity-sdk/src/libraries/BytesParsing.sol";
import { TransceiverStructs } from "../../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";
import {
    TrimmedAmount,
    TrimmedAmountLib
} from "../../../lib/native-token-transfers/evm/src/libraries/TrimmedAmount.sol";

import { TypeConverter } from "../../../src/libs/TypeConverter.sol";
import { PayloadType, PayloadEncoder } from "../../../src/libs/PayloadEncoder.sol";

contract PayloadEncoderTest is Test {
    using TypeConverter for *;
    using TrimmedAmountLib for *;

    uint16 internal constant _DESTINATION_CHAIN_ID = 2;
    uint8 internal constant _TOKEN_DECIMALS = 6;

    address internal immutable _token = makeAddr("token");
    address internal immutable _recipient = makeAddr("recipient");

    /// forge-config: default.allow_internal_expect_revert = true
    function testFuzz_getPayloadType_invalidPayloadPrefixLength(bytes3 randomBytes_) external {
        bytes memory payload_ = abi.encodePacked(randomBytes_);

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadLength.selector, payload_.length));
        PayloadEncoder.getPayloadType(payload_);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testFuzz_getPayloadType_invalidPayloadPrefix(bytes4 randomBytes_) external {
        vm.assume(randomBytes_ != TransceiverStructs.NTT_PREFIX);
        vm.assume(randomBytes_ != PayloadEncoder.INDEX_TRANSFER_PREFIX);
        vm.assume(randomBytes_ != PayloadEncoder.KEY_TRANSFER_PREFIX);
        vm.assume(randomBytes_ != PayloadEncoder.LIST_UPDATE_PREFIX);
        bytes memory payload_ = abi.encodePacked(randomBytes_);

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadPrefix.selector, randomBytes_));
        PayloadEncoder.getPayloadType(payload_);
    }

    function testFuzz_getPayloadType_token(bytes calldata randomBytes_) external {
        bytes memory payload_ = abi.encodePacked(TransceiverStructs.NTT_PREFIX, randomBytes_);

        assertEq(uint8(PayloadEncoder.getPayloadType(payload_)), uint8(PayloadType.Token));
    }

    function testFuzz_getPayloadType_index(bytes calldata randomBytes_) external {
        bytes memory payload_ = abi.encodePacked(PayloadEncoder.INDEX_TRANSFER_PREFIX, randomBytes_);

        assertEq(uint8(PayloadEncoder.getPayloadType(payload_)), uint8(PayloadType.Index));
    }

    function testFuzz_getPayloadType_key(bytes calldata randomBytes_) external {
        bytes memory payload_ = abi.encodePacked(PayloadEncoder.KEY_TRANSFER_PREFIX, randomBytes_);

        assertEq(uint8(PayloadEncoder.getPayloadType(payload_)), uint8(PayloadType.Key));
    }

    function testFuzz_getPayloadType_list(bytes calldata randomBytes_) external {
        bytes memory payload_ = abi.encodePacked(PayloadEncoder.LIST_UPDATE_PREFIX, randomBytes_);

        assertEq(uint8(PayloadEncoder.getPayloadType(payload_)), uint8(PayloadType.List));
    }

    function test_encodeAdditionalPayload() external {
        uint128 index_ = 1e12;
        bytes32 destinationToken_ = makeAddr("destination token").toBytes32();
        bytes memory payload_ = abi.encodePacked(uint64(index_), destinationToken_);

        assertEq(PayloadEncoder.encodeAdditionalPayload(index_, destinationToken_), payload_);
    }

    function test_decodeAdditionalPayload() external {
        uint128 encodedIndex_ = 1e12;
        address encodedDestinationToken_ = makeAddr("destination token");

        bytes memory payload_ = abi.encodePacked(uint64(encodedIndex_), encodedDestinationToken_.toBytes32());

        (uint128 decodedIndex_, address decodedDestinationToken_) = PayloadEncoder.decodeAdditionalPayload(payload_);

        assertEq(decodedIndex_, encodedIndex_);
        assertEq(decodedDestinationToken_, encodedDestinationToken_);
    }

    function testFuzz_decodeAdditionalPayload(uint64 encodedIndex_, address encodedDestinationToken_) external {
        bytes memory payload_ = abi.encodePacked(encodedIndex_, encodedDestinationToken_.toBytes32());

        (uint128 decodedIndex_, address decodedDestinationToken_) = PayloadEncoder.decodeAdditionalPayload(payload_);

        assertEq(decodedIndex_, encodedIndex_);
        assertEq(decodedDestinationToken_, encodedDestinationToken_);
    }

    function test_decodeAdditionalPayload_invalidLength() external {
        uint128 index_ = 1e12;
        // wrapped token isn't added to the payload
        bytes memory payload_ = abi.encodePacked(uint64(index_));

        vm.expectRevert(abi.encodeWithSelector(BytesParsing.LengthMismatch.selector, 8, 40));
        this.decodeAdditionalPayload(payload_);
    }

    /// @dev a wrapper to prevent internal library functions from getting inlined
    ///      https://github.com/foundry-rs/foundry/issues/7757
    function decodeAdditionalPayload(bytes memory payload_) public pure {
        PayloadEncoder.decodeAdditionalPayload(payload_);
    }

    function test_decodeTokenTransfer() external {
        uint256 encodedAmount_ = 1000;
        uint128 encodedIndex_ = 1e12;
        address encodedDestinationToken_ = makeAddr("destination token");

        bytes memory payload_ = TransceiverStructs.encodeNativeTokenTransfer(
            TransceiverStructs.NativeTokenTransfer(
                encodedAmount_.trim(_TOKEN_DECIMALS, _TOKEN_DECIMALS),
                _token.toBytes32(),
                _recipient.toBytes32(),
                _DESTINATION_CHAIN_ID,
                abi.encodePacked(uint64(encodedIndex_), encodedDestinationToken_.toBytes32())
            )
        );

        (
            TrimmedAmount decodedTrimmedAmount_,
            uint128 decodedIndex_,
            address decodedDestinationToken_,
            address decodedRecipient_,
            uint16 decodedDestinationChainId_
        ) = PayloadEncoder.decodeTokenTransfer(payload_);

        uint256 decodedAmount_ = decodedTrimmedAmount_.untrim(_TOKEN_DECIMALS);

        assertEq(decodedAmount_, encodedAmount_);
        assertEq(decodedIndex_, encodedIndex_);
        assertEq(decodedDestinationToken_, encodedDestinationToken_);
        assertEq(decodedRecipient_, _recipient);
        assertEq(decodedDestinationChainId_, _DESTINATION_CHAIN_ID);
    }

    function test_encodeIndex() external {
        uint128 index_ = 1e12;
        bytes memory payload_ = abi.encodePacked(
            PayloadEncoder.INDEX_TRANSFER_PREFIX,
            uint64(index_),
            _DESTINATION_CHAIN_ID
        );

        assertEq(PayloadEncoder.encodeIndex(uint64(index_), _DESTINATION_CHAIN_ID), payload_);
    }

    function test_decodeIndex() external {
        uint128 encodedIndex_ = 1e12;
        bytes memory payload_ = abi.encodePacked(
            PayloadEncoder.INDEX_TRANSFER_PREFIX,
            uint64(encodedIndex_),
            _DESTINATION_CHAIN_ID
        );

        (uint128 decodedIndex_, uint16 decodedDestinationChainId_) = PayloadEncoder.decodeIndex(payload_);

        assertEq(decodedIndex_, encodedIndex_);
        assertEq(decodedDestinationChainId_, _DESTINATION_CHAIN_ID);
    }

    function test_encodeKey() external {
        bytes32 key_ = "key";
        bytes32 value_ = "value";
        bytes memory payload_ = abi.encodePacked(
            PayloadEncoder.KEY_TRANSFER_PREFIX,
            key_,
            value_,
            _DESTINATION_CHAIN_ID
        );

        assertEq(PayloadEncoder.encodeKey(key_, value_, _DESTINATION_CHAIN_ID), payload_);
    }

    function test_decodeKey() external {
        bytes32 encodedKey_ = "key";
        bytes32 encodedValue_ = "value";
        bytes memory payload_ = abi.encodePacked(
            PayloadEncoder.KEY_TRANSFER_PREFIX,
            encodedKey_,
            encodedValue_,
            _DESTINATION_CHAIN_ID
        );

        (bytes32 decodedKey_, bytes32 decodedValue_, uint16 decodedDestinationChainId_) = PayloadEncoder.decodeKey(
            payload_
        );

        assertEq(decodedKey_, encodedKey_);
        assertEq(decodedValue_, encodedValue_);
        assertEq(decodedDestinationChainId_, _DESTINATION_CHAIN_ID);
    }

    function test_encodeListUpdate() external {
        bytes32 listName_ = "list";
        address account_ = makeAddr("account");
        bool add_ = true;
        bytes memory payload_ = abi.encodePacked(
            PayloadEncoder.LIST_UPDATE_PREFIX,
            listName_,
            account_,
            add_,
            _DESTINATION_CHAIN_ID
        );

        assertEq(PayloadEncoder.encodeListUpdate(listName_, account_, add_, _DESTINATION_CHAIN_ID), payload_);
    }

    function test_decodeListUpdate() external {
        bytes32 encodedListName_ = "list";
        address encodedAccount_ = makeAddr("account");
        bool encodedStatus_ = true;
        bytes memory payload_ = abi.encodePacked(
            PayloadEncoder.LIST_UPDATE_PREFIX,
            encodedListName_,
            encodedAccount_,
            encodedStatus_,
            _DESTINATION_CHAIN_ID
        );

        (
            bytes32 decodedListName_,
            address decodedAccount_,
            bool decodedStatus_,
            uint16 decodedDestinationChainId_
        ) = PayloadEncoder.decodeListUpdate(payload_);

        assertEq(decodedListName_, encodedListName_);
        assertEq(decodedAccount_, encodedAccount_);
        assertEq(decodedStatus_, encodedStatus_);
        assertEq(decodedDestinationChainId_, _DESTINATION_CHAIN_ID);
    }
}
