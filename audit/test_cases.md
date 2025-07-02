# Token Staking System: Comprehensive Test Cases

## Overview

This document defines comprehensive test cases for the **COMPLETE TOKEN STAKING SYSTEM**, including both the core staking subsystem and the comprehensive reward management system. Test cases are mapped to use cases defined in `use_cases.md` and cover all contracts and integration points.

**Status**: This specification defines the complete test suite needed for audit readiness. Many tests are missing and need to be implemented.

## Test Categories Overview

- **Core Staking Tests (TC1-TC22)**: 22 practical test cases covering StakingVault and StakingStorage
- **Reward System Tests (TC_R01-TC_R30)**: 30 test cases covering complete reward functionality
- **Flag System Tests (TC_F01-TC_F03)**: 3 test cases for extensible flag operations
- **Integration Tests (TC_I01-TC_I07)**: 7 simplified test cases for cross-system integration

**Total: 62 practical test cases** *(Removed over-engineered/redundant tests)*

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

## REWARD SYSTEM TESTS (CRITICAL - ZERO COVERAGE)

### TC_R01: Strategy Registration (UC21)

```gherkin
Feature: Strategy Registration and Management
  Scenario: Successfully register new reward strategy
    Given admin has DEFAULT_ADMIN_ROLE
    And strategy contract implements IBaseRewardStrategy
    And strategy address is valid contract
    When admin calls StrategiesRegistry.registerStrategy(strategyAddress)
    Then strategy should be registered with new strategyId
    And strategy should be inactive by default
    And StrategyRegistered event should be emitted
    And strategy should be queryable by ID

  Scenario: Register strategy with invalid address
    Given admin attempts to register invalid address
    When registerStrategy(invalidAddress) is called
    Then transaction should revert with appropriate error
    And no strategy should be registered
```

### TC_R02: Strategy Status Management (UC21)

```gherkin
Feature: Strategy Activation and Deactivation
  Scenario: Activate registered strategy
    Given strategy is registered but inactive
    And admin has proper permissions
    When admin calls setStrategyStatus(strategyId, true)
    Then strategy should be marked as active
    And strategy should appear in active strategies list
    And StrategyStatusChanged event should be emitted

  Scenario: Deactivate active strategy
    Given strategy is currently active
    When admin calls setStrategyStatus(strategyId, false)
    Then strategy should be marked as inactive
    And strategy should be removed from active list
    And event should be emitted

  Scenario: Unauthorized strategy status change
    Given user does not have admin role
    When user attempts setStrategyStatus
    Then transaction should revert with access control error
```

### TC_R03: Strategy Versioning (UC21)

```gherkin
Feature: Strategy Version Management
  Scenario: Update strategy version
    Given strategy is registered
    And admin has proper permissions
    When admin calls updateStrategyVersion(strategyId)
    Then strategy version should be incremented
    And StrategyVersionUpdated event should be emitted
    And version should be queryable

  Scenario: Update version of non-existent strategy
    Given invalid strategy ID
    When updateStrategyVersion is called
    Then transaction should revert with StrategyNotFound error
```

### TC_R04: Epoch Announcement (UC22)

```gherkin
Feature: Epoch Lifecycle - Announcement Phase
  Scenario: Successfully announce new epoch
    Given admin has proper permissions
    And epoch parameters are valid (startDay > currentDay)
    And strategy ID exists and is active
    When admin calls EpochManager.announceEpoch(startDay, endDay, strategyId, estimatedPool)
    Then new epoch should be created with ANNOUNCED state
    And epoch should be added to announced epochs list
    And epoch ID should be returned
    And epoch should be queryable

  Scenario: Announce epoch with invalid parameters
    Given invalid epoch parameters (startDay <= currentDay)
    When announceEpoch is called
    Then transaction should revert with appropriate error
    And no epoch should be created
```

### TC_R05: Epoch State Transitions (UC22)

