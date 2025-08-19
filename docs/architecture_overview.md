# Token Staking System: Architecture Overview

## System Architecture

The Token staking system features a modular architecture with clear separation of concerns across core staking functionality and reward management. The design emphasizes security, gas efficiency, and maintainability while supporting both immediate and epoch-based reward strategies.

### Core Components

#### 1. Staking Core System

##### StakingVault (Business Logic Layer)

**Location**: `src/StakingVault.sol`
**Role**: Primary interface contract that handles all user interactions and business logic.

**Key Responsibilities**:

- **Token Management**: Handles IERC20 token transfers (deposits/withdrawals)
- **Stake Operations**: Creates and processes stake/unstake requests with compound stakeId generation
- **Time Lock Enforcement**: Validates stake maturity before allowing unstaking
- **Access Control**: Role-based permissions (Admin, Manager, Claim Contract)
- **Security**: Reentrancy protection, pause mechanism, emergency controls

##### StakingStorage (Data Persistence Layer)

**Location**: `src/StakingStorage.sol`
**Role**: Dedicated storage contract that maintains all staking data and historical records.

**Key Responsibilities**:

- **Compound StakeId Management**: Generates unique stake identifiers using address + counter
- **Stake Flags System**: Extensible `uint16 flags` field for multiple boolean properties
- **Historical Data**: Maintains comprehensive checkpoint system with O(log n) queries
- **Balance Tracking**: Real-time and historical balance calculations
- **Global Statistics**: Network-wide staking metrics and daily snapshots

#### 2. Reward Management System

###### **PoolManager (`src/reward-system/PoolManager.sol`)**

- **Role**: **Scheduler**. This contract is the single source of truth for defining reward pool _schedules_ and _configurations_.
- **Key Responsibilities**:
  - **Pool Definition**: Creates pools with a `startDay` and `endDay`. Pool configurations are **immutable** once the pool has started.
  - **Layer and Strategy Assignment**: Manages which reward strategies are assigned to a pool and on which "layer". A layer is a conceptual grouping of strategies within a pool.
  - **Exclusivity Rules**: Defines the exclusivity rules for strategies within a pool (`NORMAL`, `EXCLUSIVE`, `SEMI_EXCLUSIVE`), which governs claim eligibility.
  - **Weight Finalization**: Stores the final `totalStakeWeight` for a pool, set by an off-chain `CONTROLLER` role after the pool has ended. This is used for `POOL_SIZE_DEPENDENT` strategies.

##### **StrategiesRegistry (`src/reward-system/StrategiesRegistry.sol`)**

- **Role**: **Directory**. A simple on-chain mapping from a strategy ID to its deployed contract address.

##### **RewardManager (`src/reward-system/RewardManager.sol`)**

- **Role**: **Orchestrator**. This is the central, user-facing contract for all reward claims. It orchestrates the entire claim process, interacting with all other components of the system.
- **Key Responsibilities**:
  - **Claim Processing**: Handles the `claimReward` function, which is the single entry point for users.
  - **Data Aggregation**: Fetches data from `PoolManager` (pool rules), `StakingStorage` (user stake data), and `ClaimsJournal` (claim history).
  - **Reward Calculation**: Calls the appropriate strategy contract to calculate the user's reward based on the strategy's type.
  - **Payout**: Manages funding for strategies and transfers the final reward amount to the user.

##### **ClaimsJournal (`src/reward-system/ClaimsJournal.sol`)**

- **Role**: **Ledger**. Acts as the definitive, auditable ledger for all user claims. It is the single source of truth for "who has claimed what and when."
- **Key Responsibilities**:
  - **Direct Claim Tracking**: Records the `lastClaimDay` for a specific user's stake against a specific strategy. This is crucial for preventing double-claims.
  - **Layer Exclusivity State**: Tracks the claims made by a user on each layer of a pool to enforce exclusivity rules.

##### **IRewardStrategy (`src/interfaces/reward/IRewardStrategy.sol`)**

- **Role**: **Calculation Logic Interface**. Defines a universal interface for all reward strategy contracts.
- **Key Features**:
  - **`StrategyType` Enum**: Strategies now self-report their type:
    - `POOL_SIZE_INDEPENDENT`: Can be calculated at any time based on stake duration (e.g., a simple APR).
    - `POOL_SIZE_DEPENDENT`: Requires the pool to end and the `totalStakeWeight` to be finalized before calculation (e.g., a share of a fixed reward pot).
  - **Overloaded `calculateReward` function**: Provides two distinct functions to handle the different data requirements of each strategy type.

#### 3. Interface Architecture

##### Organized Interface Structure

```
src/interfaces/
├── staking/
│   ├── IStakingStorage.sol    # Core staking data interface
│   └── StakingErrors.sol      # Staking error definitions
└── reward/
    ├── RewardEnums.sol        # Shared enumerations
    ├── RewardErrors.sol       # Standardized error definitions
    ├── IRewardStrategy.sol
    └── IRewardManager.sol     # RewardManager interface and events
```

