// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/staking/IStakingStorage.sol";
import "./interfaces/staking/StakingErrors.sol";
import {Flags} from "./lib/Flags.sol";
import {StakingFlags} from "./StakingFlags.sol";
import {StakingFlags} from "./StakingFlags.sol";

uint16 constant EMPTY_FLAGS = 0;

contract StakingVault is
    ReentrancyGuard,
    AccessControl,
    Pausable,
    StakingErrors
{
    using SafeERC20 for IERC20;
    using Flags for uint16;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CLAIM_CONTRACT_ROLE =
        keccak256("CLAIM_CONTRACT_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant MULTISIG_ROLE = keccak256("MULTISIG_ROLE");

    // Immutable references
    IStakingStorage public immutable stakingStorage;
    IERC20 public immutable token;

    // Events
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

    event EmergencyRecover(address token, address to, uint256 amount);

    constructor(
        IERC20 _token,
        address _storage,
        address _admin,
        address _manager
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _manager);
        _grantRole(CONTROLLER_ROLE, _admin);
        _grantRole(MULTISIG_ROLE, _admin);

        token = _token;
        stakingStorage = IStakingStorage(_storage);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        CORE STAKING FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Stake tokens with timelock
     * @param amount Amount to stake
     * @param daysLock Timelock period in days
     * @return stakeId Unique identifier for the stake
     */
    function stake(
        uint128 amount,
        uint16 daysLock
    ) external whenNotPaused nonReentrant returns (bytes32 stakeId) {
        require(amount > 0, InvalidAmount());

        address staker = msg.sender;

        // Transfer tokens
        token.safeTransferFrom(staker, address(this), amount);

        // Create stake in storage and get the generated ID
        stakeId = stakingStorage.createStake(
            staker,
            amount,
            daysLock,
            EMPTY_FLAGS
        );

        emit Staked(staker, stakeId, amount, _getCurrentDay(), daysLock);
    }

    /**
     * @notice Unstake matured tokens
     * @param stakeId ID of the stake to unstake
     */
    function unstake(bytes32 stakeId) external whenNotPaused nonReentrant {
        address caller = msg.sender;

        // Get stake from storage
        IStakingStorage.Stake memory _stake = stakingStorage.getStake(stakeId);

        // Validate stake
        require(_stake.amount > 0, StakeNotFound(stakeId));
        require(_stake.unstakeDay == 0, StakeAlreadyUnstaked(stakeId));

        // Check maturity
        uint16 currentDay = _getCurrentDay();
        uint16 matureDay = _stake.stakeDay + _stake.daysLock;
        require(
            currentDay > matureDay,
            StakeNotMatured(stakeId, currentDay, matureDay)
        );

        // Remove stake from storage
        stakingStorage.removeStake(caller, stakeId);

        // Transfer tokens back
        token.safeTransfer(caller, _stake.amount);

        emit Unstaked(caller, stakeId, currentDay, _stake.amount);
    }

    /**
     * @notice Stake tokens from claim contract
     * @dev This function is used to stake tokens from the claim contract
     * @dev Tokens are already transferred from the claim contract to the staking vault
     * @param staker Address of the staker
     * @param amount Amount to stake
     * @param daysLock Timelock period in days
     * @return stakeId Unique identifier for the stake
     */
    function stakeFromClaim(
        address staker,
        uint128 amount,
        uint16 daysLock
    )
        external
        whenNotPaused
        onlyRole(CLAIM_CONTRACT_ROLE)
        returns (bytes32 stakeId)
    {
        require(amount > 0, InvalidAmount());

        uint16 flags = Flags.set(EMPTY_FLAGS, StakingFlags.IS_FROM_CLAIM_BIT);

        // Create stake in storage and get the generated ID
        stakeId = stakingStorage.createStake(staker, amount, daysLock, flags);

        emit Staked(staker, stakeId, amount, _getCurrentDay(), daysLock);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency token recovery
     * @param token_ Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecover(
        IERC20 token_,
        uint256 amount
    ) external onlyRole(MULTISIG_ROLE) {
        require(token_ != token, CannotRecoverStakingToken());
        token_.safeTransfer(msg.sender, amount);
        emit EmergencyRecover(address(token_), msg.sender, amount);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    function _getCurrentDay() internal view returns (uint16) {
        return uint16(block.timestamp / 1 days);
    }
}