```gherkin
Feature: Epoch State Machine
  Scenario: ANNOUNCED to ACTIVE transition
    Given epoch is in ANNOUNCED state
    And current day >= epoch.startDay
    When updateEpochStates() is called
    Then epoch state should change to ACTIVE
    And epoch should be moved from announced to active list
    And state should be queryable

  Scenario: ACTIVE to ENDED transition
    Given epoch is in ACTIVE state
    And current day > epoch.endDay
    When updateEpochStates() is called
    Then epoch state should change to ENDED
    And epoch should be removed from active list

  Scenario: ENDED to CALCULATED transition
    Given epoch is in ENDED state
    And admin sets actual pool size
    When admin calls finalizeEpoch(epochId, participants, totalWeight)
    Then epoch state should change to CALCULATED
    And statistics should be recorded
    And calculatedAt timestamp should be set
```

### TC_R06: Epoch Pool Management (UC22)

```gherkin
Feature: Epoch Pool Size Management
  Scenario: Set actual pool size for ended epoch
    Given epoch is in ENDED state
    When admin calls setEpochPoolSize(epochId, actualAmount)
    Then epoch.actualPoolSize should be updated
    And epoch should be ready for calculation

  Scenario: Set pool size for non-ended epoch
    Given epoch is not in ENDED state
    When setEpochPoolSize is called
    Then transaction should revert with EpochNotEnded error
```

### TC_R07: Immediate Reward Calculation (UC23)

```gherkin
Feature: APR-Style Reward Processing
  Scenario: Calculate immediate rewards for batch of users
    Given strategy is registered and active
    And strategy type is IMMEDIATE
    And users have stakes within time period
    And batch size is within limits
    When admin calls calculateImmediateRewards(strategyId, fromDay, toDay, batchStart, batchSize)
    Then system should fetch user stakes via pagination
    And strategy should determine stake applicability
    And rewards should be calculated for eligible stakes
    And rewards should be granted to GrantedRewardStorage
    And processing should be gas-efficient

  Scenario: Calculate rewards with invalid strategy
    Given strategy is not IMMEDIATE type
    When calculateImmediateRewards is called
    Then transaction should revert with InvalidStrategyType error

  Scenario: Batch size exceeds maximum
    Given batch size > MAX_BATCH_SIZE
    When calculateImmediateRewards is called
    Then transaction should revert with BatchSizeExceeded error
```

### TC_R08: Epoch Reward Distribution (UC24)

```gherkin
Feature: Pool-Based Reward Distribution
  Scenario: Calculate epoch rewards for participants
    Given epoch is in CALCULATED state
    And epoch has actual pool size set
    And strategy is EPOCH_BASED type
    When admin calls calculateEpochRewards(epochId, batchStart, batchSize)
    Then system should calculate user participation weights
    And rewards should be distributed proportionally
    And rewards should be granted with epoch ID
    And mathematical precision should be maintained

  Scenario: Calculate rewards for non-calculated epoch
    Given epoch is not in CALCULATED state
    When calculateEpochRewards is called
    Then transaction should revert with EpochNotCalculated error

  Scenario: Epoch without pool size
    Given epoch is CALCULATED but actualPoolSize = 0
    When calculateEpochRewards is called
    Then transaction should revert with EpochPoolSizeNotSet error
```

### TC_R09: User Weight Calculation (UC24)

```gherkin
Feature: Epoch Participation Weight Calculation
  Scenario: Calculate user weight for epoch period
    Given user has stakes during epoch period
    And stakes have different amounts and durations
    When _calculateUserEpochWeight is called
    Then weight should equal sum of (amount × effective_days)
    And effective days should be intersection of stake period and epoch
    And unstaked positions should be handled correctly
    And mathematical precision should be maintained

  Scenario: User with no stakes during epoch
    Given user has no active stakes during epoch period
    When weight calculation is performed
    Then weight should be zero
    And user should receive no rewards
```

### TC_R10: Reward Claiming - All Rewards (UC25)

```gherkin
Feature: Complete Reward Claiming
  Scenario: Claim all available rewards
    Given user has multiple unclaimed rewards
    And rewards are from different strategies/epochs
    When user calls claimAllRewards()
    Then all unclaimed rewards should be identified
    And total amount should be calculated
    And rewards should be marked as claimed
    And tokens should be transferred to user
    And claiming state should be updated

  Scenario: Claim when no rewards available
    Given user has no unclaimed rewards
    When claimAllRewards is called
    Then transaction should revert with NoRewardsToClaim error
```

### TC_R11: Reward Claiming - Specific Rewards (UC25)

