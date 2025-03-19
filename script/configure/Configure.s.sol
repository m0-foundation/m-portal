// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";
import { WormholeConfig } from "../config/WormholeConfig.sol";
import { ConfigureBase } from "./ConfigureBase.sol";

contract Configure is ConfigureBase {
    using WormholeConfig for uint256;

    function run(uint16[] memory peerChainIds_) external {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 chainId_ = block.chainid;
        uint16 wormholeChainId_ = chainId_.toWormholeChainId();
        PeerConfig[] memory peers_ = peerChainIds_.length > 0
            ? PeersConfig.getPeersConfig(peerChainIds_) // specific peers
            : PeersConfig.getPeersConfig(wormholeChainId_); // all peers

        (address mToken_, address portal_, , address transceiver_, , address wrappedM_) = _readDeployment(chainId_);

        vm.startBroadcast(signer_);

        _configurePeers(portal_, mToken_, wrappedM_, transceiver_, peers_);

        vm.stopBroadcast();
    }
}
