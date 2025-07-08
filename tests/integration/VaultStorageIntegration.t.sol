// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {StakingVault} from "../../src/StakingVault.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {Flags} from "../../src/lib/Flags.sol";
import {StakingFlags} from "../../src/StakingFlags.sol";
import {StakingErrors} from "../../src/interfaces/staking/StakingErrors.sol";

contract VaultStorageIntegrationTest is Test {
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public claimContract = address(0x5);

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

    function setUp() public {
        token = new MockERC20("Test Token", "TEST");
        stakingStorage = new StakingStorage(admin, manager, address(0));
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

        // Grant CLAIM_CONTRACT_ROLE to claim contract as admin
        vm.startPrank(admin);
        vault.grantRole(vault.CLAIM_CONTRACT_ROLE(), claimContract);
        vm.stopPrank();

        // Setup users with tokens
        token.mint(user1, 10_000e18);
        token.mint(user2, 10_000e18);
        token.mint(claimContract, 10_000e18);

        vm.startPrank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    // ============================================================================
    // TC27: Vault-Storage Integration (UC19)
    // ============================================================================

    function test_TC27_VaultStorageCoordination() public {
        vm.startPrank(user1);

        // Test vault correctly calls storage functions
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify storage state is updated appropriately
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);
        assertTrue(!Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT)); // Not from claim

        // Verify CONTROLLER_ROLE is properly enforced
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(); // AccessControl error - user doesn't have CONTROLLER_ROLE
        stakingStorage.createStake(user1, STAKE_AMOUNT, DAYS_LOCK, 0);
        vm.stopPrank();

        // Verify events are emitted from both contracts
        vm.startPrank(user1);

        vm.expectEmit(true, false, true, true, address(stakingStorage));
        emit Staked(
            user1,
            bytes32(0),
            STAKE_AMOUNT * 2,
            uint16(block.timestamp / 1 days),
            DAYS_LOCK,
            uint16(0)
        );

        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);

        // Verify data remains consistent across contracts
        assertEq(stakingStorage.getStakerInfo(user1).stakesCounter, 2);
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 3);

        vm.stopPrank();
    }

    function test_TC27_CrossContractStateConsistency() public {
        vm.startPrank(user1);

        // Create multiple stakes
        bytes32 stakeId1 = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);

        // Verify consistency
        assertEq(stakingStorage.getStakerInfo(user1).stakesCounter, 2);
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 3);

        // Unstake one stake
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId1);

        // Verify consistency after unstaking
        assertEq(
            stakingStorage.getStakerInfo(user1).stakesCounter,
            2,
            "stakesCounter should not decrement"
        );
        assertEq(
            stakingStorage.getStakerInfo(user1).activeStakesNumber,
            1,
            "activeStakesNumber should decrement"
        );
        assertEq(
            stakingStorage.getCurrentTotalStaked(),
            STAKE_AMOUNT * 2,
            "Total should be 2x after unstaking 1x"
        );

        // Verify stake is properly marked as unstaked, not removed
        StakingStorage.Stake memory unstakedStake = stakingStorage.getStake(
            stakeId1
        );
        assertTrue(unstakedStake.unstakeDay > 0);

        vm.stopPrank();
    }

    function test_TC6_StakeFromClaimContract() public {
        vm.startPrank(claimContract);

        // Test claim contract integration
        bytes32 stakeId = vault.stakeFromClaim(user1, STAKE_AMOUNT, DAYS_LOCK);

        // Verify stake is created for correct user
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);
        assertTrue(Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT)); // From claim

        // Verify staker info is updated
        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user1
        );
        assertEq(info.stakesCounter, 1);
        assertEq(info.totalStaked, STAKE_AMOUNT);

        vm.stopPrank();
    }

    function test_TC24_UnauthorizedStorageAccess() public {
        // Test that only vault can call storage functions
        vm.startPrank(user1);
        vm.expectRevert(); // AccessControl error
        stakingStorage.createStake(user1, STAKE_AMOUNT, DAYS_LOCK, 0);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert(); // AccessControl error
        stakingStorage.createStake(user1, STAKE_AMOUNT, DAYS_LOCK, 0);
        vm.stopPrank();

        // Only vault should be able to call storage functions
        vm.startPrank(address(vault));
        stakingStorage.createStake(user1, STAKE_AMOUNT, DAYS_LOCK, 0);
        vm.stopPrank();
    }

    // ============================================================================
    // TC42: Cross-Contract Event Coordination
    // ============================================================================

    function test_TC42_CrossContractEventCoordination() public {
        vm.startPrank(user1);

        // The Staked event is emitted from StakingStorage. Can't check stakeId.
        vm.expectEmit(true, false, true, true, address(stakingStorage));
        emit Staked(
            user1,
            bytes32(0),
            STAKE_AMOUNT,
            uint16(block.timestamp / 1 days),
            DAYS_LOCK,
            uint16(0)
        );

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Test event synchronization during unstake
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        // The Unstaked event is emitted from StakingStorage. All topics can be checked.
        vm.expectEmit(true, true, true, true, address(stakingStorage));
        emit Unstaked(
            user1,
            stakeId,
            uint16(block.timestamp / 1 days),
            STAKE_AMOUNT
        );

        vault.unstake(stakeId);

        vm.stopPrank();
    }

    function test_TC32_EventParameterVerification() public {
        vm.startPrank(user1);

        // Test event parameters are consistent
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify stake details match event parameters
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);
        assertEq(stake.stakeDay, uint16(block.timestamp / 1 days));

        vm.stopPrank();
    }

    function test_TC25_CheckpointCreationOnBalanceChange() public {
        vm.startPrank(user1);

        // Test CheckpointCreated event emission
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify checkpoint was created
        uint16 currentDay = uint16(block.timestamp / 1 days);
        uint128 balance = stakingStorage.getStakerBalanceAt(user1, currentDay);
        assertEq(balance, STAKE_AMOUNT);

        vm.stopPrank();
    }

    // ============================================================================
    // Additional Integration Tests
    // ============================================================================

    function test_MultipleUsersIntegration() public {
        // Test multiple users interacting with the system
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        // Verify global totals
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 3);
        assertEq(stakingStorage.getTotalStakersCount(), 2);

        // Verify individual balances
        assertEq(stakingStorage.getStakerBalance(user1), STAKE_AMOUNT);
        assertEq(stakingStorage.getStakerBalance(user2), STAKE_AMOUNT * 2);
    }

    function test_ComplexStakeAndUnstakeLifecycle() public {
        vm.startPrank(user1);

        // Create multiple stakes
        bytes32 stakeId1 = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);

        // Verify initial state
        assertEq(stakingStorage.getStakerInfo(user1).stakesCounter, 3);
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT * 6);

        // Unstake one stake
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId1);

        // Verify state after unstaking
        assertEq(
            stakingStorage.getStakerInfo(user1).stakesCounter,
            3,
            "stakesCounter should not decrement"
        );
        assertEq(
            stakingStorage.getStakerInfo(user1).activeStakesNumber,
            2,
            "activeStakesNumber should be 2"
        );
        assertEq(
            stakingStorage.getCurrentTotalStaked(),
            STAKE_AMOUNT * 5,
            "total staked should be 5x"
        );

        // Create another stake
        vault.stake(STAKE_AMOUNT * 4, DAYS_LOCK);

        // Verify final state
        StakingStorage.StakerInfo memory info_after = stakingStorage
            .getStakerInfo(user1);
        assertEq(info_after.stakesCounter, 4, "stakesCounter should be 4");
        assertEq(
            info_after.activeStakesNumber,
            3,
            "activeStakesNumber should be 3"
        );
        assertEq(
            stakingStorage.getCurrentTotalStaked(),
            STAKE_AMOUNT * 9,
            "total staked should be 9x"
        );

        vm.stopPrank();
    }

    function test_TC15_HistoricalDataConsistency() public {
        vm.startPrank(user1);

        uint16 day1 = uint16(block.timestamp / 1 days);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.warp(block.timestamp + 5 days);
        uint16 day2 = uint16(block.timestamp / 1 days);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);

        vm.warp(block.timestamp + 5 days);
        uint16 day3 = uint16(block.timestamp / 1 days);
        vault.stake(STAKE_AMOUNT * 3, DAYS_LOCK);

        // Verify historical consistency
        assertEq(stakingStorage.getStakerBalanceAt(user1, day1), STAKE_AMOUNT);
        assertEq(
            stakingStorage.getStakerBalanceAt(user1, day2),
            STAKE_AMOUNT * 3
        );
        assertEq(
            stakingStorage.getStakerBalanceAt(user1, day3),
            STAKE_AMOUNT * 6
        );

        // Verify daily snapshots
        StakingStorage.DailySnapshot memory snapshot1 = stakingStorage
            .getDailySnapshot(day1);
        assertEq(snapshot1.totalStakedAmount, STAKE_AMOUNT);
        assertEq(snapshot1.totalStakesCount, 1);

        StakingStorage.DailySnapshot memory snapshot2 = stakingStorage
            .getDailySnapshot(day2);
        // The snapshot should accumulate the total from the previous day.
        assertEq(snapshot2.totalStakedAmount, STAKE_AMOUNT * 3);
        assertEq(snapshot2.totalStakesCount, 2);

        StakingStorage.DailySnapshot memory snapshot3 = stakingStorage
            .getDailySnapshot(day3);
        // The snapshot should accumulate the total from the previous day.
        assertEq(snapshot3.totalStakedAmount, STAKE_AMOUNT * 6);
        assertEq(snapshot3.totalStakesCount, 3);

        vm.stopPrank();
    }

    function test_TC3_TC19_ErrorHandlingIntegration() public {
        vm.startPrank(user1);

        // Test error handling across contracts
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Try to unstake before maturity
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingErrors.StakeNotMatured.selector,
                stakeId,
                uint16(block.timestamp / 1 days),
                uint16(block.timestamp / 1 days) + DAYS_LOCK
            )
        );
        vault.unstake(stakeId);

        // Try to unstake non-existent stake
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingErrors.StakeNotFound.selector,
                bytes32(0)
            )
        );
        vault.unstake(bytes32(0));

        vm.stopPrank();
    }
}
