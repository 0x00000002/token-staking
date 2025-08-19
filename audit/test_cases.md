# Token Staking System: Test Cases

## Overview

This document defines comprehensive test cases for the **TOKEN STAKING & REWARD SYSTEM**, including both the core staking subsystem and the comprehensive reward management system. Test cases are mapped to use cases defined in `use_cases.md` and cover all contracts and integration points.

**Status**: This specification defines the complete test suite needed for audit readiness. Many tests are missing and need to be implemented.

## Test Categories Overview

- **Core Staking Tests (TC1-TC28)**: 28 practical test cases covering StakingVault and StakingStorage
- **Reward System Tests**: 43 test cases covering complete reward functionality
- **Granted Reward Storage Tests**: 9 test cases for reward ledger functionality
- **Flag System Tests (TC_F01-TC_F03)**: 3 test cases for extensible flag operations
- **Integration Tests (TC_I01-TC_I07)**: 7 simplified test cases for cross-system integration

**Total: 90 practical test cases** _(Removed over-engineered/redundant tests)_

**Removed Categories:**

- Edge case tests (TC29-TC43) - Over-engineered implementation details
- Performance Tests - Use separate performance testing
- Invariant Tests - Covered by functional tests
- Error Recovery Tests - Redundant with error handling
- Event Tests - Events verified within functional tests
- Mathematical precision tests - Focus on business logic only

## Core Staking Function Tests

### TC1: Successful Direct Stake (UC1)

```gherkin
Feature: Direct Token Staking
  Scenario: User successfully stakes tokens with time lock
    Given the staking system is not paused
    And user has sufficient token balance (>= stake amount)
    And user has approved StakingVault to spend tokens (>= stake amount)
    And stake amount is greater than zero
    And days lock is valid uint16 value
    When user calls StakingVault.stake(amount, daysLock)
    Then tokens should be transferred from user to StakingVault
    And unique stake ID should be generated using compound key: bytes32((uint256(uint160(staker)) << 96) | stakesCounter)
    And StakingStorage.createStake should be called with correct parameters
    And stake should be recorded with isFromClaim = false
    And user's stakesCount should be incremented
    And user's totalStaked should be increased by amount
    And global currentTotalStaked should be increased by amount
    And checkpoint should be created for current day
    And daily snapshot should be updated
    And Staked event should be emitted from both contracts
    And stake ID should be returned to caller
```

### TC2: Successful Unstaking (UC2)

```gherkin
Feature: Token Unstaking
  Scenario: User successfully unstakes matured tokens
    Given user has an active stake with valid stake ID
    And current day >= stake day + days lock (time lock expired)
    And the staking system is not paused
    And stake has not been previously unstaked (unstakeDay == 0)
    When user calls StakingVault.unstake(stakeId)
    Then StakingStorage.getStake should be called to retrieve stake details
    And time lock validation should pass
    And StakingStorage.removeStake should be called
    And stake should be marked as unstaked (unstakeDay set to current day)
    And user's stakesCount should be decremented
    And user's totalStaked should be decreased by stake amount
    And global currentTotalStaked should be decreased by stake amount
    And checkpoint should be created with reduced balance
    And daily snapshot should be updated
    And tokens should be transferred back to user
    And Unstaked event should be emitted from both contracts
```

### TC3: Failed Unstaking - Stake Not Matured (UC11)

```gherkin
Feature: Time Lock Validation
  Scenario: User attempts to unstake before time lock expires
    Given user has an active stake with 30 days lock
    And only 15 days have passed since staking
    And current day < stake day + days lock
    When user attempts to unstake(stakeId)
    Then transaction should revert with StakeNotMatured error
    And error should include stakeId, matureDay, and currentDay
    And no tokens should be transferred
    And no state should be modified in either contract
```

### TC4: SafeERC20 Basic Usage Verification (UC12)

```gherkin
Feature: SafeERC20 Library Usage
  Scenario: Verify SafeERC20 is used for token operations
    Given StakingVault uses SafeERC20 for token transfers
    When token transfers occur during stake/unstake
    Then SafeERC20.transferFrom and SafeERC20.transfer should be used
    And basic token operations should complete successfully
```

### TC5: Failed Staking - Zero Amount (UC12)

```gherkin
Feature: Amount Validation
  Scenario: User attempts to stake zero tokens
    Given user calls stake with amount = 0
    When user attempts to stake(0, 10)
    Then transaction should revert with InvalidAmount error
    And no tokens should be transferred
    And no stake should be created
```

## Claim Contract Integration Tests

### TC6: Stake from Claim Contract (UC8)

