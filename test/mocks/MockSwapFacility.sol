// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

interface IMExtension {
    function wrap(address recipient, uint256 amount) external;
    function unwrap(address recipient, uint256 amount) external;
}

contract MockSwapFacility {
    address public immutable mToken;

    constructor(address mToken_) {
        mToken = mToken_;
    }

    function swapInM(address extensionOut, uint256 amount, address recipient) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amount);
        IERC20(mToken).approve(extensionOut, amount);
        IMExtension(extensionOut).wrap(recipient, amount);
    }

    function swapOutM(address extensionIn, uint256 amount, address recipient) external {
        IERC20(extensionIn).transferFrom(msg.sender, address(this), amount);

        uint256 balanceBefore = IERC20(mToken).balanceOf(address(this));
        IMExtension(extensionIn).unwrap(address(this), amount);

        amount = IERC20(mToken).balanceOf(address(this)) - balanceBefore;
        IERC20(mToken).transfer(recipient, amount);
    }
}
