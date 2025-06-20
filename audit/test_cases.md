# Token Staking System: Test Cases

## Overview

This document defines comprehensive test cases for the STAKING SUBSYSTEM ONLY. Test cases are mapped to use cases defined in `use_cases.md` and cover the current implementation of StakingVault and StakingStorage contracts.

**Note**: Tests are currently outdated and need to be rewritten based on these specifications.

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
    And unique stake ID should be generated using keccak256(abi.encode(staker, stakesCount))
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

### TC4: Failed Staking - Insufficient Balance (UC12)

```gherkin
Feature: Balance Validation
  Scenario: User attempts to stake more than they have
    Given user has token balance of 100
    And user attempts to stake 200 tokens
    When user calls stake(200, 0)
    Then transaction should revert (SafeERC20 will handle this)
    And no tokens should be transferred
    And no stake should be created
    And no state should be modified
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

### TC7: Failed Claim Stake - Unauthorized (UC14)

```gherkin
Feature: Access Control
  Scenario: Unauthorized contract attempts stakeFromClaim
    Given contract does not have CLAIM_CONTRACT_ROLE
    When contract calls stakeFromClaim(staker, amount, daysLock)
    Then transaction should revert with AccessControl error
    And no stake should be created
    And no state should be modified
```

## Manager Role Tests

### TC8: Pause System (UC4)

```gherkin
Feature: System Pause
  Scenario: Manager pauses the system
    Given actor has MANAGER_ROLE
    And system is not currently paused
    When manager calls StakingVault.pause()
    Then system should be paused
    And Paused event should be emitted
    And all stake/unstake operations should be blocked
```

### TC9: Unpause System (UC5)

```gherkin
Feature: System Unpause
  Scenario: Manager unpauses the system
    Given actor has MANAGER_ROLE
    And system is currently paused
    When manager calls StakingVault.unpause()
    Then system should be unpaused
    And Unpaused event should be emitted
    And stake/unstake operations should be enabled again
```

### TC10: Failed Pause - Unauthorized (UC14)

```gherkin
Feature: Access Control
  Scenario: Unauthorized user attempts to pause
    Given user does not have MANAGER_ROLE
    When user attempts to call pause()
    Then transaction should revert with AccessControl error
    And system should remain unpaused
```

## Admin Role Tests

### TC11: Emergency Token Recovery (UC6)

```gherkin
Feature: Emergency Recovery
  Scenario: Admin recovers tokens from contract
    Given actor has DEFAULT_ADMIN_ROLE
    And StakingVault has sufficient token balance
    And recovery amount is greater than zero
    When admin calls emergencyRecover(token, amount)
    Then specified tokens should be transferred to admin
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

### TC21: Not Stake Owner (UC12)

```gherkin
Feature: Ownership Validation
  Scenario: User attempts to unstake someone else's stake
    Given stake belongs to different user
    When wrong user attempts unstake(stakeId)
    Then transaction should revert with NotStakeOwner error
    And error should include caller and actual owner
    And no tokens should be transferred
```

### TC22: Paused System Operations (UC13)

```gherkin
Feature: Pause Protection
  Scenario: User attempts to stake while system is paused
    Given the staking system is paused
    And user has valid parameters
    When user calls stake(amount, daysLock)
    Then transaction should revert with Pausable error
    And no tokens should be transferred
    And no stake should be created

  Scenario: User attempts to unstake while system is paused
    Given the staking system is paused
    And user has matured stake
    When user calls unstake(stakeId)
    Then transaction should revert with Pausable error
    And no tokens should be transferred
```

## Security Tests

### TC23: Reentrancy Protection (UC15)

```gherkin
Feature: Security
  Scenario: Malicious contract attempts reentrancy during stake
    Given malicious contract implements token interface
    When malicious contract attempts reentrancy during stake operation
    Then transaction should revert with ReentrancyGuard error
    And state should remain consistent

  Scenario: Malicious contract attempts reentrancy during unstake
    Given malicious contract has valid stake
    When malicious contract attempts reentrancy during unstake
    Then transaction should revert with ReentrancyGuard error
    And state should remain consistent
```

### TC24: Access Control Enforcement (UC14)

