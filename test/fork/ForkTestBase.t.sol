// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { Vm } from "../../lib/forge-std/src/Test.sol";

import {
    IWormholeRelayer
} from "../../lib/native-token-transfers/evm/lib/wormhole-solidity-sdk/src/interfaces/IWormholeRelayer.sol";
import {
    WormholeSimulator
} from "../../lib/native-token-transfers/evm/lib/wormhole-solidity-sdk/src/testing/helpers/WormholeSimulator.sol";

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IWormholeTransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";
import { TransceiverStructs } from "../../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { TaskBase } from "../../script/tasks/TaskBase.sol";
import { ConfigureBase } from "../../script/configure/ConfigureBase.sol";
import { DeployBase } from "../../script/deploy/DeployBase.sol";
import { DeployConfig, SpokeDeployConfig, HubDeployConfig } from "../../script/config/DeployConfig.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../../script/config/WormholeConfig.sol";
import { PeersConfig, PeerConfig } from "../../script/config/PeersConfig.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";

contract ForkTestBase is TaskBase, ConfigureBase, DeployBase, Test {
    using WormholeConfig for uint256;
    using TypeConverter for *;

    uint256 internal constant _MAINNET_FORK_BLOCK = 21_828_330;
    uint256 internal constant _ARBITRUM_FORK_BLOCK = 305_187_338;
    uint256 internal constant _OPTIMISM_FORK_BLOCK = 131_869_592;

    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    address internal constant _MAINNET_REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant _MAINNET_M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _MAINNET_WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;
    address internal constant _MAINNET_VAULT = 0xd7298f620B0F752Cf41BD818a16C756d9dCAA34f;

    address internal constant _MAINNET_WORMHOLE_RELAYER = 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911;
    address internal constant _ARBITRUM_WORMHOLE_RELAYER = 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911;
    address internal constant _OPTIMISM_WORMHOLE_RELAYER = 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911;

    // TODO: confirm that this is the correct address.
    address internal constant _MIGRATION_ADMIN = 0x431169728D75bd02f4053435b87D15c8d1FB2C72;

    uint256 internal constant _DEVNET_GUARDIAN_PK = 0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    address internal immutable _alice = makeAddr("alice");
    address internal immutable _bob = makeAddr("bob");
    address internal immutable _mHolder = 0x3f0376da3Ae4313E7a5F1dA184BAFC716252d759;
    address internal immutable _wrappedMHolder = 0x6AaA90D689942b5eaB3D8433f2E02B32a0214390;

    TransceiverStructs.TransceiverInstruction internal _emptyTransceiverInstruction =
        TransceiverStructs.TransceiverInstruction({ index: 0, payload: "" });

    bytes internal _encodedEmptyTransceiverInstructions = new bytes(1);

    WormholeSimulator _hubGuardian;
    WormholeSimulator _arbitrumSpokeGuardian;
    WormholeSimulator _optimismSpokeGuardian;

    // Fork IDs
    uint256 internal _mainnetForkId;
    uint256 internal _arbitrumForkId;
    uint256 internal _optimismForkId;
    uint256[] internal _forkIds = new uint256[](3);

    // Mainnet - Hub
    address internal _hubPortal;
    address internal _hubWormholeTransceiver;
    address internal _hubWormholeCore;

    // Arbitrum - Spoke
    address internal _arbitrumSpokePortal;
    address internal _arbitrumSpokeWormholeTransceiver;
    address internal _arbitrumSpokeWormholeCore;
    address internal _arbitrumSpokeRegistrar;
    address internal _arbitrumSpokeMToken;

    address internal _arbitrumSpokeVault;

    address internal _arbitrumSpokeWrappedMTokenImplementation;
    address internal _arbitrumSpokeWrappedMTokenProxy;

    // Optimism - Spoke
    address internal _optimismSpokePortal;
    address internal _optimismSpokeWormholeTransceiver;
    address internal _optimismSpokeWormholeCore;
    address internal _optimismSpokeRegistrar;
    address internal _optimismSpokeMToken;

    address internal _optimismSpokeVault;

    address internal _optimismSpokeWrappedMTokenImplementation;
    address internal _optimismSpokeWrappedMTokenProxy;

    function setUp() public virtual {
        // Deploy Mainnet - Hub
        _mainnetForkId = vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: _MAINNET_FORK_BLOCK });
        _forkIds[0] = _mainnetForkId;

        deal(_DEPLOYER, 10 ether);
        deal(_alice, 10 ether);
        deal(_mHolder, 10 ether);

        vm.startPrank(_DEPLOYER);

        uint256 ethereumChainId_ = block.chainid;
        uint16 ethereumWormholeChainId_ = ethereumChainId_.toWormholeChainId();
        HubDeployConfig memory hubDeployConfig_ = DeployConfig.getHubDeployConfig(ethereumChainId_);
        WormholeTransceiverConfig memory hubTransceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(
            ethereumChainId_
        );

        _hubWormholeCore = hubTransceiverConfig_.coreBridge;
        _hubGuardian = new WormholeSimulator(_hubWormholeCore, _DEVNET_GUARDIAN_PK);

        (_hubPortal, _hubWormholeTransceiver) = _deployHubComponents(
            _DEPLOYER,
            ethereumWormholeChainId_,
            hubDeployConfig_,
            hubTransceiverConfig_
        );

        // set peers
        _configurePeers(
            _hubPortal,
            _MAINNET_M_TOKEN,
            _MAINNET_WRAPPED_M_TOKEN,
            _hubWormholeTransceiver,
            PeersConfig.getPeersConfig(ethereumChainId_)
        );

        vm.stopPrank();

        // Enable earning for the Hub Portal
        vm.mockCall(
            _MAINNET_REGISTRAR,
            abi.encodeWithSelector(IRegistrarLike.listContains.selector, bytes32("earners"), _hubPortal),
            abi.encode(true)
        );

        IHubPortal(_hubPortal).enableEarning();

        // Deploy Arbitrum - Spoke
        _arbitrumForkId = vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: _ARBITRUM_FORK_BLOCK });
        _forkIds[1] = _arbitrumForkId;

        deal(_DEPLOYER, 10 ether);
        deal(_alice, 10 ether);
        deal(_mHolder, 10 ether);

        vm.startPrank(_DEPLOYER);

        uint256 arbitrumChainId_ = block.chainid;
        uint16 arbitrumWormholeChainId_ = arbitrumChainId_.toWormholeChainId();
        SpokeDeployConfig memory arbitrumSpokeDeployConfig_ = DeployConfig.getSpokeDeployConfig(arbitrumChainId_);
        WormholeTransceiverConfig memory arbitrumSpokeTransceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(
            arbitrumChainId_
        );

        _arbitrumSpokeWormholeCore = arbitrumSpokeTransceiverConfig_.coreBridge;
        _arbitrumSpokeGuardian = new WormholeSimulator(_arbitrumSpokeWormholeCore, _DEVNET_GUARDIAN_PK);

        (
            _arbitrumSpokePortal,
            _arbitrumSpokeWormholeTransceiver,
            _arbitrumSpokeRegistrar,
            _arbitrumSpokeMToken
        ) = _deploySpokeComponents(_DEPLOYER, arbitrumWormholeChainId_, arbitrumSpokeTransceiverConfig_, _burnNonces);

        (, _arbitrumSpokeVault) = _deploySpokeVault(
            _DEPLOYER,
            _arbitrumSpokePortal,
            arbitrumSpokeDeployConfig_.hubVault,
            arbitrumSpokeDeployConfig_.hubWormholeChainId,
            _MIGRATION_ADMIN
        );

        (_arbitrumSpokeWrappedMTokenImplementation, _arbitrumSpokeWrappedMTokenProxy) = _deploySpokeWrappedMToken(
            _DEPLOYER,
            _arbitrumSpokeMToken,
            _arbitrumSpokeRegistrar,
            _arbitrumSpokeVault,
            _MIGRATION_ADMIN,
            _burnNonces
        );

        // set peers
        _configurePeers(
            _arbitrumSpokePortal,
            _arbitrumSpokeMToken,
            _arbitrumSpokeWrappedMTokenProxy,
            _arbitrumSpokeWormholeTransceiver,
            PeersConfig.getPeersConfig(arbitrumChainId_)
        );

        vm.stopPrank();

        // Deploy Optimism - Spoke
        _optimismForkId = vm.createSelectFork({ urlOrAlias: "optimism", blockNumber: _OPTIMISM_FORK_BLOCK });
        _forkIds[2] = _optimismForkId;

        deal(_DEPLOYER, 10 ether);
        deal(_alice, 10 ether);
        deal(_mHolder, 10 ether);

        vm.startPrank(_DEPLOYER);

        uint256 optimismChainId_ = block.chainid;
        uint16 optimismWormholeChainId_ = optimismChainId_.toWormholeChainId();
        SpokeDeployConfig memory optimismSpokeDeployConfig_ = DeployConfig.getSpokeDeployConfig(optimismChainId_);
        WormholeTransceiverConfig memory optimismSpokeTransceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(
            optimismChainId_
        );

        _optimismSpokeWormholeCore = optimismSpokeTransceiverConfig_.coreBridge;
        _optimismSpokeGuardian = new WormholeSimulator(_optimismSpokeWormholeCore, _DEVNET_GUARDIAN_PK);

        (
            _optimismSpokePortal,
            _optimismSpokeWormholeTransceiver,
            _optimismSpokeRegistrar,
            _optimismSpokeMToken
        ) = _deploySpokeComponents(_DEPLOYER, optimismWormholeChainId_, optimismSpokeTransceiverConfig_, _burnNonces);

        (, _optimismSpokeVault) = _deploySpokeVault(
            _DEPLOYER,
            _optimismSpokePortal,
            optimismSpokeDeployConfig_.hubVault,
            optimismSpokeDeployConfig_.hubWormholeChainId,
            _MIGRATION_ADMIN
        );

        (_optimismSpokeWrappedMTokenImplementation, _optimismSpokeWrappedMTokenProxy) = _deploySpokeWrappedMToken(
            _DEPLOYER,
            _optimismSpokeMToken,
            _optimismSpokeRegistrar,
            _optimismSpokeVault,
            _MIGRATION_ADMIN,
            _burnNonces
        );

        // set peers
        _configurePeers(
            _optimismSpokePortal,
            _optimismSpokeMToken,
            _optimismSpokeWrappedMTokenProxy,
            _optimismSpokeWormholeTransceiver,
            PeersConfig.getPeersConfig(optimismChainId_)
        );

        vm.stopPrank();
    }

    function _burnNonces(address account_, uint64 /**  startingNonce_ */, uint64 targetNonce_) internal {
        vm.setNonce(account_, targetNonce_);
    }

    function _signMessage(
        WormholeSimulator guardian_,
        uint16 wormholeChainId_
    ) internal returns (bytes memory signedMessage_) {
        Vm.Log[] memory messages_ = guardian_.fetchWormholeMessageFromLog(vm.getRecordedLogs());
        return guardian_.fetchSignedMessageFromLogs(messages_[0], wormholeChainId_);
    }

    function _deliverMessage(address wormholeRelayer_, bytes memory signedMessage_) internal {
        // TODO: compute delivery budget
        vm.deal(wormholeRelayer_, 1 ether);

        IWormholeRelayer(wormholeRelayer_).deliver{ value: 1 ether }(
            new bytes[](0),
            signedMessage_,
            payable(address(this)),
            new bytes(0)
        );
    }

    // Fallback function to receive refund from Wormhole relayer
    fallback() external payable {}
    receive() external payable {}
}
