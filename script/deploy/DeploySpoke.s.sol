// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { DeployBase } from "./DeployBase.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract DeploySpoke is DeployBase {
    using WormholeConfig for uint256;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address migrationAdmin_ = vm.envAddress("MIGRATION_ADMIN");
        address excessDestination_ = vm.envAddress("EXCESS_DESTINATION");

        console.log("Deployer              ", deployer_);
        console.log("MigrationAdmin        ", migrationAdmin_);
        console.log("ExcessDestination     ", excessDestination_);

        uint256 chainId_ = block.chainid;
        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);

        vm.startBroadcast(deployer_);

        (address portal_, address transceiver_, address registrar_, address mToken_) = _deploySpokeComponents(
            deployer_,
            chainId_.toWormholeChainId(),
            _SWAP_FACILITY,
            transceiverConfig_,
            migrationAdmin_
        );

        (, address executorEntryPoint_) = _deployExecutorEntryPoint(
            deployer_,
            migrationAdmin_,
            transceiverConfig_,
            portal_
        );

        (, address vault_) = _deploySpokeVault(deployer_, mToken_, excessDestination_, migrationAdmin_);

        (, address wrappedMToken_) = _deploySpokeWrappedMToken(deployer_, mToken_, registrar_, vault_, migrationAdmin_);

        vm.stopBroadcast();

        console.log("M Token:              ", mToken_);
        console.log("Portal:               ", portal_);
        console.log("Registrar:            ", registrar_);
        console.log("Transceiver:          ", transceiver_);
        console.log("Vault:                ", vault_);
        console.log("WrappedM Token:       ", wrappedMToken_);
        console.log("Executor Entry Point: ", executorEntryPoint_);

        _serializeSpokeDeployments(
            chainId_,
            executorEntryPoint_,
            mToken_,
            registrar_,
            portal_,
            transceiver_,
            vault_,
            wrappedMToken_
        );
    }

    function _serializeSpokeDeployments(
        uint256 chainId_,
        address executorEntryPoint_,
        address mToken_,
        address registrar_,
        address portal_,
        address transceiver_,
        address vault_,
        address wrappedMToken_
    ) internal {
        string memory root = "";

        vm.serializeAddress(root, "executor_entry_point", executorEntryPoint_);
        vm.serializeAddress(root, "m_token", mToken_);
        vm.serializeAddress(root, "portal", portal_);
        vm.serializeAddress(root, "registrar", registrar_);
        vm.serializeAddress(root, "transceiver", transceiver_);
        vm.serializeAddress(root, "vault", vault_);
        vm.writeJson(vm.serializeAddress(root, "wrapped_m_token", wrappedMToken_), _deployOutputPath(chainId_));
    }
}