```gherkin
Feature: Claim Integration
  Scenario: Claiming contract stakes on behalf of user
    Given claiming contract has CLAIM_CONTRACT_ROLE
    And the staking system is not paused
    And tokens have been transferred to StakingVault beforehand
    And staker address is valid (not zero)
    And amount is greater than zero
    When claiming contract calls stakeFromClaim(staker, amount, daysLock)
    Then unique stake ID should be generated for the staker
    And StakingStorage.createStake should be called with isFromClaim = true
    And stake should be created for specified staker (not claiming contract)
    And stake should be marked as from claim
    And staker's totals should be updated
    And global totals should be updated
    And checkpoint should be created for staker
    And Staked event should be emitted
    And stake ID should be returned to claiming contract
```

### TC7: Basic Role Verification - Claim Contract (UC14)

```gherkin
Feature: Basic Access Control
  Scenario: Verify CLAIM_CONTRACT_ROLE enforcement
    Given contract does not have CLAIM_CONTRACT_ROLE
    When contract calls stakeFromClaim(staker, amount, daysLock)
    Then transaction should revert with AccessControl error
```

## Manager Role Tests

### TC8: Basic Pausable Usage (UC4)

```gherkin
Feature: Pausable Library Usage
  Scenario: Basic pause functionality
    Given actor has MANAGER_ROLE
    When manager calls StakingVault.pause()
    Then system should be paused
    And stake/unstake operations should be blocked
```

### TC9: Basic Unpause Usage (UC5)

```gherkin
Feature: Pausable Library Usage
  Scenario: Basic unpause functionality
    Given actor has MANAGER_ROLE and system is paused
    When manager calls StakingVault.unpause()
    Then system should be unpaused
    And operations should be enabled again
```

### TC10: Basic Role Verification - Manager (UC14)

```gherkin
Feature: Basic Access Control
  Scenario: Verify MANAGER_ROLE enforcement
    Given user does not have MANAGER_ROLE
    When user attempts to call pause()
    Then transaction should revert with AccessControl error
```

## Admin Role Tests

### TC11: Emergency Token Recovery (UC6)

```gherkin
Feature: Emergency Recovery
  Scenario: Multisig recovers tokens from contract
    Given actor has MULTISIG_ROLE
    And StakingVault has sufficient token balance
    And recovery amount is greater than zero
    When multisig calls emergencyRecover(token, amount)
    Then specified tokens should be transferred to multisig
    And contract balance should decrease by amount
```

### TC12: Role Management (UC7)

```gherkin
Feature: Role Management
  Scenario: Admin grants role to address
    Given actor has DEFAULT_ADMIN_ROLE
    And target address does not have specific role
    When admin calls grantRole(role, address)
    Then target address should have the role
    And RoleGranted event should be emitted

  Scenario: Admin revokes role from address
    Given actor has DEFAULT_ADMIN_ROLE
    And target address has specific role
    When admin calls revokeRole(role, address)
    Then target address should lose the role
    And RoleRevoked event should be emitted
```

## Query Function Tests

### TC13: Get Stake Information (UC3)

```gherkin
Feature: Stake Queries
  Scenario: Query specific stake details
    Given user has an active stake
    When getStake(staker, stakeId) is called
    Then stake details should be returned
    And details should include amount, stakeDay, unstakeDay, daysLock, isFromClaim
    And no state changes should occur
```

### TC14: Get Staker Information (UC3)

```gherkin
Feature: Staker Queries
  Scenario: Query staker summary information
    Given user has multiple stakes
    When getStakerInfo(staker) is called
    Then staker info should be returned
    And info should include stakesCount, totalStaked, lastCheckpointDay
    And no state changes should occur
```

### TC15: Historical Balance Queries (UC9)

```gherkin
Feature: Historical Tracking
  Scenario: Query historical staking balance
    Given staking activity has occurred over time
    And checkpoints have been created
    When getStakerBalanceAt(staker, targetDay) is called
    Then accurate historical balance should be returned
    And binary search should be used for efficiency
    And query should complete in O(log n) time
    And no state changes should occur
```

### TC16: Batch Historical Queries (UC9)

```gherkin
Feature: Batch Historical Queries
  Scenario: Query multiple stakers' historical balances
    Given multiple stakers with historical data
    When batchGetStakerBalances(stakers[], targetDay) is called
    Then array of historical balances should be returned
    And results should match individual queries
    And operation should be gas-efficient
    And no state changes should occur
```

### TC17: Global Statistics (UC9)

```gherkin
Feature: Global Statistics
  Scenario: Query current total staked amount
    Given multiple active stakes exist
    When getCurrentTotalStaked() is called
    Then current total should equal sum of all active stakes
    And value should match internal tracking

  Scenario: Query daily snapshot
    Given stakes have been created/removed on specific day
    When getDailySnapshot(day) is called
    Then snapshot should show total amount and count for that day
    And historical data should be accurate
```

### TC18: Staker Enumeration (UC10)

