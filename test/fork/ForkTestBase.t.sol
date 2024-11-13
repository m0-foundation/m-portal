// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { Vm } from "../../lib/forge-std/src/Test.sol";

import {
    IWormholeRelayer
} from "../../lib/example-native-token-transfers/evm/lib/wormhole-solidity-sdk/src/interfaces/IWormholeRelayer.sol";
import {
    WormholeSimulator
} from "../../lib/example-native-token-transfers/evm/lib/wormhole-solidity-sdk/src/testing/helpers/WormholeSimulator.sol";

import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";
import { TransceiverStructs } from "../../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";

import { CastBase } from "../../script/cast/CastBase.sol";
import { ConfigureBase } from "../../script/configure/ConfigureBase.sol";
import { DeployBase } from "../../script/deploy/DeployBase.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";

contract ForkTestBase is CastBase, ConfigureBase, DeployBase, Test {
    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    // TODO: confirm that this is the correct address.
    address internal constant _MIGRATION_ADMIN = 0x431169728D75bd02f4053435b87D15c8d1FB2C72;

    uint256 internal constant _DEVNET_GUARDIAN_PK = 0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    address internal immutable _alice = makeAddr("alice");
    address internal immutable _bob = makeAddr("bob");
    address internal immutable _mHolder = 0x3f0376da3Ae4313E7a5F1dA184BAFC716252d759;

    TransceiverStructs.TransceiverInstruction internal _emptyTransceiverInstruction =
        TransceiverStructs.TransceiverInstruction({ index: 0, payload: "" });

    bytes internal _encodedEmptyTransceiverInstructions = new bytes(1);

    WormholeSimulator _hubGuardian;
    WormholeSimulator _baseSpokeGuardian;
    WormholeSimulator _optimismSpokeGuardian;

    // Fork IDs
    uint256 internal _mainnetForkId;
    uint256 internal _baseForkId;
    uint256 internal _optimismForkId;
    uint256[] internal _forkIds = new uint256[](3);

    // Mainnet - Hub
    address internal _hubPortal;
    address internal _hubWormholeTransceiver;
    address internal _hubWormholeCore;

    // Base - Spoke
    address internal _baseSpokePortal;
    address internal _baseSpokeWormholeTransceiver;
    address internal _baseSpokeWormholeCore;
    address internal _baseSpokeRegistrar;
    address internal _baseSpokeMToken;

    address internal _baseSpokeVault;

    address internal _baseSpokeSmartMTokenEarnerManagerImplementation;
    address internal _baseSpokeSmartMTokenEarnerManagerProxy;
    address internal _baseSpokeSmartMTokenImplementation;
    address internal _baseSpokeSmartMTokenProxy;

    // Optimism - Spoke
    address internal _optimismSpokePortal;
    address internal _optimismSpokeWormholeTransceiver;
    address internal _optimismSpokeWormholeCore;
    address internal _optimismSpokeRegistrar;
    address internal _optimismSpokeMToken;

    address internal _optimismSpokeVault;

    address internal _optimismSpokeSmartMTokenEarnerManagerImplementation;
    address internal _optimismSpokeSmartMTokenEarnerManagerProxy;
    address internal _optimismSpokeSmartMTokenImplementation;
    address internal _optimismSpokeSmartMTokenProxy;

    function setUp() public virtual {
        // Deploy Mainnet - Hub
        _mainnetForkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
        _forkIds[0] = _mainnetForkId;

        deal(_DEPLOYER, 10 ether);
        deal(_alice, 10 ether);
        deal(_mHolder, 10 ether);

        vm.startPrank(_DEPLOYER);

        string memory configPath_ = "test/fork/fixtures/deploy-config.json";

        HubConfiguration memory hubConfig_ = _loadHubConfig(configPath_, block.chainid);

        _hubWormholeCore = hubConfig_.wormhole.coreBridge;
        _hubGuardian = new WormholeSimulator(_hubWormholeCore, _DEVNET_GUARDIAN_PK);

        (_hubPortal, _hubWormholeTransceiver) = _deployHubComponents(_DEPLOYER, hubConfig_);

        vm.stopPrank();

        // Enable earning for the Hub Portal
        vm.mockCall(
            _MAINNET_REGISTRAR,
            abi.encodeWithSelector(IRegistrarLike.listContains.selector, bytes32("earners"), _hubPortal),
            abi.encode(true)
        );

        IHubPortal(_hubPortal).enableEarning();

        // Deploy Base - Spoke
        _baseForkId = vm.createSelectFork(vm.rpcUrl("base"));
        _forkIds[1] = _baseForkId;

        deal(_DEPLOYER, 10 ether);
        deal(_alice, 10 ether);
        deal(_mHolder, 10 ether);

        vm.startPrank(_DEPLOYER);

        SpokeConfiguration memory baseSpokeConfig_ = _loadSpokeConfig(configPath_, block.chainid);

        _baseSpokeWormholeCore = baseSpokeConfig_.wormhole.coreBridge;
        _baseSpokeGuardian = new WormholeSimulator(baseSpokeConfig_.wormhole.coreBridge, _DEVNET_GUARDIAN_PK);

        (
            _baseSpokePortal,
            _baseSpokeWormholeTransceiver,
            _baseSpokeRegistrar,
            _baseSpokeMToken
        ) = _deploySpokeComponents(_DEPLOYER, baseSpokeConfig_, _burnNonces);

        (, _baseSpokeVault) = _deploySpokeVault(
            _DEPLOYER,
            _baseSpokePortal,
            baseSpokeConfig_.hubVault,
            baseSpokeConfig_.hubVaultWormholechainId,
            _MIGRATION_ADMIN
        );

        (
            _baseSpokeSmartMTokenEarnerManagerImplementation,
            _baseSpokeSmartMTokenEarnerManagerProxy,
            _baseSpokeSmartMTokenImplementation,
            _baseSpokeSmartMTokenProxy
        ) = _deploySpokeSmartMToken(
            _DEPLOYER,
            _baseSpokeMToken,
            _baseSpokeRegistrar,
            _baseSpokeVault,
            _MIGRATION_ADMIN,
            _burnNonces
        );

        vm.stopPrank();

        // Deploy Optimism - Spoke
        _optimismForkId = vm.createSelectFork(vm.rpcUrl("optimism"));
        _forkIds[2] = _optimismForkId;

        deal(_DEPLOYER, 10 ether);
        deal(_alice, 10 ether);
        deal(_mHolder, 10 ether);

        vm.startPrank(_DEPLOYER);

        SpokeConfiguration memory optimismSpokeConfig_ = _loadSpokeConfig(configPath_, block.chainid);

        _optimismSpokeWormholeCore = optimismSpokeConfig_.wormhole.coreBridge;
        _optimismSpokeGuardian = new WormholeSimulator(optimismSpokeConfig_.wormhole.coreBridge, _DEVNET_GUARDIAN_PK);

        (
            _optimismSpokePortal,
            _optimismSpokeWormholeTransceiver,
            _optimismSpokeRegistrar,
            _optimismSpokeMToken
        ) = _deploySpokeComponents(_DEPLOYER, optimismSpokeConfig_, _burnNonces);

        (, _optimismSpokeVault) = _deploySpokeVault(
            _DEPLOYER,
            _optimismSpokePortal,
            optimismSpokeConfig_.hubVault,
            optimismSpokeConfig_.hubVaultWormholechainId,
            _MIGRATION_ADMIN
        );

        (
            _optimismSpokeSmartMTokenEarnerManagerImplementation,
            _optimismSpokeSmartMTokenEarnerManagerProxy,
            _optimismSpokeSmartMTokenImplementation,
            _optimismSpokeSmartMTokenProxy
        ) = _deploySpokeSmartMToken(
            _DEPLOYER,
            _optimismSpokeMToken,
            _optimismSpokeRegistrar,
            _optimismSpokeVault,
            _MIGRATION_ADMIN,
            _burnNonces
        );

        vm.stopPrank();
    }

    function _configurePortals() internal {
        for (uint256 i_; i_ < _forkIds.length; ++i_) {
            vm.selectFork(_forkIds[i_]);
            vm.startPrank(_DEPLOYER);

            ChainConfig[] memory chainsConfig_ = _loadChainConfig(
                "test/fork/fixtures/configure-config.json",
                block.chainid
            );

            uint256 chainsConfigLength_ = chainsConfig_.length;

            for (uint256 j_; j_ < chainsConfigLength_; ++j_) {
                ChainConfig memory chainConfig_ = chainsConfig_[j_];

                if (chainConfig_.chainId == block.chainid) {
                    _configureWormholeTransceiver(
                        IWormholeTransceiver(chainConfig_.wormholeTransceiver),
                        chainsConfig_,
                        chainConfig_.wormholeChainId
                    );

                    _configurePortal(INttManager(chainConfig_.portal), chainsConfig_, chainConfig_.wormholeChainId);
                }
            }

            vm.stopPrank();
        }
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
