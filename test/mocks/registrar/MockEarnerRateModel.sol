// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

contract MockEarnerRateModel {
    error NotAdmin();

    uint32 public rate;
    address public admin;

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    constructor(address admin_) {
        admin = admin_;
    }

    function setRate(uint32 rate_) external onlyAdmin {
        rate = rate_;
    }

    /// @dev Reverts if the caller is not the admin.
    function _revertIfNotAdmin() internal view {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
    }
}
