// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { MockMToken } from "./MockMToken.sol";

contract MockSpokeMToken is MockMToken {
    function mint(address account_, uint256 amount_, uint128 index_) external {
        _updateIndex(index_);
        _mint(account_, amount_);
    }

    function burn(uint256 amount_) external {
        _burn(msg.sender, amount_);
    }

    function updateIndex(uint128 index_) external {
        _updateIndex(index_);
    }

    function _updateIndex(uint128 index_) private {
        currentIndex = index_;
    }
}