```gherkin
Feature: Access Control
  Scenario: Unauthorized storage access
    Given user does not have CONTROLLER_ROLE
    When user attempts to call StakingStorage.createStake directly
    Then transaction should revert with AccessControl error
    And no state should be modified

  Scenario: Unauthorized emergency recovery
    Given user does not have DEFAULT_ADMIN_ROLE
    When user attempts emergencyRecover
    Then transaction should revert with AccessControl error
    And no tokens should be transferred
```

## Data Integrity Tests

### TC25: Checkpoint System Integrity (UC16)

```gherkin
Feature: Checkpoint System
  Scenario: Checkpoints maintain sorted order
    Given multiple balance changes occur
    When checkpoints are created
    Then checkpoint array should remain sorted by day
    And binary search should function correctly
    And historical queries should return accurate data

  Scenario: Checkpoint creation on balance changes
    Given user balance changes (stake/unstake)
    When operation completes
    Then checkpoint should be created for current day
    And checkpoint should reflect new balance
    And CheckpointCreated event should be emitted
```

### TC26: Global Statistics Accuracy (UC17)

```gherkin
Feature: Global Statistics
  Scenario: Total staked amount consistency
    Given multiple stake and unstake operations
    When operations complete
    Then global currentTotalStaked should equal sum of active stakes
    And daily snapshots should be accurate
    And totalStakesCount should match active stakes

  Scenario: Staker registration consistency
    Given new staker creates first stake
    When stake operation completes
    Then staker should be registered in allStakers array
    And isStakerRegistered should be true
    And staker count should be incremented
```

## Integration Tests

### TC27: Vault-Storage Integration (UC19)

```gherkin
Feature: Contract Integration
  Scenario: StakingVault and StakingStorage coordination
    Given both contracts are deployed and configured
    When staking operations are performed
    Then vault should correctly call storage functions
    And storage should update state appropriately
    And CONTROLLER_ROLE should be properly enforced
    And events should be emitted from both contracts
    And data should remain consistent across contracts
```

### TC28: Token Integration (UC18)

```gherkin
Feature: Token Integration
  Scenario: SafeERC20 token operations
    Given standard ERC20 token
    When stake/unstake operations occur
    Then SafeERC20 should handle transfers securely
    And allowance checks should be enforced
    And balance validation should work correctly
    And token-related errors should be handled properly
```

## Edge Case Tests

### TC29: Time Lock Boundary Conditions

```gherkin
Feature: Time Lock Edge Cases
  Scenario: Exact time lock expiry
    Given stake with specific time lock
    And current day equals stake day + days lock (exact boundary)
    When user attempts to unstake
    Then unstaking should be allowed
    And transaction should succeed

  Scenario: Zero time lock staking
    Given user stakes with daysLock = 0
    When user immediately attempts to unstake
    Then unstaking should be allowed immediately
    And no time lock validation should occur
```

### TC30: Large Number Handling

```gherkin
Feature: Numeric Edge Cases
  Scenario: Maximum uint128 stake amount
    Given user stakes maximum uint128 amount
    When operations are performed
    Then calculations should not overflow
    And state should be updated correctly

  Scenario: Maximum uint16 time lock
    Given user stakes with maximum uint16 days lock
    When time calculations are performed
    Then no overflow should occur
    And maturity calculation should be correct
```

### TC31: Storage Efficiency

```gherkin
Feature: Storage Optimization
  Scenario: Binary search performance
    Given large number of checkpoints (1000+)
    When historical balance query is performed
    Then operation should complete efficiently
    And gas usage should be logarithmic
    And result should be accurate

  Scenario: Paginated queries with large datasets
    Given large number of stakers (10000+)
    When paginated query is performed
    Then operation should complete without gas limit issues
    And pagination should work correctly
    And results should be accurate
```

## Event Emission Tests

### TC32: Event Parameter Verification

```gherkin
Feature: Event Logging
  Scenario: Staked event emission
    Given successful stake operation
    When operation completes
    Then Staked event should be emitted with correct parameters
    And event should include staker, stakeId, amount, stakeDay, daysLock
    And both vault and storage should emit coordinated events

  Scenario: Unstaked event emission
    Given successful unstake operation
    When operation completes
    Then Unstaked event should be emitted with correct parameters
    And event should include staker, stakeId, unstakeDay, amount
    And both vault and storage should emit coordinated events
```

## Gas Optimization Tests

