# Reward System Implementation Guide for AI

## Context and Objective

You are implementing a gas-efficient, retroactive reward system for an existing staking platform. The system must support two types of reward strategies while achieving 30× gas reduction for users through pre-calculation patterns.

**IMPORTANT: START FROM SCRATCH**
- Build all reward contracts from scratch
- Do NOT modify or extend existing reward contracts
- Only integrate with existing staking system via public interfaces
- Use optimal design without backward compatibility constraints

**Existing System (USE AS-IS):**
- `StakingVault.sol` and `StakingStorage.sol` - working staking system
- Checkpoint system tracks all balance changes with timestamps
- Historical data available via `getStakerBalanceAt(address, uint16 day)` functions
- Interface: `IStakingStorage` - import and use this

**Your Task:**
Build a complete NEW reward system with the specifications below.

## Core Requirements Summary

### **Strategy Types to Support:**
1. **Immediate Strategies**: Calculate rewards anytime using historical data (e.g., "10% APR")
2. **Epoch-Based Strategies**: Fixed pools distributed after epoch ends (e.g., "$100K monthly pool")

### **Key Features Required:**
- Pre-calculation: Admin pays for expensive calculations, users get cheap lookups
- Retroactive rewards: Calculate rewards for past staking periods
- Dual strategy support: Same claiming interface for both strategy types
- Gas optimization: Target 30× reduction in user gas costs
- Batch processing: Handle large user sets efficiently

### **Architecture Pattern:**
```
StrategiesRegistry ← RewardManager → GrantedRewardStorage
       ↓                  ↓               ↓
Strategy Contracts    EpochManager    User Claims
```

## Implementation Specifications

### **File 1: Reward Strategy Interface**
**Location:** `src/interfaces/IRewardStrategy.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

enum StrategyType {
    IMMEDIATE,     // Can calculate anytime (APR-style)
    EPOCH_BASED    // Fixed pools after epoch ends
}

enum EpochState {
    ANNOUNCED,     // Rules published, users can prepare
    ACTIVE,        // Epoch running, tracking participants
    ENDED,         // Finished, awaiting admin pool size
    CALCULATED,    // Rewards calculated, ready to claim
    FINALIZED      // All rewards claimed, epoch closed
}

interface IRewardStrategy {
    struct StrategyParameters {
        string name;
        string description;
        uint16 startDay;           // When strategy becomes active
        uint16 endDay;             // When strategy expires (0 = permanent)
        StrategyType strategyType;
        uint32 epochDuration;      // Days per epoch (0 for immediate)
    }

    // Required for all strategies
    function getStrategyType() external view returns (StrategyType);
    function getEpochDuration() external view returns (uint32);
    function getParameters() external view returns (StrategyParameters memory);
    function updateParameters(uint256[] calldata params) external;
    function isApplicable(address staker, bytes32 stakeId) external view returns (bool);
    
    // For immediate strategies only
    function calculateHistoricalReward(
        address staker,
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    ) external view returns (uint256);
    
    // For epoch-based strategies only  
    function calculateEpochReward(
        address staker,
        bytes32 stakeId,
        uint32 epochId,
        uint256 userStakeWeight,
        uint256 totalStakeWeight,
        uint256 poolSize
    ) external pure returns (uint256);
    
    // Strategy-specific validation
    function validateEpochParticipation(
        address staker,
        bytes32 stakeId,
        uint32 epochStartDay,
        uint32 epochEndDay
    ) external view returns (bool);
}
```

**Implementation Notes:**
- Use this exact interface - do not modify function signatures
- All strategies must implement all functions (revert for unsupported operations)
- `validateEpochParticipation` should check if stake overlaps with epoch period

### **File 2: Granted Reward Storage**
**Location:** `src/GrantedRewardStorage.sol`

**Requirements:**
- Store pre-calculated rewards for users
- Support both immediate and epoch-based rewards
- Optimize for gas efficiency (struct packing)
- Support pagination and batch operations
- Track claiming status and totals

**Key Data Structures:**
```solidity
struct GrantedReward {
    uint128 amount;           // Reward amount (fits most token amounts)
    uint32 grantedAt;         // Block timestamp when granted
    uint32 epochId;           // 0 for immediate strategies
    uint16 strategyId;        // Which strategy granted this
    uint16 strategyVersion;   // Strategy version for auditability
    bool claimed;             // Claiming status
    // Total: 257 bits = 2 storage slots (good balance of size vs efficiency)
}
```

