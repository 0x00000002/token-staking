# Token Staking System: Test Coverage Matrix

## Overview

This matrix maps use cases to test cases and functions, ensuring practical coverage of the Token Staking System. It provides traceability from requirements through implementation to testing for both core staking and the rewards system.

**Scope**: This document covers the entire system, including core staking contracts (`StakingVault`, `StakingStorage`) and the reward management system (`PoolManager`, `StrategiesRegistry`, `RewardManager`, `ClaimsJournal`, and strategy implementations).

## Use Case to Test Cases Mapping

| Use Case ID  | Description                            | Test Cases                                                             |
| :----------- | :------------------------------------- | :--------------------------------------------------------------------- |
| **UC1-UC20** | _Core Staking, Roles, and Integration_ | TC1-TC28, TC_F01-F03                                                   |
| **UC21**     | **Pool and Strategy Configuration**    | TC_R01, TC_R02                                                         |
| **UC22**     | **Pool Finalization**                  | TC_R03                                                                 |
| **UC23**     | **Unified Reward Claiming**            | TC_R04, TC_R05, TC_R06, TC_R07, TC_R08, TC_R10, TC_R12, TC_R13, TC_R14 |
| **UC24**     | **Reward Funding**                     | TC_R09                                                                 |

## Function to Test Cases Matrix

### Core Staking Contracts (Largely Unchanged)

| Contract                                 | Function                 | Required Test Cases        |
| :--------------------------------------- | :----------------------- | :------------------------- |
| **StakingVault**                         | `stake(uint128, uint16)` | TC1, TC4, TC5, TC22, TC23  |
| **StakingVault**                         | `unstake(bytes32)`       | TC2, TC3, TC22, TC23       |
| **StakingStorage**                       | `createStake(...)`       | TC1, TC6, TC24, TC25, TC26 |
| **StakingStorage**                       | `removeStake(...)`       | TC2, TC24, TC25, TC26      |
| _... (other core staking functions) ..._ | _..._                    | _..._                      |

### Reward System Contracts

| Contract                    | Function                       | Required Test Cases                |
| :-------------------------- | :----------------------------- | :--------------------------------- |
| **PoolManager**             | `upsertPool(...)`              | TC_R01, TC_R17, TC_R18, TC_R19 (✔) |
| **PoolManager**             | `announcePool(...)`            | (Not Covered) (❌)                 |
| **PoolManager**             | `assignStrategyToPool(...)`    | TC_R02 (✔)                         |
| **PoolManager**             | `setPoolTotalStakeWeight(...)` | TC_R03, TC_R15 (✔)                 |
| **PoolManager**             | `getStrategiesFromLayer(...)`  | TC_R11 (✔)                         |
| **PoolManager**             | `markStrategyAsIgnored(...)`   | TC_R20 (✔)                         |
| **PoolManager**             | `unmarkStrategyAsIgnored(...)` | TC_R21 (✔)                         |
| **PoolManager**             | `getPool(...)`                 | TC_R22 (❌)                        |
| **StrategiesRegistry**      | `registerStrategy(...)`        | TC_SR04 (✔)                        |
| **StrategiesRegistry**      | `enableStrategy(...)`          | TC_SR02, TC_SR06, TC_SR07 (✔)      |
| **StrategiesRegistry**      | `disableStrategy(...)`         | TC_SR02, TC_SR05 (✔)               |
| **StrategiesRegistry**      | `removeStrategy(...)`          | TC_SR01 (❌)                       |
| **RewardManager**           | `fundStrategy(...)`            | TC_R09 (✔)                         |
| **RewardManager**           | `claimReward(...)`             | TC_R04-R08, TC_R25-R31 (✔)         |
| **RewardManager**           | `calculateRewardsForPool(...)` | TC_R12 (✔)                         |
| **RewardManager**           | `calculateReward(...)`         | TC_R10, TC_R32 (✔)                 |
| **RewardManager**           | `pause()`                      | TC_R14 (✔)                         |
| **RewardManager**           | `unpause()`                    | TC_R14 (✔)                         |
| **RewardManager**           | `batchClaimReward(...)`        | TC_R13 (✔)                         |
| **RewardManager**           | `batchCalculateReward(...)`    | TC_R24 (❌)                        |
| **RewardManager**           | `setClaimsJournal(...)`        | TC_R23 (❌)                        |
| **ClaimsJournal**           | `recordClaim(...)`             | TC_R04, TC_R05 (✔)                 |
| **ClaimsJournal**           | `getLastClaimDay(...)`         | TC_R04, TC_R05 (✔)                 |
| **ClaimsJournal**           | `getLayerClaimState(...)`      | TC_R08                             |
| **FullStakingStrategy**     | `calculateReward(...)`         | TC_FS01, TC_FS02, TC_FS03, TC_FS04 |
| **StandardStakingStrategy** | `calculateReward(...)`         | TC_SS01, TC_SS02                   |

### Granted Reward Storage

| Contract                 | Function                        | Required Test Cases |
| :----------------------- | :------------------------------ | :------------------ |
| **GrantedRewardStorage** | `grantReward(...)`              | TC_GRS01 (❌)       |
| **GrantedRewardStorage** | `markRewardClaimed(...)`        | TC_GRS02 (❌)       |
| **GrantedRewardStorage** | `batchMarkClaimed(...)`         | TC_GRS03 (❌)       |
| **GrantedRewardStorage** | `getUserRewards(...)`           | TC_GRS04 (❌)       |
| **GrantedRewardStorage** | `getUserClaimableAmount(...)`   | TC_GRS05 (❌)       |
| **GrantedRewardStorage** | `getUserClaimableRewards(...)`  | TC_GRS06 (❌)       |
| **GrantedRewardStorage** | `getUserEpochRewards(...)`      | TC_GRS07 (❌)       |
| **GrantedRewardStorage** | `getUserRewardsPaginated(...)`  | TC_GRS08 (❌)       |
| **GrantedRewardStorage** | `updateNextClaimableIndex(...)` | TC_GRS09 (❌)       |

## Gap Analysis

### Investigation Workflow

1.  **Check forge coverage**: `forge coverage --report summary`. Focus on contracts in `src/reward-system/` and `src/`.
2.  **Find uncovered functions** in the coverage report.
3.  **Look up required test cases** in the "Function to Test Cases Matrix" above.
4.  **Implement missing tests** if any gaps are found. All tests are in `tests/unit/`.
