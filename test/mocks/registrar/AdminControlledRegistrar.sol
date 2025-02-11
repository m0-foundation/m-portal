// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import { IERC6372 } from "./interfaces/IERC6372.sol";
import { IAdminControlledRegistrar } from "./interfaces/IAdminControlledRegistrar.sol";
import { PureEpochs } from "./libs/PureEpochs.sol";

contract AdminControlledRegistrar is IAdminControlledRegistrar {
    /// @dev A mapping of keys to values.
    mapping(bytes32 key => bytes32 value) internal _valueAt;

    address public admin;

    address public vault;

    /* ============ Modifiers ============ */

    /// @dev Revert if the caller is not the admin.
    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Constructor ============ */

    constructor(address admin_) {
        admin = admin_;
        vault = admin_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IAdminControlledRegistrar
    function addToList(bytes32 list_, address account_) external onlyAdmin {
        _valueAt[_getIsInListKey(list_, account_)] = bytes32(uint256(1));

        emit AddressAddedToList(list_, account_);
    }

    /// @inheritdoc IAdminControlledRegistrar
    function removeFromList(bytes32 list_, address account_) external onlyAdmin {
        delete _valueAt[_getIsInListKey(list_, account_)];

        emit AddressRemovedFromList(list_, account_);
    }

    /// @inheritdoc IAdminControlledRegistrar
    function setKey(bytes32 key_, bytes32 value_) external onlyAdmin {
        emit KeySet(key_, _valueAt[_getValueKey(key_)] = value_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IERC6372
    function clock() external view returns (uint48) {
        return PureEpochs.currentEpoch();
    }

    /// @inheritdoc IAdminControlledRegistrar
    function get(bytes32 key_) external view returns (bytes32) {
        return _valueAt[_getValueKey(key_)];
    }

    /// @inheritdoc IAdminControlledRegistrar
    function get(bytes32[] calldata keys_) external view returns (bytes32[] memory values_) {
        values_ = new bytes32[](keys_.length);

        for (uint256 index_; index_ < keys_.length; ++index_) {
            values_[index_] = _valueAt[_getValueKey(keys_[index_])];
        }
    }

    /// @inheritdoc IAdminControlledRegistrar
    function listContains(bytes32 list_, address account_) external view returns (bool) {
        return _valueAt[_getIsInListKey(list_, account_)] == bytes32(uint256(1));
    }

    /// @inheritdoc IAdminControlledRegistrar
    function listContains(bytes32 list_, address[] calldata accounts_) external view returns (bool) {
        for (uint256 index_; index_ < accounts_.length; ++index_) {
            if (_valueAt[_getIsInListKey(list_, accounts_[index_])] != bytes32(uint256(1))) return false;
        }

        return true;
    }

    /// @inheritdoc IERC6372
    function CLOCK_MODE() external pure returns (string memory) {
        return PureEpochs.clockMode();
    }

    /// @inheritdoc IAdminControlledRegistrar
    function clockStartingTimestamp() external pure returns (uint256) {
        return PureEpochs.STARTING_TIMESTAMP;
    }

    /// @inheritdoc IAdminControlledRegistrar
    function clockPeriod() external pure returns (uint256) {
        return PureEpochs.EPOCH_PERIOD;
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Reverts if the caller is not the admin.
    function _revertIfNotAdmin() internal view {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
    }

    /**
     * @dev    Returns the key used to store the value of `key_`.
     * @param  key_ The key of the value.
     * @return The key used to store the value of `key_`.
     */
    function _getValueKey(bytes32 key_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("VALUE", key_));
    }

    /**
     * @dev    Returns the key used to store whether `account_` is in `list_`.
     * @param  list_    The list of addresses.
     * @param  account_ The address of the account.
     * @return The key used to store whether `account_` is in `list_`.
     */
    function _getIsInListKey(bytes32 list_, address account_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("IN_LIST", list_, account_));
    }
}
