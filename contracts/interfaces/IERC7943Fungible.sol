// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7943Fungible
 * @notice Universal Real-World Asset (uRWA) interface for fungible (ERC-20) tokens.
 * @dev Compliant with EIP-7943.
 */
interface IERC7943Fungible is IERC165 {
    /**
     * @notice Emitted when tokens are forcibly transferred by an authorized entity.
     * @param from The address from which tokens are moved.
     * @param to The address to which tokens are moved.
     * @param amount The amount of tokens transferred.
     */
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount);

    /**
     * @notice Emitted when the frozen amount of tokens for an account is updated.
     * @param account The address of the account whose frozen amount is updated.
     * @param amount The new total frozen token amount.
     */
    event Frozen(address indexed account, uint256 amount);

    // Custom errors for EIP-7943 compliance checks
    error ERC7943CannotTransact(address account);
    error ERC7943CannotTransfer(address from, address to, uint256 amount);
    error ERC7943InsufficientUnfrozenBalance(address account, uint256 amount, uint256 unfrozen);

    /**
     * @notice Performs a forced transfer of tokens from one account to another.
     * @dev MUST emit the ForcedTransfer event.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param amount The amount of tokens to transfer.
     */
    function forcedTransfer(address from, address to, uint256 amount) external;

    /**
     * @notice Returns the amount of frozen tokens for an account.
     * @param account The address to check.
     * @return The amount of frozen tokens.
     */
    function getFrozenTokens(address account) external view returns (uint256);

    /**
     * @notice Freezes or unfreezes a specific amount of tokens for an account.
     * @dev MUST emit the Frozen event.
     * @param account The address of the account.
     * @param amount The new frozen token amount.
     */
    function setFrozenTokens(address account, uint256 amount) external;

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
     * @param amount The amount of tokens to transfer.
     * @return True if the transfer is allowed, false otherwise.
     */
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);
}
