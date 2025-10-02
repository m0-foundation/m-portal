// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { WormholeConfig } from "../config/WormholeConfig.sol";
import { UpgradeBase } from "./UpgradeBase.sol";

contract UpgradeHubPortal is UpgradeBase {
    using WormholeConfig for uint256;

    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint256 chainId_ = block.chainid;
        (address mToken_, address portal_, address registrar_, , , ) = _readDeployment(chainId_);

        vm.startBroadcast(deployer_);

        _upgradeHubPortal(portal_, mToken_, registrar_, _SWAP_FACILITY, chainId_.toWormholeChainId());

        vm.stopBroadcast();
    }
}
