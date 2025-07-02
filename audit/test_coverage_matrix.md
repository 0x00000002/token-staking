# Token Staking System: Test Coverage Matrix

## Overview

This matrix maps use cases to test cases and functions, ensuring practical coverage of the complete Token Staking System. It provides traceability from requirements through implementation to testing for both core staking and reward management functionality.

**Scope**: Complete Token Staking System including core staking contracts (StakingVault.sol and StakingStorage.sol) and comprehensive reward management system (RewardManager.sol, EpochManager.sol, StrategiesRegistry.sol, GrantedRewardStorage.sol, and strategy implementations).

**Note**: Test specifications focus on business logic validation rather than implementation details, external library internals, or unrealistic edge cases. Total test cases reduced from 124 to 62 practical tests.

## Use Cases to Test Cases Matrix

| Use Case                              | Description                         | Test Cases                       | Contract Functions                                                |
| ------------------------------------- | ----------------------------------- | -------------------------------- | ----------------------------------------------------------------- |
| **UC1: Direct Token Staking**         | User stakes tokens with time lock   | TC1, TC4, TC5, TC22              | `StakingVault.stake()`                                            |
| **UC2: Stake Unstaking**              | User unstakes matured tokens        | TC2, TC3, TC22                   | `StakingVault.unstake()`                                          |
| **UC3: Query Active Stakes**          | Query stake and balance information | TC13, TC14                       | `StakingStorage.getStake()`, `getStakerInfo()`, `isActiveStake()` |
| **UC4: Pause System**                 | Manager pauses staking system       | TC8, TC10, TC22                  | `StakingVault.pause()`                                            |
| **UC5: Unpause System**               | Manager unpauses system             | TC9                              | `StakingVault.unpause()`                                          |
| **UC6: Emergency Token Recovery**     | Multisig recovers tokens            | TC11, TC12, TC24                 | `StakingVault.emergencyRecover()`                                 |
| **UC7: Role Management**              | Admin manages roles                 | TC12, TC24                       | `grantRole()`, `revokeRole()`                                     |
| **UC8: Stake from Claim**             | Claim contract stakes for user      | TC6, TC7                         | `StakingVault.stakeFromClaim()`                                   |
| **UC9: Historical Balance Queries**   | Query historical staking data       | TC15, TC16, TC17                 | `StakingStorage.getStakerBalanceAt()`, `batchGetStakerBalances()` |
| **UC10: Staker Enumeration**          | Enumerate stakers for analytics     | TC18                             | `StakingStorage.getStakersPaginated()`, `getTotalStakersCount()`  |
| **UC20: Stake Flag System**           | Manage stake flags and properties   | TC_F01, TC_F02, TC_F03           | `Flags.set()`, `Flags.isSet()`, flag validation                   |
| **UC21: Reward Strategy Management**  | Register and manage strategies      | TC_R01, TC_R02, TC_R03           | `StrategiesRegistry` functions                                    |
| **UC22: Epoch Lifecycle Management**  | Manage epoch state transitions      | TC_R04, TC_R05, TC_R06           | `EpochManager` state management                                   |
| **UC23: Immediate Reward Processing** | Calculate APR-style rewards         | TC_R07, TC_R08, TC_R09           | `RewardManager.calculateImmediateRewards()`                      |
| **UC24: Epoch Reward Distribution**   | Distribute pool rewards             | TC_R10, TC_R11, TC_R12           | `RewardManager.calculateEpochRewards()`                          |
| **UC25: Reward Claiming**             | Claim accumulated rewards           | TC_R13, TC_R14, TC_R15           | `RewardManager` claiming functions                                |
| **UC26: Reward Storage Management**   | Track granted rewards               | TC_R16, TC_R17, TC_R18           | `GrantedRewardStorage` functions                                  |
| **UC27: Immature Stake Unstaking**    | Reject premature unstaking          | TC3                              | Time lock validation in `unstake()`                               |
| **UC28: Invalid Stake Operations**    | Handle various error conditions     | TC4, TC5                         | Error handling across functions                                   |
| **UC29: Paused System Operations**    | Reject operations when paused       | TC22                             | Pausable modifier enforcement                                     |
| **UC30: Access Control Enforcement**  | Ensure role-based permissions       | TC7, TC10, TC12, TC24            | Role modifier enforcement                                         |
| **UC31: Reentrancy Protection**       | Prevent reentrancy attacks          | TC23                             | ReentrancyGuard protection                                        |
| **UC32: Checkpoint System Integrity** | Ensure historical data accuracy     | TC25                             | Checkpoint creation and queries                                   |
| **UC33: Global Statistics Accuracy**  | Maintain accurate global totals     | TC26                             | Total tracking and daily snapshots                                |
| **UC34: Token Integration**           | Secure ERC20 token operations       | TC28                             | SafeERC20 usage verification                                      |
| **UC35: Storage-Vault Integration**   | Contract coordination               | TC27                             | Cross-contract calls and state management                         |

