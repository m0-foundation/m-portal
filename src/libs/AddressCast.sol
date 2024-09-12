// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

library AddressCast {
    function toBytes32(address address_) internal pure returns (bytes32 result) {
        result = bytes32(uint256(uint160(address_)));
    }

    function toAddress(bytes32 addressBytes32_) internal pure returns (address result) {
        result = address(uint160(uint256(addressBytes32_)));
    }
}
