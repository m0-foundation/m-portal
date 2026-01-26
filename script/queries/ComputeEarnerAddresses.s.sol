// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { ScriptBase } from "../ScriptBase.sol";

contract ComputeEarnerAddresses is ScriptBase {
    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    function run(string[] memory names_) public view {
        for (uint256 i_; i_ < names_.length; ++i_) {
            bytes32 salt_ = _computeSalt(_DEPLOYER, names_[i_]);
            bytes32 guardedSalt_ = _computeGuardedSalt(_DEPLOYER, salt_);
            address address_ = _getCreate3Address(_DEPLOYER, salt_);

            console.log("Contract:     ", names_[i_]);
            console.log("Salt:         ");
            console.logBytes32(salt_);
            console.log("Guarded Salt: ");
            console.logBytes32(guardedSalt_);
            console.log("Address:      ", address_);
            console.log("====================================================================");
        }
    }
}
