// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  MerkleTreeBuilder interface.
 * @author M^0 Labs
 * @dev    This contract allows constructing Merkle Trees from values set on the TTGRegistrar.
 *         The reason for this is to allow propagating these values, via the Merkle tree roots,
 *         to other chains in a way that is efficient and trustless.
 */
interface IMerkleTreeBuilder {
    /* ========== ERRORS ========== */

    error ListAlreadyExists();
    error InvalidList();
    error InvalidAdd();
    error InvalidRemove();
    error NotInList();
    error ValueInList();
    error ValueNotInList();

    /* ========== EVENTS ========== */

    event RootUpdated(bytes32 indexed list, bytes32 root);

    /* ========== MANAGE LISTS ========== */

    /**
     * @notice Adds a value to a list.
     * @dev    The value must be included in the list on the TTGRegistrar.
     *         All registrar values are bytes32 => bytes32 mappings.
     *         In the case of lists, the key is the hash of abi.encodePacked("VALUE", list, value).
     * @param  list   The list to add the value to.
     * @param  before The value immediately before the position in the list where the new value should be inserted.
     * @param  value  The value to add to the list.
     */
    function addToList(bytes32 list, bytes32 before, bytes32 value) external;

    /**
     * @notice Removes a value from a list.
     * @dev    The value must have been removed from the list on the TTGRegistrar.
     * @param  list   The list to remove the value from.
     * @param  before The value immediately before the value in list.
     * @param  value  The value to remove from the list.
     */
    function removeFromList(bytes32 list, bytes32 before, bytes32 value) external;

    /* ========== MERKLE TREE ========== */

    /**
     * @notice Updates the Merkle tree root for a list and stores it for later retrieval.
     * @dev    This should be called after adding or removing values from the list.
     * @param  list The list to update the root for.
     */
    function updateRoot(bytes32 list) external;

    /* ========== VIEWS ========== */

    /**
     * @notice Retrieves the value following the provided value in the list.
     * @dev    This is useful for iterating over the list off-chain.
     */
    function getNext(bytes32 list, bytes32 value) external view returns (bytes32);

    /**
     * @notice Retrieves the length of the list.
     * @dev    This is useful for iterating over the list off-chain.
     */
    function getLen(bytes32 list) external view returns (uint256);

    /**
     * @notice Retrieves the root of the Merkle tree for a list.
     */
    function getRoot(bytes32 list) external view returns (bytes32);

    /**
     * @notice Retrieves the list of values in the provided list.
     * @dev    This is useful for retrieving smaller lists off-chain in one go.
     *         Larger lists may run into the gas limit at which point
     *         the list should be retrieved using `getNext`.
     */
    function getList(bytes32 list) external view returns (bytes32[] memory);

    /**
     * @notice Returns whether or not a value is in the provided list on this contract.
     */
    function contains(bytes32 list, bytes32 value) external view returns (bool);
}