##### Data Structures

**Compound StakeId System**:

```solidity
// 256-bit stakeId: [160-bit address][96-bit counter]
function _generateStakeId(address staker, uint32 counter) internal pure returns (bytes32) {
    return bytes32((uint256(uint160(staker)) << 96) | counter);
}
```

**Flag System**:

```solidity
struct Stake {
    uint128 amount;
    uint16 stakeDay;
    uint16 unstakeDay;
    uint16 daysLock;
    uint16 flags;  // Supports 16 boolean properties
}
```

**Checkpoint System**: Binary search optimization for historical balance queries.

### Data Flow Architecture

#### Staking Flow

```
User Transaction
       ↓
StakingVault (validates & processes)
       ↓
StakingStorage (persists & tracks)
       ↓
Checkpoint System (historical record)
       ↓
Event Emission (transparency)
```

#### Reward Claim Flows

**1. Granted Rewards (`claimReward`)**

```mermaid
graph TD
    subgraph "Actors"
        User
        Manager["Manager/Admin"]
        Controller["Controller<br/>(Off-chain)"]
    end

    subgraph "Core Contracts"
        RewardManager["RewardManager<br/><i>Orchestrator</i>"]
        PoolManager["PoolManager<br/><i>Scheduler</i>"]
        ClaimsJournal["ClaimsJournal<br/><i>Ledger</i>"]
        StakingStorage["StakingStorage<br/><i>Stake Data</i>"]
        StrategiesRegistry["StrategiesRegistry<br/><i>Strategy Lookup</i>"]
        Strategy["IRewardStrategy<br/>(Implementation)"]
        RewardToken["RewardToken<br/>(ERC20)"]
    end

    %% Configuration Flow
    Manager -- "1. Creates Pool" --> PoolManager
    Manager -- "2. Registers Strategy" --> StrategiesRegistry
    Manager -- "3. Assigns Strategy to Pool" --> PoolManager
    Manager -- "4. Funds Strategy" --> RewardManager

    %% Calculation Flow
    Controller -- "5. Sets Total Weight<br/>(for dependent strategies)" --> PoolManager

    %% Claim Flow
    User -- "6. claimReward(poolId, ...)" --> RewardManager

    RewardManager -- "7. Reads Pool Data" --> PoolManager
    RewardManager -- "8. Reads Strategy Addr" --> StrategiesRegistry
    RewardManager -- "9. Reads Stake Data" --> StakingStorage
    RewardManager -- "10. Reads Claim History" --> ClaimsJournal
    RewardManager -- "11. Calls calculateReward()" --> Strategy
    Strategy -- "rewardAmount" --> RewardManager

    RewardManager -- "12. Records Claim" --> ClaimsJournal
    RewardManager -- "13. Transfers Reward" --> RewardToken
    RewardToken -- "Tokens" --> User

## Deployment Architecture (Updated)

1.  **Token Contract**: Deploy or use existing ERC20 token.
2.  **StakingStorage**: Deploy storage contract.
3.  **StakingVault**: Deploy vault, linking to storage.
4.  **PoolManager**: Deploy pool manager.
5.  **StrategiesRegistry**: Deploy strategy registry.
6.  **RewardManager**: Deploy `RewardManager` with a **placeholder `address(0)` for `ClaimsJournal`**.
7.  **ClaimsJournal**: Deploy `ClaimsJournal`, passing the real `RewardManager` address in the constructor.
8.  **Finalize Connection**: Call `setClaimsJournal()` on the deployed `RewardManager` to provide it with the real `ClaimsJournal` address.
9.  **Role Configuration**: Grant all necessary roles across contracts (e.g., give `RewardManager` the `REWARD_MANAGER_ROLE` on `ClaimsJournal`).

### Configuration Management

- **Immutable References**: Core contract addresses cannot be changed
- **Role Management**: Flexible role assignment for operational needs
- **Emergency Controls**: Pause and emergency recovery mechanisms

## Monitoring and Observability

### Event Architecture

Comprehensive event emission for complete system transparency:

- **Stake Events**: Full stake creation details
- **Unstake Events**: Complete unstaking information
- **Checkpoint Events**: Historical data tracking
- **Reward Events**: Detailed events for both granted and immediate claims.
- **Administrative Events**: Role changes and system state updates

### Analytics Support

- **Daily Snapshots**: Network-wide statistics
- **Historical Queries**: Complete historical balance data
- **Staker Analytics**: Individual and aggregate staking metrics
- **Integration Points**: Data export capabilities for external analytics

## Upgrade and Maintenance Strategy

### Immutable Core

- **Core Logic**: StakingVault and StakingStorage are immutable once deployed
- **Data Integrity**: Historical data cannot be modified or lost
- **Security**: Eliminates upgrade-related attack vectors

### Extensibility

- **Modular Design**: New features can be added through additional contracts
- **Integration Layers**: External contracts can build on top of the core system
- **Backward Compatibility**: Future enhancements maintain compatibility
```
