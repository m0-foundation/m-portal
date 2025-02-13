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

contract DeployIntegrationTests is Test, DeployBase {
    using WormholeConfig for uint256;

    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    address internal constant _EXPECTED_HUB_PORTAL_ADDRESS = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;

    address internal constant _REGISTRAR = 0xB024aC5a7c6bC92fbACc8C3387E628a07e1Da016;
    address internal constant _STANDARD_GOVERNOR = 0xB024aC5a7c6bC92fbACc8C3387E628a07e1Da016;

    function testIntegration_deployHub() external {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        deal(_DEPLOYER, 10 ether);

        vm.prank(_STANDARD_GOVERNOR);
        IRegistrarLike(_REGISTRAR).addToList("earners", _EXPECTED_HUB_PORTAL_ADDRESS);

        vm.startPrank(_DEPLOYER);

        HubDeployConfig memory hubDeployConfig_ = DeployConfig.getHubDeployConfig(block.chainid);
        WormholeTransceiverConfig memory hubTransceiverConfig_ = WormholeConfig.getWormholeTransceiverConfig(
            block.chainid
        );

        (address hubPortal_, ) = _deployHubComponents(
            _DEPLOYER,
            block.chainid.toWormholeChainId(),
            hubDeployConfig_,
            hubTransceiverConfig_
        );

        assertEq(hubPortal_, _EXPECTED_HUB_PORTAL_ADDRESS);

        IMTokenLike mToken_ = IMTokenLike(IHubPortal(hubPortal_).mToken());

        IHubPortal(hubPortal_).enableEarning();

        assertTrue(mToken_.isEarning(hubPortal_));
        assertEq(IHubPortal(hubPortal_).currentIndex(), mToken_.currentIndex());
    }
}