```gherkin
Feature: Staker Enumeration
  Scenario: Paginated staker retrieval
    Given multiple unique stakers exist
    When getStakersPaginated(offset, limit) is called
    Then correct subset of stakers should be returned
    And pagination should work correctly
    And total count should match getTotalStakersCount()
```

## Error Handling Tests

### TC19: Invalid Stake ID (UC12)

```gherkin
Feature: Stake Validation
  Scenario: User attempts operation with non-existent stake ID
    Given user provides invalid stake ID
    When user attempts unstake(invalidStakeId)
    Then transaction should revert with StakeNotFound error
    And error should include staker and stakeId
    And no tokens should be transferred
```

### TC20: Already Unstaked Stake (UC12)

```gherkin
Feature: Stake State Validation
  Scenario: User attempts to unstake already unstaked stake
    Given user has previously unstaked a stake
    And stake has unstakeDay != 0
    When user attempts to unstake same stake again
    Then transaction should revert with StakeAlreadyUnstaked error
    And no tokens should be transferred
```

### TC21: Not Stake Owner (UC12) - Covered by TC19

```gherkin
Feature: Ownership Validation
  Scenario: User attempts to unstake someone else's stake
    Given stakeId belongs to userB
    When userA attempts to call unstake(stakeId)
    Then the transaction should revert with StakeNotFound error
    And This is because the design of StakingStorage uses `msg.sender` to look up stakes, so the stakeId is not found for the caller. This scenario is covered by TC19.
    And no tokens should be transferred
```

### TC22: Basic Pausable Verification (UC13)

```gherkin
Feature: Pausable Library Usage
  Scenario: Operations blocked when paused
    Given the staking system is paused
    When user calls stake() or unstake()
    Then transaction should revert with Pausable error
```

## Security Tests

### TC23: ReentrancyGuard Basic Usage Verification (UC15)

```gherkin
Feature: ReentrancyGuard Library Usage
  Scenario: Verify nonReentrant modifier usage
    Given StakingVault functions making external calls
    When stake() and unstake() are called
    Then these functions should have nonReentrant modifier
    And normal operations should work with protection in place
```

### TC24: AccessControl Basic Usage Verification (UC14)

```gherkin
Feature: AccessControl Library Usage
  Scenario: Basic role enforcement verification
    Given user does not have CONTROLLER_ROLE
    When user attempts to call StakingStorage.createStake directly
    Then transaction should revert with AccessControl error
```

## Core Business Logic Tests

### TC25: Basic Data Integrity (UC16-17)

```gherkin
Feature: Core Data Consistency
  Scenario: Stake and unstake state consistency
    Given multiple stake and unstake operations
    When operations complete
    Then global currentTotalStaked should equal sum of active stakes
    And user totals should match individual stakes
    And state should be consistent across contracts
```

## Integration Tests

### TC26: Vault-Storage Integration (UC19)

```gherkin
Feature: Contract Integration
  Scenario: Basic vault-storage coordination
    Given both contracts are deployed and configured
    When staking operations are performed
    Then vault should correctly call storage functions
    And CONTROLLER_ROLE should be properly enforced
    And data should remain consistent across contracts
```

### TC27: Token Integration (UC18)

```gherkin
Feature: Token Integration
  Scenario: Basic token operations
    Given standard ERC20 token
    When stake/unstake operations occur
    Then token transfers should work correctly
    And balances should be updated appropriately
```

### TC28: Basic Time Lock Validation

```gherkin
Feature: Time Lock Business Logic
  Scenario: Realistic time lock boundaries (7-365 days)
    Given stake with 30 day time lock
    When 30 days have passed
    Then unstaking should be allowed
    And time lock validation should work correctly
```

# ═══════════════════════════════════════════════════════════════════════════

# 🔥 MISSING TEST CASES - CRITICAL FOR AUDIT READINESS

# ═══════════════════════════════════════════════════════════════════════════

## REWARD SYSTEM TESTS

### PoolManager (Scheduler) Tests

### TC_R01: Pool Creation and Configuration

```gherkin
Feature: Pool Scheduling and Configuration
  Scenario: Manager successfully creates a new pool
    Given caller has MANAGER_ROLE
    When manager calls upsertPool() with valid start/end days
    Then a new pool should be created with a unique ID
    And the pool's startDay and endDay should be set correctly
    And PoolUpserted event should be emitted

  Scenario: Manager fails to update a started pool
    Given a pool's startDay has already passed
    When manager calls upsertPool() for that poolId
    Then the transaction should revert with PoolAlreadyStarted()
```

### TC_R02: Strategy Assignment

```gherkin
Feature: Strategy Assignment to Pools
  Scenario: Manager successfully assigns a strategy to a pool layer
    Given a pool exists and has not started
    And caller has MANAGER_ROLE
    When manager calls assignStrategyToPool() with poolId, layerId, strategyId, and exclusivity
    Then the strategy should be added to the pool's specified layer
    And the strategy's exclusivity should be recorded
    And StrategyAssigned event should be emitted

  Scenario: Manager fails to assign a strategy to a started pool
    Given a pool has already started
    When manager calls assignStrategyToPool()
    Then the transaction should revert with PoolAlreadyStarted()
```

