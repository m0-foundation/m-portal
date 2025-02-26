// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { DeployBase } from "./DeployBase.sol";
import { DeployConfig, HubDeployConfig } from "../config/DeployConfig.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract DeployNobleHub is DeployBase {
    using WormholeConfig for uint256;

    /// @dev Contract names are used for deterministic deployment
    string internal constant _NOBLE_PORTAL_NAME = "NoblePortal";
    string internal constant _NOBLE_TRANSCEIVER_NAME = "NobleWormholeTransceiver";

    address internal constant _EXPECTED_NOBLE_PORTAL_ADDRESS = 0x83Ae82Bd4054e815fB7B189C39D9CE670369ea16;
    address internal constant _EXPECTED_NOBLE_TRANSCEIVER_ADDRESS = 0xc7Dd372c39E38BF11451ab4A8427B4Ae38ceF644;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        uint256 chainId_ = block.chainid;
        HubDeployConfig memory hubDeployConfig_ = DeployConfig.getHubDeployConfig(chainId_);
        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);

        vm.startBroadcast(deployer_);

        (address portal_, address transceiver_) = _deployNobleHubComponents(
            deployer_,
            chainId_.toWormholeChainId(),
            hubDeployConfig_,
            transceiverConfig_
        );

        // Enable earning for Noble HubPortal. It's already an approve earner
        IHubPortal(portal_).enableEarning();

        vm.stopBroadcast();

        console.log("Deployer:         ", deployer_);
        console.log("Noble Hub Portal: ", portal_);
        console.log("Noble Transceiver:", transceiver_);

        _serializeHubDeployments(chainId_, portal_, transceiver_);
    }

    function _serializeHubDeployments(uint256 chainId_, address portal_, address transceiver_) internal {
        string memory deployOutputPath_ = string.concat(vm.projectRoot(), "/deployments/noble/");
        if (!vm.isDir(deployOutputPath_)) {
            vm.createDir(deployOutputPath_, true);
        }
        deployOutputPath_ = string.concat(deployOutputPath_, vm.toString(chainId_), ".json");

        string memory root = "";
        vm.serializeAddress(root, "portal", portal_);
        vm.writeJson(vm.serializeAddress(root, "transceiver", transceiver_), deployOutputPath_);
    }
}
