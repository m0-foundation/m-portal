// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";
import { SpokeVaultMigrator } from "../../src/SpokeVaultMigrator.sol";

import { ScriptBase } from "../ScriptBase.sol";
import { MultiSigBatchBase } from "../MultiSigBatchBase.sol";

contract ProposeDeprecateSpokeVault is ScriptBase, MultiSigBatchBase {
    /// @dev The current migration admin of the deployed Vaults, and the only account allowed to migrate them.
    address constant _SAFE_MULTISIG = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    /// @dev The migration admin of the deprecated implementation, allowed to migrate the Vaults from now on.
    address constant _MIGRATION_ADMIN = 0x48670B46380FE1645f0E3e821a25162dB2589D19;

    error ZeroExcessDestination();

    function run() public {
        address excessDestination_ = vm.envAddress("EXCESS_DESTINATION");

        if (excessDestination_ == address(0)) revert ZeroExcessDestination();

        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        (address mToken_, , , , address vault_, ) = _readDeployment(block.chainid);

        console.log("Deployer:            ", deployer_);
        console.log("Vault:               ", vault_);
        console.log("M Token:             ", mToken_);
        console.log("Excess Destination:  ", excessDestination_);
        console.log("Migration Admin:     ", _MIGRATION_ADMIN);

        vm.startBroadcast(deployer_);

        address implementation_ = address(new SpokeVault(mToken_, excessDestination_, _MIGRATION_ADMIN));
        address migrator_ = address(new SpokeVaultMigrator(implementation_));

        vm.stopBroadcast();

        console.log("New Implementation:  ", implementation_);
        console.log("Migrator:            ", migrator_);

        _addToBatch(vault_, abi.encodeCall(ISpokeVault.migrate, (migrator_)));
        _addToBatch(vault_, abi.encodeCall(ISpokeVault.transferExcessM, ()));

        _simulateBatch(_SAFE_MULTISIG);
        _proposeBatch(_SAFE_MULTISIG, deployer_);
    }
}
