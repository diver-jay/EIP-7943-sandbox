// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC7943MultiToken} from "./interfaces/IERC7943MultiToken.sol";
import {ComplianceRegistry} from "./ComplianceRegistry.sol";

/**
 * @title ERC1155uRWA
 * @notice An ERC-1155 token implementation conforming to the EIP-7943 (uRWA) standard.
 */
contract ERC1155uRWA is ERC1155, AccessControl, IERC7943MultiToken {
    // Roles for compliance management
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Reference to the external ComplianceRegistry
    ComplianceRegistry public complianceRegistry;

    // Mapping from account => tokenId => frozen amount
    mapping(address => mapping(uint256 => uint256)) private _frozenTokens;

    // Transient flag to bypass standard compliance checks during a forced transfer
    bool private _forcedTransferInProgress;

    constructor(
        string memory uri,
        address admin,
        address registry
    ) ERC1155(uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        complianceRegistry = ComplianceRegistry(registry);
    }

    /**
     * @notice Mints tokens of a specific ID to an eligible recipient.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    /**
     * @notice Updates the Compliance Registry address.
     */
    function setComplianceRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRegistry != address(0), "Invalid registry address");
        complianceRegistry = ComplianceRegistry(newRegistry);
    }

    // --- IERC7943MultiToken Implementation ---

    /**
     * @dev See {IERC7943MultiToken-forcedTransfer}.
     */
    function forcedTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external override onlyRole(COMPLIANCE_ROLE) returns (bool) {
        require(from != address(0), "Forced transfer from the zero address");
        require(to != address(0), "Forced transfer to the zero address");

        _forcedTransferInProgress = true;
        _safeTransferFrom(from, to, tokenId, amount, "");
        _forcedTransferInProgress = false;

        // Keep frozen tokens accounting consistent if sender balance fell below frozen threshold
        uint256 balanceFrom = balanceOf(from, tokenId);
        if (balanceFrom < _frozenTokens[from][tokenId]) {
            _frozenTokens[from][tokenId] = balanceFrom;
            emit Frozen(from, tokenId, balanceFrom);
        }

        emit ForcedTransfer(from, to, tokenId, amount);
        return true;
    }

    /**
     * @dev See {IERC7943MultiToken-getFrozenTokens}.
     */
    function getFrozenTokens(address account, uint256 tokenId) public view override returns (uint256) {
        return _frozenTokens[account][tokenId];
    }

    /**
     * @dev See {IERC7943MultiToken-setFrozenTokens}.
     */
    function setFrozenTokens(
        address account,
        uint256 tokenId,
        uint256 amount
    ) external override onlyRole(COMPLIANCE_ROLE) returns (bool) {
        _frozenTokens[account][tokenId] = amount;
        emit Frozen(account, tokenId, amount);
        return true;
    }

    /**
     * @dev See {IERC7943MultiToken-canTransact}.
     */
    function canTransact(address account) public view override returns (bool) {
        return complianceRegistry.isEligible(account);
    }

    /**
     * @dev See {IERC7943MultiToken-canTransfer}.
     */
    function canTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) public view override returns (bool) {
        // Eligibility checks
        if (!canTransact(from) || !canTransact(to)) {
            return false;
        }

        // Frozen balance check
        uint256 balance = balanceOf(from, tokenId);
        uint256 frozen = _frozenTokens[from][tokenId];
        uint256 unfrozen = balance > frozen ? balance - frozen : 0;
        if (unfrozen < amount) {
            return false;
        }

        // Registry transfer rules check
        if (!complianceRegistry.checkTransfer(from, to, amount)) {
            return false;
        }

        return true;
    }

    // --- Overrides ---

    /**
     * @dev Hook that is called for any transfer of tokens.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // If it's a normal transfer (not forced)
        if (!_forcedTransferInProgress) {
            if (from != address(0)) {
                for (uint256 i = 0; i < ids.length; i++) {
                    uint256 id = ids[i];
                    uint256 value = values[i];

                    // Check frozen status
                    uint256 frozen = _frozenTokens[from][id];
                    uint256 balance = balanceOf(from, id);
                    uint256 unfrozen = balance > frozen ? balance - frozen : 0;
                    if (unfrozen < value) {
                        revert ERC7943InsufficientUnfrozenBalance(from, id, value, unfrozen);
                    }

                    // Check transfer permission & eligibility
                    if (!canTransfer(from, to, id, value)) {
                        revert ERC7943CannotTransfer(from, to, id, value);
                    }
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

        super._update(from, to, ids, values);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC7943MultiToken).interfaceId || super.supportsInterface(interfaceId);
    }
}
