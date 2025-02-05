// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { DeployBase } from "./DeployBase.sol";

contract DeploySpoke is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address migrationAdmin_ = vm.envAddress("MIGRATION_ADMIN");

        vm.startBroadcast(deployer_);

        SpokeConfiguration memory spokeConfig_ = _loadSpokeConfig(vm.envString("CONFIG"), block.chainid);
        (address portal_, address transceiver_, address registrar_, address mToken_) = _deploySpokeComponents(
            deployer_,
            spokeConfig_,
            _burnNonces
        );

        (, address vault_) = _deploySpokeVault(
            deployer_,
            portal_,
            spokeConfig_.hubVault,
            spokeConfig_.hubWormholeChainId,
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

        _serializeSpokeDeployments(mToken_, registrar_, portal_, transceiver_, vault_, wrappedMToken_);
    }

    function _burnNonces(address account_, uint64 startingNonce_, uint64 targetNonce_) internal {
        for (uint64 i_; i_ < targetNonce_ - startingNonce_; ++i_) {
            payable(account_).transfer(0);
        }
    }

    function _serializeSpokeDeployments(
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
        vm.writeJson(vm.serializeAddress(root, "wrapped_m_token", wrappedMToken_), _deployOutputPath());
    }
}
