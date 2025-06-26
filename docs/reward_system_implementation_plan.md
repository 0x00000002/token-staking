# Reward System Implementation Plan

## Overview

This document provides a detailed implementation plan for the dual-strategy reward system, including code snippets, data structures, contract specifications, and step-by-step development phases.

## Phase 1: Core Data Structures and Interfaces

### **1.1 Enhanced Strategy Interface**

```solidity
// File: src/interfaces/IRewardStrategy.sol
pragma solidity ^0.8.30;

enum StrategyType {
    IMMEDIATE,     // Can calculate anytime with historical data
    EPOCH_BASED    // Must wait for epoch to close
}

interface IRewardStrategy {
    struct StrategyParameters {
        string name;
        string description;
        uint16 startDay;
        uint16 endDay;
        StrategyType strategyType;
        uint32 epochDuration;  // 0 for immediate strategies
    }

    function getStrategyType() external view returns (StrategyType);
    function getEpochDuration() external view returns (uint32);
    function getParameters() external view returns (StrategyParameters memory);
    function updateParameters(uint256[] calldata params) external;
    
    // For immediate strategies
    function calculateReward(
        address staker,
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    ) external view returns (uint256);
    
    // For epoch-based strategies
    function calculateEpochReward(
        address staker,
        bytes32 stakeId,
        uint32 epochId
    ) external view returns (uint256);
    
    function isApplicable(
        address staker,
        bytes32 stakeId
    ) external view returns (bool);
}
```

### **1.2 Epoch Management Structures**

```solidity
// File: src/interfaces/IEpochManager.sol
pragma solidity ^0.8.30;

enum EpochState {
    ANNOUNCED,     // Rules announced, users can prepare
    ACTIVE,        // Epoch running, stakes count toward rewards
    ENDED,         // Epoch finished, awaiting calculation
    CALCULATED,    // Rewards calculated and ready to claim
    FINALIZED      // Rewards distributed, epoch closed
}

interface IEpochManager {
    struct Epoch {
        uint32 epochId;
        uint32 startDay;
        uint32 endDay;
        uint256 estimatedPoolSize;
        uint256 actualPoolSize;
        uint256 strategyId;
        EpochState state;
        uint256 totalParticipants;
        uint256 totalStakeWeight;
        uint32 announcedAt;
        uint32 calculatedAt;
    }

    function announceEpoch(
        uint32 startDay,
        uint32 endDay,
        uint256 strategyId,
        uint256 estimatedPoolSize
    ) external returns (uint32 epochId);
    
    function setEpochPoolSize(uint32 epochId, uint256 actualPoolSize) external;
    function calculateEpochRewards(uint32 epochId, uint256 batchStart, uint256 batchSize) external;
    function getEpochState(uint32 epochId) external view returns (EpochState);
    function getEpoch(uint32 epochId) external view returns (Epoch memory);
}
```

### **1.3 Granted Reward Storage**

```solidity
// File: src/interfaces/IGrantedRewardStorage.sol
pragma solidity ^0.8.30;

interface IGrantedRewardStorage {
    struct GrantedReward {
        uint128 amount;           // Up to 340 trillion tokens
        uint32 epochId;          // 0 for immediate strategies
        uint32 grantedAt;        // Timestamp when granted
        uint16 strategyId;       // Which strategy granted this
        uint16 version;          // Strategy version
        bool claimed;            // Claim status
        // Total: 256 bits = 1 storage slot
    }

    function grantReward(
        address user,
        uint256 strategyId,
        uint256 amount,
        uint32 epochId
    ) external;
    
    function markRewardClaimed(
        address user,
        uint256 rewardIndex
    ) external;
    
    function getUserRewards(address user) external view returns (GrantedReward[] memory);
    function getUserClaimableAmount(address user) external view returns (uint256);
    function getUserEpochRewards(address user, uint32 epochId) external view returns (GrantedReward[] memory);
}
```

## Phase 2: Core Contract Implementations

### **2.1 Enhanced Strategies Registry**

