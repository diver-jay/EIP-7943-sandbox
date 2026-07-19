const { expect } = require("chai");
const pkg = require("hardhat");
const { ethers } = pkg;

describe("Universal Real-World Asset (uRWA) EIP-7943 Study Project Tests", function () {
    let admin, complianceManager, minter, alice, bob, charlie;
    let complianceRegistry;
    let erc20Token;
    let erc721Token;
    let erc1155Token;

    // Interface IDs (can be calculated using ethers or solidity type(I).interfaceId)
    // We will verify supportsInterface using calculated selectors
    const INTERFACE_IDS = {
        IERC7943Fungible: "0x29388973",
        IERC7943NonFungible: "0xa8fdc849",
        IERC7943MultiToken: "0x5627c61a"
    };

    beforeEach(async function () {
        [admin, complianceManager, minter, alice, bob, charlie] = await ethers.getSigners();

        // 1. Deploy ComplianceRegistry
        const ComplianceRegistryFactory = await ethers.getContractFactory("ComplianceRegistry");
        complianceRegistry = await ComplianceRegistryFactory.deploy();
        await complianceRegistry.waitForDeployment();

        // 2. Deploy ERC20uRWA
        const ERC20uRWAFactory = await ethers.getContractFactory("ERC20uRWA");
        erc20Token = await ERC20uRWAFactory.deploy(
            "RealWorldGold",
            "RWG",
            admin.address,
            await complianceRegistry.getAddress()
        );
        await erc20Token.waitForDeployment();

        // 3. Deploy ERC721uRWA
        const ERC721uRWAFactory = await ethers.getContractFactory("ERC721uRWA");
        erc721Token = await ERC721uRWAFactory.deploy(
            "RealWorldRealEstate",
            "RWRE",
            admin.address,
            await complianceRegistry.getAddress()
        );
        await erc721Token.waitForDeployment();

        // 4. Deploy ERC1155uRWA
        const ERC1155uRWAFactory = await ethers.getContractFactory("ERC1155uRWA");
        erc1155Token = await ERC1155uRWAFactory.deploy(
            "https://api.rwa-study.com/metadata/{id}.json",
            admin.address,
            await complianceRegistry.getAddress()
        );
        await erc1155Token.waitForDeployment();

        // Configure roles
        const COMPLIANCE_ROLE = await erc20Token.COMPLIANCE_ROLE();
        const MINTER_ROLE = await erc20Token.MINTER_ROLE();

        // Grant roles to specific testers
        await erc20Token.grantRole(COMPLIANCE_ROLE, complianceManager.address);
        await erc20Token.grantRole(MINTER_ROLE, minter.address);

        await erc721Token.grantRole(COMPLIANCE_ROLE, complianceManager.address);
        await erc721Token.grantRole(MINTER_ROLE, minter.address);

        await erc1155Token.grantRole(COMPLIANCE_ROLE, complianceManager.address);
        await erc1155Token.grantRole(MINTER_ROLE, minter.address);

        // Whitelist Alice, Bob, and Compliance Manager in the registry
        await complianceRegistry.setWhitelistStatus(alice.address, true);
        await complianceRegistry.setWhitelistStatus(bob.address, true);
        await complianceRegistry.setWhitelistStatus(complianceManager.address, true);
    });

    describe("ComplianceRegistry (KYC & Jurisdictions)", function () {
        it("should allow admin to whitelist users", async function () {
            expect(await complianceRegistry.isEligible(alice.address)).to.be.true;
            expect(await complianceRegistry.isEligible(charlie.address)).to.be.false;

            await complianceRegistry.setWhitelistStatus(charlie.address, true);
            expect(await complianceRegistry.isEligible(charlie.address)).to.be.true;
        });

        it("should restrict eligibility based on blocked jurisdictions", async function () {
            // Set Alice to jurisdiction "FR" (France) which is not allowed by default
            await complianceRegistry.setUserJurisdiction(alice.address, "FR");
            expect(await complianceRegistry.isEligible(alice.address)).to.be.false;

            // Allow "FR"
            await complianceRegistry.setJurisdictionStatus("FR", true);
            expect(await complianceRegistry.isEligible(alice.address)).to.be.true;
        });
    });

    describe("ERC20uRWA (Fungible Asset)", function () {
        beforeEach(async function () {
            // Mint some tokens to Alice (whitelisted)
            await erc20Token.connect(minter).mint(alice.address, 1000);
        });

        it("should prevent minting to non-whitelisted users", async function () {
            await expect(
                erc20Token.connect(minter).mint(charlie.address, 500)
            ).to.be.revertedWithCustomError(erc20Token, "ERC7943CannotTransact");
        });

        it("should allow transfers between whitelisted users", async function () {
            await expect(erc20Token.connect(alice).transfer(bob.address, 400))
                .to.changeTokenBalances(erc20Token, [alice, bob], [-400, 400]);
        });

        it("should prevent transfers if sender or recipient is not whitelisted", async function () {
            await expect(
                erc20Token.connect(alice).transfer(charlie.address, 100)
            ).to.be.revertedWithCustomError(erc20Token, "ERC7943CannotTransfer");

            // De-whitelist Bob
            await complianceRegistry.setWhitelistStatus(bob.address, false);
            await expect(
                erc20Token.connect(alice).transfer(bob.address, 100)
            ).to.be.revertedWithCustomError(erc20Token, "ERC7943CannotTransfer");
        });

        it("should allow setting and enforcing frozen balances", async function () {
            // Freeze 600 of Alice's tokens
            await expect(erc20Token.connect(complianceManager).setFrozenTokens(alice.address, 600))
                .to.emit(erc20Token, "Frozen")
                .withArgs(alice.address, 600);

            expect(await erc20Token.getFrozenTokens(alice.address)).to.equal(600);

            // Alice has 1000 tokens. Unfrozen = 400.
            // Transferring 300 should succeed
            await expect(erc20Token.connect(alice).transfer(bob.address, 300))
                .to.changeTokenBalances(erc20Token, [alice, bob], [-300, 300]);

            // Alice now has 700 tokens (600 frozen, 100 unfrozen).
            // Transferring 200 should fail because it exceeds unfrozen balance
            await expect(
                erc20Token.connect(alice).transfer(bob.address, 200)
            ).to.be.revertedWithCustomError(erc20Token, "ERC7943InsufficientUnfrozenBalance");
        });

        it("should support forced transfers by compliance managers", async function () {
            // Freeze Alice's tokens completely
            await erc20Token.connect(complianceManager).setFrozenTokens(alice.address, 1000);

            // Block Alice in the registry (de-whitelist)
            await complianceRegistry.setWhitelistStatus(alice.address, false);

            // Compliance manager forces transfer of 300 tokens from Alice to Bob
            await expect(erc20Token.connect(complianceManager).forcedTransfer(alice.address, bob.address, 300))
                .to.emit(erc20Token, "ForcedTransfer")
                .withArgs(alice.address, bob.address, 300);

            expect(await erc20Token.balanceOf(alice.address)).to.equal(700);
            expect(await erc20Token.balanceOf(bob.address)).to.equal(300);

            // Verify that the frozen amount was adjusted down because Alice's balance (700) is now less than previous frozen (1000)
            expect(await erc20Token.getFrozenTokens(alice.address)).to.equal(700);
        });

        it("should support ERC-165 interface introspection", async function () {
            expect(await erc20Token.supportsInterface(INTERFACE_IDS.IERC7943Fungible)).to.be.true;
            expect(await erc20Token.supportsInterface("0xffffffff")).to.be.false;
        });
    });

    describe("ERC721uRWA (Non-Fungible Asset)", function () {
        const tokenId = 42;

        beforeEach(async function () {
            await erc721Token.connect(minter).safeMint(alice.address, tokenId);
        });

        it("should enforce whitelisting on mint", async function () {
            await expect(
                erc721Token.connect(minter).safeMint(charlie.address, 43)
            ).to.be.revertedWithCustomError(erc721Token, "ERC7943CannotTransact");
        });

        it("should allow transfers between whitelisted users", async function () {
            await expect(
                erc721Token.connect(alice).transferFrom(alice.address, bob.address, tokenId)
            ).to.emit(erc721Token, "Transfer").withArgs(alice.address, bob.address, tokenId);
        });

        it("should prevent transfers when token is frozen", async function () {
            await expect(erc721Token.connect(complianceManager).setFrozenTokens(alice.address, tokenId, true))
                .to.emit(erc721Token, "Frozen")
                .withArgs(alice.address, tokenId, true);

            expect(await erc721Token.getFrozenTokens(alice.address, tokenId)).to.be.true;

            await expect(
                erc721Token.connect(alice).transferFrom(alice.address, bob.address, tokenId)
            ).to.be.revertedWithCustomError(erc721Token, "ERC7943InsufficientUnfrozenBalance");
        });

        it("should support forced transfers and clear frozen status", async function () {
            // Freeze and de-whitelist Alice
            await erc721Token.connect(complianceManager).setFrozenTokens(alice.address, tokenId, true);
            await complianceRegistry.setWhitelistStatus(alice.address, false);

            // Force transfer to Bob
            await expect(erc721Token.connect(complianceManager).forcedTransfer(alice.address, bob.address, tokenId))
                .to.emit(erc721Token, "ForcedTransfer")
                .withArgs(alice.address, bob.address, tokenId)
                .and.to.emit(erc721Token, "Frozen")
                .withArgs(alice.address, tokenId, false);

            expect(await erc721Token.ownerOf(tokenId)).to.equal(bob.address);
            expect(await erc721Token.getFrozenTokens(bob.address, tokenId)).to.be.false;
        });

        it("should support ERC-165 interface introspection", async function () {
            expect(await erc721Token.supportsInterface(INTERFACE_IDS.IERC7943NonFungible)).to.be.true;
        });
    });

    describe("ERC1155uRWA (Multi-Token Asset)", function () {
        const tokenId = 99;

        beforeEach(async function () {
            await erc1155Token.connect(minter).mint(alice.address, tokenId, 100, "0x");
        });

        it("should enforce whitelisting on mint", async function () {
            await expect(
                erc1155Token.connect(minter).mint(charlie.address, tokenId, 50, "0x")
            ).to.be.revertedWithCustomError(erc1155Token, "ERC7943CannotTransact");
        });

        it("should respect frozen balances", async function () {
            await expect(erc1155Token.connect(complianceManager).setFrozenTokens(alice.address, tokenId, 70))
                .to.emit(erc1155Token, "Frozen")
                .withArgs(alice.address, tokenId, 70);

            // Alice has 100 tokens, 70 frozen. Unfrozen = 30.
            // Transferring 20 should succeed
            await expect(
                erc1155Token.connect(alice).safeTransferFrom(alice.address, bob.address, tokenId, 20, "0x")
            ).to.emit(erc1155Token, "TransferSingle");

            // Alice now has 80 tokens, 70 frozen. Unfrozen = 10.
            // Transferring 20 should fail
            await expect(
                erc1155Token.connect(alice).safeTransferFrom(alice.address, bob.address, tokenId, 20, "0x")
            ).to.be.revertedWithCustomError(erc1155Token, "ERC7943InsufficientUnfrozenBalance");
        });

        it("should support forced transfers and adjust frozen amounts", async function () {
            await erc1155Token.connect(complianceManager).setFrozenTokens(alice.address, tokenId, 100);
            await complianceRegistry.setWhitelistStatus(alice.address, false);

            await expect(
                erc1155Token.connect(complianceManager).forcedTransfer(alice.address, bob.address, tokenId, 40)
            )
                .to.emit(erc1155Token, "ForcedTransfer")
                .withArgs(alice.address, bob.address, tokenId, 40);

            expect(await erc1155Token.balanceOf(alice.address, tokenId)).to.equal(60);
            expect(await erc1155Token.balanceOf(bob.address, tokenId)).to.equal(40);

            // Frozen amount should be adjusted down to 60
            expect(await erc1155Token.getFrozenTokens(alice.address, tokenId)).to.equal(60);
        });

        it("should support ERC-165 interface introspection", async function () {
            expect(await erc1155Token.supportsInterface(INTERFACE_IDS.IERC7943MultiToken)).to.be.true;
        });
    });
});
