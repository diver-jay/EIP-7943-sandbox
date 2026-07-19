// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7943MultiToken
 * @notice Universal Real-World Asset (uRWA) interface for multi-token (ERC-1155) standards.
 * @dev Compliant with EIP-7943.
 */
interface IERC7943MultiToken is IERC165 {
    /**
     * @notice Emitted when a specific amount of a token ID is forcibly transferred by an authorized entity.
     * @param from The address from which tokens are moved.
     * @param to The address to which tokens are moved.
     * @param tokenId The ID of the token type.
     * @param amount The amount of tokens transferred.
     */
    event ForcedTransfer(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice Emitted when the frozen amount of a token ID for an account is updated.
     * @param account The address of the account.
     * @param tokenId The ID of the token type.
     * @param amount The new frozen token amount.
     */
    event Frozen(address indexed account, uint256 indexed tokenId, uint256 amount);

    // Custom errors for EIP-7943 compliance checks
    error ERC7943CannotTransact(address account);
    error ERC7943CannotTransfer(address from, address to, uint256 tokenId, uint256 amount);
    error ERC7943InsufficientUnfrozenBalance(address account, uint256 tokenId, uint256 amount, uint256 unfrozen);

    /**
     * @notice Performs a forced transfer of a specific amount of a token ID.
     * @dev MUST emit the ForcedTransfer event.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param tokenId The ID of the token type to transfer.
     * @param amount The amount of tokens to transfer.
     * @return True if the forced transfer was successful.
     */
    function forcedTransfer(address from, address to, uint256 tokenId, uint256 amount) external returns (bool);

    /**
     * @notice Returns the frozen amount of a token ID for an account.
     * @param account The address to check.
     * @param tokenId The ID of the token type.
     * @return The amount of frozen tokens.
     */
    function getFrozenTokens(address account, uint256 tokenId) external view returns (uint256);

    /**
     * @notice Freezes or unfreezes a specific amount of a token ID for an account.
     * @dev MUST emit the Frozen event.
     * @param account The address of the account.
     * @param tokenId The ID of the token type.
     * @param amount The new frozen token amount.
     * @return True if the operation was successful.
     */
    function setFrozenTokens(address account, uint256 tokenId, uint256 amount) external returns (bool);

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
     * @param tokenId The ID of the token type.
     * @param amount The amount of tokens to transfer.
     * @return True if the transfer is allowed, false otherwise.
     */
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount) external view returns (bool);
}
