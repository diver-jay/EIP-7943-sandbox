# EIP-7943 (uRWA - Universal Real World Asset) 스터디용 테스트 프로젝트

이 프로젝트는 실자산(Real World Asset, RWA)의 규제 준수(Compliance) 및 통제 기능 표준인 **EIP-7943 (uRWA - Universal Real World Asset Interface)**을 준수하여 작성된 테스트 및 학습용 Hardhat 스마트 계약 프로젝트입니다.

EIP-7943 표준은 토큰화된 자산에 필수적인 규제 기능(자산 동결, 강제 이체, 적격성 검사)을 통일된 인터페이스로 정의하여 DeFi 프로토콜, 지갑, 거래소 등이 다양한 규제 토큰과 표준화된 방식으로 상호작용할 수 있도록 지원합니다.

---

## 📌 주요 특징 (EIP-7943 핵심 프리미티브)

1. **사용자 적격성 통제 (Whitelisting & Gating)**
   - `canTransact(address)`: 특정 사용자가 자산을 보유하거나 거래할 자격이 있는지 확인합니다. (예: KYC/AML 통과 여부)
   - `canTransfer(address, address, uint256)`: 발신자와 수신자 간의 이체가 현재 정책 및 한도에 따라 허용되는지 미리 확인하는 Pre-flight 체크 함수입니다.

2. **자산 동결 및 동결 검사 (Asset Freezing)**
   - `setFrozenTokens(address, uint256)`: 특정 계정의 자산 중 동결할 수량을 지정합니다.
   - `getFrozenTokens(address)`: 동결된 자산의 수량을 확인합니다.
   - 사용자는 자신의 전체 잔액 중 동결된 자산을 제외한 **해제 자산(Unfrozen Balance)** 범위 내에서만 자유롭게 이체할 수 있습니다.

3. **강제 이체 (Forced Transfer)**
   - `forcedTransfer(address, address, uint256)`: 사법 조치, 비밀번호 분실 복구, 규제 준수 등을 위해 사용자의 서명 없이 지정된 관리자(Compliance Manager)가 강제로 자산을 이전시킬 수 있는 기능입니다. 이 기능은 사용자 잔액 동결 여부 등을 우회하지만, 이체 대상의 적격성(KYC)은 여전히 검증할 수 있습니다.

4. **ERC-165 인터페이스 탐지 (Introspection)**
   - 각 토큰 계약은 자신이 어떤 uRWA 규격(Fungible, NonFungible, MultiToken)을 구현하고 있는지 ERC-165를 통해 외부 계약에 알립니다.

---

## 📂 프로젝트 구조

```text
EIP-7943/
├── contracts/
│   ├── interfaces/
│   │   ├── IERC7943Fungible.sol       # ERC-20 기반 uRWA 인터페이스
│   │   ├── IERC7943NonFungible.sol    # ERC-721 기반 uRWA 인터페이스
│   │   └── IERC7943MultiToken.sol     # ERC-1155 기반 uRWA 인터페이스
│   ├── ERC20uRWA.sol                  # EIP-7943을 준수하는 ERC-20 대체 가능 RWA 토큰
│   ├── ERC721uRWA.sol                 # EIP-7943을 준수하는 ERC-721 대체 불가능(NFT) RWA 토큰
│   ├── ERC1155uRWA.sol                # EIP-7943을 준수하는 ERC-1155 다중 토큰 RWA 토큰
│   └── ComplianceRegistry.sol         # KYC 및 국가 관할구역 통제를 시뮬레이션하는 외부 컴플라이언스 레지스트리
├── test/
│   └── uRWA.test.js                   # EIP-7943의 모든 요구사항을 검증하는 종합 테스트 스위트
├── hardhat.config.js                  # 컴파일러 버전(0.8.24) 및 EVM 버전(Cancun) 설정
├── package.json
└── README.md
```

---

## 🛠️ 시작하기 (Quick Start)

### 1. 패키지 설치
프로젝트 루트 폴더에서 아래 명령어를 실행해 필수 개발 종속성 패키지를 설치합니다:

```bash
npm install
```

### 2. 스마트 계약 컴파일
OpenZeppelin v5+의 효율적인 메모리 복사 기능(`mcopy` EVM 명령어)을 지원하기 위해 **Cancun EVM 버전** 타겟 컴파일이 설정되어 있습니다.

```bash
npm run compile
```

### 3. 테스트 실행
작성된 17개의 EIP-7943 규격 검증 테스트(동결, 적격성 차단, 강제 이체, ERC-165)를 실행합니다.

```bash
npm test
```

---

## 🔍 테스트 시나리오 상세

학습용 테스트(`test/uRWA.test.js`)에는 다음 규격 검증들이 구현되어 있습니다:

- **`ComplianceRegistry` 테스트**: 관리자가 사용자의 KYC 승인 상태를 바꾸거나 특정 국가 관할(예: US, KR 등)에 따라 적격성을 동적으로 통제할 수 있는지 검증합니다.
- **ERC-20 기반 uRWA 테스트**:
  - KYC를 거치지 않은 사용자에게 민팅이나 이체가 거부되는지 확인합니다.
  - 관리자가 Alice의 자산 중 일부를 동결(Freeze)시켰을 때, 동결 금액을 제외한 한도 내에서만 이체가 가능한지 확인합니다.
  - Alice가 차단되거나 완전히 동결된 상황에서, 사법 집행관(Compliance Role)이 강제 이체(`forcedTransfer`)를 실행하여 Bob에게 자산을 보낼 수 있는지, 그리고 남은 동결 자산 회계 처리가 정확히 갱신되는지 확인합니다.
- **ERC-721 (NFT) / ERC-1155 (Multi-Token) uRWA 테스트**:
  - 각각 개별 Token ID 및 ID별 수량 단위의 자산 동결과 강제 이체가 정확히 수행되는지 확인합니다.
- **ERC-165 인터페이스 ID 검증**:
  - `IERC7943Fungible` (인터페이스 ID: `0x29388973`)
  - `IERC7943NonFungible` (인터페이스 ID: `0xa8fdc849`)
  - `IERC7943MultiToken` (인터페이스 ID: `0x5627c61a`)
  - 토큰 계약이 외부 조회기에 해당 인터페이스 규격을 갖추고 있다고 정상적으로 응답하는지 검증합니다.

---

## ⚠️ 보안 주의사항
본 레포지토리에 구현된 구현체는 **EIP-7943 표준 사양 분석 및 학습/테스트용 목적**으로 작성되었습니다. 본 계약 코드는 정식 보안 감사를 받지 않았으므로 실제 메인넷 서비스 배포 및 프로덕션 환경 사용 시에는 전문 오딧(Audit) 및 추가 보안 검증이 반드시 필요합니다.