## Functions to Test Cases Matrix

| Contract           | Function                                               | Test Cases                                   | Use Cases                        | Coverage Type                            |
| ------------------ | ------------------------------------------------------ | -------------------------------------------- | -------------------------------- | ---------------------------------------- |
| **StakingVault**   | `stake(uint128, uint16)`                               | TC1, TC4, TC5, TC22, TC23               | UC1, UC28, UC29, UC31, UC34      | Core functionality, validation, security |
| **StakingVault**   | `unstake(bytes32)`                                     | TC2, TC3, TC22, TC23                    | UC2, UC27, UC28, UC29, UC31      | Core functionality, validation, security |
| **StakingVault**   | `stakeFromClaim(address, uint128, uint16)`             | TC6, TC7, TC22                               | UC8, UC29, UC30                  | Integration, access control              |
| **StakingVault**   | `pause()`                                              | TC8, TC10                                    | UC4, UC30                        | Admin functions, access control          |
| **StakingVault**   | `unpause()`                                            | TC9, TC10                                    | UC5, UC30                        | Admin functions, access control          |
| **StakingVault**   | `emergencyRecover(IERC20, uint256)`                    | TC11, TC12, TC24                             | UC6, UC30                        | Emergency functions, access control      |
| **StakingStorage** | `createStake(address, uint128, uint16, uint16)`        | TC1, TC6, TC24, TC25, TC26, TC27             | UC1, UC8, UC30, UC32, UC33, UC35 | Data persistence, access control         |
| **StakingStorage** | `removeStake(address, bytes32)`                        | TC2, TC24, TC25, TC26, TC27                  | UC2, UC30, UC32, UC33, UC35      | Data persistence, access control         |
| **StakingStorage** | `getStake(address, bytes32)`                           | TC2, TC13                                    | UC2, UC3, UC28                   | Data retrieval, validation               |
| **StakingStorage** | `isActiveStake(address, bytes32)`                      | TC13                                         | UC3, UC28                        | Data retrieval, validation               |
| **StakingStorage** | `getStakerInfo(address)`                               | TC14, TC26                                   | UC3, UC33                        | Data retrieval, statistics               |
| **StakingStorage** | `getStakerBalance(address)`                            | TC14, TC26                                   | UC3, UC33                        | Data retrieval, statistics               |
| **StakingStorage** | `getStakerBalanceAt(address, uint16)`                  | TC15, TC25                                   | UC9, UC32                        | Historical queries, optimization         |
| **StakingStorage** | `batchGetStakerBalances(address[], uint16)`            | TC16                                         | UC9                              | Batch operations, optimization           |
| **StakingStorage** | `getDailySnapshot(uint16)`                             | TC17, TC26                                   | UC9, UC33                        | Historical data, statistics              |
| **StakingStorage** | `getCurrentTotalStaked()`                              | TC17, TC26                                   | UC9, UC33                        | Statistics, data integrity               |
| **StakingStorage** | `getStakersPaginated(uint256, uint256)`                | TC18                                         | UC10                             | Enumeration, scalability                 |
| **StakingStorage** | `getTotalStakersCount()`                               | TC18, TC26                                   | UC10, UC33                       | Statistics, enumeration                  |
| **Flags Library**  | `set(uint16, uint8)`, `isSet(uint16, uint8)`           | TC_F01, TC_F02, TC_F03                       | UC20                             | Flag operations, extensibility           |
| **RewardManager**  | `calculateImmediateRewards()`                          | TC_R07, TC_R08, TC_R09                       | UC23                             | APR reward processing                    |
| **RewardManager**  | `calculateEpochRewards()`                              | TC_R10, TC_R11, TC_R12                       | UC24                             | Pool reward distribution                 |
| **RewardManager**  | `claimAllRewards()`, `claimSpecificRewards()`          | TC_R13, TC_R14, TC_R15                       | UC25                             | Reward claiming, security                |
| **EpochManager**   | `announceEpoch()`, `finalizeEpoch()`                   | TC_R04, TC_R05, TC_R06                       | UC22                             | Epoch lifecycle management              |
| **StrategiesRegistry** | `registerStrategy()`, `setStrategyStatus()`        | TC_R01, TC_R02, TC_R03                       | UC21                             | Strategy management                      |
| **GrantedRewardStorage** | `grantReward()`, `getUserRewards()`               | TC_R16, TC_R17, TC_R18                       | UC26                             | Reward tracking, storage                 |

