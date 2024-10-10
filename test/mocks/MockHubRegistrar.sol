// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockHubRegistrar {
    mapping(bytes32 key => bytes32 value) internal _values;

    mapping(bytes32 listName => mapping(address account => bool contains)) public listContains;

    function get(bytes32 key_) external view returns (bytes32 value_) {
        return _values[key_];
    }

    function set(bytes32 key_, bytes32 value_) external {
        _values[key_] = value_;
    }

    function setListContains(bytes32 listName_, address account_, bool contains_) external {
        listContains[listName_][account_] = contains_;
    }
}
