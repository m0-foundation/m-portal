// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { DeployBase } from "./DeployBase.sol";
import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";

contract DeployHub is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        (address portal_, address transceiver_) = _deployHubComponents(
            deployer_,
            _loadHubConfig(vm.envString("CONFIG"), block.chainid)
        );

        // HubPortal is already an approve earner
        IHubPortal(portal_).enableEarning();

        vm.stopBroadcast();

        _serializeHubDeployments(portal_, transceiver_);
    }

    function _serializeHubDeployments(address portal_, address transceiver_) internal {
        string memory root = "";

        vm.serializeAddress(root, "portal", portal_);
        vm.writeJson(vm.serializeAddress(root, "transceiver", transceiver_), _deployOutputPath());
    }
}
