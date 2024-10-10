// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../../lib/forge-std/src/Script.sol";

import { ITransceiver } from "../../lib/example-native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { Utils } from "../helpers/Utils.sol";

contract UpgradeBase is Script, Utils {
    struct UpgradeParams {
        uint16 wormholeChainId;
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
        uint8 consistencyLevel;
        uint256 gasLimit;
    }

    function _upgradeWormholeTransceiver(address deployer_, UpgradeParams memory params_) internal {
        WormholeTransceiver implementation_ = new WormholeTransceiver(
            _getCreate3Address(deployer_, _computeSalt(deployer_, "Portal")),
            params_.wormholeCoreBridge,
            params_.wormholeRelayerAddr,
            params_.specialRelayerAddr,
            params_.consistencyLevel,
            params_.gasLimit
        );

        console2.log("WormholeTransceiver Implementation deployed at: ", address(implementation_));

        ITransceiver(_getCreate3Address(deployer_, _computeSalt(deployer_, "WormholeTransceiver"))).upgrade(
            address(implementation_)
        );
    }
}
