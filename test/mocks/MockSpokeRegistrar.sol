// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockSpokeRegistrar {
    function setKey(bytes32 key_, bytes32 value_) external {}

    function addToList(bytes32 list_, address account_) external {}

    function removeFromList(bytes32 list_, address account_) external {}
}
