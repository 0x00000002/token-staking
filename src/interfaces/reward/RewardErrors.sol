// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./RewardEnums.sol";

/**
 * @title RewardErrors
 * @notice Comprehensive standardized error definitions for the reward system
 */
interface RewardErrors {
    
    // ============================================================================
    // General System Errors
    // ============================================================================
    error BatchSizeExceeded(uint256 batchSize);
    error InsufficientRewardFunds(uint256 required, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    
    // ============================================================================
    // Strategy Registry Errors
    // ============================================================================
    error StrategyNotFound(uint256 strategyId);
    error StrategyNotActive(uint256 strategyId);
    error InvalidStrategyType(uint256 strategyId);
    error StrategyAlreadyRegistered(address strategyAddress);
    
    // ============================================================================
    // Strategy Implementation Errors
    // ============================================================================
    error OnlyManagerCanUpdate();
    error InvalidParams();
    error UseCalculateEpochRewardForEpochStrategies();
    error NotSupportedForImmediateStrategies();
    
    // ============================================================================
    // Epoch Management Errors
    // ============================================================================
    error EpochNotFound(uint32 epochId);
    error EpochNotCalculated(uint32 epochId);
    error EpochNotEnded(uint32 epochId);
    error EpochPoolSizeNotSet(uint32 epochId);
    error EpochAlreadyFinalized(uint32 epochId);
    error InvalidEpochDuration(uint32 duration);
    error EpochOverlap(uint32 epochId, uint32 conflictingEpochId);
    
    // ============================================================================
    // Reward Claiming Errors
    // ============================================================================
    error NoRewardsToClaim(address user);
    error NoClaimableRewardsForEpoch(uint32 epochId);
    error InvalidRewardIndex(uint256 index);
    error RewardAlreadyClaimed(uint256 index);
    error RewardGrantFailed(address user, uint256 strategyId, uint256 amount);
    
    // ============================================================================
    // Stake Validation Errors
    // ============================================================================
    error StakeNotFound(address staker, bytes32 stakeId);
    error StakeNotActive(address staker, bytes32 stakeId);
    error StakeNotApplicable(address staker, bytes32 stakeId, uint256 strategyId);
    error StakeNotActiveInEpoch(bytes32 stakeId, uint32 epochStart, uint32 epochEnd);
    
    // ============================================================================
    // Time and Calculation Errors
    // ============================================================================
    error InvalidTimeRange(uint32 fromDay, uint32 toDay);
    error InvalidDay(uint32 day);
    error CalculationOverflow(uint256 value);
    error DivisionByZero();
    
    // ============================================================================
    // Access Control Errors
    // ============================================================================
    error UnauthorizedCaller(address caller, bytes32 requiredRole);
    error UnauthorizedOperation(address caller, string operation);
}