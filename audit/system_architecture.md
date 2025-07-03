# Token Staking System: System Architecture

## Project Intention

We've developed the Token Staking system to enable users to stake their tokens with flexible time locks and earn rewards. The primary goal is to provide a secure, efficient staking mechanism with comprehensive tracking capabilities and integration with external claiming systems.

## Key Design Decisions

### Modular Architecture

We chose to implement a two-contract system for **separation of concerns** and **gas optimization**:

1. **StakingVault**: Handles staking/unstaking logic and token transfers
2. **StakingStorage**: Manages stake state and historical tracking with checkpoint system

### Flexible Time Lock System

We offer configurable time locks to accommodate different staking strategies:

1. **Individual Time Locks**: Each stake can have its own time lock period (in days)
2. **Mature Stake Validation**: Stakes cannot be unstaked until the time lock expires
3. **Day-based Tracking**: Uses day numbers (block.timestamp / 1 days) for time lock enforcement

### Access Control Architecture

We've implemented a tiered permission system (detailed in [roles.md](./roles.md)) to ensure proper separation of concerns:

- **DEFAULT_ADMIN_ROLE**: Controls role assignments and critical system configurations
- **MANAGER_ROLE**: Handles operational functions like pause/unpause and batch operations
- **MULTISIG_ROLE**: Controls emergency withdrawals and treasury operations
- **CONTROLLER_ROLE**: Allows the StakingVault to modify bookkeeper state
- **CLAIM_CONTRACT_ROLE**: Enables external claiming contracts to stake on behalf of users

This segregation prevents unauthorized access and ensures proper operational boundaries.

## Implementation Notes

### Stake ID Management

Each user's stakes are tracked with auto-incrementing stake IDs. The system maintains:

1. **Individual stake records**: Amount, timestamp, time lock, and deletion timestamp for each stake
2. **Total staked tracking**: Real-time totals per user and globally
3. **Historical data preservation**: Stakes are never deleted, only marked with deletion timestamp
4. **Historical checkpoints**: Time-based snapshots for reward calculations
5. **Claim integration flags**: Tracking which stakes originated from external claiming (preserved permanently)

#### Optimized Stake Structure

```solidity
struct Stake {
    uint128 amount;      // 16 bytes - amount of tokens staked
    uint16 stakeDay;     // 2 bytes - day when stake was created
    uint16 unstakeDay;   // 2 bytes - day when stake was unstaked (0 if active)
    uint16 daysLock;     // 2 bytes - lock period in days
    uint16 flags;        // bits encoded flags
}
```

This structure is optimized for gas efficiency while preserving complete historical data for reward calculations and claim tracking.

### Historical Data with Checkpoints

We implement a custom checkpoint system optimized for our use case:

1. **Binary Search Optimization**: O(log n) historical balance queries using custom binary search
2. **Per-user tracking**: Individual staking history with automatic checkpoint creation
3. **Daily Snapshots**: Global daily statistics for network-wide analytics
4. **Historical preservation**: Stakes maintain complete history even after unstaking
5. **Efficient Queries**: Optimized data structures for large datasets with pagination support

The specific query functions are detailed in the [Contract Specifications](../docs/contract_specifications.md).

### Pause Functionality

Implemented pausability as an emergency control measure. Only `MANAGER_ROLE` can pause/unpause, allowing us to quickly stop all staking operations if security issues arise.

### Areas of Concern

We'd particularly appreciate audit review of:

1. **Time Lock Validation Logic** in `unstake` (src/StakingVault.sol:105-133)

   - Timestamp boundary conditions
   - Integer overflow/underflow scenarios
   - Time-based manipulation vectors

2. **Reentrancy Vectors** in the staking/unstaking process

   - External ERC20 token calls
   - State changes before external calls
   - Cross-contract interactions with bookkeeper

3. **Checkpoint System Integrity** (src/StakingStorage.sol)

   - Checkpoint creation and validation
   - Historical data consistency
   - Gas efficiency for large datasets

4. **Role-Based Permission System Security**

   - Initial role assignment in constructors
   - Role escalation possibilities
   - Controller role security boundaries

5. **Batch Operation Considerations** - Future batch operations design

   - Array length validation
   - Gas limit considerations
   - State consistency across batch operations

6. **Integration Security**
   - Storage contract interface assumptions
   - External claiming contract integration via CLAIM_CONTRACT_ROLE
   - ERC20 token compatibility with SafeERC20
   - Emergency recovery mechanisms

## Gas Cost Estimates

| Operation                  | Estimated Gas | Notes                                     |
| -------------------------- | ------------- | ----------------------------------------- |
| `stake()`                  | ~150,000 gas  | First-time stake with storage updates     |
| `unstake()`                | ~120,000 gas  | Includes time lock validation and cleanup |
| `stakeFromClaim()`         | ~140,000 gas  | Optimized path from external claiming     |
| `getStakerBalanceAt()`     | ~15,000 gas   | Binary search historical query            |
| `batchGetStakerBalances()` | ~25,000 gas   | Batch historical queries                  |
| `getDailySnapshot()`       | ~2,000 gas    | View function for daily statistics        |

## Security Model Overview

### Trust Assumptions

1. **Admin Multisig**: Trusted with role management and system configuration
2. **Manager Address**: Trusted with operational functions and emergency controls
3. **Treasury Multisig**: Trusted with emergency withdrawals
4. **Token Contract**: Trusted ERC20 implementation
5. **External Claiming Contract**: Trusted integration for stake-from-claim functionality

