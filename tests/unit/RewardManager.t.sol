// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/reward-system/RewardManager.sol";
import "../../src/reward-system/PoolManager.sol";
import "../../src/reward-system/ClaimsJournal.sol";
import "../../src/reward-system/StrategiesRegistry.sol";
import "../../src/reward-system/strategies/FullStakingStrategy.sol";
import "../../src/interfaces/reward/IRewardStrategy.sol";
import "../../src/interfaces/staking/IStakingStorage.sol";
import "../helpers/MockERC20.sol";
import "../mocks/MockStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @dev Internal mock for a POOL_SIZE_INDEPENDENT strategy (e.g., APR-based)
contract MockSimpleStrategy is IRewardStrategy, AccessControl {
    uint256 public constant APR = 10_000; // 10% with 2 decimals
    address public immutable rewardToken;

    constructor(address admin, address _rewardToken) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        rewardToken = _rewardToken;
    }

    function getStrategyType() external pure returns (StrategyType) {
        return IRewardStrategy.StrategyType.POOL_SIZE_INDEPENDENT;
    }

    function getName() external pure returns (string memory) {
        return "MockSimpleStrategy";
    }

    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    function getRewardLayer() external pure returns (uint8) {
        return 0; // Not used in this mock
    }

    function calculateReward(
        address, // user
        IStakingStorage.Stake calldata stake,
        uint16 poolStartDay,
        uint16 poolEndDay,
        uint16 lastClaimDay
    ) external view returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 calculationStartDay = lastClaimDay == 0
            ? stake.stakeDay
            : lastClaimDay;

        // The calculation should not start before the pool starts.
        if (calculationStartDay < poolStartDay) {
            calculationStartDay = poolStartDay;
        }

        // The calculation should not go beyond the pool's end day.
        uint256 calculationEndDay = currentDay;
        if (calculationEndDay > poolEndDay) {
            calculationEndDay = poolEndDay;
        }

        if (calculationEndDay <= calculationStartDay) {
            return 0;
        }

        uint256 daysToCalculate = calculationEndDay - calculationStartDay;
        return (stake.amount * APR * daysToCalculate) / (100_000 * 365);
    }

    function calculateReward(
        address,
        IStakingStorage.Stake calldata,
        uint256,
        uint256,
        uint16,
        uint16
    ) external pure returns (uint256) {
        revert("MethodNotSupported");
    }
}

