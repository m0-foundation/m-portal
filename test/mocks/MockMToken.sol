// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { MockERC20 } from "./MockERC20.sol";

contract MockMToken is MockERC20 {
    uint128 public currentIndex;

    mapping(address account => bool earning) public isEarning;

    constructor() MockERC20("M Token", "M", 6) {}

    function setCurrentIndex(uint128 currentIndex_) external {
        currentIndex = currentIndex_;
    }

    function setIsEarning(address account_, bool isEarning_) external {
        isEarning[account_] = isEarning_;
    }

    function startEarning() external {
        isEarning[msg.sender] = true;
    }

    function stopEarning(address account_) external {
        isEarning[account_] = false;
    }
}
