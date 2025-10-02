// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { DeployBase } from "./DeployBase.sol";
import { DeployConfig, HubDeployConfig } from "../config/DeployConfig.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract DeployHub is DeployBase {
    using WormholeConfig for uint256;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        uint256 chainId_ = block.chainid;
        HubDeployConfig memory hubDeployConfig_ = DeployConfig.getHubDeployConfig(chainId_);
        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);

        vm.startBroadcast(deployer_);

        (address portal_, address transceiver_) = _deployHubComponents(
            deployer_,
            chainId_.toWormholeChainId(),
            _SWAP_FACILITY,
            hubDeployConfig_,
            transceiverConfig_
        );

        // HubPortal is already an approve earner
        IHubPortal(portal_).enableEarning();

        vm.stopBroadcast();

        console.log("Hub Portal: ", portal_);
        console.log("Transceiver:", transceiver_);

        _serializeHubDeployments(chainId_, portal_, transceiver_);
    }

    function _serializeHubDeployments(uint256 chainId_, address portal_, address transceiver_) internal {
        string memory root = "";

        vm.serializeAddress(root, "portal", portal_);
        vm.writeJson(vm.serializeAddress(root, "transceiver", transceiver_), _deployOutputPath(chainId_));
    }
}