### TC_R03: Pool Weight Finalization

```gherkin
Feature: Pool Weight Finalization for Dependent Strategies
  Scenario: Controller successfully sets the total stake weight
    Given a pool has ended (current day > endDay)
    And caller has CONTROLLER_ROLE
    When controller calls setPoolTotalStakeWeight() with a non-zero weight
    Then the pool's totalStakeWeight should be updated
    And PoolWeightSet event should be emitted

  Scenario: Controller fails to set weight for an active pool
    Given a pool is still active (current day <= endDay)
    When controller calls setPoolTotalStakeWeight()
    Then the transaction should revert with PoolNotEnded()

  Scenario: Unauthorized actor fails to set weight
    Given caller does not have CONTROLLER_ROLE
    When caller attempts to setPoolTotalStakeWeight()
    Then transaction should revert with AccessControl error
```

### TC_R17: Upsert Pool - Fail - Pool Does Not Exist

```gherkin
Feature: Pool Creation and Configuration
  Scenario: Manager attempts to update a non-existent pool
    Given caller has MANAGER_ROLE
    When manager calls upsertPool() with a non-existent poolId (not 0)
    Then the transaction should revert with PoolDoesNotExist()
```

### TC_R18: Upsert Pool - Fail - Parent Pool Is Self

```gherkin
Feature: Pool Creation and Configuration
  Scenario: Manager attempts to create/update a pool with itself as parent
    Given caller has MANAGER_ROLE
    When manager calls upsertPool() with _parentPoolId equal to the poolId
    Then the transaction should revert with ParentPoolIsSelf()
```

### TC_R19: Upsert Pool - Fail - Invalid Dates

```gherkin
Feature: Pool Creation and Configuration
  Scenario: Manager attempts to create/update a pool with invalid dates
    Given caller has MANAGER_ROLE
    When manager calls upsertPool() with _startDay >= _endDay
    Then the transaction should revert with InvalidDates()
```

### TC_R20: Mark Strategy As Ignored - Success

```gherkin
Feature: Pool Configuration
  Scenario: Manager successfully marks a strategy as ignored
    Given a pool exists with a strategy assigned to a layer
    And caller has MANAGER_ROLE
    When manager calls markStrategyAsIgnored(poolId, layer, strategyId)
    Then the strategy should be marked as ignored
```

### TC_R21: Unmark Strategy As Ignored - Success

```gherkin
Feature: Pool Configuration
  Scenario: Manager successfully unmarks a strategy as ignored
    Given a pool exists with a strategy assigned to a layer and marked as ignored
    And caller has MANAGER_ROLE
    When manager calls unmarkStrategyAsIgnored(poolId, layer, strategyId)
    Then the strategy should no longer be marked as ignored
```

### TC_R22: Get Pool - Fail - Pool Does Not Exist

```gherkin
Feature: Pool Queries
  Scenario: User attempts to query a non-existent pool
    Given a pool with the given poolId does not exist
    When a user calls getPool(poolId)
    Then the function should revert with PoolDoesNotExist()
```

### FundingManager Tests

### TC_FM01: Fund Strategy - Invalid Strategy

```gherkin
Feature: Funding Strategy
  Scenario: Manager attempts to fund a non-existent strategy
    Given caller has MANAGER_ROLE
    When manager calls fundStrategy() with an invalid strategyId
    Then the transaction should revert with StrategyNotExist()
```

### TC_FM02: Assign Reward to Pool - Happy Path

```gherkin
Feature: Assign Reward to Pool
  Scenario: Manager successfully assigns rewards to a pool
    Given caller has MANAGER_ROLE
    And a strategy is funded in the FundingManager
    When manager calls assignRewardToPool() with a valid poolId, strategyId, and amount
    Then the rewardAssignedToPool mapping should be updated correctly
    And no revert should occur
```

## RewardManager (Orchestrator) & ClaimsJournal (Ledger) Tests

### TC_R04: Successful Claim (Pool Size Dependent Strategy)

```gherkin
Feature: Claiming Rewards for Dependent Strategies
  Scenario: User claims a reward after a pool is finalized
    Given a POOL_SIZE_DEPENDENT strategy exists
    And its pool has ended and its totalStakeWeight has been set
    And the user has an eligible stake
    And the user has NOT claimed this reward before
    When user calls RewardManager.claimReward(poolId, strategyId, stakeId)
    Then RewardManager verifies the pool is calculated
    And it retrieves the strategy type (POOL_SIZE_DEPENDENT)
    And it calls the correct `calculateReward` overload on the strategy contract
    And ClaimsJournal.recordClaim() is called to log the claim day and layer state
    And the calculated reward amount is transferred to the user
    And a RewardClaimed event is emitted
```