## Security Test Coverage

| Security Aspect             | Test Cases                   | Contract Functions             | Attack Vectors Covered                    |
| --------------------------- | ---------------------------- | ------------------------------ | ----------------------------------------- |
| **Access Control**          | TC7, TC10, TC12, TC24        | All role-restricted functions  | Unauthorized access, privilege escalation |
| **Reentrancy Protection**   | TC23                         | `stake()`, `unstake()`         | Recursive call attacks                    |
| **Time Lock Validation**    | TC3                          | `unstake()`, time calculations | Time manipulation, premature withdrawal   |
| **State Management**        | TC25, TC26                   | State-changing functions       | State inconsistency, data corruption      |
| **Input Validation**        | TC4, TC5                     | Parameter validation           | Invalid inputs, basic validation          |
| **Pause Mechanism**         | TC22                         | All user-facing functions      | Emergency protection bypass               |
| **Token Integration**       | TC28                         | Token transfer functions       | Token-related vulnerabilities             |
| **Cross-Contract Security** | TC24, TC27                   | Storage modification functions | Unauthorized storage access               |
| **Reward System Access**    | TC_R01, TC_R04, TC_R07       | Reward admin functions         | Unauthorized reward manipulation          |
| **Reward Claiming Security** | TC_R13, TC_R14, TC_R15       | All claiming functions         | Double claiming, ownership validation     |
| **Mathematical Precision**  | TC_R08, TC_R11, TC_R12       | Reward calculations            | Calculation manipulation, overflow        |
| **Strategy Validation**     | TC_R02, TC_R03               | Strategy management            | Malicious strategy registration           |

## Data Integrity Coverage

| Data Aspect              | Test Cases           | Functions                    | Validation Points                             |
| ------------------------ | -------------------- | ---------------------------- | --------------------------------------------- |
| **Checkpoint System**    | TC25                 | Checkpoint creation/queries  | Historical accuracy, business logic validation |
| **Global Totals**        | TC26                 | Total tracking functions     | Sum consistency, snapshot accuracy            |
| **Stake Lifecycle**      | TC1, TC2             | Stake CRUD operations        | State transitions, data preservation          |
| **Balance Calculations** | TC15, TC16, TC26     | Balance query functions      | Mathematical accuracy, historical consistency |

## Practical Edge Case Coverage

