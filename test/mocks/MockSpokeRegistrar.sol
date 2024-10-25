// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockSpokeRegistrar {
    mapping(bytes32 key => bytes32 value) public get;

    function setKey(bytes32 key_, bytes32 value_) external {
        get[key_] = value_;
    }

    function addToList(bytes32 list_, address account_) external {}

    function removeFromList(bytes32 list_, address account_) external {}
}
