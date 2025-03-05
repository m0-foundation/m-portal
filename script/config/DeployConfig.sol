// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Chains } from "./Chains.sol";
import { WormholeConfig } from "./WormholeConfig.sol";

struct HubDeployConfig {
    address mToken;
    address registrar;
}

struct SpokeDeployConfig {
    address hubVault;
    uint16 hubWormholeChainId;
}

/// @dev Configuration for deploying Hub and Spoke Portals
library DeployConfig {
    address internal constant M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant ETHEREUM_VAULT = 0xd7298f620B0F752Cf41BD818a16C756d9dCAA34f;
    address internal constant ETHEREUM_SEPOLIA_VAULT = 0x3dc71Be52d6D687e21FC0d4FFc196F32cacbc26d;

    function getHubDeployConfig(uint256 chainId_) internal pure returns (HubDeployConfig memory _hubDeployConfig) {
        if (chainId_ == Chains.ETHEREUM || chainId_ == Chains.ETHEREUM_SEPOLIA)
            return HubDeployConfig({ mToken: M_TOKEN, registrar: REGISTRAR });

        revert Chains.UnsupportedChain(chainId_);
    }

    function getSpokeDeployConfig(
        uint256 chainId_
    ) internal pure returns (SpokeDeployConfig memory _spokeDeployConfig) {
        if (chainId_ == Chains.ARBITRUM) return _getMainnetSpokeDeployConfig();
        if (chainId_ == Chains.OPTIMISM) return _getMainnetSpokeDeployConfig();

        if (chainId_ == Chains.ARBITRUM_SEPOLIA) return _getTestnetSpokeDeployConfig();
        if (chainId_ == Chains.OPTIMISM_SEPOLIA) return _getTestnetSpokeDeployConfig();

        revert Chains.UnsupportedChain(chainId_);
    }

    function _getMainnetSpokeDeployConfig() private pure returns (SpokeDeployConfig memory _spokeDeployConfig) {
        return SpokeDeployConfig({ hubVault: ETHEREUM_VAULT, hubWormholeChainId: Chains.WORMHOLE_ETHEREUM });
    }

    function _getTestnetSpokeDeployConfig() private pure returns (SpokeDeployConfig memory _spokeDeployConfig) {
        return
            SpokeDeployConfig({
                hubVault: ETHEREUM_SEPOLIA_VAULT,
                hubWormholeChainId: Chains.WORMHOLE_ETHEREUM_SEPOLIA
            });
    }
}