### TC33: Gas Usage Verification

```gherkin
Feature: Gas Efficiency
  Scenario: Stake operation gas usage
    Given normal stake operation
    When gas usage is measured
    Then gas should be approximately 150,000 or less
    And usage should be consistent across similar operations

  Scenario: Historical query gas usage
    Given checkpoint system with moderate data
    When historical balance query is performed
    Then gas should be approximately 25,000 or less
    And binary search should provide O(log n) complexity
```

## Additional Critical Tests (Implementation-Specific)

### TC34: StakingStorage Direct Function Tests

```gherkin
Feature: Storage Controller Functions
  Scenario: Direct createStake call with proper role
    Given caller has CONTROLLER_ROLE
    And stake ID does not already exist
    When createStake(staker, id, amount, daysLock, isFromClaim) is called
    Then stake should be created successfully
    And all state updates should occur correctly
    And events should be emitted

  Scenario: Direct createStake call without role
    Given caller does not have CONTROLLER_ROLE
    When createStake is called directly
    Then transaction should revert with AccessControl error

  Scenario: Duplicate stake ID prevention
    Given stake ID already exists
    When createStake is called with same ID
    Then transaction should revert with StakeAlreadyExists error
```

### TC35: Stake ID Generation Validation

```gherkin
Feature: Stake ID Generation
  Scenario: Deterministic stake ID generation
    Given specific staker and stakesCount
    When stake() is called multiple times
    Then stake IDs should be deterministic and unique
    And should follow keccak256(abi.encode(staker, stakesCount)) pattern

  Scenario: Stake ID collision prevention
    Given high volume of stakes from same staker
    When stakes are created sequentially
    Then no stake ID collisions should occur
    And stakesCount should increment correctly
```

### TC36: Day Calculation Edge Cases

```gherkin
Feature: Day Calculation Precision
  Scenario: Day boundary transitions
    Given block.timestamp is near day boundary (86399 seconds)
    When stake operations occur across day transition
    Then day calculations should be consistent
    And maturity checks should be accurate

  Scenario: Maximum day values
    Given stakes with maximum uint16 daysLock (65535)
    When maturity calculations are performed
    Then no overflow should occur
    And calculations should remain accurate

  Scenario: Same-day multiple operations
    Given multiple stakes and unstakes occur same day
    When day-based operations are performed
    Then all should use consistent day value
    And checkpoints should be managed correctly
```

### TC37: Binary Search Algorithm Validation

```gherkin
Feature: Checkpoint Binary Search
  Scenario: Empty checkpoint array
    Given staker has no checkpoints
    When getStakerBalanceAt is called
    Then should return zero balance
    And should not revert

  Scenario: Single checkpoint
    Given staker has exactly one checkpoint
    When querying balance before, at, and after checkpoint
    Then results should be correct for all cases

  Scenario: Checkpoint exact match
    Given checkpoint exists for exact target day
    When getStakerBalanceAt is called for that day
    Then should return exact checkpoint value
    And should not use binary search interpolation

  Scenario: Large checkpoint array performance
    Given staker has 1000+ checkpoints
    When historical balance query is performed
    Then operation should complete in O(log n) time
    And gas usage should remain reasonable
```

### TC38: Staker Registration System

```gherkin
Feature: Staker Registration
  Scenario: First-time staker registration
    Given address has never staked before
    When first stake is created
    Then staker should be registered in allStakers array
    And isStakerRegistered should be set to true
    And totalStakersCount should increment

  Scenario: Existing staker additional stakes
    Given staker is already registered
    When additional stakes are created
    Then staker should not be re-registered
    And allStakers array should not grow
    And stakesCount should increment

  Scenario: Staker enumeration consistency
    Given multiple unique stakers exist
    When getStakersPaginated is called
    Then results should match registered stakers
    And pagination should cover all stakers exactly once
```

### TC39: Checkpoint System Internal Logic

```gherkin
Feature: Checkpoint Creation and Management
  Scenario: Multiple balance changes same day
    Given staker performs multiple operations same day
    When balance changes occur
    Then only latest checkpoint should exist for that day
    And checkpoint should reflect final balance
    And checkpoint array should remain sorted

  Scenario: Checkpoint array sorting validation
    Given balance changes occur on different days out of order
    When checkpoints are created
    Then checkpoint array should maintain sorted order
    And binary search should function correctly

  Scenario: Balance delta calculations
    Given stake and unstake operations
    When checkpoint updates occur
    Then positive and negative deltas should be applied correctly
    And final balances should be accurate
    And underflow should be prevented
```