### TC_R05: Successful Claim (Pool Size Independent Strategy)

```gherkin
Feature: Claiming Rewards for Independent Strategies
  Scenario: User claims a reward from an active pool
    Given a POOL_SIZE_INDEPENDENT strategy exists
    And its pool is currently active
    And the user has an eligible stake
    When user calls RewardManager.claimReward(poolId, strategyId, stakeId)
    Then RewardManager retrieves the strategy type (POOL_SIZE_INDEPENDENT)
    And it calls the correct `calculateReward` overload, passing the `lastClaimDay` from ClaimsJournal
    And ClaimsJournal.recordClaim() updates the `lastClaimDay` to the current day
    And the calculated reward is transferred to the user
    And a RewardClaimed event is emitted
```

### TC_R06: Failed Claim - Pool Not Finalized (Dependent Strategy)

```gherkin
Feature: Claim Validation for Dependent Strategies
  Scenario: User attempts to claim before pool is calculated
    Given a POOL_SIZE_DEPENDENT strategy's pool has ended but weight is NOT set
    When user calls claimReward()
    Then the transaction should revert with PoolNotCalculated()
```

### TC_R07: Failed Claim - Double Claim (Dependent Strategy)

```gherkin
Feature: Double-Claim Prevention
  Scenario: User attempts to claim a dependent reward twice
    Given a user has already successfully claimed a POOL_SIZE_DEPENDENT reward
    And ClaimsJournal has a record for that stakeId and strategyId
    When the user calls claimReward() for the same reward again
    Then the transaction should revert with "Reward already claimed"
```

### TC_R08: Failed Claim - Exclusivity Violation

```gherkin
Feature: Claim Exclusivity Enforcement
  Scenario: User attempts to claim a normal reward after an exclusive one on the same layer
    Given a user has claimed a reward from an EXCLUSIVE strategy on layer 1
    And ClaimsJournal has recorded this exclusive claim
    When the user attempts to call claimReward() for a NORMAL strategy on the same layer 1
    Then the transaction should revert with LayerIsExclusive()
```

### TC_R09: Funding a Strategy

```gherkin
Feature: Reward Funding
  Scenario: Manager successfully funds a strategy
    Given caller has MANAGER_ROLE
    And has approved RewardManager to spend reward tokens
    When manager calls fundStrategy(strategyId, amount)
    Then reward tokens are transferred to RewardManager
    And the balance for the strategyId is increased
    And StrategyFunded event is emitted

  Scenario: Manager fails to fund a strategy with zero amount
    Given caller has MANAGER_ROLE
    When manager calls fundStrategy(strategyId, 0)
    Then the transaction should revert with AmountMustBeGreaterThanZero()
```

### TC_R10: View Claimable Reward

```gherkin
Feature: Reward Preview
  Scenario: User checks pending reward amount
    Given a user is eligible for a reward
    When user calls getClaimableReward(poolId, strategyId, stakeId)
    Then the function should return the calculated pending reward amount
    And no state change should occur (it is a view function)
```

### TC_R11: Get Layer Strategies and Exclusivity

```gherkin
Feature: Querying Pool Layer Strategies
  Scenario: Client queries a pool layer to get its constituent strategies
    Given a pool exists with multiple layers
    And each layer has one or more strategies assigned with different exclusivities (NORMAL, EXCLUSIVE, SEMI_EXCLUSIVE)
    When a client calls getStrategiesFromLayer(poolId, layerId)
    Then the function should return two arrays: strategyIds and exclusivities
    And the arrays should contain the correct strategy IDs and exclusivity enums for that specific layer
    And the order of strategies in both arrays should be consistent
    And calling the function for a layer with no strategies should return empty arrays
```

### TC_R12: Calculate All Rewards for a Pool Layer

```gherkin
Feature: Reward Calculation Preview for a Pool Layer
  Scenario: User previews all available rewards for a specific stake on a given pool layer
    Given a user has an active stake
    And a pool is configured with multiple strategies on a layer
    And the strategies have been funded
    When the user calls calculateRewardsForPool(stakeId, poolId, layerId)
    Then the function should return the strategy IDs, the calculated reward amounts, and the exclusivity for each strategy on that layer
    And the calculated amounts should be correct for both POOL_SIZE_DEPENDENT and POOL_SIZE_INDEPENDENT strategies
    And the function should correctly use the staker's address from the stakeId, not the caller's address
    And no state change should occur (it is a view function)
```

### TC_R23: Set Claims Journal - Access Control

```gherkin
Feature: Claims Journal Management
  Scenario: Non-admin attempts to set the ClaimsJournal address
    Given caller does NOT have the DEFAULT_ADMIN_ROLE
    When the caller attempts to call setClaimsJournal()
    Then the transaction should revert with an AccessControl error
```

