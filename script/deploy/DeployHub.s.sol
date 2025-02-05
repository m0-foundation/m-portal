// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { DeployBase } from "./DeployBase.sol";

contract DeployHub is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(deployer_);

        (address hubPortal_, address wormholeTransceiver_) = _deployHubComponents(
            deployer_,
            _loadHubConfig(vm.envString("CONFIG"), block.chainid)
        );
        _serializeHubDeployments(hubPortal_, wormholeTransceiver_);

        vm.stopBroadcast();
    }

    function _serializeHubDeployments(address hubPortal_, address wormholeTransceiver_) internal {
        string memory root = "";

        vm.serializeAddress(root, "hub_portal", hubPortal_);
        vm.writeJson(vm.serializeAddress(root, "wormhole_transceiver", wormholeTransceiver_), _deployOutputPath());
    }
}