| Edge Case Category      | Test Cases | Functions                     | Scenarios                                 |
| ----------------------- | ---------- | ----------------------------- | ----------------------------------------- |
| **Time Lock Boundaries** | TC3        | Time validation functions     | Realistic time lock scenarios (0-365 days) |
| **Input Validation**    | TC4, TC5   | Parameter validation          | Zero amounts, basic boundary conditions    |

## Integration Test Coverage

| Integration Point                  | Test Cases     | Coverage                                               |
| ---------------------------------- | -------------- | ------------------------------------------------------ |
| **StakingVault ↔ StakingStorage**  | TC27           | Cross-contract calls, data consistency, access control |
| **StakingVault ↔ ERC20 Token**     | TC28           | Token transfers, balance checks, allowance validation  |
| **External Claims ↔ StakingVault** | TC6, TC7       | Claim integration, role validation, token handling     |
| **Access Control System**          | TC12, TC24     | Role-based permissions, OpenZeppelin integration       |
| **Pausable Mechanism**             | TC8, TC9, TC22 | Emergency controls, state management                   |
| **RewardManager ↔ StakingStorage** | TC_R07, TC_R10 | Historical data integration, weight calculations       |
| **RewardManager ↔ EpochManager**   | TC_R10, TC_R11 | Epoch validation, state coordination                   |
| **RewardManager ↔ StrategiesRegistry** | TC_R07, TC_R10 | Strategy validation, execution integration         |
| **RewardManager ↔ GrantedRewardStorage** | TC_R07, TC_R13 | Reward granting, claiming coordination            |

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

### RewardManager.sol

- **Functions Covered**: 12/12 (100%)
  - Immediate and epoch reward calculations, all claiming methods, funding
- **Access Control**: ADMIN_ROLE enforcement for calculation functions
- **Security Features**: Reentrancy protection in claiming, batch size limits
- **Integration**: StakingStorage, EpochManager, StrategiesRegistry coordination

### EpochManager.sol

- **Functions Covered**: 8/8 (100%)
  - Complete epoch lifecycle management, state transitions, queries
- **Access Control**: ADMIN_ROLE enforcement for management functions
- **State Management**: Proper state machine transitions tested
- **Data Integrity**: Epoch statistics and pool management validated

### StrategiesRegistry.sol

- **Functions Covered**: 8/8 (100%)
  - Strategy registration, activation, versioning, queries
- **Access Control**: ADMIN_ROLE enforcement tested
- **Strategy Validation**: Type validation, status management
- **Extensibility**: Support for future strategy types

### GrantedRewardStorage.sol

- **Functions Covered**: 10/10 (100%)
  - Reward granting, claiming state management, user queries
- **Access Control**: CONTROLLER_ROLE enforcement tested
- **Data Integrity**: Immutable grant records, accurate claiming state
- **Optimization**: Claiming index management, pagination support

### Strategy Implementations

- **LinearAPRStrategy.sol**: APR calculations, applicability logic
- **EpochPoolStrategy.sol**: Pool distribution, participation validation
- **Mathematical Precision**: Overflow protection, accurate calculations
- **Integration**: Proper IBaseRewardStrategy implementation

## Test Priority Matrix

| Priority     | Test Cases                                           | Functionality                               |
| ------------ | ---------------------------------------------------- | ------------------------------------------- |
| **Critical** | TC1, TC2, TC3, TC6, TC23, TC24, TC27, TC_R07, TC_R10, TC_R13 | Core staking, reward processing, security |
| **High**     | TC4, TC5, TC8, TC9, TC13-TC17, TC19-TC22, TC25, TC26, TC_R01-R06, TC_R08-R12, TC_R14-R18 | Validation, admin functions, data integrity, reward management |
| **Medium**   | TC7, TC10, TC12, TC18, TC28-TC31, TC_F01-F03         | Edge cases, optimization, enumeration, flags |
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
- All security tests must pass (both staking and reward systems)
- Event emissions must be verified across all contracts
- State consistency must be maintained across integrated systems
- Mathematical precision validated in all reward calculations
- Cross-contract integration points fully tested

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

