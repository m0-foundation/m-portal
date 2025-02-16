// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";

import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { TaskBase } from "./TaskBase.sol";

contract Transfer is TaskBase {
    using TypeConverter for address;

    function run() public {
        (address mToken_, address portal_, , , , ) = _readDeployment(block.chainid);
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        uint256 amount_ = _promptForTransferAmount(mToken_, signer_);
        uint256 deliveryPrice_ = _quoteDeliveryPrice(portal_, destinationChainId_);
        bytes32 recipient_ = signer_.toBytes32();
        bytes32 refundAddress_ = recipient_;

        vm.startBroadcast(signer_);

        IERC20(mToken_).approve(portal_, amount_);
        _transfer(portal_, destinationChainId_, amount_, recipient_, refundAddress_, deliveryPrice_);

        vm.stopBroadcast();
    }
}
