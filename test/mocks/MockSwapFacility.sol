// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { MockWrappedMToken } from "./MockWrappedMToken.sol";

contract MockSwapFacility {
    address public mToken;

    function setMToken(address mToken_) external {
        mToken = mToken_;
    }

    function swapInM(address extensionOut_, uint256 amount_, address recipient_) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amount_);
        IERC20(mToken).approve(extensionOut_, amount_);
        MockWrappedMToken(extensionOut_).wrap(recipient_, amount_);
    }

    function swapOutM(address extensionIn_, uint256 amount_, address recipient_) external {
        IERC20(extensionIn_).transferFrom(msg.sender, address(this), amount_);
        MockWrappedMToken(extensionIn_).unwrap(recipient_, amount_);
    }
}
