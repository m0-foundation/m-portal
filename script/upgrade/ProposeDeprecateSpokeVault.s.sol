// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { ISpokeVault } from "../../src/interfaces/ISpokeVault.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";
import { SpokeVaultMigrator } from "../../src/SpokeVaultMigrator.sol";

import { ScriptBase } from "../ScriptBase.sol";
import { MultiSigBatchBase } from "../MultiSigBatchBase.sol";

contract ProposeDeprecateSpokeVault is ScriptBase, MultiSigBatchBase {
    address constant _SAFE_MULTISIG = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    /// @dev MUST be set to the address controlled by M0 that receives the excess M before running this script.
    address constant _EXCESS_DESTINATION = address(0);

    error ZeroExcessDestination();

    function run() public {
        if (_EXCESS_DESTINATION == address(0)) revert ZeroExcessDestination();

        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        (address mToken_, , , , address vault_, ) = _readDeployment(block.chainid);

        console.log("Deployer:            ", deployer_);
        console.log("Vault:               ", vault_);
        console.log("M Token:             ", mToken_);
        console.log("Excess Destination:  ", _EXCESS_DESTINATION);

        vm.startBroadcast(deployer_);

        address implementation_ = address(new SpokeVault(mToken_, _EXCESS_DESTINATION, _SAFE_MULTISIG));
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
