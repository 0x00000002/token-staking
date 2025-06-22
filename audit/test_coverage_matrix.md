# Token Staking System: Test Coverage Matrix

## Overview

This matrix maps use cases to test cases and functions, ensuring comprehensive coverage of the STAKING SUBSYSTEM ONLY. It provides traceability from requirements through implementation to testing.

**Scope**: StakingVault.sol and StakingStorage.sol contracts only. Reward system is excluded from current audit.

## Use Cases to Test Cases Matrix

| Use Case                              | Description                         | Test Cases                       | Contract Functions                                                |
| ------------------------------------- | ----------------------------------- | -------------------------------- | ----------------------------------------------------------------- |
| **UC1: Direct Token Staking**         | User stakes tokens with time lock   | TC1, TC4, TC5, TC22              | `StakingVault.stake()`                                            |
| **UC2: Stake Unstaking**              | User unstakes matured tokens        | TC2, TC3, TC19, TC20, TC21, TC22 | `StakingVault.unstake()`                                          |
| **UC3: Query Active Stakes**          | Query stake and balance information | TC13, TC14                       | `StakingStorage.getStake()`, `getStakerInfo()`, `isActiveStake()` |
| **UC4: Pause System**                 | Manager pauses staking system       | TC8, TC10, TC22                  | `StakingVault.pause()`                                            |
| **UC5: Unpause System**               | Manager unpauses system             | TC9                              | `StakingVault.unpause()`                                          |
| **UC6: Emergency Token Recovery**     | Admin recovers tokens               | TC11, TC12, TC24                 | `StakingVault.emergencyRecover()`                                 |
| **UC7: Role Management**              | Admin manages roles                 | TC12, TC24                       | `grantRole()`, `revokeRole()`                                     |
| **UC8: Stake from Claim**             | Claim contract stakes for user      | TC6, TC7                         | `StakingVault.stakeFromClaim()`                                   |
| **UC9: Historical Balance Queries**   | Query historical staking data       | TC15, TC16, TC17                 | `StakingStorage.getStakerBalanceAt()`, `batchGetStakerBalances()` |
| **UC10: Staker Enumeration**          | Enumerate stakers for analytics     | TC18                             | `StakingStorage.getStakersPaginated()`, `getTotalStakersCount()`  |
| **UC11: Immature Stake Unstaking**    | Reject premature unstaking          | TC3, TC29                        | Time lock validation in `unstake()`                               |
| **UC12: Invalid Stake Operations**    | Handle various error conditions     | TC4, TC5, TC19, TC20, TC21       | Error handling across functions                                   |
| **UC13: Paused System Operations**    | Reject operations when paused       | TC22                             | Pausable modifier enforcement                                     |
| **UC14: Access Control Enforcement**  | Ensure role-based permissions       | TC7, TC10, TC12, TC24            | Role modifier enforcement                                         |
| **UC15: Reentrancy Protection**       | Prevent reentrancy attacks          | TC23                             | ReentrancyGuard protection                                        |
| **UC16: Checkpoint System Integrity** | Ensure historical data accuracy     | TC25, TC31                       | Checkpoint creation and binary search                             |
| **UC17: Global Statistics Accuracy**  | Maintain accurate global totals     | TC26                             | Total tracking and daily snapshots                                |
| **UC18: Token Integration**           | Secure ERC20 token operations       | TC28                             | SafeERC20 usage                                                   |
| **UC19: Storage-Vault Integration**   | Contract coordination               | TC27                             | Cross-contract calls and state management                         |

## Functions to Test Cases Matrix

