// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";

import {
    IAccessControl
} from "../../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";

import { HubPortal } from "../../src/HubPortal.sol";

/**
 * @title  Deploys the new HubPortal implementation for the Noble Portal SwapFacility upgrade.
 * @dev    The upgrade itself must be executed by the Noble Portal owner Safe,
 *         and the M_SWAPPER_ROLE grant by the SwapFacility admin Safe.
 *         This script only deploys the implementation and prints the required Safe transactions.
 */
contract DeployNobleHubImplementation is Script {
    address internal constant _MAINNET_M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _MAINNET_REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant _SWAP_FACILITY = 0xB6807116b3B1B321a390594e31ECD6e0076f6278;

    address internal constant _NOBLE_PORTAL = 0x83Ae82Bd4054e815fB7B189C39D9CE670369ea16;
    address internal constant _NOBLE_PORTAL_OWNER = 0x7176665e336e8692e9b265aB6290934C93F99cCf;
    address internal constant _SWAP_FACILITY_ADMIN = 0x48670B46380FE1645f0E3e821a25162dB2589D19;

    uint16 internal constant _ETHEREUM_WORMHOLE_CHAIN_ID = 2;

    bytes32 internal constant _M_SWAPPER_ROLE = keccak256("M_SWAPPER_ROLE");

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        require(block.chainid == 1, "Mainnet only");

        vm.startBroadcast(deployer_);

        HubPortal implementation_ = new HubPortal(_MAINNET_M_TOKEN, _MAINNET_REGISTRAR, _ETHEREUM_WORMHOLE_CHAIN_ID);

        vm.stopBroadcast();

        console.log("Deployer:                  ", deployer_);
        console.log("HubPortal implementation:  ", address(implementation_));
    }
}