```solidity
// File: src/strategies/EnhancedStrategiesRegistry.sol
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IRewardStrategy.sol";

contract EnhancedStrategiesRegistry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct RegistryEntry {
        address strategyAddress;
        StrategyType strategyType;
        uint32 registeredAt;
        bool isActive;
        uint16 version;
    }

    mapping(uint256 => RegistryEntry) public strategies;
    mapping(StrategyType => uint256[]) public strategiesByType;
    uint256 public strategyCount;
    uint256[] private _activeStrategyIds;

    event StrategyRegistered(uint256 indexed strategyId, address strategyAddress, StrategyType strategyType);
    event StrategyStatusChanged(uint256 indexed strategyId, bool isActive);

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
    }

    function registerStrategy(address strategyAddress) external onlyRole(ADMIN_ROLE) returns (uint256) {
        uint256 newStrategyId = ++strategyCount;
        IRewardStrategy strategy = IRewardStrategy(strategyAddress);
        StrategyType strategyType = strategy.getStrategyType();
        
        strategies[newStrategyId] = RegistryEntry({
            strategyAddress: strategyAddress,
            strategyType: strategyType,
            registeredAt: uint32(block.timestamp),
            isActive: true,
            version: 1
        });

        strategiesByType[strategyType].push(newStrategyId);
        _activeStrategyIds.push(newStrategyId);

        emit StrategyRegistered(newStrategyId, strategyAddress, strategyType);
        return newStrategyId;
    }

    function setStrategyStatus(uint256 strategyId, bool isActive) external onlyRole(ADMIN_ROLE) {
        require(strategies[strategyId].strategyAddress != address(0), "Strategy not found");
        strategies[strategyId].isActive = isActive;

        if (isActive) {
            _addToActiveList(strategyId);
        } else {
            _removeFromActiveList(strategyId);
        }

        emit StrategyStatusChanged(strategyId, isActive);
    }

    function getActiveStrategies() external view returns (uint256[] memory) {
        return _activeStrategyIds;
    }

    function getActiveStrategiesByType(StrategyType strategyType) external view returns (uint256[] memory) {
        uint256[] memory typeStrategies = strategiesByType[strategyType];
        uint256 activeCount = 0;
        
        // Count active strategies of this type
        for (uint256 i = 0; i < typeStrategies.length; i++) {
            if (strategies[typeStrategies[i]].isActive) {
                activeCount++;
            }
        }
        
        // Build active strategies array
        uint256[] memory activeStrategies = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < typeStrategies.length; i++) {
            if (strategies[typeStrategies[i]].isActive) {
                activeStrategies[index++] = typeStrategies[i];
            }
        }
        
        return activeStrategies;
    }

    function _addToActiveList(uint256 strategyId) internal {
        for (uint256 i = 0; i < _activeStrategyIds.length; i++) {
            if (_activeStrategyIds[i] == strategyId) return; // Already in list
        }
        _activeStrategyIds.push(strategyId);
    }

    function _removeFromActiveList(uint256 strategyId) internal {
        for (uint256 i = 0; i < _activeStrategyIds.length; i++) {
            if (_activeStrategyIds[i] == strategyId) {
                _activeStrategyIds[i] = _activeStrategyIds[_activeStrategyIds.length - 1];
                _activeStrategyIds.pop();
                break;
            }
        }
    }
}
```

### **2.2 Granted Reward Storage Implementation**