| Contract           | Function                                               | Test Cases                                   | Use Cases                        | Coverage Type                            |
| ------------------ | ------------------------------------------------------ | -------------------------------------------- | -------------------------------- | ---------------------------------------- |
| **StakingVault**   | `stake(uint128, uint16)`                               | TC1, TC4, TC5, TC22, TC23, TC28, TC29, TC30  | UC1, UC12, UC13, UC15, UC18      | Core functionality, validation, security |
| **StakingVault**   | `unstake(bytes32)`                                     | TC2, TC3, TC19, TC20, TC21, TC22, TC23, TC29 | UC2, UC11, UC12, UC13, UC15      | Core functionality, validation, security |
| **StakingVault**   | `stakeFromClaim(address, uint128, uint16)`             | TC6, TC7, TC22                               | UC8, UC13, UC14                  | Integration, access control              |
| **StakingVault**   | `pause()`                                              | TC8, TC10                                    | UC4, UC14                        | Admin functions, access control          |
| **StakingVault**   | `unpause()`                                            | TC9, TC10                                    | UC5, UC14                        | Admin functions, access control          |
| **StakingVault**   | `emergencyRecover(IERC20, uint256)`                    | TC11, TC12, TC24                             | UC6, UC14                        | Emergency functions, access control      |
| **StakingStorage** | `createStake(address, bytes32, uint128, uint16, bool)` | TC1, TC6, TC24, TC25, TC26, TC27             | UC1, UC8, UC14, UC16, UC17, UC19 | Data persistence, access control         |
| **StakingStorage** | `removeStake(bytes32)`                                 | TC2, TC24, TC25, TC26, TC27                  | UC2, UC14, UC16, UC17, UC19      | Data persistence, access control         |
| **StakingStorage** | `getStake(address, bytes32)`                           | TC2, TC13, TC19                              | UC2, UC3, UC12                   | Data retrieval, validation               |
| **StakingStorage** | `isActiveStake(address, bytes32)`                      | TC13, TC20                                   | UC3, UC12                        | Data retrieval, validation               |
| **StakingStorage** | `getStakerInfo(address)`                               | TC14, TC26                                   | UC3, UC17                        | Data retrieval, statistics               |
| **StakingStorage** | `getStakerBalance(address)`                            | TC14, TC26                                   | UC3, UC17                        | Data retrieval, statistics               |
| **StakingStorage** | `getStakerBalanceAt(address, uint16)`                  | TC15, TC25, TC31                             | UC9, UC16                        | Historical queries, optimization         |
| **StakingStorage** | `batchGetStakerBalances(address[], uint16)`            | TC16, TC31                                   | UC9                              | Batch operations, optimization           |
| **StakingStorage** | `getDailySnapshot(uint16)`                             | TC17, TC26                                   | UC9, UC17                        | Historical data, statistics              |
| **StakingStorage** | `getCurrentTotalStaked()`                              | TC17, TC26                                   | UC9, UC17                        | Statistics, data integrity               |
| **StakingStorage** | `getStakersPaginated(uint256, uint256)`                | TC18, TC31                                   | UC10                             | Enumeration, scalability                 |
| **StakingStorage** | `getTotalStakersCount()`                               | TC18, TC26                                   | UC10, UC17                       | Statistics, enumeration                  |

## Security Test Coverage

| Security Aspect             | Test Cases                   | Contract Functions             | Attack Vectors Covered                    |
| --------------------------- | ---------------------------- | ------------------------------ | ----------------------------------------- |
| **Access Control**          | TC7, TC10, TC12, TC24        | All role-restricted functions  | Unauthorized access, privilege escalation |
| **Reentrancy Protection**   | TC23                         | `stake()`, `unstake()`         | Recursive call attacks                    |
| **Time Lock Validation**    | TC3, TC29                    | `unstake()`, time calculations | Time manipulation, premature withdrawal   |
| **State Management**        | TC19, TC20, TC21, TC25, TC26 | State-changing functions       | State inconsistency, data corruption      |
| **Input Validation**        | TC4, TC5, TC19, TC30         | Parameter validation           | Invalid inputs, overflow/underflow        |
| **Pause Mechanism**         | TC22                         | All user-facing functions      | Emergency protection bypass               |
| **Token Integration**       | TC28                         | Token transfer functions       | Token-related vulnerabilities             |
| **Cross-Contract Security** | TC24, TC27                   | Storage modification functions | Unauthorized storage access               |

## Data Integrity Coverage

| Data Aspect              | Test Cases           | Functions                    | Validation Points                             |
| ------------------------ | -------------------- | ---------------------------- | --------------------------------------------- |
| **Checkpoint System**    | TC25, TC31           | Checkpoint creation/queries  | Historical accuracy, binary search            |
| **Global Totals**        | TC26                 | Total tracking functions     | Sum consistency, snapshot accuracy            |
| **Stake Lifecycle**      | TC1, TC2, TC19, TC20 | Stake CRUD operations        | State transitions, data preservation          |
| **Balance Calculations** | TC15, TC16, TC26     | Balance query functions      | Mathematical accuracy, historical consistency |
| **Event Emission**       | TC32                 | All state-changing functions | Event parameter accuracy, coordination        |

## Edge Case Coverage

| Edge Case Category      | Test Cases             | Functions                       | Scenarios                                     |
| ----------------------- | ---------------------- | ------------------------------- | --------------------------------------------- |
| **Boundary Conditions** | TC29, TC30, TC36, TC41 | Time and amount validations     | Zero values, maximum values, exact boundaries |
| **Large Datasets**      | TC31, TC37, TC43       | Query and enumeration functions | Performance, gas limits, pagination           |
| **State Transitions**   | TC20, TC29, TC34, TC39 | Stake lifecycle functions       | Valid/invalid state changes                   |
| **Numeric Edge Cases**  | TC30, TC36, TC41       | Amount calculations             | Overflow, underflow, precision                |

## Integration Test Coverage

| Integration Point                  | Test Cases     | Coverage                                               |
| ---------------------------------- | -------------- | ------------------------------------------------------ |
| **StakingVault ↔ StakingStorage**  | TC27           | Cross-contract calls, data consistency, access control |
| **StakingVault ↔ ERC20 Token**     | TC28           | Token transfers, balance checks, allowance validation  |
| **External Claims ↔ StakingVault** | TC6, TC7       | Claim integration, role validation, token handling     |
| **Access Control System**          | TC12, TC24     | Role-based permissions, OpenZeppelin integration       |
| **Pausable Mechanism**             | TC8, TC9, TC22 | Emergency controls, state management                   |