```gherkin
Feature: Selective Reward Claiming
  Scenario: Claim specific reward indices
    Given user has multiple unclaimed rewards
    And user specifies valid reward indices
    When user calls claimSpecificRewards(indices[])
    Then only specified rewards should be claimed
    And other rewards should remain unclaimed
    And tokens should be transferred for specified amount
    And state should be updated correctly

  Scenario: Claim with invalid indices
    Given user specifies out-of-bounds indices
    When claimSpecificRewards is called
    Then transaction should revert with InvalidRewardIndex error

  Scenario: Claim already claimed rewards
    Given user specifies already-claimed reward indices
    When claimSpecificRewards is called
    Then transaction should revert with RewardAlreadyClaimed error
```

### TC_R12: Epoch-Specific Claiming (UC25)

```gherkin
Feature: Epoch-Specific Reward Claiming
  Scenario: Claim rewards from specific epoch
    Given user has rewards from multiple epochs
    And user specifies valid epoch ID
    When user calls claimEpochRewards(epochId)
    Then only rewards from specified epoch should be claimed
    And rewards from other epochs should remain unclaimed
    And claiming should work correctly

  Scenario: Claim from epoch with no rewards
    Given user has no rewards from specified epoch
    When claimEpochRewards is called
    Then transaction should revert with NoClaimableRewardsForEpoch error
```

### TC_R13: Reward Storage - Grant Tracking (UC26)

```gherkin
Feature: Reward Grant Management
  Scenario: Grant reward to user
    Given reward parameters are valid
    And caller has CONTROLLER_ROLE
    When grantReward(user, strategyId, version, amount, epochId) is called
    Then reward should be added to user's reward array
    And reward should be marked as unclaimed
    And RewardGranted event should be emitted
    And reward should be queryable

  Scenario: Unauthorized reward granting
    Given caller does not have CONTROLLER_ROLE
    When grantReward is called
    Then transaction should revert with access control error
```

### TC_R14: Reward Storage - Batch Claiming (UC26)

```gherkin
Feature: Batch Claiming State Management
  Scenario: Mark multiple rewards as claimed
    Given user has multiple unclaimed rewards
    And valid reward indices are provided
    When batchMarkClaimed(user, indices[]) is called
    Then specified rewards should be marked as claimed
    And total amount should be calculated
    And BatchRewardsClaimed event should be emitted
    And state should be consistent

  Scenario: Partial batch claiming with some already claimed
    Given batch includes some already-claimed rewards
    When batchMarkClaimed is called
    Then only unclaimed rewards should be processed
    And already-claimed rewards should be skipped
    And operation should succeed partially
```

### TC_R15: Reward Storage - User Queries (UC26)

```gherkin
Feature: User Reward Information
  Scenario: Get user's complete reward history
    Given user has rewards from multiple strategies/epochs
    When getUserRewards(user) is called
    Then complete reward array should be returned
    And all reward details should be accurate
    And claimed status should be correct

  Scenario: Get user's claimable amount
    Given user has mix of claimed and unclaimed rewards
    When getUserClaimableAmount(user) is called
    Then total of unclaimed rewards should be returned
    And calculation should be accurate

  Scenario: Get claimable rewards with indices optimization
    Given user has large reward history
    When getUserClaimableRewards is called
    Then only unclaimed rewards should be returned with indices
    And optimization should start from nextClaimableIndex
    And results should be paginated efficiently
```

### TC_R16: Strategy Implementation - Linear APR (UC23)

```gherkin
Feature: Linear APR Strategy Calculations
  Scenario: Calculate historical APR rewards
    Given stake is applicable to strategy period
    And annual rate is configured (e.g., 1000 basis points = 10%)
    When calculateHistoricalReward(staker, stakeId, fromDay, toDay) is called
    Then reward should equal (amount × rate × days) / (365 × 10000)
    And calculation should handle partial periods
    And unstaking should be considered for end period
    And precision should be maintained

  Scenario: Calculate reward for non-applicable stake
    Given stake is outside strategy period
    When calculateHistoricalReward is called
    Then reward should be zero

  Scenario: Calculate reward with strategy period limits
    Given stake spans beyond strategy end date
    When reward calculation is performed
    Then calculation should use min(toDay, strategyEndDay)
    And reward should be prorated correctly
```

### TC_R17: Strategy Implementation - Epoch Pool (UC24)

