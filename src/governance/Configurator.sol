// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

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

    constructor(address portal_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();

        registrar = IPortal(portal_).registrar();
    }

    /// @inheritdoc IConfigurator
    function execute() external virtual {}

    function _setPeerPortal(uint16 peerChainId_, bytes32 peerPortal_) internal {
        portal.delegatecall(
            abi.encodeWithSignature("setPeer(uint16,bytes32,uint8,uint256)", peerChainId_, peerPortal_, 6, 0)
        );
    }

    function _setPeerWormholeTransceiver(
        address wormholeTransceiver_,
        uint16 peerChainId_,
        bytes32 peerWormholeTransceiver_
    ) internal {
        wormholeTransceiver_.delegatecall(
            abi.encodeWithSignature("setWormholePeer(uint16,bytes32)", peerChainId_, peerWormholeTransceiver_)
        );
    }

    function _setIsWormholeRelayingEnabled(
        address wormholeTransceiver_,
        uint16 chainId_,
        bool isRelayingEnabled_
    ) internal {
        wormholeTransceiver_.delegatecall(
            abi.encodeWithSignature("setIsWormholeRelayingEnabled(uint16,bool)", chainId_, isRelayingEnabled_)
        );
    }

    function _setIsSpecialRelayingEnabled(
        address wormholeTransceiver_,
        uint16 chainId_,
        bool isRelayingEnabled_
    ) internal {
        wormholeTransceiver_.delegatecall(
            abi.encodeWithSignature("setIsSpecialRelayingEnabled(uint16,bool)", chainId_, isRelayingEnabled_)
        );
    }

    function _setIsWormholeEvmChain(address wormholeTransceiver_, uint16 chainId_, bool isEvm_) internal {
        wormholeTransceiver_.delegatecall(
            abi.encodeWithSignature("setIsWormholeEvmChain(uint16,bool)", chainId_, isEvm_)
        );
    }
}
