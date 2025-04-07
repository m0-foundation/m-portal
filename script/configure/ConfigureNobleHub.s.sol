// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Chains } from "../config/Chains.sol";
import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";
import { ConfigureBase } from "./ConfigureBase.sol";

contract ConfigureNobleHub is ConfigureBase {
    // Noble Portal
    address internal constant _NOBLE_PORTAL = 0x83Ae82Bd4054e815fB7B189C39D9CE670369ea16;
    address internal constant _NOBLE_TRANSCEIVER = 0xc7Dd372c39E38BF11451ab4A8427B4Ae38ceF644;

    function run() external {
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 chainId_ = block.chainid;

        uint16[] memory peerChainIds_ = new uint16[](1);
        peerChainIds_[0] = Chains.WORMHOLE_NOBLE;
        PeerConfig[] memory peers_ = PeersConfig.getPeersConfig(peerChainIds_);

        (address mToken_, , , , , address wrappedM_) = _readDeployment(chainId_);

        vm.startBroadcast(signer_);

        _configurePeers(_NOBLE_PORTAL, mToken_, wrappedM_, _NOBLE_TRANSCEIVER, peers_);

        vm.stopBroadcast();
    }
}
