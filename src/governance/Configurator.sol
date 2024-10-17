// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { IPortal } from "../interfaces/IPortal.sol";

import { IConfigurator } from "./interfaces/IConfigurator.sol";

/**
 * @title  Base configurator contract.
 * @author M^0 Labs
 */
contract Configurator is IConfigurator {
    /// @inheritdoc IConfigurator
    address public immutable portal;

    /// @inheritdoc IConfigurator
    address public immutable registrar;

    /// @inheritdoc IConfigurator
    address public immutable wormholeTransceiver;

    constructor(address portal_, address wormholeTransceiver_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        if ((wormholeTransceiver = wormholeTransceiver_) == address(0)) revert ZeroWormholeTransceiver();

        registrar = IPortal(portal_).registrar();
    }

    /// @inheritdoc IConfigurator
    function execute() external virtual {}

    function _setPeerPortal(uint16 peerChainId_, bytes32 peerPortal_) internal {
        INttManager(portal).setPeer(peerChainId_, peerPortal_, 6, 0);
    }

    function _setPeerWormholeTransceiver(uint16 peerChainId_, bytes32 peerWormholeTransceiver_) internal {
        IWormholeTransceiver(wormholeTransceiver).setWormholePeer(peerChainId_, peerWormholeTransceiver_);
    }

    function _setIsWormholeRelayingEnabled(uint16 chainId_, bool isRelayingEnabled_) internal {
        IWormholeTransceiver(wormholeTransceiver).setIsWormholeRelayingEnabled(chainId_, isRelayingEnabled_);
    }

    function _setIsSpecialRelayingEnabled(uint16 chainId_, bool isRelayingEnabled_) internal {
        IWormholeTransceiver(wormholeTransceiver).setIsSpecialRelayingEnabled(chainId_, isRelayingEnabled_);
    }

    function _setIsWormholeEvmChain(uint16 chainId_, bool isEvm_) internal {
        IWormholeTransceiver(wormholeTransceiver).setIsWormholeEvmChain(chainId_, isEvm_);
    }
}
