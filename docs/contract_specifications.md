# Token Staking System: Contract Specifications

This document provides technical specifications for the staking system contracts, including functions, events, errors, and data structures.

## Reward System Contracts

### IRewardStrategy.sol

This interface defines the standard for all reward calculation strategy contracts.

#### Enums

- **`StrategyType`**:
  - `POOL_SIZE_INDEPENDENT`: Strategy whose reward can be calculated at any time.
  - `POOL_SIZE_DEPENDENT`: Strategy that requires pool-wide data (like `totalStakeWeight`) available only after the pool ends.

#### Functions

- `getStrategyType() external view returns (StrategyType)`: Returns the type of the strategy.
- `calculateReward(address user, IStakingStorage.Stake calldata stake, uint256 lastClaimDay, uint16 poolStartDay, uint16 poolEndDay) external view returns (uint256)`: Calculates reward for `POOL_SIZE_INDEPENDENT` strategies.
- `calculateReward(address user, IStakingStorage.Stake calldata stake, uint128 totalPoolWeight, uint256 totalRewardAmount, uint16 poolStartDay, uint16 poolEndDay) external view returns (uint256)`: Calculates reward for `POOL_SIZE_DEPENDENT` strategies.

---

### PoolManager.sol

Manages the scheduling and configuration of reward pools.

#### State Variables

- `pools`: `mapping(uint256 => Pool)`: Stores all pool configurations.
- `poolStrategies`: `mapping(uint256 => mapping(uint8 => uint32[]))`: Maps pool ID and layer ID to an array of strategy IDs.
- `strategyExclusivity`: `mapping(uint32 => StrategyExclusivity)`: Stores the exclusivity type for a strategy within a pool context.
- `nextPoolId`: `uint256`: Counter for auto-incrementing pool IDs.

#### Data Structures

- `struct Pool { uint16 startDay; uint16 endDay; uint128 totalStakeWeight; uint256 parentPoolId; }`
- `enum StrategyExclusivity { NORMAL, EXCLUSIVE, SEMI_EXCLUSIVE }`

#### Functions

- `upsertPool(uint256 _poolId, uint16 _startDay, uint16 _endDay, uint256 _parentPoolId) external returns (uint256 poolId)`: Creates a new pool or updates an existing one. Can only be called before the pool starts. Access: `MANAGER_ROLE`.
- `assignStrategyToPool(uint256 _poolId, uint8 _layerId, uint32 _strategyId, StrategyExclusivity _exclusivity)`: Assigns a strategy to a specific layer within a pool. Can only be done before the pool starts. Access: `MANAGER_ROLE`.
- `setPoolTotalStakeWeight(uint256 _poolId, uint128 _totalStakeWeight)`: Sets the final total stake weight for a pool. Can only be called after the pool has ended. Access: `CONTROLLER_ROLE`.
- `getPool(uint256 _poolId) external view returns (Pool memory)`: Returns the configuration for a specific pool.
- `getPoolsByDateRange(uint16 _fromDay, uint16 _toDay) external view returns (Pool[] memory, uint256[] memory)`: Returns all pools that are active within a given date range.

#### Events

- `PoolUpserted(uint256 indexed poolId, uint16 startDay, uint16 endDay)`
- `StrategyAssigned(uint256 indexed poolId, uint8 indexed layerId, uint32 indexed strategyId, StrategyExclusivity exclusivity)`
- `PoolWeightSet(uint256 indexed poolId, uint128 totalStakeWeight)`

---

### ClaimsJournal.sol

Acts as the ledger for all user claims.

#### State Variables

- `directStrategyClaims`: `mapping(bytes32 => mapping(uint32 => uint256))`: Stake ID -> Strategy ID -> Last Claim Day.
- `layerClaimState`: `mapping(address => mapping(uint256 => mapping(uint8 => LayerClaimType)))`: User -> Pool ID -> Layer ID -> Claim Type.

#### Enums

- `LayerClaimType { NONE, NORMAL, EXCLUSIVE, SEMI_EXCLUSIVE }`

#### Functions

- `recordClaim(address _user, uint32 _poolId, uint8 _layerId, uint32 _strategyId, bytes32 _stakeId, LayerClaimType _claimType, uint256 _claimDay)`: Records a claim in the journal. Access: `REWARD_MANAGER_ROLE`.
- `getLastClaimDay(bytes32 _stakeId, uint32 _strategyId) external view returns (uint256)`: Returns the last day a claim was made for a specific stake and strategy.
- `getLayerClaimState(address _user, uint256 _poolId, uint8 _layerId) external view returns (LayerClaimType)`: Returns the claim state for a user on a specific pool layer.

#### Events

- `DirectClaimRecorded(bytes32 indexed stakeId, uint32 indexed strategyId, uint256 claimDay)`
- `LayerStateUpdated(address indexed user, uint256 indexed poolId, uint8 indexed layerId, LayerClaimType claimType)`

---

### RewardManager.sol

The central orchestrator for reward claims.

#### Functions

- `fundStrategy(uint32 _strategyId, uint256 _amount)`: Deposits funds for a specific strategy. Access: `MANAGER_ROLE`.
- `claimReward(uint32 _poolId, uint32 _strategyId, bytes32 _stakeId)`: The primary function for users to claim their reward from a specific strategy in a pool.
- `getClaimableReward(uint32 _poolId, uint32 _strategyId, bytes32 _stakeId) external view returns (uint256)`: A view function to check the pending reward amount without executing a claim.

