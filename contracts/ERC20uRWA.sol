// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC7943Fungible} from "./interfaces/IERC7943Fungible.sol";
import {ComplianceRegistry} from "./ComplianceRegistry.sol";

/**
 * @title ERC20uRWA
 * @notice An ERC-20 token implementation conforming to the EIP-7943 (uRWA) standard.
 */
contract ERC20uRWA is ERC20, AccessControl, IERC7943Fungible {
    // Roles for compliance management
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Reference to the external ComplianceRegistry
    ComplianceRegistry public complianceRegistry;

    // Mapping from account to frozen token amount
    mapping(address => uint256) private _frozenTokens;

    // Transient flag to bypass standard compliance checks during a forced transfer
    bool private _forcedTransferInProgress;

    constructor(
        string memory name,
        string memory symbol,
        address admin,
        address registry
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        complianceRegistry = ComplianceRegistry(registry);
    }

    /**
     * @notice Mints tokens to an eligible recipient.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Updates the Compliance Registry address.
     */
    function setComplianceRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRegistry != address(0), "Invalid registry address");
        complianceRegistry = ComplianceRegistry(newRegistry);
    }

    // --- IERC7943Fungible Implementation ---

    /**
     * @dev See {IERC7943Fungible-forcedTransfer}.
     */
    function forcedTransfer(
        address from,
        address to,
        uint256 amount
    ) external override onlyRole(COMPLIANCE_ROLE) {
        require(from != address(0), "Forced transfer from the zero address");
        require(to != address(0), "Forced transfer to the zero address");
        
        _forcedTransferInProgress = true;
        _transfer(from, to, amount);
        _forcedTransferInProgress = false;

        // Keep frozen tokens accounting consistent if sender balance fell below frozen threshold
        uint256 balanceFrom = balanceOf(from);
        if (balanceFrom < _frozenTokens[from]) {
            _frozenTokens[from] = balanceFrom;
            emit Frozen(from, balanceFrom);
        }

        emit ForcedTransfer(from, to, amount);
    }

    /**
     * @dev See {IERC7943Fungible-getFrozenTokens}.
     */
    function getFrozenTokens(address account) public view override returns (uint256) {
        return _frozenTokens[account];
    }

    /**
     * @dev See {IERC7943Fungible-setFrozenTokens}.
     */
    function setFrozenTokens(address account, uint256 amount) external override onlyRole(COMPLIANCE_ROLE) {
        _frozenTokens[account] = amount;
        emit Frozen(account, amount);
    }

    /**
     * @dev See {IERC7943Fungible-canTransact}.
     */
    function canTransact(address account) public view override returns (bool) {
        return complianceRegistry.isEligible(account);
    }

    /**
     * @dev See {IERC7943Fungible-canTransfer}.
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) public view override returns (bool) {
        // Eligibility checks
        if (!canTransact(from) || !canTransact(to)) {
            return false;
        }

        // Frozen balance check
        uint256 balance = balanceOf(from);
        uint256 frozen = _frozenTokens[from];
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
        uint256 value
    ) internal virtual override {
        // If it's a normal transfer (not forced)
        if (!_forcedTransferInProgress) {
            if (from != address(0)) {
                // Check frozen status
                uint256 frozen = _frozenTokens[from];
                uint256 balance = balanceOf(from);
                uint256 unfrozen = balance > frozen ? balance - frozen : 0;
                if (unfrozen < value) {
                    revert ERC7943InsufficientUnfrozenBalance(from, value, unfrozen);
                }

                // Check transfer permission & eligibility
                if (!canTransfer(from, to, value)) {
                    revert ERC7943CannotTransfer(from, to, value);
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

        super._update(from, to, value);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IERC7943Fungible).interfaceId || super.supportsInterface(interfaceId);
    }
}
