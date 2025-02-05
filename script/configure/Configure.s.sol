// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IWormholeTransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { ConfigureBase } from "./ConfigureBase.sol";

contract Configure is ConfigureBase {
    function run() external {
        address caller_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        ChainConfig[] memory chainsConfig_ = _loadChainConfig(vm.envString("CONFIG"), block.chainid);
        uint256 chainsConfigLength_ = chainsConfig_.length;

        vm.startBroadcast(caller_);

        for (uint256 i_; i_ < chainsConfigLength_; ++i_) {
            ChainConfig memory chainConfig_ = chainsConfig_[i_];

            if (chainConfig_.chainId == block.chainid) {
                _configureWormholeTransceiver(
                    IWormholeTransceiver(chainConfig_.transceiver),
                    chainsConfig_,
                    chainConfig_.wormholeChainId
                );

                _configurePortal(chainConfig_.portal, chainsConfig_, chainConfig_);
            }
        }

        vm.stopBroadcast();
    }
}