### Attack Vectors Considered

1. **Time Manipulation**: Mitigated by using block.timestamp and proper validation
2. **Reentrancy**: Protected by ReentrancyGuard and proper state management
3. **Integer Overflow/Underflow**: Protected by Solidity 0.8+ built-in checks
4. **Role Escalation**: Prevented by OpenZeppelin AccessControl
5. **Stake Manipulation**: Prevented by controller role restrictions
6. **Front-running**: Limited impact due to time-locked nature of stakes

## Integration Requirements

### External Claiming Contract Interface

External claiming contracts must:

1. **Transfer tokens first**: Transfer tokens to StakingVault before calling `stakeFromClaim`
2. **Have CLAIM_CONTRACT_ROLE**: Must be granted the claim contract role
3. **Provide valid parameters**: Staker address, amount, and time lock

```solidity
function stakeFromClaim(
    address staker,
    uint128 amount,
    uint48 timeLock
) external returns (uint256 stakeId);
```

### StakingStorage Controller Setup

The StakingVault must be configured as the controller:

1. **Grant CONTROLLER_ROLE**: Only the controller can modify stake state
2. **Set controller address**: Configured during StakingStorage deployment
3. **Maintain single controller**: Only one active controller at a time

### Token Approval Requirements

For normal staking operations:

1. **User approval**: Users must approve StakingVault to spend their tokens
2. **Sufficient allowance**: Allowance must cover stake amount
3. **SafeERC20 compliance**: All token operations use SafeERC20

## Troubleshooting Guide

### Common Issues

| Error                | Possible Causes                   | Solutions                                       |
| -------------------- | --------------------------------- | ----------------------------------------------- |
| `StakeNotMatured`    | Attempting to unstake too early   | Wait until stake timestamp + timeLock           |
| `StakeNotFound`      | Invalid stake ID or deleted stake | Verify stake ID exists and hasn't been unstaked |
| `InsufficientAmount` | Zero amount staking attempt       | Ensure stake amount is greater than zero        |
| `ArraysDontMatch`    | Batch operation array mismatch    | Ensure all arrays have same length in batch ops |
| `Paused`             | System paused                     | Check pause status, unpause if needed           |
| `InvalidAmount`      | Zero amount in bookkeeper         | Validate amount before calling setStake         |
| Transfer failures    | Insufficient balance/allowance    | Check user balance and token allowance          |

## Upgrade Considerations

These contracts are **not upgradeable** by design for security reasons. Any changes require:

1. Deploy new contract versions
2. Pause old contracts
3. Allow users to unstake from old system
4. Migrate any remaining tokens
5. Update integrations to use new contracts

**Migration Process:**

1. Pause old contracts
2. Deploy new contract versions
3. Configure new role assignments
4. Set up new bookkeeper-vault relationship
5. Update external integrations
6. Communicate migration timeline to users

## Code Quality Metrics

### Test Coverage Expectations

- **Function Coverage**: 100% of public functions
- **Branch Coverage**: 100% of conditional logic
- **Edge Cases**: We are not going to test edge cases that makes no sense, like locking tokens for maximum possible by `uint16` 179 years.
- **Integration Tests**: Full vault-bookkeeper integration
- **Historical Data Tests**: Checkpoint functionality verification
- **Batch Operation Tests**: Multi-stake/unstake scenarios

## Staker Enumeration and Access Control

- **Staker Enumeration**: The contract uses OpenZeppelin's `EnumerableSet` library to store the unique list of all stakers. This provides a gas-efficient mechanism for adding new stakers (`O(1)` complexity) and allows for paginated enumeration of all stakers, ensuring predictable and scalable performance.
- **Access Control**: Utilizes OpenZeppelin's `AccessControl` for role-based permissions. Key roles include:
  - `DEFAULT_ADMIN_ROLE`: For core administrative tasks and role management.
  - `MANAGER_ROLE`: For operational tasks like pausing/unpausing.
  - `MULTISIG_ROLE`: A dedicated, highly-secured role intended for a multisig wallet, with the sole ability to call the `emergencyRecover` function.

### Data Structures

- **Stakes**: `mapping(address => mapping(bytes32 => Stake))`
- **Daily Snapshots**: `mapping(uint16 => DailySnapshot)`
- **All Stakers**: `EnumerableSet.AddressSet` for efficient, unique storage and enumeration.

## Security Analysis

- **Centralization Risk & Mitigation**: The contract design includes a powerful `emergencyRecover` function. To mitigate risk, this function is strictly controlled by a dedicated `MULTISIG_ROLE`, which is separate from the `DEFAULT_ADMIN_ROLE`. This enforces the principle of least privilege. For production deployment, the `MULTISIG_ROLE` must be assigned to a secure, multi-signature wallet.
- **Gas Efficiency**: The use of `EnumerableSet` for staker management effectively mitigates gas limit concerns related to adding new stakers, as the operation has a constant time complexity.

## Recommendations

- **Secure Role Management**: It is critical that the `MULTISIG_ROLE` and `DEFAULT_ADMIN_ROLE` are managed by secure, time-locked multisig wallets in a production environment.
- **Event Emission**: Ensure all state-changing functions emit events for comprehensive off-chain tracking.
