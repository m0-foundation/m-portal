// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import {
    ERC1967Proxy
} from "lib/example-native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrimmedAmountLib } from "lib/example-native-token-transfers/evm/src/libraries/TrimmedAmount.sol";
import { TransceiverStructs } from "lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { Portal } from "../../src/Portal.sol";

import { MockTransceiver } from "../mocks/MockTransceiver.sol";

contract UnitTestBase is Test {
    using TypeConverter for *;
    using TrimmedAmountLib for *;

    uint16 internal constant _LOCAL_CHAIN_ID = 2;
    uint16 internal constant _REMOTE_CHAIN_ID = 3;
    bytes32 internal constant _PEER = "peer";

    /// @dev Registrar key holding value of whether the earners list can be ignored or not.
    bytes32 internal constant _EARNERS_LIST_IGNORED = "earners_list_ignored";

    /// @dev Registrar key of earners list.
    bytes32 internal constant _EARNERS_LIST = "earners";

    /// @notice The scaling of rates in for exponent math.
    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    address internal immutable _alice = makeAddr("alice");
    address internal immutable _bob = makeAddr("bob");

    TransceiverStructs.TransceiverInstruction internal _emptyTransceiverInstruction;
    bytes internal _encodedEmptyTransceiverInstructions;

    MockTransceiver internal _transceiver;

    address internal _tokenAddress;
    uint8 internal _tokenDecimals;

    constructor() {
        _emptyTransceiverInstruction = TransceiverStructs.TransceiverInstruction({ index: 0, payload: "" });
        _encodedEmptyTransceiverInstructions = new bytes(1);
    }

    function _createProxy(address implementation_) internal returns (address proxy_) {
        return address(new ERC1967Proxy(implementation_, ""));
    }

    function _initializePortal(Portal portal_) internal {
        portal_.initialize();
        portal_.setTransceiver(address(_transceiver));
        portal_.setPeer(_REMOTE_CHAIN_ID, _PEER, _tokenDecimals, type(uint64).max);
    }

    function _createMessage(
        bytes memory payload_,
        uint16 sourceChainId_
    ) internal view returns (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) {
        message_ = TransceiverStructs.NttManagerMessage(bytes32(0), _alice.toBytes32(), payload_);
        messageId_ = TransceiverStructs.nttManagerMessageDigest(sourceChainId_, message_);
    }

    function _createTransferMessage(
        uint256 amount_,
        uint128 index_,
        bytes32 recipient_,
        uint16 sourceChainId_,
        uint16 destinationChainId_
    ) internal view returns (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) {
        TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_ = TransceiverStructs.NativeTokenTransfer(
            amount_.trim(_tokenDecimals, _tokenDecimals),
            _tokenAddress.toBytes32(),
            recipient_,
            destinationChainId_,
            abi.encodePacked(index_.toUint64())
        );
        bytes memory payload_ = TransceiverStructs.encodeNativeTokenTransfer(nativeTokenTransfer_);
        message_ = TransceiverStructs.NttManagerMessage(bytes32(0), _alice.toBytes32(), payload_);
        messageId_ = TransceiverStructs.nttManagerMessageDigest(sourceChainId_, message_);
    }

    function _getMaxTransferAmount(uint8 decimals_) internal pure returns (uint256 maxAmount_) {
        return TrimmedAmountLib.untrim(TrimmedAmountLib.max(decimals_), decimals_);
    }
}