```gherkin
Feature: Epoch Pool Strategy Distribution
  Scenario: Calculate proportional epoch reward
    Given user weight and total epoch weight are known
    And pool size is set
    When calculateEpochReward is called
    Then reward should equal (userWeight × poolSize) / totalWeight
    And calculation should handle zero total weight
    And precision should be maintained

  Scenario: Validate epoch participation
    Given stake period and epoch period
    When validateEpochParticipation is called
    Then should return true if stake overlaps with epoch
    And should handle unstaked positions correctly
    And should validate time boundaries
```

### TC_R18: Access Control - Reward System (UC21-UC26)

```gherkin
Feature: Reward System Access Control
  Scenario: Admin functions access control
    Given various users with different roles
    When admin-only functions are called
    Then only users with ADMIN_ROLE should succeed
    And others should revert with access control error
    And this applies to: strategy management, epoch management, reward calculation

  Scenario: Controller functions access control
    Given RewardManager needs to control GrantedRewardStorage
    When CONTROLLER_ROLE functions are called
    Then only RewardManager should succeed
    And direct access should be prevented

  Scenario: User functions public access
    Given any user
    When public query functions are called
    Then access should be allowed for all users
    And no access control restrictions
```

### TC_R19: Emergency Controls (UC Security)

```gherkin
Feature: Reward System Emergency Controls
  Scenario: Emergency pause reward system
    Given reward system is operating normally
    And admin detects security issue
    When admin calls emergencyPause()
    Then reward system should be paused
    And claiming should be blocked
    And calculations should be blocked

  Scenario: Resume from emergency pause
    Given reward system is paused
    When admin calls emergencyResume()
    Then system should resume normal operations
    And all functions should work again
```

### TC_R20: Reentrancy Protection - Rewards (UC25)

```gherkin
Feature: Reward Claiming Reentrancy Protection
  Scenario: Attempt reentrancy during claiming
    Given malicious token contract attempts reentrancy
    When claiming operation is in progress
    Then reentrancy attempt should be blocked
    And state should remain consistent
    And claiming should complete safely

  Scenario: Normal claiming with reentrancy protection
    Given standard ERC20 token
    When normal claiming occurs
    Then operations should work correctly
    And protection should not interfere
```

### TC_R21: Mathematical Precision (UC23, UC24)

```gherkin
Feature: Reward Calculation Precision
  Scenario: Large number handling in calculations
    Given very large stake amounts and long periods
    When reward calculations are performed
    Then calculations should not overflow
    And precision should be maintained within acceptable bounds
    And rounding should be consistent

  Scenario: Division precision in pool distributions
    Given pool distribution with prime numbers
    When rewards are calculated for many users
    Then total distributed should not exceed pool size
    And precision loss should be minimized
    And edge cases should be handled gracefully

  Scenario: Zero values and edge cases
    Given edge case inputs (zero amounts, zero periods)
    When calculations are performed
    Then system should handle gracefully
    And should not revert unexpectedly
    And results should be mathematically correct
```

### TC_R22: Integration - Rewards with Staking Data (UC23, UC24)

```gherkin
Feature: Reward System Integration with Staking
  Scenario: Use historical staking data for rewards
    Given users have complex staking history
    And multiple stakes with different time periods
    When reward calculations access staking data
    Then historical balances should be accurate
    And checkpoint system should provide correct data
    And calculations should match actual staking behavior

  Scenario: Real-time staking during active epochs
    Given epoch is currently active
    When users stake and unstake during epoch
    Then weight calculations should reflect real-time changes
    And epoch statistics should be accurate
    And integration should be seamless
```

### TC_R23: Performance - Large Scale Operations (UC23, UC24)

```gherkin
Feature: Reward System Scalability
  Scenario: Process rewards for 1000+ users
    Given large user base with many stakes
    When batch reward processing is performed
    Then operations should complete within gas limits
    And pagination should work efficiently
    And state should remain consistent
    And processing should be deterministic

  Scenario: Handle large reward histories
    Given users with 100+ reward entries
    When claiming operations are performed
    Then queries should remain efficient
    And claiming should work correctly
    And index optimization should function
```

### TC_R24: Strategy Parameter Updates (UC21)

