// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Safe } from "../../lib/safe-utils/src/Safe.sol";
import { ManagerBase } from "../../lib/native-token-transfers/evm/src/NttManager/ManagerBase.sol";
import { TaskBase } from "./TaskBase.sol";

contract ProposeUnpausePortal is TaskBase {
    using Safe for *;

    address constant _SAFE_MULTISIG = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    Safe.Client internal _safeMultiSig;

    function run() public {
        address proposer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        (, address portal_, , , , ) = _readDeployment(block.chainid);

        _safeMultiSig.initialize(_SAFE_MULTISIG);
        _safeMultiSig.proposeTransaction(portal_, abi.encodeCall(ManagerBase.unpause, ()), proposer_);
    }
}
