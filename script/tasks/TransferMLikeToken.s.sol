// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { IWrappedMTokenLike } from "../../src/interfaces/IWrappedMTokenLike.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";

import { TaskBase } from "./TaskBase.sol";

contract TransferMLikeToken is TaskBase {
    using TypeConverter for address;

    function run() public {
        (address mToken_, address portal_, , , , ) = _readDeployment(block.chainid);
        address signer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        uint16 destinationChainId_ = _promptForDestinationChainId(portal_);
        address sourceToken_ = vm.parseAddress(vm.prompt("Enter source token"));
        bytes32 destinationToken_ = vm.parseAddress(vm.prompt("Enter destination token")).toBytes32();

        if (!IPortal(portal_).supportedBridgingPath(sourceToken_, destinationChainId_, destinationToken_)) {
            revert("Unsupported bridging path");
        }

        uint256 amount_ = _promptForTransferAmount(mToken_, signer_);
        uint256 deliveryPrice_ = _quoteDeliveryPrice(portal_, destinationChainId_);
        bytes32 recipient_ = signer_.toBytes32();
        bytes32 refundAddress_ = recipient_;

        vm.startBroadcast(signer_);

        IERC20(sourceToken_).approve(portal_, amount_);
        IPortal(portal_).transferMLikeToken{ value: deliveryPrice_ }(
            amount_,
            sourceToken_,
            destinationChainId_,
            destinationToken_,
            recipient_,
            refundAddress_
        );

        vm.stopBroadcast();
    }
}
