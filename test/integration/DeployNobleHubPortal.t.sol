// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import { DeployBase } from "../../script/deploy/DeployBase.sol";
import { DeployConfig, HubDeployConfig } from "../../script/config/DeployConfig.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../../script/config/WormholeConfig.sol";

import { IHubPortal } from "../../src/interfaces/IHubPortal.sol";
import { IMTokenLike } from "../../src/interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";

contract DeployNobleHubPortalTests is Test, DeployBase {
    using WormholeConfig for uint256;

    uint256 internal constant _MAINNET_FORK_BLOCK = 21_926_632;

    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    address internal constant _EXPECTED_NOBLE_PORTAL_ADDRESS = 0x83Ae82Bd4054e815fB7B189C39D9CE670369ea16;
    address internal constant _EXPECTED_NOBLE_TRANSCEIVER_ADDRESS = 0xc7Dd372c39E38BF11451ab4A8427B4Ae38ceF644;

    function testIntegration_deployNobleHub() external {
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: _MAINNET_FORK_BLOCK });

        deal(_DEPLOYER, 1 ether);

        vm.startPrank(_DEPLOYER);

        HubDeployConfig memory hubDeployConfig_ = DeployConfig.getHubDeployConfig(block.chainid);
        WormholeTransceiverConfig memory hubTransceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(
            block.chainid
        );

        (address hubPortal_, address transceiver_) = _deployNobleHubComponents(
            _DEPLOYER,
            block.chainid.toWormholeChainId(),
            _SWAP_FACILITY,
            hubDeployConfig_,
            hubTransceiverConfig_
        );

        assertEq(hubPortal_, _EXPECTED_NOBLE_PORTAL_ADDRESS);
        assertEq(transceiver_, _EXPECTED_NOBLE_TRANSCEIVER_ADDRESS);

        IMTokenLike mToken_ = IMTokenLike(IHubPortal(hubPortal_).mToken());

        IHubPortal(hubPortal_).enableEarning();

        assertTrue(mToken_.isEarning(hubPortal_));
        assertEq(IHubPortal(hubPortal_).currentIndex(), mToken_.currentIndex());
    }
}