### TC_R24: Batch Calculate Reward - Happy Path

```gherkin
Feature: Batch Reward Calculation
  Scenario: User calculates rewards for multiple stakes/pools/strategies in a single call
    Given a user has multiple eligible stakes across different pools and strategies
    And all pools and strategies are correctly configured and funded
    When the user calls batchCalculateReward() with the stakeIds, poolIds, and strategyIds for all desired calculations
    Then the function should return an array of calculated reward amounts for each entry
    And no state change should occur (it is a view function)
```

### TC_R25: Claim Reward - No Reward To Claim

```gherkin
Feature: Claim Reward Validation
  Scenario: User attempts to claim a reward when the calculated amount is zero
    Given a user has an eligible stake
    And the reward calculation for the given stake/pool/strategy results in zero
    When the user calls claimReward()
    Then the transaction should revert with NoRewardToClaim()
```

### TC_R26: Claim Reward - Not Stake Owner

```gherkin
Feature: Claim Reward Validation
  Scenario: User attempts to claim a reward for a stake they do not own
    Given a stake exists that is owned by another address
    When the current caller attempts to call claimReward() for that stake
    Then the transaction should revert with NotStakeOwner()
```

### TC_R27: Claim Reward - Strategy Not Exist

```gherkin
Feature: Claim Reward Validation
  Scenario: User attempts to claim a reward for a non-existent strategy
    Given a pool and stake exist
    When the user attempts to call claimReward() with an invalid strategyId
    Then the transaction should revert with StrategyNotExist()
```

### TC_R28: Claim Reward - Pool Not Ended (Dependent Strategy)

```gherkin
Feature: Claim Reward Validation
  Scenario: User attempts to claim a POOL_SIZE_DEPENDENT reward before the pool has ended
    Given a POOL_SIZE_DEPENDENT strategy exists
    And its pool is still active (current day <= endDay)
    When the user attempts to call claimReward()
    Then the transaction should revert with PoolNotEnded()
```

### TC_R29: Claim Reward - Pool Not Started (Independent Strategy)

```gherkin
Feature: Claim Reward Validation
  Scenario: User attempts to claim a POOL_SIZE_INDEPENDENT reward before the pool has started
    Given a POOL_SIZE_INDEPENDENT strategy exists
    And its pool has not yet started (current day < startDay)
    When the user attempts to call claimReward()
    Then the transaction should revert with PoolNotStarted()
```

### TC_R30: Claim Reward - Layer Already Has Claim

```gherkin
Feature: Claim Exclusivity Enforcement
  Scenario: User attempts to claim a NORMAL reward after another NORMAL reward on the same layer
    Given a user has claimed a reward from a NORMAL strategy on layer 1
    And ClaimsJournal has recorded this claim
    When the user attempts to call claimReward() for another NORMAL strategy on the same layer 1
    Then the transaction should revert with LayerAlreadyHasClaim()
```

### TC_R31: Claim Reward - Layer Already Has Semi-Exclusive Claim

```gherkin
Feature: Claim Exclusivity Enforcement
  Scenario: User attempts to claim a SEMI_EXCLUSIVE reward after another SEMI_EXCLUSIVE reward on the same layer
    Given a user has claimed a reward from a SEMI_EXCLUSIVE strategy on layer 1
    And ClaimsJournal has recorded this claim
    When the user attempts to call claimReward() for another SEMI_EXCLUSIVE strategy on the same layer 1
    Then the transaction should revert with LayerAlreadyHasSemiExclusiveClaim()
```

### TC_R32: Calculate Reward - Pool Not Initialized Or Calculated

```gherkin
Feature: Reward Calculation Validation
  Scenario: User attempts to calculate a POOL_SIZE_DEPENDENT reward before the pool's total weight is set
    Given a POOL_SIZE_DEPENDENT strategy exists
    And its pool has ended but its totalStakeWeight has NOT been set
    When the user attempts to call claimReward() or calculateReward()
    Then the transaction should revert with PoolNotInitializedOrCalculated()
```

### TC_SCS01: Simple Strategy Full Period Calculation

```gherkin
Feature: Simple User Claimable Strategy Calculation
  Scenario: User has an active stake for the full period
    Given a user's stake was active for a full period
    And the reward rate is set
    When calculateReward is called for that period
    Then the returned reward should be (stake.amount * rate * days)
```

### TC_SCS02: Simple Strategy Partial Period Calculation

```gherkin
Feature: Simple User Claimable Strategy Calculation
  Scenario: User's stake was only active for a portion of the claim period
    Given a user's stake starts or ends within the claim period
    When calculateReward is called
    Then the reward should be calculated only for the effective days of overlap
```

### TC_RBK01: RewardBookkeeper Query Functions

