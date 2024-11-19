// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

contract MockSpokePortal {
    address public immutable mToken;
    address public immutable registrar;

    constructor(address mToken_, address registrar_) {
        mToken = mToken_;
        registrar = registrar_;
    }

    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient,
        bytes32 refundAddress,
        bool shouldQueue,
        bytes memory transceiverInstructions
    ) external payable returns (uint64) {
        IERC20(mToken).transferFrom(msg.sender, address(this), amount);

        // Simulate ETH refund
        if (msg.value > 1) {
            msg.sender.call{ value: msg.value - 1 }("");
        }

        return uint64(1);
    }
}
