// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../../lib/forge-std/src/Script.sol";

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";

import { Utils } from "../helpers/Utils.sol";

contract CastBase is Script, Utils {
    function _quoteDeliveryPrice(
        address hubPortal_,
        uint16 destinationChainId_
    ) internal view returns (uint256 deliveryPrice_) {
        (, deliveryPrice_) = IManagerBase(hubPortal_).quoteDeliveryPrice(destinationChainId_, new bytes(1));
    }

    function _sendMTokenIndex(
        address hubPortal_,
        uint16 destinationChainId_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (bytes32 messageId_) {
        return
            IHubPortal(hubPortal_).sendMTokenIndex{ value: value_ }(destinationChainId_, refundAddress_, new bytes(1));
    }

    function _sendRegistrarKey(
        address hubPortal_,
        uint16 destinationChainId_,
        bytes32 key_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (bytes32 messageId_) {
        return
            IHubPortal(hubPortal_).sendRegistrarKey{ value: value_ }(
                destinationChainId_,
                key_,
                refundAddress_,
                new bytes(1)
            );
    }

    function _sendRegistrarListStatus(
        address hubPortal_,
        uint16 destinationChainId_,
        bytes32 listName_,
        address account_,
        bytes32 refundAddress_,
        uint256 value_
    ) internal returns (bytes32 messageId_) {
        return
            IHubPortal(hubPortal_).sendRegistrarListStatus{ value: value_ }(
                destinationChainId_,
                listName_,
                account_,
                refundAddress_,
                new bytes(1)
            );
    }
}