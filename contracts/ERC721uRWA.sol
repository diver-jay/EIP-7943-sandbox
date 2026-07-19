// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC7943NonFungible} from "./interfaces/IERC7943NonFungible.sol";
import {ComplianceRegistry} from "./ComplianceRegistry.sol";

/**
 * @title ERC721uRWA
 * @notice An ERC-721 token implementation conforming to the EIP-7943 (uRWA) standard.
 */
contract ERC721uRWA is ERC721, AccessControl, IERC7943NonFungible {
    // Roles for compliance management
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Reference to the external ComplianceRegistry
    ComplianceRegistry public complianceRegistry;

    // Mapping from tokenId to frozen status
    mapping(uint256 => bool) private _frozenTokens;

    // Transient flag to bypass standard compliance checks during a forced transfer
    bool private _forcedTransferInProgress;

    constructor(
        string memory name,
        string memory symbol,
        address admin,
        address registry
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        complianceRegistry = ComplianceRegistry(registry);
    }

    /**
     * @notice Mints a token to an eligible recipient.
     */
    function safeMint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
    }

    /**
     * @notice Updates the Compliance Registry address.
     */
    function setComplianceRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRegistry != address(0), "Invalid registry address");
        complianceRegistry = ComplianceRegistry(newRegistry);
    }

    // --- IERC7943NonFungible Implementation ---

    /**
     * @dev See {IERC7943NonFungible-forcedTransfer}.
     */
    function forcedTransfer(
        address from,
        address to,
        uint256 tokenId
    ) external override onlyRole(COMPLIANCE_ROLE) returns (bool) {
        require(from != address(0), "Forced transfer from the zero address");
        require(to != address(0), "Forced transfer to the zero address");
        require(ownerOf(tokenId) == from, "Token does not belong to sender");

        _forcedTransferInProgress = true;
        _transfer(from, to, tokenId);
        _forcedTransferInProgress = false;

        // Clear freeze status for the new owner
        if (_frozenTokens[tokenId]) {
            _frozenTokens[tokenId] = false;
            emit Frozen(from, tokenId, false);
        }

        emit ForcedTransfer(from, to, tokenId);
        return true;
    }

    /**
     * @dev See {IERC7943NonFungible-getFrozenTokens}.
     */
    function getFrozenTokens(address account, uint256 tokenId) public view override returns (bool) {
        // If the account does not currently own the token, it cannot be frozen for them
        if (ownerOf(tokenId) != account) {
            return false;
        }
        return _frozenTokens[tokenId];
    }

    /**
     * @dev See {IERC7943NonFungible-setFrozenTokens}.
     */
    function setFrozenTokens(
        address account,
        uint256 tokenId,
        bool frozen
    ) external override onlyRole(COMPLIANCE_ROLE) returns (bool) {
        require(ownerOf(tokenId) == account, "Account does not own token");
        _frozenTokens[tokenId] = frozen;
        emit Frozen(account, tokenId, frozen);
        return true;
    }

    /**
     * @dev See {IERC7943NonFungible-canTransact}.
     */
    function canTransact(address account) public view override returns (bool) {
        return complianceRegistry.isEligible(account);
    }

    /**
     * @dev See {IERC7943NonFungible-canTransfer}.
     */
    function canTransfer(
        address from,
        address to,
        uint256 tokenId
    ) public view override returns (bool) {
        // Eligibility checks
        if (!canTransact(from) || !canTransact(to)) {
            return false;
        }

        // Frozen check
        if (_frozenTokens[tokenId]) {
            return false;
        }

        // Registry rules check (using standard 1 token amount)
        if (!complianceRegistry.checkTransfer(from, to, 1)) {
            return false;
        }

        return true;
    }

    // --- Overrides ---

    /**
     * @dev Hook that is called for any transfer of tokens.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);

        // If it's a normal transfer (not forced)
        if (!_forcedTransferInProgress) {
            if (from != address(0)) {
                // Check frozen status
                if (_frozenTokens[tokenId]) {
                    revert ERC7943InsufficientUnfrozenBalance(from, tokenId);
                }

                // Check transfer permission & eligibility
                if (!canTransfer(from, to, tokenId)) {
                    revert ERC7943CannotTransfer(from, to, tokenId);
                }
            } else {
                // Minting checks
                if (!canTransact(to)) {
                    revert ERC7943CannotTransact(to);
                }
            }
        } else {
            // For forced transfers, we only verify that the destination is eligible to hold assets
            if (to != address(0) && !canTransact(to)) {
                revert ERC7943CannotTransact(to);
            }
        }

        return super._update(to, tokenId, auth);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC7943NonFungible).interfaceId || super.supportsInterface(interfaceId);
    }
}
