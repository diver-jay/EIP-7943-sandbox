// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ComplianceRegistry
 * @notice A mock compliance registry to manage user whitelisting/eligibility for the study project.
 * @dev In a real-world scenario, this would interface with a KYC/AML provider, ZK-identity solution, or regulatory database.
 */
contract ComplianceRegistry is Ownable {
    // Mapping from account to its whitelisting (KYC/AML status) status
    mapping(address => bool) private _whitelist;

    // Mapping from country codes to allow/block status (for jurisdictional controls)
    mapping(string => bool) private _jurisdictionAllowlist;

    // Mapping of user addresses to country code strings
    mapping(address => string) private _userJurisdiction;

    event AddressWhitelisted(address indexed account, bool status);
    event JurisdictionStatusUpdated(string countryCode, bool allowed);
    event UserJurisdictionUpdated(address indexed account, string countryCode);

    constructor() Ownable(msg.sender) {
        // By default allow a mock country "US" and "KR"
        _jurisdictionAllowlist["US"] = true;
        _jurisdictionAllowlist["KR"] = true;
    }

    /**
     * @notice Updates the whitelist status of an account.
     * @param account The address to update.
     * @param status True to whitelist (KYC verify), false to remove.
     */
    function setWhitelistStatus(address account, bool status) external onlyOwner {
        _whitelist[account] = status;
        emit AddressWhitelisted(account, status);
    }

    /**
     * @notice Updates the eligibility of a country jurisdiction.
     * @param countryCode The 2-letter ISO code or similar custom code.
     * @param allowed True to allow this jurisdiction, false to block.
     */
    function setJurisdictionStatus(string calldata countryCode, bool allowed) external onlyOwner {
        _jurisdictionAllowlist[countryCode] = allowed;
        emit JurisdictionStatusUpdated(countryCode, allowed);
    }

    /**
     * @notice Sets the jurisdiction country code of a user.
     * @param account The user address.
     * @param countryCode The country code of the user.
     */
    function setUserJurisdiction(address account, string calldata countryCode) external onlyOwner {
        _userJurisdiction[account] = countryCode;
        emit UserJurisdictionUpdated(account, countryCode);
    }

    /**
     * @notice Checks if an address is currently KYC whitelisted and from an allowed jurisdiction.
     * @param account The address to check.
     */
    function isEligible(address account) public view returns (bool) {
        if (!_whitelist[account]) {
            return false;
        }

        string memory userCountry = _userJurisdiction[account];
        // If user country is not set, we assume US for mock simplicity, or we can check the registry
        if (bytes(userCountry).length == 0) {
            return true; // Default true if no jurisdiction restriction is configured
        }

        return _jurisdictionAllowlist[userCountry];
    }

    /**
     * @notice Pre-flight check to verify if a transfer from sender to recipient is allowed.
     */
    function checkTransfer(address from, address to, uint256 /*amount*/) external view returns (bool) {
        // Minting (from address(0)) only requires the recipient to be eligible
        if (from == address(0)) {
            return isEligible(to);
        }
        // Burning (to address(0)) only requires the sender to be eligible (or we allow burning freely)
        if (to == address(0)) {
            return isEligible(from);
        }
        // General transfer requires both sender and receiver to be eligible
        return isEligible(from) && isEligible(to);
    }
}
