// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";

import { TaskBase } from "./TaskBase.sol";

/**
 * @title  AddToEarnersList
 * @notice Adds an address to the earners list in the Hub Registrar.
 * @dev    Only works on Hub chains (Ethereum mainnet or Sepolia testnet).
 *         To propagate earner status from Hub to Spoke, use SendEarnerStatus.
 */
contract AddToEarnersList is TaskBase {
    uint256 internal constant ETHEREUM_CHAIN_ID = 1;
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

    bytes32 internal constant EARNERS_LIST = "earners";

    function run() public {
        _requireHubChain();

        (, , address registrar_, , , ) = _readDeployment(block.chainid);
        address account_ = vm.parseAddress(vm.prompt("Enter address to add to earners list"));
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        // Check if already in list
        bool alreadyEarner_ = IRegistrarLike(registrar_).listContains(EARNERS_LIST, account_);
        if (alreadyEarner_) {
            console.log("Address is already in earners list:", account_);
            return;
        }

        vm.startBroadcast(signer_);

        IRegistrarLike(registrar_).addToList(EARNERS_LIST, account_);

        console.log("Added to earners list:", account_);

        vm.stopBroadcast();
    }

    function _requireHubChain() internal view {
        if (block.chainid != ETHEREUM_CHAIN_ID && block.chainid != SEPOLIA_CHAIN_ID) {
            revert("This script can only be run on Hub chains (Ethereum or Sepolia)");
        }
    }
}