#### Events

- `RewardClaimed(address indexed user, uint32 indexed poolId, uint32 indexed strategyId, bytes32 stakeId, uint256 amount)`
- `StrategyFunded(uint32 indexed strategyId, uint256 amount)`

---

## Core Staking Contracts

_(Sections for StakingVault.sol and StakingStorage.sol remain unchanged as their external API is stable)_

---

## StakingVault.sol

### State Variables

- `MANAGER_ROLE`: `bytes32` - Role for pausing/unpausing the contract.
- `CLAIM_CONTRACT_ROLE`: `bytes32` - Role for integrated claim contracts.
- `MULTISIG_ROLE`: `bytes32` - Dedicated role for emergency token recovery.
- `stakingStorage`: `IStakingStorage` - Immutable reference to the storage contract.
- `token`: `IERC20` - Immutable reference to the staking token.

### Functions

- `stake(uint128 amount, uint16 daysLock) returns (bytes32 stakeId)`: Stakes tokens for the caller.
- `unstake(bytes32 stakeId)`: Unstakes matured tokens for the caller.
- `stakeFromClaim(address staker, uint128 amount, uint16 daysLock) returns (bytes32 stakeId)`: Stakes tokens on behalf of a user from an authorized claim contract.
- `pause()`: Pauses the contract. Access: `MANAGER_ROLE`.
- `unpause()`: Unpauses the contract. Access: `MANAGER_ROLE`.
- `emergencyRecover(IERC20 token_, uint256 amount)`: Recovers non-staking ERC20 tokens. Access: `MULTISIG_ROLE`.

### Events

- `Staked(address indexed staker, bytes32 stakeId, uint128 amount, uint16 indexed stakeDay, uint16 indexed daysLock)`
- `Unstaked(address indexed staker, bytes32 indexed stakeId, uint16 indexed unstakeDay, uint128 amount)`
- `EmergencyRecover(address token, address to, uint256 amount)`

### Custom Errors

- `InvalidAmount()`
- `StakeNotFound(address staker, bytes32 stakeId)`
- `StakeNotMatured(bytes32 stakeId, uint16 matureDay, uint16 currentDay)`
- `StakeAlreadyUnstaked(bytes32 stakeId)`
- `NotStakeOwner(address caller, address owner)`

---

## StakingStorage.sol

### State Variables

- `MANAGER_ROLE`: `bytes32` - Role for future administrative functions.
- `CONTROLLER_ROLE`: `bytes32` - Role required to modify storage state; granted to `StakingVault`.
- `_stakes`: `mapping(bytes32 => Stake)`
- `_stakers`: `mapping(address => StakerInfo)`
- `_stakerCheckpoints`: `mapping(address => uint16[])`
- `_stakerBalances`: `mapping(address => mapping(uint16 => uint128))`
- `_dailySnapshots`: `mapping(uint16 => DailySnapshot)`
- `_allStakers`: `EnumerableSet.AddressSet`

### Data Structures

- `Stake { uint128 amount, uint16 stakeDay, uint16 unstakeDay, uint16 daysLock, uint16 flags }`
- `StakerInfo { uint128 totalStaked, uint128 totalRewarded, uint128 totalClaimed, uint16 stakesCounter, uint16 activeStakesNumber, uint16 lastCheckpointDay }`
- `DailySnapshot { uint128 totalStakedAmount, uint16 totalStakesCount }`

### Functions

- `createStake(address staker, uint128 amount, uint16 daysLock, uint16 flags)`: Creates a new stake record. Access: `CONTROLLER_ROLE`.
- `removeStake(address staker, bytes32 id)`: Marks a stake as unstaked. Access: `CONTROLLER_ROLE`.
- `getStake(bytes32 id) returns (Stake memory)`: Retrieves a specific stake.
- `getStakerInfo(address staker) returns (StakerInfo memory)`: Retrieves information about a staker.
- `getStakerBalanceAt(address staker, uint16 targetDay) returns (uint128)`: Retrieves a staker's historical balance using binary search.
- `getStakersPaginated(uint256 offset, uint256 limit) returns (address[] memory)`: Returns a paginated list of all unique stakers.
- `getTotalStakersCount() returns (uint256)`: Returns the total number of unique stakers.
- `getCurrentTotalStaked() returns (uint128)`: Returns the total amount of tokens currently staked in the system.
- `getDailySnapshot(uint16 day) returns (DailySnapshot memory)`: Returns the daily snapshot for a given day.

### Events

- `Staked(address indexed staker, bytes32 indexed stakeId, uint128 amount, uint16 indexed stakeDay, uint16 daysLock, uint16 flags)`
- `Unstaked(address indexed staker, bytes32 indexed stakeId, uint16 indexed unstakeDay, uint128 amount)`
- `CheckpointCreated(address indexed staker, uint16 indexed day, uint128 balance, uint16 stakesCount)`

---

_For interfaces, see `src/interfaces/`._
_For gas costs and security analysis, see the [System Architecture](audit/system_architecture.md) document._
