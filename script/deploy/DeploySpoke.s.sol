// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { DeployBase } from "./DeployBase.sol";

contract DeploySpoke is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        address migrationAdmin_ = vm.envAddress("MIGRATION_ADMIN");

        vm.startBroadcast(deployer_);

        SpokeConfiguration memory spokeConfig_ = _loadSpokeConfig(vm.envString("CONFIG"), block.chainid);
        (address spokePortal_, , address spokeRegistrar_, address spokeMToken_) = _deploySpokeComponents(
            deployer_,
            spokeConfig_,
            _burnNonces
        );

        (, address spokeVault_) = _deploySpokeVault(
            deployer_,
            spokePortal_,
            spokeConfig_.hubVault,
            spokeConfig_.hubVaultWormholechainId,
            migrationAdmin_
        );

        _deploySpokeWrappedMToken(deployer_, spokeMToken_, spokeRegistrar_, spokeVault_, migrationAdmin_, _burnNonces);

        vm.stopBroadcast();
    }

    function _burnNonces(address account_, uint64 startingNonce_, uint64 targetNonce_) internal {
        for (uint64 i_; i_ < targetNonce_ - startingNonce_; ++i_) {
            payable(account_).transfer(0);
        }
    }
}