**Required Functions:**
```solidity
function grantReward(address user, uint256 strategyId, uint256 amount, uint32 epochId) external;
function markRewardClaimed(address user, uint256 rewardIndex) external;
function batchMarkClaimed(address user, uint256[] calldata rewardIndices) external;
function getUserRewards(address user) external view returns (GrantedReward[] memory);
function getUserClaimableAmount(address user) external view returns (uint256);
function getUserClaimableRewards(address user) external view returns (GrantedReward[] memory, uint256[] memory indices);
function getUserEpochRewards(address user, uint32 epochId) external view returns (GrantedReward[] memory);
function getUserRewardsPaginated(address user, uint256 offset, uint256 limit) external view returns (GrantedReward[] memory);
```

**Access Control:**
- `CONTROLLER_ROLE`: Can grant rewards and mark as claimed (RewardManager only)
- `ADMIN_ROLE`: Can set controller and emergency functions

**Events to Emit:**
```solidity
event RewardGranted(address indexed user, uint256 indexed strategyId, uint32 indexed epochId, uint256 amount);
event RewardClaimed(address indexed user, uint256 indexed rewardIndex, uint256 amount);
event BatchRewardsClaimed(address indexed user, uint256 totalAmount, uint256 rewardCount);
```

### **File 3: Strategies Registry**
**Location:** `src/StrategiesRegistry.sol`

**Purpose:** Manage strategy registration, activation, and metadata

**Required Data Structures:**
```solidity
struct RegistryEntry {
    address strategyAddress;
    StrategyType strategyType;
    uint32 registeredAt;
    uint16 version;
    bool isActive;
}
```

**Required Functions:**
```solidity
function registerStrategy(address strategyAddress) external returns (uint256 strategyId);
function setStrategyStatus(uint256 strategyId, bool isActive) external;
function updateStrategyVersion(uint256 strategyId) external;
function getActiveStrategies() external view returns (uint256[] memory);
function getActiveStrategiesByType(StrategyType strategyType) external view returns (uint256[] memory);
function getStrategy(uint256 strategyId) external view returns (RegistryEntry memory);
function getStrategyAddress(uint256 strategyId) external view returns (address);
```

**Implementation Requirements:**
- Auto-increment strategy IDs starting from 1
- Maintain separate arrays for each strategy type for efficient filtering
- Emit events for all registration and status changes
- Only `ADMIN_ROLE` can register/modify strategies

### **File 4: Epoch Manager**
**Location:** `src/EpochManager.sol`

**Purpose:** Manage epoch-based strategy lifecycles

**Required Data Structures:**
```solidity
struct Epoch {
    uint32 epochId;
    uint32 startDay;
    uint32 endDay;
    uint256 strategyId;
    uint256 estimatedPoolSize;    // Announced pool size
    uint256 actualPoolSize;       // Final pool size set by admin
    EpochState state;
    uint32 announcedAt;
    uint32 calculatedAt;
    uint256 totalParticipants;    // Set during calculation
    uint256 totalStakeWeight;     // Set during calculation
}
```

**Required Functions:**
```solidity
function announceEpoch(uint32 startDay, uint32 endDay, uint256 strategyId, uint256 estimatedPool) external returns (uint32 epochId);
function setEpochPoolSize(uint32 epochId, uint256 actualPoolSize) external;
function updateEpochStates() external; // Updates states based on current day
function finalizeEpoch(uint32 epochId, uint256 totalParticipants, uint256 totalWeight) external;
function getEpoch(uint32 epochId) external view returns (Epoch memory);
function getActiveEpochs() external view returns (uint32[] memory);
function getEpochState(uint32 epochId) external view returns (EpochState);
function getCurrentDay() public view returns (uint32); // block.timestamp / 86400
```

**State Transition Logic:**
- `ANNOUNCED` → `ACTIVE` when `currentDay >= startDay`
- `ACTIVE` → `ENDED` when `currentDay > endDay`
- `ENDED` → `CALCULATED` when admin calls `finalizeEpoch`
- Only allow pool size setting when state is `ENDED`

### **File 5: Reward Manager**
**Location:** `src/RewardManager.sol`

