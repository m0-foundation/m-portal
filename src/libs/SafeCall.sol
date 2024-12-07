// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

library SafeCall {
    function safeCall(address target, bytes memory data) internal returns (bool success) {
        if (target.code.length > 0) {
            (success, ) = target.call(data);
        }
    }
}
