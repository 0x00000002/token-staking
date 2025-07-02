# Token Staking System: Contract Specifications

This document provides comprehensive technical specifications for the Token staking system contracts, including all functions, events, errors, and data structures across both the core staking system and reward management components.

## StakingVault.sol

### State Variables

- `MANAGER_ROLE`: `bytes32` - Role for pausing/unpausing the contract.
- `CLAIM_CONTRACT_ROLE`: `bytes32` - Role for integrated claim contracts.
- `CONTROLLER_ROLE`: `bytes32` - Role for the vault to interact with storage.
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
- `_stakes`: `mapping(address => mapping(bytes32 => Stake))`
- `_stakers`: `mapping(address => StakerInfo)`
- `_checkpoints`: `mapping(address => Checkpoint[])`
- `_dailySnapshots`: `mapping(uint16 => DailySnapshot)`
- `_allStakers`: `EnumerableSet.AddressSet`

### Data Structures

- `Stake { uint128 amount, uint16 stakeDay, uint16 unstakeDay, uint16 daysLock, uint16 flags }`
- `StakerInfo { uint128 totalStaked, uint128 totalRewarded, uint128 totalClaimed, uint32 stakesCounter, uint32 activeStakesNumber, uint16 lastCheckpointDay }`
- `DailySnapshot { uint128 totalStakedAmount, uint16 totalStakesCount }`

### Functions

- `createStake(address staker, uint128 amount, uint16 daysLock, uint16 flags)`: Creates a new stake record. Access: `CONTROLLER_ROLE`.
- `removeStake(address staker, bytes32 id)`: Marks a stake as unstaked. Access: `CONTROLLER_ROLE`.
- `getStake(address staker, bytes32 id) returns (Stake memory)`: Retrieves a specific stake.
- `getStakerInfo(address staker) returns (StakerInfo memory)`: Retrieves information about a staker.
- `getStakerBalanceAt(address staker, uint16 targetDay) returns (uint128)`: Retrieves a staker's historical balance using binary search.
- `getStakersPaginated(uint256 offset, uint256 limit) returns (address[] memory)`: Returns a paginated list of all unique stakers.
- `getTotalStakersCount() returns (uint256)`: Returns the total number of unique stakers.
- `getCurrentTotalStaked() returns (uint128)`: Returns the total amount of tokens currently staked in the system.
- `getDailySnapshot(uint16 day) returns (DailySnapshot memory)`: Returns the daily snapshot for a given day.

### Events

- `Staked(address indexed staker, bytes32 indexed id, uint128 amount, uint16 indexed day, uint16 daysLock, uint16 flags)`
- `Unstaked(address indexed staker, bytes32 indexed id, uint16 indexed day, uint128 amount)`
- `CheckpointCreated(address indexed staker, uint16 indexed day, uint128 balance, uint16 stakesCount)`

---

_For interfaces, see `src/interfaces/`._
_For gas costs and security analysis, see the [System Architecture](audit/system_architecture.md) document._
