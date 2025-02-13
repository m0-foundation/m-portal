// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { Chains } from "../../script/config/Chains.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract SpokeVaultForkTests is ForkTestBase {
    using TypeConverter for *;

    uint256 internal _amount;

    function setUp() public override {
        super.setUp();
    }

    /* ============ transfer ============ */

    function testFork_transferExcessM() external {
        _beforeTest();

        vm.prank(_DEPLOYER);
        IPortal(_arbitrumSpokePortal).setDestinationMToken(Chains.WORMHOLE_ETHEREUM, _MAINNET_M_TOKEN.toBytes32());

        vm.startPrank(_mHolder);

        // Then, transfer excess M tokens to the Hub chain.
        _transferExcessM(
            _arbitrumSpokeVault,
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_arbitrumSpokePortal, Chains.WORMHOLE_ETHEREUM)
        );

        vm.stopPrank();

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_arbitrumSpokeVault), 0);

        bytes memory spokeSignedMessage_ = _signMessage(_arbitrumSpokeGuardian, Chains.WORMHOLE_ARBITRUM);

        vm.selectFork(_mainnetForkId);

        uint256 balanceOfBefore_ = IERC20(_MAINNET_M_TOKEN).balanceOf(_MAINNET_VAULT);

        _deliverMessage(_MAINNET_WORMHOLE_RELAYER, spokeSignedMessage_);

        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_hubPortal), 0);
        assertEq(IERC20(_MAINNET_M_TOKEN).balanceOf(_MAINNET_VAULT), balanceOfBefore_ + _amount);
    }

    function _beforeTest() internal {
        _amount = 1_000e6;

        vm.selectFork(_mainnetForkId);

        vm.prank(_DEPLOYER);
        IPortal(_hubPortal).setDestinationMToken(Chains.WORMHOLE_ARBITRUM, _MAINNET_M_TOKEN.toBytes32());

        vm.startPrank(_mHolder);

        // First, transfer M tokens to the Spoke chain
        IERC20(_MAINNET_M_TOKEN).approve(_hubPortal, _amount);

        vm.recordLogs();

        _transfer(
            _hubPortal,
            Chains.WORMHOLE_ARBITRUM,
            _amount,
            _toUniversalAddress(_mHolder),
            _toUniversalAddress(_mHolder),
            _quoteDeliveryPrice(_hubPortal, Chains.WORMHOLE_ARBITRUM)
        );

        vm.stopPrank();

        bytes memory hubSignedMessage_ = _signMessage(_hubGuardian, Chains.WORMHOLE_ETHEREUM);

        vm.selectFork(_arbitrumForkId);
        _deliverMessage(_ARBITRUM_WORMHOLE_RELAYER, hubSignedMessage_);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_arbitrumSpokeVault), 0);

        _amount = IERC20(_arbitrumSpokeMToken).balanceOf(_mHolder);

        vm.prank(_mHolder);

        // Then, transfer M tokens to the SpokeVault to simulate accrual of excess M
        IERC20(_arbitrumSpokeMToken).transfer(_arbitrumSpokeVault, _amount);

        assertEq(IERC20(_arbitrumSpokeMToken).balanceOf(_arbitrumSpokeVault), _amount);
    }
}
