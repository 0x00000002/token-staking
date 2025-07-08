// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title StakingErrors
 * @notice Comprehensive standardized error definitions for the staking system
 */
interface StakingErrors {
    // ============================================================================
    // Stake Validation Errors
    // ============================================================================
    error InvalidAmount();
    error StakeNotFound(bytes32 stakeId);
    error StakeAlreadyExists(bytes32 stakeId);
    error StakeAlreadyUnstaked(bytes32 stakeId);
    error StakeNotMatured(bytes32 stakeId, uint16 currentDay, uint16 matureDay);

    // ============================================================================
    // Ownership and Access Errors
    // ============================================================================
    error NotStakeOwner(address caller, address owner);
    error StakerNotFound(address staker);
    error UnauthorizedCaller(address caller, bytes32 requiredRole);

    // ============================================================================
    // Token and Recovery Errors
    // ============================================================================
    error CannotRecoverStakingToken();
    error InsufficientTokenBalance(uint256 requested, uint256 available);
    error TokenTransferFailed(address token, address to, uint256 amount);

    // ============================================================================
    // Data Access and Pagination Errors
    // ============================================================================
    error OutOfBounds(uint256 total, uint256 offset);
    error InvalidPaginationParameters(uint256 offset, uint256 limit);
    error LimitTooLarge(uint256 limit, uint256 maximum);

    // ============================================================================
    // Time and Lock Period Errors
    // ============================================================================
    error InvalidLockPeriod(uint16 daysLock, uint16 minimum, uint16 maximum);
    error InvalidDay(uint16 day);
    error TimeLockNotExpired(
        bytes32 stakeId,
        uint16 currentDay,
        uint16 unlockDay
    );

    // ============================================================================
    // State Management Errors
    // ============================================================================
    error ContractPaused();
    error ContractNotPaused();
    error InvalidContractState(string expectedState, string currentState);

    // ============================================================================
    // Checkpoint and Historical Data Errors
    // ============================================================================
    error CheckpointNotFound(address staker, uint16 day);
    error InvalidCheckpointDay(uint16 day, uint16 currentDay);
    error CheckpointArrayCorrupted(address staker);

    // ============================================================================
    // Stake Creation and Management Errors
    // ============================================================================
    error StakeCreationFailed(address staker, uint128 amount, uint16 daysLock);
    error StakeRemovalFailed(address staker, bytes32 stakeId);
    error InvalidStakeParameters(uint128 amount, uint16 daysLock);

    // ============================================================================
    // Address Validation Errors
    // ============================================================================
    error ZeroAddress();
    error InvalidStakerAddress(address staker);
    error InvalidContractAddress(address contractAddr);

    // ============================================================================
    // Arithmetic and Calculation Errors
    // ============================================================================
    error ArithmeticOverflow(uint256 value);
    error ArithmeticUnderflow(uint256 value);
    error DivisionByZero();
    error InvalidCalculationResult(uint256 result);

    // ============================================================================
    // Flag System Errors
    // ============================================================================
    error InvalidFlags(uint16 flags);
    error UnsupportedFlagOperation(uint16 flags, string operation);

    // ============================================================================
    // Batch Operation Errors
    // ============================================================================
    error BatchSizeExceeded(uint256 batchSize, uint256 maximum);
    error BatchOperationFailed(uint256 successCount, uint256 totalCount);
    error EmptyBatchOperation();
}
