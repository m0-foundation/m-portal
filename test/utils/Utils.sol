// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

library Utils {
    /// @dev Registrar key holding value of whether the earners list can be ignored or not.
    bytes32 internal constant EARNERS_LIST_IGNORED = "earners_list_ignored";

    /// @dev Registrar key of earners list.
    bytes32 internal constant EARNERS_LIST = "earners";

    /// @notice The scaling of rates in for exponent math.
    uint56 internal constant EXP_SCALED_ONE = 1e12;

    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    uint32 internal constant SEND_M_TOKEN_INDEX_GAS_LIMIT = 100_000;
    uint32 internal constant SEND_M_TOKEN_GAS_LIMIT = 200_000;
    uint32 internal constant SEND_REGISTRAR_KEY_GAS_LIMIT = 150_000;
    uint32 internal constant SEND_REGISTRAR_LIST_STATUS_GAS_LIMIT = 150_000;

    function getMaxEarningAmount(uint128 index_) internal pure returns (uint240 maxAmount_) {
        return (uint240(type(uint112).max) * index_) / EXP_SCALED_ONE;
    }
}
