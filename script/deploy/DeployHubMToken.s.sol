// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Script, console2 as console } from "../../lib/forge-std/src/Script.sol";
import { MToken } from "../../lib/hub-protocol/src/MToken.sol";
import { WrappedMToken } from "../../lib/hub-wrapped-m-token/src/WrappedMToken.sol";
import { Proxy } from "../../lib/hub-wrapped-m-token/src/Proxy.sol";
import { AdminControlledRegistrar } from "../../test/mocks/registrar/AdminControlledRegistrar.sol";

/// @dev Deploys Admin-controlled Registrar, $M token and Wrapped $M token on Sepolia to simplify multi-chain testing
contract DeployHubMToken is Script {
    uint256 _INITIAL_SUPPLY = 1_000_000e6;

    function run() external {
        uint256 deployerPrivateKey_ = vm.envUint("DEV_PRIVATE_KEY");
        address deployer_ = vm.addr(deployerPrivateKey_);

        vm.startBroadcast(deployerPrivateKey_);

        address registrar_ = address(new AdminControlledRegistrar(deployer_));
        MToken mToken_ = new MToken(registrar_, deployer_);
        mToken_.mint(deployer_, _INITIAL_SUPPLY);

        // Wrapped M
        address wrappedMImplementation_ = address(new WrappedMToken(address(mToken_), deployer_));
        address wrappedMProxy_ = address(new Proxy(wrappedMImplementation_));

        vm.stopBroadcast();

        console.log("Chain Id:                ", block.chainid);
        console.log("Deployer/Minter Gateway: ", deployer_);
        console.log("Registrar:               ", registrar_);
        console.log("M Token:                 ", address(mToken_));
        console.log("Wrapped M Proxy:         ", wrappedMProxy_);
        console.log("Wrapped M implementation:", wrappedMImplementation_);
    }
}