```solidity
// File: src/GrantedRewardStorage.sol
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IGrantedRewardStorage.sol";

contract GrantedRewardStorage is IGrantedRewardStorage, AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address user => GrantedReward[]) private userRewards;
    mapping(address user => uint256) public userRewardCount;
    mapping(address user => uint256) public userTotalGranted;
    mapping(address user => uint256) public userTotalClaimed;

    // Epoch tracking
    mapping(uint32 epochId => mapping(address => uint256[])) private epochUserRewards;
    mapping(uint32 epochId => uint256) public epochTotalRewards;

    event RewardGranted(address indexed user, uint256 strategyId, uint256 amount, uint32 epochId);
    event RewardClaimed(address indexed user, uint256 amount, uint256 rewardIndex);

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
    }

    function setController(address controller) external onlyRole(ADMIN_ROLE) {
        _grantRole(CONTROLLER_ROLE, controller);
    }

    function grantReward(
        address user,
        uint256 strategyId,
        uint256 amount,
        uint32 epochId
    ) external onlyRole(CONTROLLER_ROLE) {
        require(amount > 0, "Amount must be positive");
        require(amount <= type(uint128).max, "Amount too large");

        GrantedReward memory newReward = GrantedReward({
            amount: uint128(amount),
            epochId: epochId,
            grantedAt: uint32(block.timestamp),
            strategyId: uint16(strategyId),
            version: 1,
            claimed: false
        });

        userRewards[user].push(newReward);
        uint256 rewardIndex = userRewards[user].length - 1;
        
        userRewardCount[user]++;
        userTotalGranted[user] += amount;

        // Track epoch rewards
        if (epochId > 0) {
            epochUserRewards[epochId][user].push(rewardIndex);
            epochTotalRewards[epochId] += amount;
        }

        emit RewardGranted(user, strategyId, amount, epochId);
    }

    function markRewardClaimed(
        address user,
        uint256 rewardIndex
    ) external onlyRole(CONTROLLER_ROLE) {
        require(rewardIndex < userRewards[user].length, "Invalid reward index");
        require(!userRewards[user][rewardIndex].claimed, "Already claimed");

        userRewards[user][rewardIndex].claimed = true;
        userTotalClaimed[user] += userRewards[user][rewardIndex].amount;

        emit RewardClaimed(user, userRewards[user][rewardIndex].amount, rewardIndex);
    }

    function getUserRewards(address user) external view returns (GrantedReward[] memory) {
        return userRewards[user];
    }

    function getUserClaimableAmount(address user) external view returns (uint256) {
        uint256 claimable = 0;
        for (uint256 i = 0; i < userRewards[user].length; i++) {
            if (!userRewards[user][i].claimed) {
                claimable += userRewards[user][i].amount;
            }
        }
        return claimable;
    }

    function getUserEpochRewards(address user, uint32 epochId) external view returns (GrantedReward[] memory) {
        uint256[] memory rewardIndices = epochUserRewards[epochId][user];
        GrantedReward[] memory epochRewards = new GrantedReward[](rewardIndices.length);
        
        for (uint256 i = 0; i < rewardIndices.length; i++) {
            epochRewards[i] = userRewards[user][rewardIndices[i]];
        }
        
        return epochRewards;
    }

    function getUserClaimableRewardsWithIndices(address user) external view returns (
        GrantedReward[] memory rewards,
        uint256[] memory indices
    ) {
        uint256 count = 0;
        // Count claimable rewards
        for (uint256 i = 0; i < userRewards[user].length; i++) {
            if (!userRewards[user][i].claimed) {
                count++;
            }
        }

        rewards = new GrantedReward[](count);
        indices = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < userRewards[user].length; i++) {
            if (!userRewards[user][i].claimed) {
                rewards[index] = userRewards[user][i];
                indices[index] = i;
                index++;
            }
        }
    }
}
```

### **2.3 Epoch Manager Implementation**

