// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { OwnableUpgradeable } from "../../lib/native-token-transfers/evm/src/libraries/external/OwnableUpgradeable.sol";

import { TaskBase } from "./TaskBase.sol";

contract TransferOwnership is TaskBase {
    function run() public {
        (, address portal_, , address transceiver_, , ) = _readDeployment(block.chainid);
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address newOwner_ = vm.envAddress("PORTAL_OWNER_ADDRESS");
        address currentOwner_ = OwnableUpgradeable(portal_).owner();

        assert(signer_ == currentOwner_);

        console.log("New Owner", newOwner_);

        vm.startBroadcast(signer_);

        // Transfers Portal and Transceiver ownership
        OwnableUpgradeable(portal_).transferOwnership(newOwner_);

        assert(OwnableUpgradeable(portal_).owner() == newOwner_);
        assert(OwnableUpgradeable(transceiver_).owner() == newOwner_);

        vm.stopBroadcast();
    }
}
