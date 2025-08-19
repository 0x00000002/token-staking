// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/StakingStorage.sol";
import "../../src/StakingVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../helpers/MockERC20.sol";
import "../../src/lib/Flags.sol";
import "../../src/StakingFlags.sol";
import "../../src/interfaces/staking/StakingErrors.sol";

contract StakingStorageTest is Test {
    StakingStorage public stakingStorage;
    StakingVault public vault;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    event Staked(
        address indexed staker,
        bytes32 indexed stakeId,
        uint128 amount,
        uint16 indexed stakeDay,
        uint16 daysLock,
        uint16 flags
    );

    event Unstaked(
        address indexed staker,
        bytes32 indexed stakeId,
        uint16 indexed unstakeDay,
        uint128 amount
    );

    event CheckpointCreated(
        address indexed staker,
        uint16 indexed day,
        uint128 balance,
        uint16 stakesCount
    );

    function setUp() public {
        token = new MockERC20("Test Token", "TEST");
        stakingStorage = new StakingStorage(admin, manager);
        vault = new StakingVault(
            IERC20(token),
            address(stakingStorage),
            admin,
            manager
        );

        // Grant CONTROLLER_ROLE to vault as admin
        vm.startPrank(admin);
        stakingStorage.grantRole(
            stakingStorage.CONTROLLER_ROLE(),
            address(vault)
        );
        vm.stopPrank();

        // Setup users with tokens
        token.mint(user1, 10_000e18);
        token.mint(user2, 10_000e18);
        token.mint(user3, 10_000e18);

        vm.startPrank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // Warp time to avoid day 0 issues in tests
        vm.warp(10 days);
    }

    // ============================================================================
    // TC13: Get Stake Information (UC3)
    // ============================================================================

    function test_TC13_GetStakeInformation() public {
        vm.startPrank(user1);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);

        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);
        assertEq(stake.unstakeDay, 0);
        assertTrue(!Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT)); // Not from claim
        assertEq(stake.stakeDay, uint16(block.timestamp / 1 days));

        vm.stopPrank();
    }

    // ============================================================================
    // TC14: Get Staker Information (UC3)
    // ============================================================================

    function test_TC14_GetStakerInformation() public {
        vm.startPrank(user1);

        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);

        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user1
        );

        assertEq(info.stakesCounter, 2);
        assertEq(info.totalStaked, STAKE_AMOUNT * 3);
        assertEq(info.lastCheckpointDay, uint16(block.timestamp / 1 days));

        vm.stopPrank();
    }

    // ============================================================================
    // TC15: Historical Balance Queries (UC9)
    // ============================================================================

    function test_TC15_HistoricalBalanceQueries() public {
        vm.startPrank(user1);

        uint16 day1 = uint16(block.timestamp / 1 days);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.warp(block.timestamp + 5 days);
        uint16 day2 = uint16(block.timestamp / 1 days);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);

        vm.warp(block.timestamp + 5 days);
        uint16 day3 = uint16(block.timestamp / 1 days);
        vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);

        // Query historical balances
        assertEq(stakingStorage.getStakerBalanceAt(user1, day1), STAKE_AMOUNT);
        assertEq(
            stakingStorage.getStakerBalanceAt(user1, day2),
            STAKE_AMOUNT * 3
        );
        assertEq(
            stakingStorage.getStakerBalanceAt(user1, day3),
            STAKE_AMOUNT * 6
        );

        // Query future day should return current balance
        assertEq(
            stakingStorage.getStakerBalanceAt(user1, day3 + 10),
            STAKE_AMOUNT * 6
        );

        // Query day before first checkpoint
        assertEq(stakingStorage.getStakerBalanceAt(user1, day1 - 1), 0);

        vm.stopPrank();
    }

    // ============================================================================
    // TC16: Batch Historical Queries (UC9)
    // ============================================================================

    function test_TC16_BatchHistoricalQueries() public {
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user3);
        vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);
        vm.stopPrank();

        uint16 targetDay = uint16(block.timestamp / 1 days);
        address[] memory stakers = new address[](3);
        stakers[0] = user1;
        stakers[1] = user2;
        stakers[2] = user3;

        uint128[] memory balances = stakingStorage.batchGetStakerBalances(
            stakers,
            targetDay
        );

        assertEq(balances.length, 3);
        assertEq(balances[0], STAKE_AMOUNT);
        assertEq(balances[1], STAKE_AMOUNT * 2);
        assertEq(balances[2], STAKE_AMOUNT * 3);
    }

    // ============================================================================
    // TC17: Global Statistics (UC9)
    // ============================================================================

    function test_TC17_GlobalStatistics() public {
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        // Test current total staked
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 3);

        // Test daily snapshot
        uint16 today = uint16(block.timestamp / 1 days);
        StakingStorage.DailySnapshot memory snapshot = stakingStorage
            .getDailySnapshot(today);

        assertEq(snapshot.totalStakedAmount, STAKE_AMOUNT * 3);
        assertEq(snapshot.totalStakesCount, 2);
    }

    // ============================================================================
    // TC18: Staker Enumeration (UC10)
    // ============================================================================

    function test_TC18_StakerEnumeration() public {
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user3);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        // Test total count
        assertEq(stakingStorage.getTotalStakersCount(), 3);

        // Test pagination
        address[] memory stakers = stakingStorage.getStakersPaginated(0, 2);
        assertEq(stakers.length, 2);

        stakers = stakingStorage.getStakersPaginated(2, 1);
        assertEq(stakers.length, 1);

        // Test out of bounds
        vm.expectRevert(
            abi.encodeWithSelector(StakingErrors.OutOfBounds.selector, 3, 5)
        );
        stakingStorage.getStakersPaginated(5, 1);
    }

    // ============================================================================
    // TC25: Basic Data Integrity (UC16-17)
    // ============================================================================

    function test_TC25_BasicDataIntegrity() public {
        vm.startPrank(user1);
        bytes32 stakeId1 = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);
        vm.stopPrank();

        // Verify global currentTotalStaked equals sum of active stakes
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 6);

        // Unstake one stake
        vm.startPrank(user1);
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId1);
        vm.stopPrank();

        // Verify state consistency after unstaking
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 5);

        // Verify user totals match individual stakes
        StakingStorage.StakerInfo memory info1 = stakingStorage.getStakerInfo(
            user1
        );
        assertEq(info1.totalStaked, STAKE_AMOUNT * 2); // Only active stakes

        StakingStorage.StakerInfo memory info2 = stakingStorage.getStakerInfo(
            user2
        );
        assertEq(info2.totalStaked, STAKE_AMOUNT * 3);
    }

    // ============================================================================
    // TC26: Vault-Storage Integration (UC19)
    // ============================================================================

    function test_TC26_VaultStorageIntegration() public {
        vm.startPrank(user1);

        // Test that vault correctly calls storage functions
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify stake was created in storage
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);

        // Verify CONTROLLER_ROLE enforcement
        vm.stopPrank();

        // Test that only vault (with CONTROLLER_ROLE) can call storage functions
        vm.startPrank(user2);
        vm.expectRevert(); // AccessControl error
        stakingStorage.createStake(user2, STAKE_AMOUNT, DAYS_LOCK, 0);
        vm.stopPrank();

        // Test unstaking integration
        vm.startPrank(user1);
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId);

        // Verify data consistency across contracts
        StakingStorage.Stake memory unstakedStake = stakingStorage.getStake(
            stakeId
        );
        assertEq(unstakedStake.unstakeDay, uint16(block.timestamp / 1 days));

        vm.stopPrank();
    }

    // ============================================================================
    // TC27: Token Integration (UC18)
    // ============================================================================

    function test_TC27_TokenIntegration() public {
        vm.startPrank(user1);

        // Test basic token operations with standard ERC20
        uint256 balanceBefore = token.balanceOf(user1);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify token transfers work correctly
        assertEq(token.balanceOf(user1), balanceBefore - STAKE_AMOUNT);
        assertEq(
            token.balanceOf(address(vault)),
            vaultBalanceBefore + STAKE_AMOUNT
        );

        // Test unstaking token transfer
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        uint256 balanceBeforeUnstake = token.balanceOf(user1);

        vault.unstake(stakeId);

        // Verify balances updated appropriately
        assertEq(token.balanceOf(user1), balanceBeforeUnstake + STAKE_AMOUNT);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore);

        vm.stopPrank();
    }

    // ============================================================================
    // TC28: Basic Time Lock Validation
    // ============================================================================

    function test_TC28_BasicTimeLockValidation() public {
        vm.startPrank(user1);

        // Test realistic time lock boundaries (30 days)
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Should not be able to unstake before time lock expires
        vm.expectRevert();
        vault.unstake(stakeId);

        // Fast forward exactly 30 days
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        // Should be able to unstake when time lock expires
        vault.unstake(stakeId);

        // Verify time lock validation worked correctly
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.unstakeDay, uint16(block.timestamp / 1 days));

        vm.stopPrank();
    }

    function test_TC28_BasicTimeLockValidation_just1day() public {
        vm.startPrank(user1);

        vm.warp(10 hours); // it's 10am

        // Test realistic time lock boundaries (1 day)
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, 1);

        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);

        vm.assertEq(stake.stakeDay, uint16(block.timestamp / 1 days));
        vm.assertEq(stake.daysLock, 1);

        // Should not be able to unstake before time lock expires
        vm.expectRevert();
        vault.unstake(stakeId);

        uint256 currentTimestamp = block.timestamp;
        // Fast forward less than 1 days
        vm.warp(currentTimestamp + 2 days);

        vm.assertEq(block.timestamp, currentTimestamp + 2 days);

        // Should be able to unstake when time lock expires
        vault.unstake(stakeId);

        // Verify time lock validation worked correctly
        stake = stakingStorage.getStake(stakeId);
        assertEq(stake.unstakeDay, uint16(block.timestamp / 1 days));

        vm.stopPrank();
    }
}