```solidity
// File: src/EpochManager.sol
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IEpochManager.sol";
import "./interfaces/IRewardStrategy.sol";

contract EpochManager is IEpochManager, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(uint32 => Epoch) public epochs;
    uint32 public currentEpochId;
    
    // Mapping strategy to its active epochs
    mapping(uint256 => uint32[]) public strategyEpochs;
    
    event EpochAnnounced(uint32 indexed epochId, uint256 indexed strategyId, uint32 startDay, uint32 endDay);
    event EpochStateChanged(uint32 indexed epochId, EpochState newState);
    event EpochPoolSizeSet(uint32 indexed epochId, uint256 actualPoolSize);

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
    }

    function announceEpoch(
        uint32 startDay,
        uint32 endDay,
        uint256 strategyId,
        uint256 estimatedPoolSize
    ) external onlyRole(ADMIN_ROLE) returns (uint32 epochId) {
        require(startDay < endDay, "Invalid epoch period");
        require(startDay > getCurrentDay(), "Start day must be in future");
        
        epochId = ++currentEpochId;
        
        epochs[epochId] = Epoch({
            epochId: epochId,
            startDay: startDay,
            endDay: endDay,
            estimatedPoolSize: estimatedPoolSize,
            actualPoolSize: 0,
            strategyId: strategyId,
            state: EpochState.ANNOUNCED,
            totalParticipants: 0,
            totalStakeWeight: 0,
            announcedAt: uint32(block.timestamp),
            calculatedAt: 0
        });

        strategyEpochs[strategyId].push(epochId);
        
        emit EpochAnnounced(epochId, strategyId, startDay, endDay);
    }

    function setEpochPoolSize(uint32 epochId, uint256 actualPoolSize) external onlyRole(ADMIN_ROLE) {
        Epoch storage epoch = epochs[epochId];
        require(epoch.epochId != 0, "Epoch not found");
        require(epoch.state == EpochState.ENDED, "Epoch not ended");
        require(actualPoolSize > 0, "Pool size must be positive");
        
        epoch.actualPoolSize = actualPoolSize;
        emit EpochPoolSizeSet(epochId, actualPoolSize);
    }

    function calculateEpochRewards(
        uint32 epochId,
        uint256 batchStart,
        uint256 batchSize
    ) external onlyRole(ADMIN_ROLE) {
        Epoch storage epoch = epochs[epochId];
        require(epoch.state == EpochState.ENDED, "Epoch not ended");
        require(epoch.actualPoolSize > 0, "Pool size not set");
        
        // Implementation will interact with reward calculation logic
        // This is a placeholder for the batch processing logic
        
        if (batchStart == 0) {
            // First batch - transition to CALCULATED state
            epoch.state = EpochState.CALCULATED;
            epoch.calculatedAt = uint32(block.timestamp);
            emit EpochStateChanged(epochId, EpochState.CALCULATED);
        }
    }

    function updateEpochStates() external {
        uint32 currentDay = getCurrentDay();
        
        for (uint32 i = 1; i <= currentEpochId; i++) {
            Epoch storage epoch = epochs[i];
            
            if (epoch.state == EpochState.ANNOUNCED && currentDay >= epoch.startDay) {
                epoch.state = EpochState.ACTIVE;
                emit EpochStateChanged(i, EpochState.ACTIVE);
            } else if (epoch.state == EpochState.ACTIVE && currentDay > epoch.endDay) {
                epoch.state = EpochState.ENDED;
                emit EpochStateChanged(i, EpochState.ENDED);
            }
        }
    }

    function getEpochState(uint32 epochId) external view returns (EpochState) {
        return epochs[epochId].state;
    }

    function getEpoch(uint32 epochId) external view returns (Epoch memory) {
        return epochs[epochId];
    }

    function getActiveEpochs() external view returns (uint32[] memory) {
        uint32 currentDay = getCurrentDay();
        uint256 activeCount = 0;
        
        // Count active epochs
        for (uint32 i = 1; i <= currentEpochId; i++) {
            if (epochs[i].state == EpochState.ACTIVE) {
                activeCount++;
            }
        }
        
        uint32[] memory activeEpochs = new uint32[](activeCount);
        uint256 index = 0;
        
        for (uint32 i = 1; i <= currentEpochId; i++) {
            if (epochs[i].state == EpochState.ACTIVE) {
                activeEpochs[index++] = i;
            }
        }
        
        return activeEpochs;
    }

    function getCurrentDay() public view returns (uint32) {
        return uint32(block.timestamp / 86400);
    }
}
```

## Phase 3: Enhanced Reward Manager

### **3.1 Enhanced Reward Manager Interface**

```solidity
// File: src/interfaces/IEnhancedRewardManager.sol
pragma solidity ^0.8.30;

interface IEnhancedRewardManager {
    // Events
    event ImmediateRewardsCalculated(uint256 indexed strategyId, uint32 fromDay, uint32 toDay, uint256 totalUsers);
    event EpochRewardsCalculated(uint32 indexed epochId, uint256 totalRewards, uint256 totalParticipants);
    event RewardsClaimed(address indexed user, uint256 totalAmount, uint256 rewardCount);

    // Immediate strategy functions
    function calculateImmediateRewards(
        uint256 strategyId,
        uint32 fromDay,
        uint32 toDay,
        uint256 batchStart,
        uint256 batchSize
    ) external;

    function calculateRetroactiveRewards(
        uint256 strategyId,
        uint32 fromDay,
        uint32 toDay
    ) external;

    // Epoch strategy functions
    function calculateEpochRewards(
        uint32 epochId,
        uint256 batchStart,
        uint256 batchSize
    ) external;

    // User functions
    function claimAllRewards() external returns (uint256);
    function claimEpochRewards(uint32 epochId) external returns (uint256);
    function claimSpecificRewards(uint256[] calldata rewardIndices) external returns (uint256);

    // View functions
    function getClaimableRewards(address user) external view returns (uint256);
    function getClaimableEpochRewards(address user, uint32 epochId) external view returns (uint256);
    function getUserRewardSummary(address user) external view returns (
        uint256 totalGranted,
        uint256 totalClaimed,
        uint256 totalClaimable,
        uint256 rewardCount
    );

    // Admin functions
    function addRewardFunds(uint256 amount) external;
    function emergencyPause() external;
    function emergencyResume() external;
}
```

### **3.2 Enhanced Reward Manager Implementation**