**Purpose:** Core orchestration contract for reward calculations and claiming

**Required Dependencies:**
```solidity
import "./StrategiesRegistry.sol";
import "./GrantedRewardStorage.sol";
import "./EpochManager.sol";
import "./interfaces/IStakingStorage.sol"; // EXISTING - use as-is
```

**Key Member Variables:**
```solidity
StrategiesRegistry public immutable strategyRegistry;
GrantedRewardStorage public immutable grantedRewardStorage;
EpochManager public immutable epochManager;
IStakingStorage public immutable stakingStorage; // EXISTING contract
IERC20 public immutable rewardToken;
uint256 public constant MAX_BATCH_SIZE = 100;
```

**Required Functions for Immediate Strategies:**
```solidity
function calculateImmediateRewards(
    uint256 strategyId,
    uint32 fromDay,
    uint32 toDay,
    uint256 batchStart,
    uint256 batchSize
) external onlyRole(ADMIN_ROLE);
```

**Implementation Logic for calculateImmediateRewards:**
1. Validate strategy exists and is IMMEDIATE type
2. Get paginated list of all stakers from `stakingStorage.getStakersPaginated(batchStart, batchSize)`
3. For each staker, get their stake IDs via `stakingStorage.getStakerStakeIds(staker)`
4. For each stake, check `strategy.isApplicable(staker, stakeId)`
5. If applicable, call `strategy.calculateHistoricalReward(staker, stakeId, fromDay, toDay)`
6. If reward > 0, call `grantedRewardStorage.grantReward(staker, strategyId, reward, 0)`
7. Emit progress events

**Required Functions for Epoch Strategies:**
```solidity
function calculateEpochRewards(
    uint32 epochId,
    uint256 batchStart,
    uint256 batchSize
) external onlyRole(ADMIN_ROLE);
```

**Implementation Logic for calculateEpochRewards:**
1. Validate epoch exists and state is `ENDED`
2. Get epoch details and verify actualPoolSize > 0
3. Calculate total stake weight for epoch (use helper function)
4. Get paginated participants who had stakes during epoch
5. For each participant, calculate their stake weight during epoch
6. Call `strategy.calculateEpochReward()` with weights and pool size
7. Grant rewards via `grantedRewardStorage.grantReward()`
8. Update epoch state to `CALCULATED` when all batches complete

**Required User Functions:**
```solidity
function claimAllRewards() external nonReentrant returns (uint256);
function claimSpecificRewards(uint256[] calldata rewardIndices) external nonReentrant returns (uint256);
function claimEpochRewards(uint32 epochId) external nonReentrant returns (uint256);
function getClaimableRewards(address user) external view returns (uint256);
function getUserRewardSummary(address user) external view returns (uint256 totalGranted, uint256 totalClaimed, uint256 totalClaimable);
```

**Claiming Implementation Pattern:**
1. Get user's claimable rewards from `grantedRewardStorage`
2. Calculate total claimable amount
3. Mark all rewards as claimed via `grantedRewardStorage.batchMarkClaimed()`
4. Transfer total amount via `rewardToken.safeTransfer(user, totalAmount)`
5. Emit claiming events

**Required Admin Functions:**
```solidity
function addRewardFunds(uint256 amount) external;
function withdrawRewardFunds(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE);
function emergencyPause() external onlyRole(ADMIN_ROLE);
function emergencyResume() external onlyRole(ADMIN_ROLE);
```

**Access Control Setup:**
- Inherit from `AccessControl`, `ReentrancyGuard`, `Pausable`
- `DEFAULT_ADMIN_ROLE`: Emergency functions, fund management
- `ADMIN_ROLE`: Calculate rewards, manage epochs
- Grant `CONTROLLER_ROLE` to this contract in `GrantedRewardStorage`

### **File 6: Linear APR Strategy Example**
**Location:** `src/strategies/LinearAPRStrategy.sol`

**Purpose:** Example immediate strategy implementing fixed APR

**Required Constructor Parameters:**
```solidity
constructor(
    IRewardStrategy.StrategyParameters memory _params,
    address _manager,
    uint256 _annualRateBasisPoints,  // e.g., 1000 = 10%
    IStakingStorage _stakingStorage  // EXISTING contract interface
)
```