contract RewardManagerTest is Test {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    // --- Contracts ---
    RewardManager public rewardManager;
    PoolManager public poolManager;
    ClaimsJournal public claimsJournal;
    StrategiesRegistry public strategiesRegistry;
    MockStakingStorage public mockStakingStorage;
    MockERC20 public rewardToken;
    FullStakingStrategy public fullStakingStrategy;
    MockSimpleStrategy public simpleStrategy;

    // --- Users ---
    address public admin = makeAddr("ADMIN");
    address public manager = makeAddr("MANAGER");
    address public controller = makeAddr("CONTROLLER");
    address public user = makeAddr("USER");

    // --- IDs ---
    uint256 public constant POOL_ID = 1;
    uint256 public constant STRATEGY_ID_0 = 0;
    uint256 public constant STRATEGY_ID_1 = 1;
    bytes32 public stakeId;

    function setUp() public {
        vm.prank(admin);
        poolManager = new PoolManager(admin, manager, controller);

        vm.prank(admin);
        strategiesRegistry = new StrategiesRegistry(admin, manager);

        vm.prank(admin);
        mockStakingStorage = new MockStakingStorage(admin);

        rewardToken = new MockERC20("Reward Token", "RWD");

        vm.prank(admin);
        fullStakingStrategy = new FullStakingStrategy(address(rewardToken), 14);

        simpleStrategy = new MockSimpleStrategy(admin, address(rewardToken));
        assertNotEq(
            address(simpleStrategy),
            address(0),
            "Simple strategy address should not be 0"
        );
        assertEq(
            simpleStrategy.getRewardToken(),
            address(rewardToken),
            "Reward token mismatch"
        );

        vm.prank(admin);
        claimsJournal = new ClaimsJournal(admin);

        // Deploy RewardManager initially with a placeholder for ClaimsJournal
        vm.prank(admin);
        rewardManager = new RewardManager(
            admin,
            manager,
            mockStakingStorage,
            strategiesRegistry,
            claimsJournal,
            poolManager
        );

        vm.prank(admin);
        claimsJournal.grantRole(
            keccak256("REWARD_MANAGER_ROLE"),
            address(rewardManager)
        );

        // --- Initial State Setup ---
        vm.startPrank(manager);
        // Register strategies
        strategiesRegistry.registerStrategy(address(fullStakingStrategy));
        strategiesRegistry.registerStrategy(address(simpleStrategy));

        assertEq(
            strategiesRegistry.getStrategyAddress(STRATEGY_ID_0),
            address(fullStakingStrategy)
        );
        assertEq(
            strategiesRegistry.getStrategyAddress(STRATEGY_ID_1),
            address(simpleStrategy)
        );

        // Create a pool (e.g., from day 10 to day 100)
        vm.warp(10 days); // Set current time to day 10
        uint256 poolId = poolManager.upsertPool(0, 11, 100, 0);
        assertEq(poolId, POOL_ID, "Pool ID mismatch");
        poolManager.announcePool(poolId);

        // Assign strategies to pool layers
        poolManager.assignStrategyToPool(
            poolId,
            0,
            STRATEGY_ID_0,
            PoolManager.StrategyExclusivity.NORMAL
        );
        poolManager.assignStrategyToPool(
            poolId,
            1,
            STRATEGY_ID_1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.stopPrank();

        // Fund the strategies
        vm.prank(address(this));
        rewardToken.mint(manager, 2_000_000 ether);

        vm.startPrank(manager);
        rewardToken.approve(address(rewardManager), 2_000_000 ether);

        rewardManager.fundStrategy(STRATEGY_ID_0, 1_000_000 ether);
        rewardManager.assignRewardToPool(
            POOL_ID,
            STRATEGY_ID_0,
            1_000_000 ether
        );
        rewardManager.fundStrategy(STRATEGY_ID_1, 1_000_000 ether);
        rewardManager.assignRewardToPool(
            POOL_ID,
            STRATEGY_ID_1,
            1_000_000 ether
        );

        // Create a stake for the user, starting on day 10
        vm.stopPrank();

        assertEq(
            mockStakingStorage.hasRole(0x0, admin),
            true,
            "Admin should have DEFAULT_ADMIN_ROLE"
        );

        vm.prank(admin);
        mockStakingStorage.grantRole(
            keccak256("CONTROLLER_ROLE"),
            address(this)
        );

        assertEq(
            mockStakingStorage.hasRole(
                keccak256("CONTROLLER_ROLE"),
                address(this)
            ),
            true
        );

        vm.prank(address(this));
        stakeId = mockStakingStorage.createStake(user, 1000 ether, 10, 0);
    }

    function test_ClaimReward_Success_DependentStrategy() public {
        // --- Setup ---
        vm.warp(101 days);
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(POOL_ID, 2000 * 1e18);

        // --- Action ---
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_0);

        // --- Assertions ---
        assertEq(rewardToken.balanceOf(user), (1_000_000 * 1e18) / 2);
        assertEq(
            claimsJournal.getLastClaimDay(stakeId, POOL_ID, STRATEGY_ID_0),
            101
        );
    }

    function test_ClaimReward_Fail_IfAlreadyClaimed_DependentStrategy() public {
        // --- Setup ---
        vm.warp(101 days);
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(POOL_ID, 1000 * 1e18);

        // First claim
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_0);
        assertEq(rewardToken.balanceOf(user), 1_000_000 * 1e18);

        // --- Action ---
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.RewardAlreadyClaimed.selector,
                0
            )
        );
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_0);
    }

    function test_ClaimReward_Success_IndependentStrategy() public {
        // --- Setup ---
        vm.warp(20 days); // 10 days after stake started

        // --- Action ---
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_1);

        // --- Assertions ---
        // Stake is from day 10, but pool starts on day 11. So reward days = 20 - 11 = 9.
        uint256 expectedReward = uint256(1000 ether * 10_000 * 9) /
            (100_000 * 365);
        assertApproxEqAbs(rewardToken.balanceOf(user), expectedReward, 1e15);
        assertEq(
            claimsJournal.getLastClaimDay(stakeId, POOL_ID, STRATEGY_ID_1),
            20
        );
    }

    function test_ClaimReward_Fail_IfExclusiveClaimedOnLayer() public {
        // --- Setup ---
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            POOL_ID,
            0,
            STRATEGY_ID_0,
            PoolManager.StrategyExclusivity.EXCLUSIVE
        );

        vm.prank(manager);
        // Assign another strategy to the same layer to test exclusivity
        poolManager.assignStrategyToPool(
            POOL_ID,
            0,
            STRATEGY_ID_1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        // User claims the exclusive reward
        vm.warp(101 days);
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(POOL_ID, 1000 * 1e18);
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_0);

        // --- Action ---
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.LayerAlreadyHasExclusiveClaim.selector,
                0,
                101
            )
        );
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_1);
    }

    function test_CalculateRewardsForPool() public {
        // --- Setup ---
        // The main setup is done in setUp()
        // We have a pool from day 11 to 100.
        // Stake was created on day 10.
        // Strategy 0 (FullStaking) is on layer 0.
        // Strategy 1 (Simple APR) is on layer 1.

        // --- Test Layer 1 (POOL_SIZE_INDEPENDENT) ---
        vm.warp(25 days); // 15 days of staking for reward calculation

        (
            uint256[] memory strategyIds1,
            uint256[] memory amounts1,
            PoolManager.StrategyExclusivity[] memory exclusivities1
        ) = rewardManager.calculateRewardsForPool(stakeId, POOL_ID, 1);

        assertEq(strategyIds1.length, 1, "Layer 1: Strategy count mismatch");
        assertEq(
            strategyIds1[0],
            STRATEGY_ID_1,
            "Layer 1: Strategy ID mismatch"
        );
        assertEq(
            uint8(exclusivities1[0]),
            uint8(PoolManager.StrategyExclusivity.NORMAL),
            "Layer 1: Exclusivity mismatch"
        );

        // Expected reward = (stake * APR * days) / (100_000 * 365)
        // Stake is from day 10, but pool starts on day 11. So reward days = 25 - 11 = 14.
        uint256 stakeAmount = 1000 ether;
        uint256 apr = 10_000;
        uint16 numDays = 14;
        uint256 expectedReward1 = (stakeAmount * apr * numDays) /
            (100_000 * 365);
        assertApproxEqAbs(
            amounts1[0],
            expectedReward1,
            1e15,
            "Layer 1: Reward amount mismatch"
        );

        // --- Test Layer 0 (POOL_SIZE_DEPENDENT) ---
        vm.warp(101 days); // Pool has ended
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(POOL_ID, 2000 ether); // User's stake is 1000 ether

        (
            uint256[] memory strategyIds0,
            uint256[] memory amounts0,
            PoolManager.StrategyExclusivity[] memory exclusivities0
        ) = rewardManager.calculateRewardsForPool(stakeId, POOL_ID, 0);

        assertEq(strategyIds0.length, 1, "Layer 0: Strategy count mismatch");
        assertEq(
            strategyIds0[0],
            STRATEGY_ID_0,
            "Layer 0: Strategy ID mismatch"
        );
        assertEq(
            uint8(exclusivities0[0]),
            uint8(PoolManager.StrategyExclusivity.NORMAL),
            "Layer 0: Exclusivity mismatch"
        );

        // Expected reward = (user_stake / total_stake) * total_pool_reward
        // User stake is 1000, total is 2000. Pool reward is 1,000,000 ether.
        uint256 expectedReward0 = (1000 ether * 1_000_000 ether) / (2000 ether);
        assertEq(
            amounts0[0],
            expectedReward0,
            "Layer 0: Reward amount mismatch"
        );
    }

    function test_BatchClaimReward_Success() public {
        // --- Setup ---
        // Based on setUp(): pool runs day 11-100, stake created day 10.
        // Strategy 0 (Dependent) on Layer 0, Strategy 1 (Independent) on Layer 1.

        // 1. Finalize conditions for both claims
        vm.warp(101 days); // Pool ended
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(POOL_ID, 2000 ether); // User has 1000 ether stake

        // 2. Calculate expected rewards for each claim individually
        // Dependent reward
        uint256 expectedReward0 = (1000 ether * 1_000_000 ether) / (2000 ether);

        // Independent reward
        uint256 stakeAmount = 1000 ether;
        uint256 apr = 10_000;
        // Pool is 11-100. Stake is from day 10. Overlap is 100 - 11 = 89 days.
        uint16 numDays = 89;
        uint256 expectedReward1 = (stakeAmount * apr * numDays) /
            (100_000 * 365);

        uint256 totalExpectedReward = expectedReward0 + expectedReward1;

        // 3. Prepare batch call arguments
        bytes32[] memory stakeIds = new bytes32[](2);
        stakeIds[0] = stakeId;
        stakeIds[1] = stakeId;

        uint256[] memory poolIds = new uint256[](2);
        poolIds[0] = POOL_ID;
        poolIds[1] = POOL_ID;

        uint256[] memory strategyIds = new uint256[](2);
        strategyIds[0] = STRATEGY_ID_0;
        strategyIds[1] = STRATEGY_ID_1;

        // --- Action ---
        vm.prank(user);
        rewardManager.batchClaimReward(stakeIds, poolIds, strategyIds);

        // --- Assertions ---
        assertApproxEqAbs(
            rewardToken.balanceOf(user),
            totalExpectedReward,
            1e15,
            "User token balance should match total expected reward"
        );

        // Check that both claims were recorded
        assertEq(
            claimsJournal.getLastClaimDay(stakeId, POOL_ID, STRATEGY_ID_0),
            101,
            "Claim day for dependent strategy should be updated"
        );
        assertEq(
            claimsJournal.getLastClaimDay(stakeId, POOL_ID, STRATEGY_ID_1),
            101,
            "Claim day for independent strategy should be updated"
        );
    }

    function test_Pausable_AccessControl() public {
        bytes32 managerRole = rewardManager.MANAGER_ROLE();

        // 1. Test that a non-manager cannot pause or unpause
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                managerRole
            )
        );
        rewardManager.pause();

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                managerRole
            )
        );
        rewardManager.unpause();

        // 2. Test that the manager can pause and unpause
        vm.prank(manager);
        rewardManager.pause();
        assertTrue(rewardManager.paused(), "Contract should be paused");

        // 3. Verify that claiming is blocked when paused
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(Pausable.EnforcedPause.selector)
        );
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_1);

        // 4. Test that the manager can unpause
        vm.prank(manager);
        rewardManager.unpause();
        assertFalse(rewardManager.paused(), "Contract should be unpaused");

        // 5. Verify that claiming works again when unpaused
        vm.warp(20 days);
        vm.prank(user);
        rewardManager.claimReward(stakeId, POOL_ID, STRATEGY_ID_1);
        assertEq(
            claimsJournal.getLastClaimDay(stakeId, POOL_ID, STRATEGY_ID_1),
            20,
            "Claim should succeed after unpause"
        );
    }

    function test_TC_R24_BatchCalculateReward_HappyPath() public {
        vm.warp(101 days);
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(POOL_ID, 2000 ether);

        bytes32[] memory stakeIds = new bytes32[](2);
        stakeIds[0] = stakeId;
        stakeIds[1] = stakeId;

        uint256[] memory poolIds = new uint256[](2);
        poolIds[0] = POOL_ID;
        poolIds[1] = POOL_ID;

        uint256[] memory strategyIds = new uint256[](2);
        strategyIds[0] = STRATEGY_ID_0;
        strategyIds[1] = STRATEGY_ID_1;

        uint256[] memory rewards = rewardManager.batchCalculateReward(
            stakeIds,
            poolIds,
            strategyIds
        );

        uint256 expectedReward0 = (1000 ether * 1_000_000 ether) / (2000 ether);
        uint256 expectedReward1 = (uint256(1000 ether * 10_000 * 89) /
            (100_000 * 365));

        assertEq(rewards.length, 2, "Should return 2 reward amounts");
        assertEq(
            rewards[0],
            expectedReward0,
            "Reward for strategy 0 is incorrect"
        );
        assertApproxEqAbs(
            rewards[1],
            expectedReward1,
            1e15,
            "Reward for strategy 1 is incorrect"
        );
    }

    function test_TC_R23_SetClaimsJournal_Success() public {
        vm.startPrank(admin);
        ClaimsJournal newClaimsJournal = new ClaimsJournal(admin);
        rewardManager.setClaimsJournal(newClaimsJournal);
        assertEq(
            address(rewardManager.claimsJournal()),
            address(newClaimsJournal),
            "ClaimsJournal address should be updated"
        );
        vm.stopPrank();
    }

    function test_TC_R23_SetClaimsJournal_Fail_IfNotAdmin() public {
        vm.startPrank(user);
        ClaimsJournal newClaimsJournal = new ClaimsJournal(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                rewardManager.DEFAULT_ADMIN_ROLE()
            )
        );
        rewardManager.setClaimsJournal(newClaimsJournal);
        vm.stopPrank();
    }
}