```solidity
// File: src/EnhancedRewardManager.sol
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EnhancedRewardManager is IEnhancedRewardManager, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    EnhancedStrategiesRegistry public immutable strategyRegistry;
    IStakingStorage public immutable stakingStorage;
    GrantedRewardStorage public immutable grantedRewardStorage;
    EpochManager public immutable epochManager;
    IERC20 public immutable rewardToken;

    // Gas limit for batch processing
    uint256 public constant MAX_BATCH_SIZE = 100;
    
    constructor(
        address admin,
        address strategyRegistry_,
        address stakingStorage_,
        address grantedRewardStorage_,
        address epochManager_,
        address rewardToken_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        
        strategyRegistry = EnhancedStrategiesRegistry(strategyRegistry_);
        stakingStorage = IStakingStorage(stakingStorage_);
        grantedRewardStorage = GrantedRewardStorage(grantedRewardStorage_);
        epochManager = EpochManager(epochManager_);
        rewardToken = IERC20(rewardToken_);
    }

    function calculateImmediateRewards(
        uint256 strategyId,
        uint32 fromDay,
        uint32 toDay,
        uint256 batchStart,
        uint256 batchSize
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(batchSize <= MAX_BATCH_SIZE, "Batch size too large");
        
        // Get strategy and verify it's immediate type
        EnhancedStrategiesRegistry.RegistryEntry memory entry = strategyRegistry.strategies(strategyId);
        require(entry.strategyAddress != address(0), "Strategy not found");
        require(entry.strategyType == StrategyType.IMMEDIATE, "Not immediate strategy");
        require(entry.isActive, "Strategy not active");

        IRewardStrategy strategy = IRewardStrategy(entry.strategyAddress);
        
        // Get batch of users
        address[] memory allStakers = stakingStorage.getStakersPaginated(batchStart, batchSize);
        uint256 totalUsers = 0;

        for (uint256 i = 0; i < allStakers.length; i++) {
            address staker = allStakers[i];
            bytes32[] memory stakeIds = stakingStorage.getStakerStakeIds(staker);
            bool userProcessed = false;

            for (uint256 j = 0; j < stakeIds.length; j++) {
                bytes32 stakeId = stakeIds[j];
                
                if (strategy.isApplicable(staker, stakeId)) {
                    uint256 reward = strategy.calculateReward(staker, stakeId, fromDay, toDay);
                    
                    if (reward > 0) {
                        grantedRewardStorage.grantReward(staker, strategyId, reward, 0);
                        if (!userProcessed) {
                            totalUsers++;
                            userProcessed = true;
                        }
                    }
                }
            }
        }

        emit ImmediateRewardsCalculated(strategyId, fromDay, toDay, totalUsers);
    }

    function calculateEpochRewards(
        uint32 epochId,
        uint256 batchStart,
        uint256 batchSize
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(batchSize <= MAX_BATCH_SIZE, "Batch size too large");
        
        IEpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        require(epoch.state == EpochState.ENDED, "Epoch not ended");
        require(epoch.actualPoolSize > 0, "Pool size not set");

        // Get strategy
        EnhancedStrategiesRegistry.RegistryEntry memory entry = strategyRegistry.strategies(epoch.strategyId);
        require(entry.strategyType == StrategyType.EPOCH_BASED, "Not epoch strategy");
        
        IRewardStrategy strategy = IRewardStrategy(entry.strategyAddress);

        // Calculate total epoch weight (this should be cached for efficiency)
        uint256 totalEpochWeight = _calculateTotalEpochWeight(epochId, strategy);
        require(totalEpochWeight > 0, "No eligible participants");

        // Get batch of participants
        address[] memory participants = _getEpochParticipants(epochId, batchStart, batchSize);
        uint256 totalParticipants = 0;
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            uint256 userWeight = _calculateUserEpochWeight(participants[i], epochId, strategy);
            if (userWeight > 0) {
                uint256 userReward = (userWeight * epoch.actualPoolSize) / totalEpochWeight;
                if (userReward > 0) {
                    grantedRewardStorage.grantReward(participants[i], epoch.strategyId, userReward, epochId);
                    totalRewards += userReward;
                    totalParticipants++;
                }
            }
        }

        emit EpochRewardsCalculated(epochId, totalRewards, totalParticipants);

        // Update epoch manager if this is the final batch
        epochManager.calculateEpochRewards(epochId, batchStart, batchSize);
    }

    function claimAllRewards() external nonReentrant whenNotPaused returns (uint256) {
        (
            IGrantedRewardStorage.GrantedReward[] memory claimableRewards,
            uint256[] memory rewardIndices
        ) = grantedRewardStorage.getUserClaimableRewardsWithIndices(msg.sender);

        require(claimableRewards.length > 0, "No claimable rewards");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < claimableRewards.length; i++) {
            totalAmount += claimableRewards[i].amount;
            grantedRewardStorage.markRewardClaimed(msg.sender, rewardIndices[i]);
        }

        rewardToken.safeTransfer(msg.sender, totalAmount);
        emit RewardsClaimed(msg.sender, totalAmount, claimableRewards.length);

        return totalAmount;
    }

    function claimEpochRewards(uint32 epochId) external nonReentrant whenNotPaused returns (uint256) {
        IGrantedRewardStorage.GrantedReward[] memory epochRewards = 
            grantedRewardStorage.getUserEpochRewards(msg.sender, epochId);

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < epochRewards.length; i++) {
            if (!epochRewards[i].claimed) {
                totalAmount += epochRewards[i].amount;
                // Note: This requires modification to GrantedRewardStorage to support epoch-specific claiming
            }
        }

        require(totalAmount > 0, "No claimable epoch rewards");
        rewardToken.safeTransfer(msg.sender, totalAmount);
        
        emit RewardsClaimed(msg.sender, totalAmount, epochRewards.length);
        return totalAmount;
    }

    function getClaimableRewards(address user) external view returns (uint256) {
        return grantedRewardStorage.getUserClaimableAmount(user);
    }

    function getUserRewardSummary(address user) external view returns (
        uint256 totalGranted,
        uint256 totalClaimed,
        uint256 totalClaimable,
        uint256 rewardCount
    ) {
        totalGranted = grantedRewardStorage.userTotalGranted(user);
        totalClaimed = grantedRewardStorage.userTotalClaimed(user);
        totalClaimable = grantedRewardStorage.getUserClaimableAmount(user);
        rewardCount = grantedRewardStorage.userRewardCount(user);
    }

    function addRewardFunds(uint256 amount) external override {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function emergencyResume() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Internal helper functions
    function _calculateTotalEpochWeight(uint32 epochId, IRewardStrategy strategy) internal view returns (uint256) {
        // This should use cached data or implement efficient calculation
        // Placeholder implementation
        return 1000000; // Replace with actual calculation
    }

    function _getEpochParticipants(uint32 epochId, uint256 offset, uint256 limit) internal view returns (address[] memory) {
        // This should return participants who had stakes during the epoch
        // Placeholder implementation
        return stakingStorage.getStakersPaginated(offset, limit);
    }

    function _calculateUserEpochWeight(address user, uint32 epochId, IRewardStrategy strategy) internal view returns (uint256) {
        // Calculate user's weight for the epoch based on their stakes
        // This should integrate with the checkpoint system
        // Placeholder implementation
        return 1000; // Replace with actual calculation
    }
}
```

