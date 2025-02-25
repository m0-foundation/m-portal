// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";
import { ConfigureBase } from "./ConfigureBase.sol";

contract Configure is ConfigureBase {
    function run(uint256[] memory peerChainIds_) external {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 chainId_ = block.chainid;
        PeerConfig[] memory peers_ = peerChainIds_.length > 0
            ? PeersConfig.getPeersConfig(peerChainIds_) // specific peers
            : PeersConfig.getPeersConfig(chainId_); // all peers

        (address mToken_, address portal_, , address transceiver_, , address wrappedM_) = _readDeployment(chainId_);

        vm.startBroadcast(signer_);

        _configurePeers(portal_, mToken_, wrappedM_, transceiver_, peers_);

        vm.stopBroadcast();
    }
}