**Implementation Requirements:**
- `getStrategyType()` returns `StrategyType.IMMEDIATE`
- `getEpochDuration()` returns `0`
- `calculateHistoricalReward()` implements: `(stakeAmount × annualRate × effectiveDays) / (365 × 10000)`
- Handle stake/unstake timing correctly (calculate overlap with fromDay/toDay period)
- `calculateEpochReward()` should revert with "Not supported for immediate strategies"
- `isApplicable()` checks stake day is within strategy's startDay/endDay range

**Calculation Logic:**
```solidity
function calculateHistoricalReward(address staker, bytes32 stakeId, uint32 fromDay, uint32 toDay) external view returns (uint256) {
    IStakingStorage.Stake memory stake = stakingStorage.getStake(staker, stakeId);
    
    // Calculate effective period stake was active within fromDay/toDay
    uint32 effectiveStart = stake.stakeDay > fromDay ? stake.stakeDay : fromDay;
    uint32 effectiveEnd = stake.unstakeDay > 0 && stake.unstakeDay < toDay ? stake.unstakeDay : toDay;
    
    if (effectiveStart >= effectiveEnd) return 0;
    
    uint256 effectiveDays = effectiveEnd - effectiveStart;
    return (stake.amount * annualRateBasisPoints * effectiveDays) / (365 * 10000);
}
```

### **File 7: Epoch Pool Strategy Example**
**Location:** `src/strategies/EpochPoolStrategy.sol`

**Purpose:** Example epoch-based strategy for fixed pool distribution

**Required Constructor Parameters:**
```solidity
constructor(
    IRewardStrategy.StrategyParameters memory _params,
    address _manager,
    uint32 _epochDurationDays,
    IStakingStorage _stakingStorage  // EXISTING contract interface
)
```

**Implementation Requirements:**
- `getStrategyType()` returns `StrategyType.EPOCH_BASED`
- `getEpochDuration()` returns constructor parameter
- `calculateEpochReward()` implements: `(userWeight × poolSize) / totalWeight`
- `calculateHistoricalReward()` should revert with "Use calculateEpochReward for epoch strategies"
- `validateEpochParticipation()` checks if stake overlaps with epoch period

**Weight Calculation Logic:**
Weight should be: `stakeAmount × daysStakedDuringEpoch`

### **File 8: Staking Integration Helper**
**Location:** `src/StakingIntegration.sol`

**Purpose:** Helper functions for integrating with existing staking system

**Required Functions:**
```solidity
function getEpochParticipants(uint32 epochStartDay, uint32 epochEndDay, uint256 offset, uint256 limit) external view returns (address[] memory);
function calculateUserEpochWeight(address user, uint32 epochStartDay, uint32 epochEndDay) external view returns (uint256);
function calculateTotalEpochWeight(uint32 epochStartDay, uint32 epochEndDay) external view returns (uint256);
function getStakeEffectivePeriod(address staker, bytes32 stakeId, uint32 fromDay, uint32 toDay) external view returns (uint32 effectiveStart, uint32 effectiveEnd);
```

**Implementation Requirements:**
- Use EXISTING `stakingStorage` contract functions:
  - `stakingStorage.getStakersPaginated(offset, limit)` for user lists
  - `stakingStorage.getStakerStakeIds(user)` for user's stakes
  - `stakingStorage.getStake(user, stakeId)` for stake details
  - `stakingStorage.getStakerBalanceAt(user, day)` for historical balances
- Implement efficient algorithms for epoch participant discovery
- Cache frequently accessed data to reduce gas costs
- Use checkpoint system's binary search for optimal performance

## Implementation Order

### **Phase 1: Core Infrastructure**
1. Create `IRewardStrategy.sol` with exact interface above
2. Implement `GrantedRewardStorage.sol` with struct packing optimization
3. Implement `StrategiesRegistry.sol`
4. Implement `EpochManager.sol` with state machine logic

### **Phase 2: Main Logic**
1. Implement `RewardManager.sol` with batch processing
2. Focus on gas optimization for user functions
3. Implement comprehensive access controls

### **Phase 3: Example Strategies**
1. Implement `LinearAPRStrategy.sol`
2. Implement `EpochPoolStrategy.sol`
3. Create `StakingIntegration.sol` helper