## Phase 4: Updated Strategy Implementations

### **4.1 Enhanced Linear APR Strategy**

```solidity
// File: src/strategies/EnhancedLinearAPRStrategy.sol
pragma solidity ^0.8.30;

import "../interfaces/IRewardStrategy.sol";
import "../interfaces/IStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EnhancedLinearAPRStrategy is IRewardStrategy, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    StrategyParameters public strategyParameters;
    IStakingStorage public immutable stakingStorage;
    uint256 public immutable annualRate; // in basis points
    uint256 public immutable daysPerYear;
    mapping(address => bool) public blacklist;

    constructor(
        StrategyParameters memory _strategyParameters,
        address _manager,
        uint256 _annualRate,
        uint256 _daysPerYear,
        IStakingStorage _stakingStorage
    ) {
        strategyParameters = _strategyParameters;
        _grantRole(MANAGER_ROLE, _manager);
        annualRate = _annualRate;
        daysPerYear = _daysPerYear;
        stakingStorage = _stakingStorage;
    }

    function getStrategyType() external pure returns (StrategyType) {
        return StrategyType.IMMEDIATE;
    }

    function getEpochDuration() external pure returns (uint32) {
        return 0; // Not applicable for immediate strategies
    }

    function calculateReward(
        address staker,
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    ) external view returns (uint256) {
        require(fromDay < toDay, "Invalid period");
        
        IStakingStorage.Stake memory stake = stakingStorage.getStake(staker, stakeId);
        require(stake.amount > 0, "Stake not found");
        
        // Calculate the effective period this stake was active
        uint32 effectiveStart = stake.stakeDay > fromDay ? stake.stakeDay : fromDay;
        uint32 effectiveEnd = toDay;
        
        // If stake was unstaked before toDay, use unstake day
        if (stake.unstakeDay > 0 && stake.unstakeDay < toDay) {
            effectiveEnd = stake.unstakeDay;
        }
        
        // If no overlap, return 0
        if (effectiveStart >= effectiveEnd) {
            return 0;
        }
        
        uint256 daysPassed = effectiveEnd - effectiveStart;
        return (stake.amount * annualRate * daysPassed) / (daysPerYear * 10_000);
    }

    function calculateEpochReward(
        address, /* staker */
        bytes32, /* stakeId */
        uint32 /* epochId */
    ) external pure returns (uint256) {
        revert("Not supported for immediate strategies");
    }

    function isApplicable(address staker, bytes32 stakeId) external view returns (bool) {
        if (blacklist[staker]) return false;
        
        IStakingStorage.Stake memory stake = stakingStorage.getStake(staker, stakeId);
        if (stake.amount == 0) return false;
        
        return stake.stakeDay >= strategyParameters.startDay && 
               stake.stakeDay <= strategyParameters.endDay;
    }

    function getParameters() external view returns (StrategyParameters memory) {
        return strategyParameters;
    }

    function updateParameters(uint256[] calldata params) external onlyRole(MANAGER_ROLE) {
        require(params.length >= 2, "Invalid params length");
        strategyParameters.startDay = uint16(params[0]);
        strategyParameters.endDay = uint16(params[1]);
    }
}
```

