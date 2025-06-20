# Token Staking: Contract Specifications

## Overview

This document provides detailed technical specifications for the Token staking system contracts. The system consists of two main contracts working together to provide secure, efficient staking functionality.

## Contract Architecture

### StakingVault.sol

**Primary Interface Contract**

The StakingVault serves as the main user-facing contract that handles all business logic and external interactions.

#### Inheritance

- `ReentrancyGuard` - Protection against reentrancy attacks
- `AccessControl` - Role-based permission system
- `Pausable` - Emergency pause functionality
- `IStakingVault` - Interface compliance

#### Core Dependencies

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

#### State Variables

```solidity
// Role definitions
bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
bytes32 public constant CLAIM_CONTRACT_ROLE = keccak256("CLAIM_CONTRACT_ROLE");

// Immutable references
IStakingStorage public immutable stakingStorage;
IERC20 public immutable token;
```

#### Key Functions

##### stake(uint128 amount, uint16 daysLock)

Stakes tokens with a specified time lock period.

**Parameters:**

- `amount`: Amount of tokens to stake (uint128 for gas optimization)
- `daysLock`: Number of days to lock tokens

**Returns:**

- `stakeId`: Unique identifier for the created stake

**Access:** Public, requires contract not paused
**Modifiers:** `whenNotPaused`, `nonReentrant`

##### unstake(bytes32 stakeId)

Unstakes matured tokens and returns them to the caller.

**Parameters:**

- `stakeId`: Unique identifier of the stake to unstake

**Access:** Public, requires contract not paused
**Modifiers:** `whenNotPaused`, `nonReentrant`

**Validation:**

- Stake must exist and belong to caller
- Stake must not already be unstaked
- Time lock period must have elapsed

##### stakeFromClaim(address staker, uint128 amount, uint16 daysLock)

Allows claim contracts to stake tokens on behalf of users.

**Parameters:**

- `staker`: Address of the actual staker
- `amount`: Amount of tokens to stake
- `daysLock`: Number of days to lock tokens

**Returns:**

- `stakeId`: Unique identifier for the created stake

**Access:** Only `CLAIM_CONTRACT_ROLE`
**Modifiers:** `whenNotPaused`, `onlyRole(CLAIM_CONTRACT_ROLE)`

#### Administrative Functions

##### pause() / unpause()

Emergency control functions to halt/resume contract operations.
**Access:** Only `MANAGER_ROLE`

##### emergencyRecover(IERC20 token\_, uint256 amount)

Emergency function to recover tokens from the contract.
**Access:** Only `DEFAULT_ADMIN_ROLE`

#### Events

```solidity
event Staked(
    address indexed staker,
    bytes32 stakeId,
    uint128 amount,
    uint16 indexed stakeDay,
    uint16 indexed daysLock
);

event Unstaked(
    address indexed staker,
    bytes32 indexed stakeId,
    uint16 indexed unstakeDay,
    uint128 amount
);
```

#### Custom Errors

```solidity
error InvalidAmount();
error StakeNotFound(address staker, bytes32 stakeId);
error StakeNotMatured(bytes32 stakeId, uint16 matureDay, uint16 currentDay);
error StakeAlreadyUnstaked(bytes32 stakeId);
error NotStakeOwner(address caller, address owner);
```

### StakingStorage.sol

**Data Persistence Contract**

The StakingStorage contract manages all data persistence, historical tracking, and complex queries.

#### Inheritance

- `AccessControl` - Role-based permission system
- `IStakingStorage` - Interface compliance

#### Role System

```solidity
bytes32 constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
bytes32 constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
```

#### Data Structures

##### Stake Struct

```solidity
struct Stake {
    uint128 amount;      // Amount of tokens staked
    uint16 stakeDay;     // Day when stake was created
    uint16 unstakeDay;   // Day when stake was unstaked (0 if active)
    uint16 daysLock;     // Lock period in days
    bool isFromClaim;    // Whether stake originated from claim contract
}
```

##### StakerInfo Struct

```solidity
struct StakerInfo {
    uint16 stakesCount;        // Number of stakes created by user
    uint128 totalStaked;       // Total amount currently staked
    uint16 lastCheckpointDay;  // Last day a checkpoint was created
}
```

##### DailySnapshot Struct

```solidity
struct DailySnapshot {
    uint128 totalStakedAmount; // Total tokens staked on this day
    uint16 totalStakesCount;   // Total number of active stakes
}
```

#### Storage Mappings

```solidity
// Core stake data
mapping(address => mapping(uint16 => bytes32[])) public IDs;
mapping(address => mapping(bytes32 => Stake)) private _stakes;
mapping(address => StakerInfo) private _stakers;

// Checkpoint system
mapping(address => uint16[]) private _stakerCheckpoints;
mapping(address => mapping(uint16 => uint128)) private _stakerBalances;

// Global statistics
mapping(uint16 => DailySnapshot) private _dailySnapshots;
address[] private _allStakers;
mapping(address => bool) private _isStakerRegistered;
```

#### Key Functions

##### createStake(address staker, bytes32 id, uint128 amount, uint16 daysLock, bool isFromClaim)

Creates a new stake record and updates all related data structures.

**Access:** Only `CONTROLLER_ROLE` (StakingVault)
**Side Effects:**

- Creates checkpoint
- Updates daily snapshot
- Registers new stakers
- Emits Staked event

##### removeStake(bytes32 id)

Marks a stake as unstaked and updates balances.

**Access:** Only `CONTROLLER_ROLE` (StakingVault)
**Note:** Stake records are preserved for historical purposes

##### getStakerBalanceAt(address staker, uint16 targetDay)

Retrieves a staker's balance at a specific historical point.

