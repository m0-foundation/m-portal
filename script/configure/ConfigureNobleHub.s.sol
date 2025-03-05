// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";
import { ConfigureBase } from "./ConfigureBase.sol";

contract ConfigureNobleHub is ConfigureBase {
    // Noble Portal
    address internal constant _NOBLE_PORTAL = 0x83Ae82Bd4054e815fB7B189C39D9CE670369ea16;
    address internal constant _NOBLE_TRANSCEIVER = 0xc7Dd372c39E38BF11451ab4A8427B4Ae38ceF644;

    function run(uint256[] memory peerChainIds_) external {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 chainId_ = block.chainid;

        PeerConfig[] memory peers_ = peerChainIds_.length > 0
            ? PeersConfig.getPeersConfig(peerChainIds_) // specific peers
            : PeersConfig.getPeersConfig(chainId_); // all peers

        (address mToken_, , , , , address wrappedM_) = _readDeployment(chainId_);

        vm.startBroadcast(signer_);

        _configurePeers(_NOBLE_PORTAL, mToken_, wrappedM_, _NOBLE_TRANSCEIVER, peers_);

        vm.stopBroadcast();
    }
}