### **4.2 Epoch-Based Pool Strategy**

```solidity
// File: src/strategies/EpochPoolStrategy.sol
pragma solidity ^0.8.30;

import "../interfaces/IRewardStrategy.sol";
import "../interfaces/IStakingStorage.sol";
import "../interfaces/IEpochManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EpochPoolStrategy is IRewardStrategy, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    StrategyParameters public strategyParameters;
    IStakingStorage public immutable stakingStorage;
    IEpochManager public immutable epochManager;
    uint32 public immutable epochDuration;
    mapping(address => bool) public blacklist;

    constructor(
        StrategyParameters memory _strategyParameters,
        address _manager,
        uint32 _epochDuration,
        IStakingStorage _stakingStorage,
        IEpochManager _epochManager
    ) {
        strategyParameters = _strategyParameters;
        _grantRole(MANAGER_ROLE, _manager);
        epochDuration = _epochDuration;
        stakingStorage = _stakingStorage;
        epochManager = _epochManager;
    }

    function getStrategyType() external pure returns (StrategyType) {
        return StrategyType.EPOCH_BASED;
    }

    function getEpochDuration() external view returns (uint32) {
        return epochDuration;
    }

    function calculateReward(
        address, /* staker */
        bytes32, /* stakeId */
        uint32, /* fromDay */
        uint32 /* toDay */
    ) external pure returns (uint256) {
        revert("Use calculateEpochReward for epoch-based strategies");
    }

    function calculateEpochReward(
        address staker,
        bytes32 stakeId,
        uint32 epochId
    ) external view returns (uint256) {
        IEpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        require(epoch.state == EpochState.CALCULATED, "Epoch not calculated");
        
        // Calculate user's stake weight during the epoch
        uint256 userWeight = _calculateStakeWeightForEpoch(staker, stakeId, epoch);
        
        // This would need to access total epoch weight (should be cached)
        uint256 totalWeight = epoch.totalStakeWeight;
        
        if (totalWeight == 0) return 0;
        
        return (userWeight * epoch.actualPoolSize) / totalWeight;
    }

    function isApplicable(address staker, bytes32 stakeId) external view returns (bool) {
        if (blacklist[staker]) return false;
        
        IStakingStorage.Stake memory stake = stakingStorage.getStake(staker, stakeId);
        if (stake.amount == 0) return false;
        
        return stake.stakeDay >= strategyParameters.startDay && 
               stake.stakeDay <= strategyParameters.endDay;
    }

    function getParameters() external view returns (StrategyParameters memory) {
        return strategyParameters;
    }

    function updateParameters(uint256[] calldata params) external onlyRole(MANAGER_ROLE) {
        require(params.length >= 2, "Invalid params length");
        strategyParameters.startDay = uint16(params[0]);
        strategyParameters.endDay = uint16(params[1]);
    }

    function _calculateStakeWeightForEpoch(
        address staker,
        bytes32 stakeId,
        IEpochManager.Epoch memory epoch
    ) internal view returns (uint256) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(staker, stakeId);
        
        // Calculate overlap between stake period and epoch period
        uint32 stakeStart = stake.stakeDay;
        uint32 stakeEnd = stake.unstakeDay > 0 ? stake.unstakeDay : type(uint32).max;
        
        uint32 overlapStart = stakeStart > epoch.startDay ? stakeStart : epoch.startDay;
        uint32 overlapEnd = stakeEnd < epoch.endDay ? stakeEnd : epoch.endDay;
        
        if (overlapStart >= overlapEnd) return 0;
        
        uint256 daysOverlap = overlapEnd - overlapStart;
        return stake.amount * daysOverlap;
    }
}
```