### TC40: Daily Snapshot Accuracy

```gherkin
Feature: Daily Snapshot System
  Scenario: Multi-operation daily aggregation
    Given multiple stakes and unstakes occur same day
    When daily snapshot is updated
    Then total amount should match sum of operations
    And stakes count should reflect net change
    And snapshot should be consistent with individual balances

  Scenario: Snapshot historical consistency
    Given operations occurred over multiple days
    When daily snapshots are queried
    Then each snapshot should reflect accurate daily state
    And snapshots should be consistent with checkpoint data
```

### TC41: Storage Input Validation

```gherkin
Feature: Storage Function Parameter Validation
  Scenario: Zero address validation
    Given zero address is passed as staker
    When storage functions are called
    Then functions should handle gracefully or revert appropriately

  Scenario: Parameter boundary testing
    Given maximum values for uint128 amount and uint16 daysLock
    When createStake is called
    Then operation should succeed without overflow
    And calculations should remain accurate

  Scenario: Binary search edge case handling
    Given edge case checkpoint scenarios
    When getStakerBalanceAt is called
    Then binary search should handle all edge cases correctly
    And should never return incorrect results
```

### TC42: Cross-Contract Event Coordination

```gherkin
Feature: Event Emission Coordination
  Scenario: Vault and Storage event synchronization
    Given stake operation is performed
    When operation completes
    Then both StakingVault and StakingStorage should emit events
    And event parameters should be consistent
    And event ordering should be correct

  Scenario: CheckpointCreated event verification
    Given balance change occurs
    When checkpoint is created
    Then CheckpointCreated event should be emitted with correct parameters
    And event should include staker, day, balance, stakesCount
```

### TC43: Gas Limit Edge Cases

```gherkin
Feature: Gas Limit Handling
  Scenario: Maximum array size operations
    Given pagination with maximum practical limit
    When getStakersPaginated is called
    Then operation should complete within gas limits
    And results should be accurate

  Scenario: Large batch operations
    Given batch operations with large arrays
    When batchGetStakerBalances is called
    Then operation should succeed or fail gracefully
    And partial results should not corrupt state

  Scenario: Checkpoint traversal gas limits
    Given very large checkpoint arrays
    When binary search is performed
    Then operation should complete efficiently
    And gas usage should be predictable
```

---

## Test Implementation Guidelines

### Priority Levels

- **Critical**: TC1, TC2, TC3, TC6, TC11, TC23, TC24, TC27, TC34, TC35, TC37, TC39 (Core functionality and security)
- **High**: TC4, TC5, TC8, TC9, TC13-TC17, TC19-TC22, TC25, TC26, TC36, TC38, TC40, TC41 (Important features and validations)
- **Medium**: TC7, TC10, TC12, TC18, TC28-TC31, TC42, TC43 (Edge cases and optimizations)
- **Low**: TC32, TC33 (Events and gas optimization verification)

### Test Categories

1. **Unit Tests**: Individual function testing (TC1-TC5, TC13-TC17, TC34-TC35, TC38, TC41)
2. **Integration Tests**: Contract interaction testing (TC27, TC28, TC42)
3. **Security Tests**: Attack vector testing (TC23, TC24, TC34)
4. **Edge Case Tests**: Boundary condition testing (TC29-TC31, TC36-TC37, TC39-TC41, TC43)
5. **Performance Tests**: Gas and efficiency testing (TC33, TC37, TC43)

### Coverage Requirements

- **Function Coverage**: 100% of public/external functions
- **Branch Coverage**: 100% of conditional logic paths
- **Edge Case Coverage**: All error conditions and boundary cases
- **Integration Coverage**: All contract interactions
- **Event Coverage**: All event emissions verified

### Notes for Test Implementation

1. Tests should be implemented using Foundry framework
2. Use proper setup/teardown for consistent test state
3. Mock external dependencies where appropriate
4. Implement helper functions for common operations
5. Use fuzz testing for numeric edge cases
6. Verify gas usage doesn't exceed expected limits
7. Test both success and failure scenarios for each function
