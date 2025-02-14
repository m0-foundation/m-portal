// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { UpgradeBase } from "./UpgradeBase.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract UpgradeWormholeTransceiver is UpgradeBase {
    using WormholeConfig for uint256;

    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 chainId_ = block.chainid;

        (, address portal_, , address transceiver_, , ) = _readDeployment(chainId_);
        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);

        vm.startBroadcast(deployer_);

        _upgradeWormholeTransceiver(portal_, transceiver_, transceiverConfig_);

        vm.stopBroadcast();
    }
}