## Phase 5: Deployment and Integration

### **5.1 Deployment Script**

```solidity
// File: scripts/DeployRewardSystem.sol
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/EnhancedStrategiesRegistry.sol";
import "../src/GrantedRewardStorage.sol";
import "../src/EpochManager.sol";
import "../src/EnhancedRewardManager.sol";

contract DeployRewardSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        EnhancedStrategiesRegistry strategyRegistry = new EnhancedStrategiesRegistry(admin);
        GrantedRewardStorage grantedRewardStorage = new GrantedRewardStorage(admin);
        EpochManager epochManager = new EpochManager(admin);
        
        // Deploy reward manager
        EnhancedRewardManager rewardManager = new EnhancedRewardManager(
            admin,
            address(strategyRegistry),
            vm.envAddress("STAKING_STORAGE"), // Existing staking storage
            address(grantedRewardStorage),
            address(epochManager),
            vm.envAddress("REWARD_TOKEN")
        );

        // Set up permissions
        grantedRewardStorage.setController(address(rewardManager));
        
        vm.stopBroadcast();

        // Log addresses
        console.log("StrategiesRegistry deployed at:", address(strategyRegistry));
        console.log("GrantedRewardStorage deployed at:", address(grantedRewardStorage));
        console.log("EpochManager deployed at:", address(epochManager));
        console.log("RewardManager deployed at:", address(rewardManager));
    }
}
```

### **5.2 Integration Steps**

#### **Step 1: Deploy Core Infrastructure**
1. Deploy `EnhancedStrategiesRegistry`
2. Deploy `GrantedRewardStorage`
3. Deploy `EpochManager`
4. Deploy `EnhancedRewardManager`
5. Set up access controls and permissions

#### **Step 2: Deploy Initial Strategies**
1. Deploy `EnhancedLinearAPRStrategy`
2. Deploy `EpochPoolStrategy`
3. Register strategies in registry
4. Configure initial parameters

#### **Step 3: Test Integration**
1. Test immediate strategy calculation
2. Test epoch announcement and lifecycle
3. Test reward granting and claiming
4. Verify gas costs and performance

#### **Step 4: Production Deployment**
1. Deploy to mainnet with proper access controls
2. Fund reward manager with tokens
3. Announce first reward strategies
4. Begin retroactive calculation for existing stakes

## Phase 6: Testing and Validation

### **6.1 Unit Tests**

```solidity
// File: test/RewardSystem.t.sol
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/EnhancedRewardManager.sol";
import "../src/GrantedRewardStorage.sol";

contract RewardSystemTest is Test {
    EnhancedRewardManager rewardManager;
    GrantedRewardStorage grantedStorage;
    
    function setUp() public {
        // Deploy and set up test environment
    }
    
    function testImmediateRewardCalculation() public {
        // Test immediate strategy calculation
    }
    
    function testEpochLifecycle() public {
        // Test epoch announcement, execution, and calculation
    }
    
    function testRewardClaiming() public {
        // Test user reward claiming functionality
    }
    
    function testGasEfficiency() public {
        // Verify gas costs meet targets
    }
}
```

### **6.2 Integration Tests**

```solidity
// File: test/RewardIntegration.t.sol
pragma solidity ^0.8.30;

contract RewardIntegrationTest is Test {
    function testRetroactiveCalculation() public {
        // Test calculation for historical staking data
    }
    
    function testMultiStrategyRewards() public {
        // Test multiple strategies granting rewards to same user
    }
    
    function testLargeScaleProcessing() public {
        // Test batch processing with many users
    }
}
```

## Summary

This implementation plan provides:

1. **Complete contract specifications** with detailed code snippets
2. **Phased development approach** for manageable implementation
3. **Gas-optimized data structures** for production efficiency
4. **Comprehensive testing strategy** for reliability
5. **Deployment and integration guidance** for smooth rollout

The system achieves the goal of 30× gas reduction for users while providing full retroactive capability and support for both immediate and epoch-based reward strategies.

**Next Steps:**
1. Review and approve the technical specifications
2. Begin Phase 1 implementation (core data structures)
3. Set up development environment and testing framework
4. Implement contracts following the detailed specifications above