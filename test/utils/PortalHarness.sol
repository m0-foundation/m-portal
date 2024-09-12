// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Portal } from "../../src/Portal.sol";

contract PortalHarness is Portal {
    constructor(address bridge_, address mToken_, address registrar_) Portal(bridge_, mToken_, registrar_) {}
}
