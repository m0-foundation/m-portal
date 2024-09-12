// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

/**
 * @title Subset of M Token interface required for testing.
 */
interface IMTokenLike {
    /* ============ Interactive Functions ============ */

    function approve(address spender, uint256 amount) external returns (bool);

    function mint(address account, uint256 amount) external;

    /* ============ View/Pure Functions ============ */

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function currentIndex() external view returns (uint128);
}

/**
 * @title Subset of Registrar interface required for testing.
 */
interface IRegistrarLike {
    function get(bytes32 key) external view returns (bytes32);
}