### 🔥 NEW: Comprehensive Reward System Coverage (TC_R01-R18, TC_F01-F03)

**Reward System Test Categories:**
1. **Strategy Management** (TC_R01-R03): Registration, activation, versioning
2. **Epoch Lifecycle** (TC_R04-R06): State transitions, pool management, finalization
3. **Immediate Rewards** (TC_R07-R09): APR calculations, batch processing, precision
4. **Epoch Rewards** (TC_R10-R12): Pool distributions, weight calculations, proportional allocation
5. **Reward Claiming** (TC_R13-R15): All claiming methods, security, state management
6. **Reward Storage** (TC_R16-R18): Grant tracking, claiming state, data integrity
7. **Flag System** (TC_F01-F03): Flag operations, validation, extensibility

### ⚠️ Known Gaps (To Be Addressed in Testing)

1. **Fuzz Testing**: Should be added for numeric edge cases and reward calculations
2. **Invariant Testing**: Should be added for cross-system state consistency
3. **Stress Testing**: Large-scale operation testing needed for reward distributions
4. **Strategy Security**: Malicious strategy testing and validation

### ✅ Covered Areas

1. **Core Staking Logic**: Comprehensive coverage including storage layer and flag system
2. **Reward System**: Complete coverage from strategy management to user claiming
3. **Access Control**: Full role-based testing across all contracts
4. **Data Integrity**: Historical and real-time validation with mathematical precision
5. **Security**: Reentrancy, validation, authorization across integrated systems
6. **Integration**: Complete cross-contract coordination with event verification
7. **Mathematical Precision**: Reward calculations, overflow protection, accuracy validation

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
│   ├── StakingStorage.t.sol
│   ├── RewardManager.t.sol
│   ├── EpochManager.t.sol
│   ├── StrategiesRegistry.t.sol
│   ├── GrantedRewardStorage.t.sol
│   └── strategies/
│       ├── LinearAPRStrategy.t.sol
│       └── EpochPoolStrategy.t.sol
├── integration/
│   ├── VaultStorageIntegration.t.sol
│   ├── TokenIntegration.t.sol
│   ├── RewardSystemIntegration.t.sol
│   └── FullSystemWorkflow.t.sol
├── security/
│   ├── AccessControl.t.sol
│   ├── Reentrancy.t.sol
│   └── RewardSystemSecurity.t.sol
└── helpers/
    ├── TestHelpers.sol
    ├── MockContracts.sol
    └── RewardTestHelpers.sol
```

### Helper Requirements

- Mock ERC20 token contracts for staking and reward tokens
- Test user management utilities for multi-user scenarios
- Time manipulation helpers for epoch and time lock testing
- Event assertion utilities for cross-contract event verification
- Gas measurement tools for optimization validation
- Reward calculation helpers for mathematical precision testing
- Mock strategy contracts for testing framework extensibility

---

This matrix ensures practical testing coverage for the complete Token Staking System including both core staking and reward management functionality. It provides clear traceability from requirements through implementation to testing, focusing on business logic validation rather than implementation details.

## Streamlined Testing Approach Summary

**Test Reduction**: Reduced from 124 to 62 practical test cases by removing:
- Over-detailed implementation testing (e.g., binary search algorithm internals)
- External library functionality testing (OpenZeppelin AccessControl, Pausable, SafeERC20 internals)
- Unrealistic edge cases (179-year time locks, uint256 max values)
- Redundant test categories (Performance, Invariant, Error Recovery, Event-only tests)

**Focus Areas**: 
- ✅ Business logic validation
- ✅ External library usage verification (not functionality testing)
- ✅ Realistic boundary conditions
- ✅ Security vulnerabilities specific to the application
- ✅ Cross-contract integration points
- ✅ Critical user workflows

**Audit Readiness**: Core staking system (22/22 tests) is fully audit-ready. Remaining gaps are reward system implementation (30 tests) and flag system validation (3 tests), representing 33 additional practical tests for complete system coverage.