```gherkin
Feature: Dynamic Strategy Configuration
  Scenario: Update strategy parameters by manager
    Given strategy manager wants to change parameters
    And manager has proper permissions
    When updateParameters(newParams[]) is called
    Then strategy parameters should be updated
    And new calculations should use new parameters
    And old calculations should remain unchanged

  Scenario: Unauthorized parameter update
    Given caller is not strategy manager
    When updateParameters is called
    Then transaction should revert with OnlyManagerCanUpdate error
```

### TC_R25: Multi-Token Reward Support (UC Future)

```gherkin
Feature: Different Reward Tokens
  Scenario: Reward funding with different tokens
    Given reward system supports multiple tokens
    When rewards are funded with different ERC20 tokens
    Then funding should be tracked separately
    And claiming should work for each token type
    And accounting should be accurate per token

  Scenario: Cross-token reward calculations
    Given rewards in different tokens
    When users claim rewards
    Then correct tokens should be transferred
    And amounts should be accurate per token type
```

### TC_R26: Reward Vesting (UC Future)

```gherkin
Feature: Time-Locked Reward Vesting
  Scenario: Rewards with vesting schedules
    Given rewards are granted with vesting period
    When users attempt to claim before vesting
    Then claims should be restricted appropriately
    And vested portions should be claimable
    And unvested portions should remain locked

  Scenario: Vesting schedule calculations
    Given linear vesting over time period
    When vesting calculations are performed
    Then available amounts should be accurate
    And time-based calculations should be correct
```

### TC_R27: Reward Boost System (UC Future)

```gherkin
Feature: Multiplier-Based Reward Boosts
  Scenario: Apply multipliers based on stake duration
    Given stakes with different lock periods
    And boost multipliers are configured
    When rewards are calculated
    Then longer locks should receive higher multipliers
    And calculations should be accurate
    And boosts should compound correctly

  Scenario: Governance participation boosts
    Given users participate in governance
    When reward calculations include governance boost
    Then additional rewards should be granted
    And boost tracking should be accurate
```

### TC_R28: Advanced Error Recovery (UC Error Handling)

```gherkin
Feature: Reward System Error Recovery
  Scenario: Recovery from partial batch failures
    Given batch operation fails partially
    When recovery procedures are executed
    Then completed operations should remain valid
    And failed operations should be identifiable
    And system should return to consistent state

  Scenario: Strategy malfunction handling
    Given strategy contract has bug or reverts
    When reward calculations encounter strategy errors
    Then system should handle gracefully
    And other strategies should continue working
    And error should be logged appropriately
```

### TC_R29: Reward Analytics and Reporting (UC Analytics)

```gherkin
Feature: Reward System Analytics
  Scenario: Generate reward distribution reports
    Given epoch has completed with rewards distributed
    When analytics queries are performed
    Then total rewards per strategy should be accurate
    And user participation statistics should be correct
    And distribution fairness should be verifiable

  Scenario: Historical reward performance
    Given multiple epochs and strategies have completed
    When historical analysis is performed
    Then reward trends should be queryable
    And strategy performance should be comparable
    And data should support governance decisions
```

### TC_R30: Cross-System Event Coordination (UC Integration)

```gherkin
Feature: Reward System Event Integration
  Scenario: Coordinated event emission across contracts
    Given reward operations span multiple contracts
    When operations complete
    Then events should be emitted in correct order
    And event data should be consistent
    And off-chain systems should receive complete information

  Scenario: Event-driven off-chain integration
    Given off-chain systems monitor reward events
    When reward operations occur
    Then events should provide sufficient data for indexing
    And event parameters should be accurate
    And integration should be reliable
```

## FLAG SYSTEM TESTS (MISSING)

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


---

## Summary

This document defines **62 focused test cases** for the complete Token Staking System:

- **Core Staking Tests (TC1-TC28)**: 28 test cases covering StakingVault and StakingStorage with focus on business logic
- **Reward System Tests (TC_R01-TC_R30)**: 30 test cases covering complete reward functionality  
- **Flag System Tests (TC_F01-TC_F03)**: 3 test cases for extensible flag operations
- **Integration Tests (TC_I01-TC_I07)**: 7 simplified test cases for cross-system integration

Each test case focuses on business logic and core functionality rather than implementation details or external library testing. The test cases provide practical coverage of all use cases defined in `use_cases.md` and ensure the system is audit-ready without over-engineering.
