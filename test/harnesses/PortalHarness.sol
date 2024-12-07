// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Portal } from "../../src/Portal.sol";

contract PortalHarness is Portal {
    constructor(
        address mToken_,
        address smartMToken_,
        address registrar_,
        Mode mode_,
        uint16 chainId_
    ) Portal(mToken_, smartMToken_, registrar_, mode_, chainId_) {}
}
