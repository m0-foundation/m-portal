// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { SpokePortal } from "../../src/SpokePortal.sol";

contract SpokePortalHarness is SpokePortal {
    constructor(address mToken_, address registrar_, uint16 chainId_) SpokePortal(mToken_, registrar_, chainId_) {}

    function workaround_setOutstandingPrincipal(uint112 principal_) external {
        outstandingPrincipal = principal_;
    }
}
