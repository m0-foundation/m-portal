// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Safe } from "../lib/safe-utils/src/Safe.sol";
import { Script } from "../lib/forge-std/src/Script.sol";

abstract contract MultiSigBatchBase is Script {
    using Safe for *;

    Safe.Client internal _safeMultiSig;
    address[] internal _targets;
    bytes[] internal _data;

    function _addToBatch(address target_, bytes memory data_) internal {
        _targets.push(target_);
        _data.push(data_);
    }

    function _proposeBatch(address safe_, address sender) internal {
        _safeMultiSig.initialize(safe_);
        _safeMultiSig.proposeTransactions(_targets, _data, sender, "");
    }

    function _simulateBatch(address safe_) internal {
        vm.startPrank(safe_);

        for (uint256 i = 0; i < _targets.length; i++) {
            (bool success, ) = _targets[i].call(_data[i]);
            require(success, "Simulation failed");
        }

        vm.stopPrank();
    }
}
