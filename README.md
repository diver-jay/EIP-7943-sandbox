# EIP-7943 (uRWA - Universal Real World Asset) Sandbox Study Project

This repository is a test and study project for **EIP-7943 (uRWA - Universal Real-World Asset Interface)**, implementing a standard interface for permissioned, regulatory-compliant assets (e.g., securities, real estate, commodities) on EVM-compatible blockchains. 

---

## Architecture & Flow Diagrams

### EIP-7943 Architecture
![EIP-7943 Architecture](./EIP-7943.png)

---

### Core Flowcharts

#### 1. Compliance Transfer Flow (일반 전송 및 규제 검증 흐름)

```mermaid
sequenceDiagram
    autonumber
    actor Alice as 송신자 (Alice)
    participant Token as uRWA Token (ERC20uRWA)
    participant Registry as Compliance Registry
    actor Bob as 수신자 (Bob)

    Alice->>Token: 1. transfer(Bob, amount) 호출
    activate Token
    Token->>Token: 2. 동결 잔액 확인 (balance - frozen >= amount)
    Token->>Registry: 3. isEligible(Alice) & isEligible(Bob) 검증
    activate Registry
    Registry-->>Token: 4. 자격 검증 결과 (true/false)
    deactivate Registry
    Token->>Registry: 5. checkTransfer(Alice, Bob, amount) 호출
    activate Registry
    Registry-->>Token: 6. 규제 규칙 승인 (true/false)
    deactivate Registry
    Token->>Token: 7. 토큰 이동 (_update)
    Token-->>Bob: 8. Bob 계정으로 토큰 전송 완료
    deactivate Token
```

#### 2. Forced Transfer Flow (강제 전송 / 법적 집행 흐름)

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Compliance Admin (Regulator)
    participant Token as uRWA Token (ERC20uRWA)
    participant Registry as Compliance Registry
    actor Recipient as 수신자 / 복구 계정

    Admin->>Token: 1. forcedTransfer(TargetAccount, Recipient, amount)
    activate Token
    Token->>Token: 2. COMPLIANCE_ROLE 권한 검증
    Token->>Registry: 3. canTransact(Recipient) (수신자 자격 검증)
    activate Registry
    Registry-->>Token: 4. 수신자 자격 승인
    deactivate Registry
    Token->>Token: 5. 동결 상태 우회 후 즉시 토큰 이동
    Token->>Token: 6. TargetAccount의 동결 잔액 재조정
    Token-->>Admin: 7. ForcedTransfer 이벤트 발행
    deactivate Token
```

---


## Project Structure

```text
EIP-7943/
├── contracts/
│   ├── interfaces/
│   │   ├── IERC7943Fungible.sol       # EIP-7943 Fungible (ERC-20) Interface
│   │   ├── IERC7943NonFungible.sol    # EIP-7943 Non-Fungible (ERC-721) Interface
│   │   └── IERC7943MultiToken.sol     # EIP-7943 Multi-Token (ERC-1155) Interface
│   ├── ERC20uRWA.sol                  # Fungible uRWA Token implementation (ERC-20)
│   ├── ERC721uRWA.sol                 # Non-Fungible uRWA Token implementation (ERC-721)
│   ├── ERC1155uRWA.sol                # Multi-Token uRWA Token implementation (ERC-1155)
│   └── ComplianceRegistry.sol         # Mock KYC registry for rules & whitelist gating
├── test/
│   └── uRWA.test.js                   # Comprehensive Hardhat tests for uRWA behaviors
├── hardhat.config.js                  # Solidity compiler & Cancun EVM version setup
├── package.json
└── README.md
```

---

## Quick Start

### 1. Install Dependencies
Install all required node packages and OpenZeppelin libraries:

```bash
npm install
```

### 2. Compile Contracts
Compile all Solidity contracts. The project uses Solidity version `0.8.24` and targets `cancun` to support the `mcopy` EVM instruction used in OpenZeppelin Contracts v5.

```bash
npm run compile
```

### 3. Run Tests
Execute the 17 integration tests verifying compliance rules, freezing mechanics, forced transfers, and ERC-165 support:

```bash
npm test
```

---

## Key Features (EIP-7943 Primitives)

1. **User Eligibility Control (Gating & Whitelisting)**
   - `canTransact(address)`: Checks if an account is eligible to hold or interact with tokens (e.g., has passed KYC/AML checks).
   - `canTransfer(address, address, uint256)`: Pre-flight function to check whether a transfer between two addresses is permitted under current regulatory rules.

2. **Asset Freezing (Operational Controls)**
   - `setFrozenTokens(address, uint256)`: Freezes a specific amount of tokens for an account.
   - `getFrozenTokens(address)`: Returns the amount of frozen tokens for an account.
   - The token holder is only permitted to transfer their **unfrozen balance** (`balanceOf(user) - getFrozenTokens(user)`).

3. **Forced Transfer (Law Enforcement & Recovery)**
   - `forcedTransfer(address, address, uint256)`: Allows an authorized entity (e.g., a regulator or compliance officer) to move assets unilaterally without the token holder's signature. This is used for lost key recovery, compliance audits, or court-ordered asset seizures. Forced transfers bypass frozen checks but still check the destination's eligibility.

4. **ERC-165 Introspection**
   - Implements `supportsInterface` so that external routers, bridges, and custodians can dynamically inspect which uRWA interface variant (Fungible, NonFungible, MultiToken) is implemented.
