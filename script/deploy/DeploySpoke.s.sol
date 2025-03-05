// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { DeployBase } from "./DeployBase.sol";
import { DeployConfig, SpokeDeployConfig } from "../config/DeployConfig.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract DeploySpoke is DeployBase {
    using WormholeConfig for uint256;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address migrationAdmin_ = vm.envAddress("MIGRATION_ADMIN");

        uint256 chainId_ = block.chainid;
        SpokeDeployConfig memory spokeDeployConfig_ = DeployConfig.getSpokeDeployConfig(chainId_);
        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);

        vm.startBroadcast(deployer_);

        (address portal_, address transceiver_, address registrar_, address mToken_) = _deploySpokeComponents(
            deployer_,
            chainId_.toWormholeChainId(),
            transceiverConfig_,
            _burnNonces
        );

        (, address vault_) = _deploySpokeVault(
            deployer_,
            portal_,
            spokeDeployConfig_.hubVault,
            spokeDeployConfig_.hubWormholeChainId,
            migrationAdmin_
        );

        (, address wrappedMToken_) = _deploySpokeWrappedMToken(
            deployer_,
            mToken_,
            registrar_,
            vault_,
            migrationAdmin_,
            _burnNonces
        );

        vm.stopBroadcast();

        console.log("M Token:      ", mToken_);
        console.log("Portal:       ", portal_);
        console.log("Registrar:    ", registrar_);
        console.log("Transceiver:  ", transceiver_);
        console.log("Vault:        ", vault_);
        console.log("WrappedM Token", wrappedMToken_);

        _serializeSpokeDeployments(chainId_, mToken_, registrar_, portal_, transceiver_, vault_, wrappedMToken_);
    }

    function _burnNonces(address account_, uint64 startingNonce_, uint64 targetNonce_) internal {
        for (uint64 i_; i_ < targetNonce_ - startingNonce_; ++i_) {
            payable(account_).transfer(0);
        }
    }

    function _serializeSpokeDeployments(
        uint256 chainId_,
        address mToken_,
        address registrar_,
        address portal_,
        address transceiver_,
        address vault_,
        address wrappedMToken_
    ) internal {
        string memory root = "";

        vm.serializeAddress(root, "m_token", mToken_);
        vm.serializeAddress(root, "portal", portal_);
        vm.serializeAddress(root, "registrar", registrar_);
        vm.serializeAddress(root, "transceiver", transceiver_);
        vm.serializeAddress(root, "vault", vault_);
        vm.writeJson(vm.serializeAddress(root, "wrapped_m_token", wrappedMToken_), _deployOutputPath(chainId_));
    }
}