```gherkin
Feature: RewardBookkeeper Data Queries
  Scenario: Querying a user with a mix of claimed and unclaimed rewards
    Given a user has multiple rewards, some of which are claimed
    When getUserClaimableAmount is called, it should return the sum of only unclaimed rewards
    When getUserClaimableRewards is called, it should return the rewards and indices of only unclaimed rewards
    When getUserRewardsPaginated is called, it should return the correct slice of all rewards
```

### FullStakingStrategy Tests

### TC_FS01: Calculate Reward - Ineligible - Stake Day Too Late

```gherkin
Feature: Full Staking Strategy Reward Calculation
  Scenario: User's stake starts after the grace period for the pool
    Given a stake exists with stakeDay > (poolStartDay + gracePeriod)
    When calculateReward is called
    Then the returned reward should be 0
```

### TC_FS02: Calculate Reward - Ineligible - Unstaked Too Early

```gherkin
Feature: Full Staking Strategy Reward Calculation
  Scenario: User's stake is unstaked before the pool ends
    Given a stake exists with unstakeDay != 0 AND unstakeDay < poolEndDay
    When calculateReward is called
    Then the returned reward should be 0
```

### TC_FS03: Calculate Reward - Zero Total Reward Amount

```gherkin
Feature: Full Staking Strategy Reward Calculation
  Scenario: Total reward amount for the pool is zero
    Given totalRewardAmount is 0
    When calculateReward is called
    Then the returned reward should be 0
```

### TC_FS04: Calculate Reward - Method Not Supported

```gherkin
Feature: Full Staking Strategy Reward Calculation
  Scenario: Calling the unsupported calculateReward overload
    Given the calculateReward overload with (user, stake, lastClaimDay, poolStartDay, poolEndDay) parameters
    When this function is called
    Then the transaction should revert with MethodNotSupported()
```

### TC_SR01: Strategy Removal

```gherkin
Feature: Strategy Registry Management
  Scenario: Manager successfully removes a strategy
    Given a strategy is registered with a specific ID
    When a manager calls removeStrategy with that ID
    Then isStrategyRegistered for that ID should return false
```

### StandardStakingStrategy Tests

### TC_SS01: Calculate Reward - Zero Total Reward Amount

```gherkin
Feature: Standard Staking Strategy Reward Calculation
  Scenario: Total reward amount for the pool is zero
    Given totalRewardAmount is 0
    When calculateReward is called
    Then the returned reward should be 0
```

### TC_SS02: Calculate Reward - Method Not Supported

```gherkin
Feature: Standard Staking Strategy Reward Calculation
  Scenario: Calling the unsupported calculateReward overload
    Given the calculateReward overload with (user, stake, lastClaimDay, poolStartDay, poolEndDay) parameters
    When this function is called
    Then the transaction should revert with MethodNotSupported()
```

## FLAG SYSTEM TESTS

### TC_F01: Basic Flag Operations (UC20)

```gherkin
Feature: Flag Library Operations
  Scenario: Set flag bit
    Given flag value starts at 0
    When Flags.set(flags, bitPosition) is called
    Then specified bit should be set to 1
    And other bits should remain unchanged
    And result should be returned

  Scenario: Unset flag bit
    Given flag has specific bit set
    When Flags.unset(flags, bitPosition) is called
    Then specified bit should be set to 0
    And other bits should remain unchanged

  Scenario: Check flag bit status
    Given flags with various bits set
    When Flags.isSet(flags, bitPosition) is called
    Then should return true if bit is set
    And should return false if bit is unset
    And should handle all 16 bit positions
```

### TC_F02: Stake Flag Integration (UC20)

```gherkin
Feature: Stake Flag Usage
  Scenario: Mark stake as from claim
    Given stake is created via stakeFromClaim
    When stake flags are checked
    Then IS_FROM_CLAIM_BIT should be set
    And flag should be queryable via Flags.isSet
    And stake should be identifiable as claim-originated

  Scenario: Regular stake flag handling
    Given stake is created via regular stake()
    When stake flags are checked
    Then IS_FROM_CLAIM_BIT should not be set
    And other flag bits should be available for future use
    And flag operations should work correctly

  Scenario: Multiple flag combinations
    Given stake needs multiple property flags
    When multiple flags are set simultaneously
    Then all flags should be maintained correctly
    And individual flags should be queryable
    And combinations should work as expected
```

### TC_F03: Flag System Extensibility (UC20)

```gherkin
Feature: Future Flag Extensions
  Scenario: Add new flag types
    Given system needs new stake properties
    When new flag constants are defined
    Then new flags should work with existing system
    And should not interfere with existing flags
    And should be backward compatible

  Scenario: Flag boundary conditions
    Given flags using all 16 available bits
    When flag operations are performed
    Then all bit positions should work correctly
    And should handle edge cases (bit 0, bit 15)
    And should not overflow or corrupt data

  Scenario: Flag persistence and queries
    Given stakes with various flag combinations
    When stakes are queried after time
    Then flags should persist correctly
    And should be queryable efficiently
    And should support filtering and analytics
```