## Performance and Gas Coverage

| Performance Aspect     | Test Cases       | Coverage                               |
| ---------------------- | ---------------- | -------------------------------------- |
| **Gas Optimization**   | TC33             | Operation costs, efficiency benchmarks |
| **Binary Search**      | TC15, TC25, TC31 | O(log n) complexity verification       |
| **Batch Operations**   | TC16, TC18, TC31 | Multi-operation efficiency             |
| **Storage Efficiency** | TC31             | Large dataset handling, pagination     |

## Contract Coverage Summary

### StakingVault.sol

- **Functions Covered**: 6/6 (100%)
  - `stake()`, `unstake()`, `stakeFromClaim()`, `pause()`, `unpause()`, `emergencyRecover()`
- **Access Modifiers**: All role restrictions tested
- **Security Features**: Reentrancy, pausable, access control
- **Error Handling**: All custom errors tested

### StakingStorage.sol

- **Functions Covered**: 12/12 (100%)
  - All CRUD operations, queries, statistics, and enumeration functions
- **Access Control**: CONTROLLER_ROLE enforcement tested
- **Data Structures**: All structs and mappings validated
- **Advanced Features**: Checkpoint system, binary search, pagination

## Test Priority Matrix

| Priority     | Test Cases                                           | Functionality                               |
| ------------ | ---------------------------------------------------- | ------------------------------------------- |
| **Critical** | TC1, TC2, TC3, TC6, TC23, TC24, TC27                 | Core staking, security, integration         |
| **High**     | TC4, TC5, TC8, TC9, TC13-TC17, TC19-TC22, TC25, TC26 | Validation, admin functions, data integrity |
| **Medium**   | TC7, TC10, TC12, TC18, TC28-TC31                     | Edge cases, optimization, enumeration       |
| **Low**      | TC32, TC33                                           | Events, gas optimization                    |

## Coverage Requirements

### Minimum Coverage Thresholds

- **Function Coverage**: 100% of public/external functions
- **Branch Coverage**: 100% of conditional logic paths
- **Line Coverage**: 95% minimum (excluding unreachable code)
- **Security Coverage**: 100% of security-critical functions
- **Integration Coverage**: 100% of cross-contract interactions

### Quality Gates

- All critical and high priority tests must pass
- Gas usage must not exceed expected limits
- All security tests must pass
- Event emissions must be verified
- State consistency must be maintained

## Implementation-Specific Coverage (TC34-TC43)

Enhanced coverage for critical implementation details:

### ✅ New Coverage Areas Added

1. **StakingStorage Direct Functions** (TC34): Controller role enforcement, duplicate prevention
2. **Stake ID Generation** (TC35): Deterministic generation, collision prevention
3. **Day Calculation Edge Cases** (TC36): Boundary conditions, overflow scenarios
4. **Binary Search Algorithm** (TC37): Empty arrays, single elements, large datasets
5. **Staker Registration System** (TC38): First-time registration, enumeration consistency
6. **Checkpoint System Internals** (TC39): Same-day operations, sorting validation
7. **Daily Snapshot Accuracy** (TC40): Multi-operation aggregation, historical consistency
8. **Storage Input Validation** (TC41): Zero address handling, parameter boundaries
9. **Cross-Contract Events** (TC42): Event synchronization, parameter verification
10. **Gas Limit Edge Cases** (TC43): Maximum arrays, large datasets, efficiency limits

### ⚠️ Known Gaps (To Be Addressed in Testing)

1. **Reward System**: Excluded from current audit scope
2. **Fuzz Testing**: Should be added for numeric edge cases
3. **Invariant Testing**: Should be added for state consistency
4. **Stress Testing**: Large-scale operation testing needed

### ✅ Covered Areas

1. **Core Staking Logic**: Comprehensive coverage including storage layer
2. **Access Control**: Full role-based testing across both contracts
3. **Data Integrity**: Historical and real-time validation with deep algorithm testing
4. **Security**: Reentrancy, validation, authorization with implementation specifics
5. **Integration**: Cross-contract coordination with event verification

## Test Implementation Notes

### Framework Requirements

- **Foundry**: Primary testing framework
- **Solidity**: Test implementation language
- **Forge**: Test runner and tooling

### Test Structure

```
tests/
├── unit/
│   ├── StakingVault.t.sol
│   └── StakingStorage.t.sol
├── integration/
│   ├── VaultStorageIntegration.t.sol
│   └── TokenIntegration.t.sol
├── security/
│   ├── AccessControl.t.sol
│   └── Reentrancy.t.sol
└── helpers/
    ├── TestHelpers.sol
    └── MockContracts.sol
```

### Helper Requirements

- Mock ERC20 token contracts
- Test user management utilities
- Time manipulation helpers
- Event assertion utilities
- Gas measurement tools

---

This matrix ensures comprehensive testing coverage for the staking subsystem while providing clear traceability from requirements to implementation and testing. All critical security aspects and edge cases are covered to ensure audit readiness.
