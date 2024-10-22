// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockSpokePortal {
    address public immutable mToken;

    constructor(address mToken_) {
        mToken = mToken_;
    }

    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient,
        bytes32 refundAddress,
        bool shouldQueue,
        bytes memory transceiverInstructions
    ) external payable returns (uint64) {}
}