## CROSS-SYSTEM INTEGRATION TESTS (CRITICAL)

### TC_I01: Basic Staking-Reward Data Integration (UC Integration)

```gherkin
Feature: Simplified Historical Data Integration
  Scenario: Basic reward calculation using staking data
    Given users have staking history
    When reward calculations are performed
    Then calculations should use accurate staking balances
    And results should match staking behavior
```

### TC_I02: Basic Multi-User Reward Distribution (UC Integration)

```gherkin
Feature: Simplified Multi-User Operations
  Scenario: Basic batch reward processing
    Given multiple users with active stakes
    When batch reward processing occurs
    Then all eligible users should receive correct rewards
    And state should remain consistent
```

### TC_I03: Basic Real-Time Staking During Epochs (UC Integration)

```gherkin
Feature: Simplified Dynamic Staking
  Scenario: Basic stake during active epoch
    Given epoch is currently active
    When user stakes tokens during epoch period
    Then stake should be properly accounted for in rewards
    And calculations should be correct
```

### TC_I04: Basic End-to-End User Journey (UC Integration)

```gherkin
Feature: Simplified User Experience Flow
  Scenario: Basic stake, earn, claim workflow
    Given user starts with tokens
    When user stakes, earns rewards, and claims
    Then all operations should work correctly
    And user should receive expected rewards
    And state should be consistent
```

### TC_I05: Basic Cross-Contract Event Coordination (UC Integration)

```gherkin
Feature: Simplified Event Coordination
  Scenario: Basic event coordination
    Given operations span multiple contracts
    When operations complete
    Then events should be emitted correctly
    And event data should be consistent
```

### TC_I06: Basic System State Consistency (UC Integration)

```gherkin
Feature: Simplified State Validation
  Scenario: Basic state consistency validation
    Given multiple operations across system components
    When operations complete
    Then total staked should equal sum of individual stakes
    And basic invariants should hold
```

### TC_I07: Basic System Evolution Support (UC Future)

```gherkin
Feature: Simplified System Evolution
  Scenario: Basic extensibility validation
    Given system needs to support new features
    When new components are added
    Then existing functionality should continue working
    And integration should be possible
```

### TC_R13: Batch Reward Claiming

```gherkin
Feature: Batch Reward Claiming
  Scenario: User successfully claims multiple different rewards in a single transaction
    Given a user is eligible for a reward from a POOL_SIZE_DEPENDENT strategy
    And the same user is also eligible for a reward from a POOL_SIZE_INDEPENDENT strategy
    And both pools and strategies are correctly configured and funded
    When the user calls batchClaimReward() with the stakeId and identifiers for both rewards
    Then both rewards should be calculated and transferred to the user correctly
    And the ClaimsJournal should be updated appropriately for both claims (lastClaimDay, exclusivity)
    And the final user balance and contract state should be consistent
```

### TC_R14: Pausable Access Control

```gherkin
Feature: Pausable Access Control
  Scenario: Unauthorized user attempts to pause or unpause the RewardManager
    Given a user does NOT have the MANAGER_ROLE
    When the user attempts to call pause() on RewardManager
    Then the transaction should revert with an AccessControl error
    When the user attempts to call unpause() on RewardManager
    Then the transaction should revert with an AccessControl error

  Scenario: Authorized manager successfully pauses and unpauses
    Given a user has the MANAGER_ROLE
    When the user calls pause()
    Then the contract should be paused and claimReward() should be blocked
    When the user calls unpause()
    Then the contract should be unpaused and claimReward() should be allowed again
```

### TC_R15: Pool Finalization Integrity

```gherkin
Feature: Pool Weight Finalization Integrity
  Scenario: Controller attempts to set the total stake weight on an already calculated pool
    Given a pool has ended and its totalStakeWeight has already been set
    When a controller calls setPoolTotalStakeWeight() for the same pool again
    Then the transaction should revert with PoolAlreadyCalculated()
```

---

## Summary

This document defines **90 focused test cases** for the complete Token Staking System:

- **Core Staking Tests (TC1-TC28)**: 28 test cases covering StakingVault and StakingStorage with focus on business logic
- **Reward System Tests**: 43 test cases covering complete reward functionality
- **Granted Reward Storage Tests**: 9 test cases for reward ledger functionality
- **Flag System Tests (TC_F01-TC_F03)**: 3 test cases for extensible flag operations
- **Integration Tests (TC_I01-TC_I07)**: 7 simplified test cases for cross-system integration

Each test case focuses on business logic and core functionality rather than implementation details or external library testing. The test cases provide practical coverage of all use cases defined in `use_cases.md` and ensure the system is audit-ready without over-engineering.
