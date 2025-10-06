// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { ITransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import {
    IAccessControl
} from "../../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { ISwapFacilityLike } from "../../src/interfaces/ISwapFacilityLike.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";
import { UpgradeBase } from "./UpgradeBase.sol";
import { MultiSigBatchBase } from "../MultiSigBatchBase.sol";

contract ProposeUpgradeSpokePortal is UpgradeBase, MultiSigBatchBase {
    using WormholeConfig for uint256;

    address constant _SAFE_MULTISIG = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        uint256 chainId_ = block.chainid;
        (address mToken_, address portal_, address registrar_, address transceiver_, , ) = _readDeployment(chainId_);
        WormholeTransceiverConfig memory transceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(chainId_);

        vm.startBroadcast(deployer_);

        address newTransceiverImplementation_ = _deployWormholeTransceiver(portal_, transceiverConfig_);
        address newPortalImplementation_ = _deploySpokePortalImplementation(
            mToken_,
            registrar_,
            _SWAP_FACILITY,
            chainId_.toWormholeChainId()
        );

        vm.stopBroadcast();

        // Propose SpokePortal and WormholeTransceiver upgrades via Safe
        _addToBatch(portal_, abi.encodeCall(IManagerBase.upgrade, (newPortalImplementation_)));
        _addToBatch(transceiver_, abi.encodeCall(ITransceiver.upgrade, (newTransceiverImplementation_)));

        _simulateBatch(_SAFE_MULTISIG);
        _proposeBatch(_SAFE_MULTISIG, deployer_);
    }
}
