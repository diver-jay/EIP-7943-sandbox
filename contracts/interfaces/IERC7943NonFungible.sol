// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7943NonFungible
 * @notice Universal Real-World Asset (uRWA) interface for non-fungible (ERC-721) tokens.
 * @dev Compliant with EIP-7943.
 */
interface IERC7943NonFungible is IERC165 {
    /**
     * @notice Emitted when a specific token is forcibly transferred by an authorized entity.
     * @param from The address from which the token is moved.
     * @param to The address to which the token is moved.
     * @param tokenId The ID of the token transferred.
     */
    event ForcedTransfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @notice Emitted when the frozen status of a token is updated.
     * @param account The address of the account holding the token.
     * @param tokenId The ID of the token.
     * @param frozenStatus True if frozen, false if unfrozen.
     */
    event Frozen(address indexed account, uint256 indexed tokenId, bool indexed frozenStatus);

    // Custom errors for EIP-7943 compliance checks
    error ERC7943CannotTransact(address account);
    error ERC7943CannotTransfer(address from, address to, uint256 tokenId);
    error ERC7943InsufficientUnfrozenBalance(address account, uint256 tokenId);

    /**
     * @notice Performs a forced transfer of a specific token from one account to another.
     * @dev MUST emit the ForcedTransfer event.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param tokenId The ID of the token to transfer.
     * @return True if the forced transfer was successful.
     */
    function forcedTransfer(address from, address to, uint256 tokenId) external returns (bool);

    /**
     * @notice Checks the frozen status of a specific tokenId for an account.
     * @param account The address to check.
     * @param tokenId The ID of the token.
     * @return True if the token is frozen, false otherwise.
     */
    function getFrozenTokens(address account, uint256 tokenId) external view returns (bool);

    /**
     * @notice Freezes or unfreezes a specific token for an account.
     * @dev MUST emit the Frozen event.
     * @param account The address of the account.
     * @param tokenId The ID of the token.
     * @param frozen True to freeze the token, false to unfreeze it.
     * @return True if the operation was successful.
     */
    function setFrozenTokens(address account, uint256 tokenId, bool frozen) external returns (bool);

    /**
     * @notice Checks if an account is eligible to hold or transact with tokens.
     * @param account The address to check.
     * @return True if the account is allowed to transact, false otherwise.
     */
    function canTransact(address account) external view returns (bool);

    /**
     * @notice Pre-flight check to verify if a transfer is allowed.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param tokenId The ID of the token to transfer.
     * @return True if the transfer is allowed, false otherwise.
     */
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool);
}