### **Phase 4: Testing Suite**
1. Comprehensive unit tests for all contracts
2. Integration tests with existing staking system
3. Gas optimization verification (target: 30× reduction for users)
4. Security review and access control testing

## Testing Requirements

### **Gas Optimization Tests:**
```solidity
function testUserGasEfficiency() public {
    // User preview: target <5k gas
    uint256 gasBefore = gasleft();
    uint256 claimable = rewardManager.getClaimableRewards(user);
    uint256 gasUsed = gasBefore - gasleft();
    assertLt(gasUsed, 5000, "User preview exceeds gas target");
    
    // User claim: target <50k gas  
    gasBefore = gasleft();
    rewardManager.claimAllRewards();
    gasUsed = gasBefore - gasleft();
    assertLt(gasUsed, 50000, "User claim exceeds gas target");
}
```

### **Correctness Tests:**
- Verify retroactive calculation accuracy using known historical data
- Test epoch weight calculations with multiple overlapping stakes
- Validate reward totals match expected amounts from manual calculations
- Test edge cases (zero stakes, overlapping periods, mid-epoch unstaking)

### **Integration Tests:**
- Test with existing `StakingStorage` contract functions
- Verify historical data integration using real checkpoint data
- Test large-scale batch processing (100+ users)

## Deployment Configuration

### **Constructor Parameters:**
```solidity
// RewardManager constructor
RewardManager(
    address admin,                    // Admin role for the system
    address strategyRegistry,         // StrategiesRegistry address
    address grantedRewardStorage,     // GrantedRewardStorage address  
    address epochManager,             // EpochManager address
    address stakingStorage,           // EXISTING StakingStorage address
    address rewardToken               // ERC20 token for rewards
)
```

### **Access Control Setup:**
1. Deploy all NEW contracts with same admin
2. Grant `CONTROLLER_ROLE` in GrantedRewardStorage to RewardManager
3. Fund RewardManager with reward tokens
4. Register initial strategies (LinearAPR example)
5. Test with small amounts before full deployment

## Success Criteria

### **Performance Targets:**
- User reward preview: <5k gas ✓
- User claiming: <50k gas ✓  
- Admin batch calculation: <2M gas per 100 users ✓
- Support 100+ active strategies ✓

### **Functional Requirements:**
- Full retroactive reward calculation ✓
- Support both immediate and epoch-based strategies ✓
- Seamless integration with EXISTING staking system ✓
- Gas optimization of 30× for user operations ✓

### **Code Quality:**
- 100% test coverage for critical functions
- Comprehensive documentation
- Security best practices (access control, reentrancy protection)
- Gas optimization verified through benchmarks

## Error Handling Requirements

### **Custom Errors:**
```solidity
error StrategyNotFound(uint256 strategyId);
error InvalidStrategyType(StrategyType expected, StrategyType actual);
error EpochNotReady(uint32 epochId, EpochState currentState);
error BatchSizeExceeded(uint256 requested, uint256 maximum);
error InsufficientRewards(uint256 requested, uint256 available);
error InvalidTimeRange(uint32 fromDay, uint32 toDay);
error StakeNotFound(address staker, bytes32 stakeId);
error NoOverlapWithEpoch(bytes32 stakeId, uint32 epochStart, uint32 epochEnd);
```

### **Validation Requirements:**
- Validate all user inputs at contract boundaries
- Check for arithmetic overflow/underflow in all calculations
- Verify strategy compatibility before calculations
- Ensure epoch states are valid for operations
- Validate time ranges for historical calculations
- Verify stake existence before reward calculations

---

## Final Implementation Notes

This guide provides everything needed to implement a production-ready reward system from scratch. Follow the exact specifications, interfaces, and patterns outlined above. The implementation should achieve:

- ✅ 30× gas reduction for users through pre-calculation
- ✅ Full retroactive reward capability using EXISTING checkpoints  
- ✅ Support for both immediate (APR) and epoch-based (pool) strategies
- ✅ Scalable batch processing for large user bases
- ✅ Comprehensive security and access controls

**INTEGRATION APPROACH:**
- Import and use existing `IStakingStorage` interface
- Do NOT modify any existing staking contracts
- Build completely new reward system alongside existing staking system
- Use existing checkpoint data for historical calculations

Upon completion, the system will transform expensive real-time reward calculations into cheap pre-calculated lookups while maintaining complete historical accuracy and fairness for all users.