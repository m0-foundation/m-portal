// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IManagerBase } from "lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";

import { Portal } from "../../src/Portal.sol";

contract PortalHarness is Portal {
    constructor(
        address mToken_,
        address registrar_,
        Mode mode_,
        uint16 chainId_
    ) Portal(mToken_, registrar_, mode_, chainId_) {}
}