**Implementation:** Uses binary search on checkpoints for O(log n) complexity

##### batchGetStakerBalances(address[] stakers, uint16 targetDay)

Efficient batch retrieval of multiple staker balances.

#### Checkpoint System

The checkpoint system automatically tracks balance changes over time:

##### Binary Search Optimization

```solidity
function _getStakerBalanceAt(address staker, uint16 targetDay)
    internal view returns (uint128) {

    // Quick exact match check
    uint128 exactBalance = _stakerBalances[staker][targetDay];
    if (exactBalance > 0) return exactBalance;

    // Binary search for closest checkpoint
    uint16[] memory checkpoints = _stakerCheckpoints[staker];
    // ... binary search implementation
}
```

##### Checkpoint Creation

Checkpoints are automatically created on every balance change:

- New stake creation
- Stake unstaking
- Maintains sorted checkpoint arrays
- Updates daily snapshots

#### Query Functions

##### Pagination Support

```solidity
function getStakersPaginated(uint256 offset, uint256 limit)
    external view returns (address[] memory)
```

##### Global Statistics

- `getCurrentTotalStaked()`: Real-time total staked amount
- `getDailySnapshot(uint16 day)`: Historical daily statistics
- `getTotalStakersCount()`: Total number of unique stakers

#### Events

```solidity
event Staked(
    address indexed staker,
    bytes32 indexed id,
    uint128 amount,
    uint16 indexed day,
    uint16 daysLock,
    bool isFromClaim
);

event Unstaked(
    address indexed staker,
    bytes32 indexed id,
    uint16 indexed day,
    uint128 amount
);

event CheckpointCreated(
    address indexed staker,
    uint16 indexed day,
    uint128 balance,
    uint16 stakesCount
);
```

## Interface Specifications

### IStakingVault

```solidity
interface IStakingVault {
    function stake(uint128 amount, uint16 daysLock)
        external returns (bytes32 stakeId);

    function unstake(bytes32 stakeId) external;

    function stakeFromClaim(address staker, uint128 amount, uint16 daysLock)
        external returns (bytes32 stakeId);
}
```

### IStakingStorage

```solidity
interface IStakingStorage {
    struct Stake {
        uint128 amount;
        uint16 stakeDay;
        uint16 unstakeDay;
        uint16 daysLock;
        bool isFromClaim;
    }

    struct StakerInfo {
        uint16 stakesCount;
        uint128 totalStaked;
        uint16 lastCheckpointDay;
    }

    struct DailySnapshot {
        uint128 totalStakedAmount;
        uint16 totalStakesCount;
    }

    function createStake(address staker, bytes32 id, uint128 amount, uint16 daysLock, bool isFromClaim) external;
    function removeStake(bytes32 id) external;
    function getStake(address staker, bytes32 id) external view returns (Stake memory);
    function getStakerInfo(address staker) external view returns (StakerInfo memory);
    function getStakerBalanceAt(address staker, uint16 targetDay) external view returns (uint128);
}
```

## Gas Optimization

### Design Choices

- **uint128 for amounts**: Balances gas cost and precision
- **uint16 for days**: Supports ~180 years of operation
- **Binary search**: O(log n) historical queries
- **Packed structs**: Minimizes storage slots
- **Batch operations**: Reduces per-operation overhead

### Typical Gas Costs

- **Stake operation**: ~150,000 gas
- **Unstake operation**: ~120,000 gas
- **Balance query**: ~15,000 gas
- **Historical query**: ~25,000 gas

## Security Considerations

### Access Control

- **Three-tier role system**: Admin, Manager, Controller
- **Immutable references**: Core contract addresses cannot change
- **Role separation**: Different capabilities for different roles

### Attack Prevention

- **Reentrancy guards**: All state-changing functions protected
- **Integer overflow protection**: Using OpenZeppelin SafeERC20
- **Time manipulation resistance**: Day calculation based on block.timestamp
- **Flash loan protection**: Balance changes require actual token transfers

### Emergency Mechanisms

- **Pause functionality**: Can halt all operations
- **Emergency recovery**: Admin can recover stuck tokens
- **Role management**: Flexible role assignment and revocation

## Deployment Specifications

### Constructor Parameters

#### StakingVault

```solidity
constructor(
    IERC20 _token,        // The staking token contract
    address _storage,     // StakingStorage contract address
    address _admin,       // DEFAULT_ADMIN_ROLE recipient
    address _manager      // MANAGER_ROLE recipient
)
```

#### StakingStorage

```solidity
constructor(
    address admin,    // DEFAULT_ADMIN_ROLE recipient
    address manager,  // MANAGER_ROLE recipient
    address vault     // CONTROLLER_ROLE recipient (StakingVault)
)
```

### Deployment Sequence

1. Deploy StakingStorage contract
2. Deploy StakingVault contract with storage address
3. Verify role assignments
4. Test basic functionality
5. Transfer ownership if needed

### Configuration Checklist

- [ ] Correct token address
- [ ] Proper role assignments
- [ ] Storage contract linked correctly
- [ ] Emergency functions tested
- [ ] Event emission verified

## Integration Guidelines

### External Contract Integration

- Implement `CLAIM_CONTRACT_ROLE` for claim contracts
- Use `stakeFromClaim()` for indirect staking
- Monitor events for stake tracking
- Implement proper error handling

### Frontend Integration

- Listen to `Staked` and `Unstaked` events
- Use view functions for real-time data
- Implement proper stake ID tracking
- Handle time lock validation

### Analytics Integration

- Monitor `CheckpointCreated` events
- Use daily snapshots for metrics
- Implement pagination for large datasets
- Query historical balances efficiently

---

This specification provides comprehensive technical details for implementing, integrating with, and maintaining the Token staking system contracts.
