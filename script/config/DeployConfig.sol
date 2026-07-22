// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Chains } from "./Chains.sol";
import { WormholeConfig } from "./WormholeConfig.sol";

struct HubDeployConfig {
    address mToken;
    address registrar;
}

/// @dev Configuration for deploying Hub and Spoke Portals
library DeployConfig {
    address internal constant M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;

    function getHubDeployConfig(uint256 chainId_) internal pure returns (HubDeployConfig memory _hubDeployConfig) {
        if (chainId_ == Chains.ETHEREUM || chainId_ == Chains.ETHEREUM_SEPOLIA)
            return HubDeployConfig({ mToken: M_TOKEN, registrar: REGISTRAR });

        revert Chains.UnsupportedChain(chainId_);
    }
}
