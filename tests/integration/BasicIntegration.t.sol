// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {StakingVault} from "../../src/StakingVault.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {RewardManager} from "../../src/reward-system/RewardManager.sol";
import {StrategiesRegistry} from "../../src/reward-system/StrategiesRegistry.sol";
import {GrantedRewardStorage} from "../../src/reward-system/GrantedRewardStorage.sol";
import {EpochManager} from "../../src/reward-system/EpochManager.sol";
import {LinearAPRStrategy} from "../../src/reward-system/strategies/LinearAPRStrategy.sol";
import {EpochPoolStrategy} from "../../src/reward-system/strategies/EpochPoolStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {StrategyType, EpochState} from "../../src/interfaces/reward/RewardEnums.sol";
import {IBaseRewardStrategy} from "../../src/interfaces/reward/IBaseRewardStrategy.sol";

contract BasicIntegrationTest is Test {
    // Core contracts
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;

    // Reward system contracts
    RewardManager public rewardManager;
    StrategiesRegistry public registry;
    GrantedRewardStorage public grantedRewardStorage;
    EpochManager public epochManager;
    LinearAPRStrategy public linearStrategy;
    EpochPoolStrategy public epochStrategy;

    // Test actors
    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);

    // Test constants
    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    function setUp() public {
        // Deploy tokens
        stakingToken = new MockERC20("Staking Token", "STAKE");
        rewardToken = new MockERC20("Reward Token", "REWARD");

        // Deploy core staking system
        stakingStorage = new StakingStorage(admin, manager, address(0));
        vault = new StakingVault(
            IERC20(stakingToken),
            address(stakingStorage),
            admin,
            manager
        );

        // Deploy reward system
        registry = new StrategiesRegistry(admin);
        grantedRewardStorage = new GrantedRewardStorage(admin);
        epochManager = new EpochManager(admin);
        rewardManager = new RewardManager(
            admin,
            address(registry),
            address(grantedRewardStorage),
            address(epochManager),
            address(stakingStorage),
            address(rewardToken)
        );

        // Setup roles
        vm.startPrank(admin);
        stakingStorage.grantRole(
            stakingStorage.CONTROLLER_ROLE(),
            address(vault)
        );
        grantedRewardStorage.grantRole(
            grantedRewardStorage.CONTROLLER_ROLE(),
            address(rewardManager)
        );
        vm.stopPrank();

        // Create and register strategies
        IBaseRewardStrategy.StrategyParameters
            memory params = IBaseRewardStrategy.StrategyParameters({
                name: "Test Strategy",
                description: "Test strategy for rewards",
                startDay: 1,
                endDay: 365,
                strategyType: StrategyType.IMMEDIATE
            });

        linearStrategy = new LinearAPRStrategy(
            params,
            manager,
            1000, // 10% APR
            stakingStorage
        );

        epochStrategy = new EpochPoolStrategy(
            params,
            manager,
            30, // 30 day epochs
            stakingStorage
        );

        vm.startPrank(admin);
        registry.registerStrategy(address(linearStrategy));
        registry.registerStrategy(address(epochStrategy));
        registry.setStrategyStatus(1, true); // Activate linear strategy
        registry.setStrategyStatus(2, true); // Activate epoch strategy
        vm.stopPrank();

        // Setup users with tokens
        stakingToken.mint(user1, 10_000e18);
        stakingToken.mint(user2, 10_000e18);
        stakingToken.mint(user3, 10_000e18);
        rewardToken.mint(address(rewardManager), 1_000_000e18);

        // Approve vault to spend tokens
        vm.startPrank(user1);
        stakingToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        stakingToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // Set reasonable timestamp
        vm.warp(30 days);
    }

    // ============================================================================
    // TC_I01: Basic Staking-Reward Data Integration (UC Integration)
    // ============================================================================

    function test_TCI01_BasicRewardCalculationUsingStakingData() public {
        vm.startPrank(user1);

        // User stakes tokens
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();

        // Fast forward some time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(admin);

        // Calculate immediate rewards using staking data
        uint32 fromDay = uint32((block.timestamp - 10 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);

        rewardManager.calculateImmediateRewards(1, fromDay, toDay, 0, 10);

        vm.stopPrank();

        // Verify reward was calculated using accurate staking balance
        uint256 claimableAmount = rewardManager.getClaimableRewards(user1);
        assertTrue(claimableAmount > 0, "Should have calculated rewards");

        // Verify calculation matches staking behavior
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);

        // Results should match staking behavior
        uint128 balance = stakingStorage.getStakerBalance(user1);
        assertEq(balance, STAKE_AMOUNT);
    }

    // ============================================================================
    // TC_I02: Basic Multi-User Reward Distribution (UC Integration)
    // ============================================================================

    function test_TCI02_BasicBatchRewardProcessing() public {
        // Multiple users stake tokens
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user3);
        vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 15 days);

        vm.startPrank(admin);

        // Process rewards for all users in batch
        uint32 fromDay = uint32((block.timestamp - 15 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);

        rewardManager.calculateImmediateRewards(1, fromDay, toDay, 0, 10);

        vm.stopPrank();

        // All eligible users should receive correct rewards
        uint256 user1Rewards = rewardManager.getClaimableRewards(user1);
        uint256 user2Rewards = rewardManager.getClaimableRewards(user2);
        uint256 user3Rewards = rewardManager.getClaimableRewards(user3);

        assertTrue(user1Rewards > 0, "User1 should have rewards");
        assertTrue(user2Rewards > 0, "User2 should have rewards");
        assertTrue(user3Rewards > 0, "User3 should have rewards");

        // User2 should have ~2x user1's rewards, user3 should have ~3x
        assertTrue(
            user2Rewards > user1Rewards,
            "User2 should have more rewards than user1"
        );
        assertTrue(
            user3Rewards > user2Rewards,
            "User3 should have more rewards than user2"
        );

        // State should remain consistent
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 6);
    }

    // ============================================================================
    // TC_I03: Basic Real-Time Staking During Epochs (UC Integration)
    // ============================================================================

    function test_TCI03_BasicStakeDuringActiveEpoch() public {
        vm.startPrank(admin);

        // Announce and activate an epoch
        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay;
        uint32 endDay = startDay + 30;

        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            2,
            1000000e18
        );
        epochManager.updateEpochStates(); // Move to ACTIVE

        vm.stopPrank();

        vm.startPrank(user1);

        // User stakes during active epoch
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();

        // Fast forward to end epoch
        vm.warp((endDay + 1) * 1 days);

        vm.startPrank(admin);

        // Update epoch state and finalize
        epochManager.updateEpochStates(); // Move to ENDED
        // Set pool size BEFORE finalizing (since finalizeEpoch changes state to CALCULATED)
        epochManager.setEpochPoolSize(epochId, 1000000e18);
        epochManager.finalizeEpoch(epochId, 1, STAKE_AMOUNT);

        // Calculate epoch rewards
        rewardManager.calculateEpochRewards(epochId, 0, 10);

        vm.stopPrank();

        // Stake should be properly accounted for in rewards
        uint256 claimableAmount = rewardManager.getClaimableRewards(user1);
        assertTrue(claimableAmount > 0, "Should have epoch rewards");

        // Calculations should be correct
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);
    }

    // ============================================================================
    // TC_I04: Basic End-to-End User Journey (UC Integration)
    // ============================================================================

    function test_TCI04_BasicStakeEarnClaimWorkflow() public {
        // User starts with tokens
        uint256 initialBalance = stakingToken.balanceOf(user1);
        assertEq(initialBalance, 10_000e18);

        vm.startPrank(user1);

        // User stakes tokens
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify staking worked
        assertEq(stakingToken.balanceOf(user1), initialBalance - STAKE_AMOUNT);

        vm.stopPrank();

        // Time passes, rewards are earned
        vm.warp(block.timestamp + 20 days);

        vm.startPrank(admin);

        // Admin calculates rewards
        uint32 fromDay = uint32((block.timestamp - 20 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);
        rewardManager.calculateImmediateRewards(1, fromDay, toDay, 0, 10);

        vm.stopPrank();

        vm.startPrank(user1);

        // User claims rewards
        uint256 claimableAmount = rewardManager.getClaimableRewards(user1);
        assertTrue(claimableAmount > 0, "Should have rewards to claim");

        uint256 rewardBalanceBefore = rewardToken.balanceOf(user1);
        uint256 claimedAmount = rewardManager.claimAllRewards();

        // User should receive expected rewards
        assertEq(claimedAmount, claimableAmount);
        assertEq(
            rewardToken.balanceOf(user1),
            rewardBalanceBefore + claimedAmount
        );

        // User can unstake after lock period
        vm.warp(block.timestamp + DAYS_LOCK * 1 days);
        vault.unstake(stakeId);

        // All operations should work correctly
        assertEq(stakingToken.balanceOf(user1), initialBalance); // Got staking tokens back
        assertTrue(rewardToken.balanceOf(user1) > 0); // Has reward tokens

        vm.stopPrank();

        // State should be consistent
        assertEq(stakingStorage.getCurrentTotalStaked(), 0);
    }

    // ============================================================================
    // TC_I05: Basic Cross-Contract Event Coordination (UC Integration)
    // ============================================================================

    function test_TCI05_BasicEventCoordination() public {
        vm.startPrank(user1);

        // Operations spanning multiple contracts should emit coordinated events
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(admin);

        // Reward calculation operation
        uint32 fromDay = uint32((block.timestamp - 10 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);
        rewardManager.calculateImmediateRewards(1, fromDay, toDay, 0, 10);

        vm.stopPrank();

        vm.startPrank(user1);

        // Claim operation
        rewardManager.claimAllRewards();

        vm.stopPrank();

        // Events should be emitted correctly and event data should be consistent
        // Verify data consistency across contracts
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);

        (
            uint256 totalGranted,
            uint256 totalClaimed,
            uint256 totalClaimable
        ) = rewardManager.getUserRewardSummary(user1);
        assertEq(totalClaimed, totalGranted); // All rewards claimed
        assertEq(totalClaimable, 0);
    }

    // ============================================================================
    // TC_I06: Basic System State Consistency (UC Integration)
    // ============================================================================

    function test_TCI06_BasicStateConsistencyValidation() public {
        // Multiple operations across system components
        vm.startPrank(user1);
        bytes32 stake1 = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        bytes32 stake2 = vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user3);
        bytes32 stake3 = vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);
        vm.stopPrank();

        // Operations complete - validate consistency

        // Total staked should equal sum of individual stakes
        uint128 totalStaked = stakingStorage.getCurrentTotalStaked();
        assertEq(totalStaked, STAKE_AMOUNT * 6);

        // Individual stake amounts should be correct
        StakingStorage.Stake memory s1 = stakingStorage.getStake(stake1);
        StakingStorage.Stake memory s2 = stakingStorage.getStake(stake2);
        StakingStorage.Stake memory s3 = stakingStorage.getStake(stake3);

        assertEq(s1.amount + s2.amount + s3.amount, totalStaked);

        // User balances should match
        assertEq(stakingStorage.getStakerBalance(user1), STAKE_AMOUNT);
        assertEq(stakingStorage.getStakerBalance(user2), STAKE_AMOUNT * 2);
        assertEq(stakingStorage.getStakerBalance(user3), STAKE_AMOUNT * 3);

        // Basic invariants should hold
        assertEq(stakingStorage.getTotalStakersCount(), 3);

        // Fast forward and unstake one
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        vm.startPrank(user1);
        vault.unstake(stake1);
        vm.stopPrank();

        // State should remain consistent after unstaking
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 5);
        assertEq(stakingStorage.getStakerBalance(user1), 0);
    }

    // ============================================================================
    // TC_I07: Basic System Evolution Support (UC Future)
    // ============================================================================

    function test_TCI07_BasicExtensibilityValidation() public {
        // Test that existing functionality continues working when new components are added

        // Create initial state
        vm.startPrank(user1);
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        // Verify initial functionality
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);

        // Simulate adding new strategy (future component)
        vm.startPrank(admin);

        // Create new strategy with different parameters
        IBaseRewardStrategy.StrategyParameters
            memory newParams = IBaseRewardStrategy.StrategyParameters({
                name: "New Test Strategy",
                description: "New test strategy for rewards",
                startDay: 100,
                endDay: 200,
                strategyType: StrategyType.IMMEDIATE
            });

        LinearAPRStrategy newStrategy = new LinearAPRStrategy(
            newParams,
            manager,
            2000, // 20% APR
            stakingStorage
        );

        uint256 newStrategyId = registry.registerStrategy(address(newStrategy));
        registry.setStrategyStatus(newStrategyId, true);

        vm.stopPrank();

        // Existing functionality should continue working
        vm.startPrank(user2);
        bytes32 newStakeId = vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        // Both old and new functionality should work
        StakingStorage.Stake memory newStake = stakingStorage.getStake(
            newStakeId
        );
        assertEq(newStake.amount, STAKE_AMOUNT * 2);

        // System should support both strategies
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 3);

        // Integration should be possible - old rewards still work
        vm.warp(block.timestamp + 5 days);

        vm.startPrank(admin);
        uint32 fromDay = uint32((block.timestamp - 5 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);

        // Calculate rewards with original strategy
        rewardManager.calculateImmediateRewards(1, fromDay, toDay, 0, 10);
        vm.stopPrank();

        uint256 user1Rewards = rewardManager.getClaimableRewards(user1);
        uint256 user2Rewards = rewardManager.getClaimableRewards(user2);

        assertTrue(
            user1Rewards > 0,
            "User1 should have rewards from original strategy"
        );
        assertTrue(
            user2Rewards > 0,
            "User2 should have rewards from original strategy"
        );
    }
}
