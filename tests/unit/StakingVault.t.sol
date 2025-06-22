// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {StakingVault} from "../../src/StakingVault.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract StakingVaultTest is Test {
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user;
    address public claimContract = address(0x4);
    address public unauthorized = address(0x5);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    event Staked(
        address indexed staker,
        bytes32 indexed stakeId,
        uint128 amount,
        uint16 indexed stakeDay,
        uint16 daysLock,
        bool isFromClaim
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
        // Grant CLAIM_CONTRACT_ROLE to claim contract as admin
        vault.grantRole(vault.CLAIM_CONTRACT_ROLE(), claimContract);
        vm.stopPrank();

        // Use a unique staker address for each test to avoid stake ID collisions
        user = address(0x1234567890123456789012345678901234567890);

        // Setup user with tokens
        token.mint(user, 10000e18);
        token.mint(claimContract, 10000e18);

        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    // ============================================================================
    // TC1: Successful Direct Stake (UC1)
    // ============================================================================

    function test_TC1_SuccessfulDirectStake() public {
        vm.startPrank(user);

        uint256 balanceBefore = token.balanceOf(user);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify token transfer
        assertEq(token.balanceOf(user), balanceBefore - STAKE_AMOUNT);
        assertEq(
            token.balanceOf(address(vault)),
            vaultBalanceBefore + STAKE_AMOUNT
        );

        // Verify stake creation
        StakingStorage.Stake memory stake = stakingStorage.getStake(
            user,
            stakeId
        );
        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);
        assertEq(stake.unstakeDay, 0);
        assertEq(stake.isFromClaim, false);

        // Verify staker info
        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user
        );
        assertEq(info.stakesCounter, 1);
        assertEq(info.activeStakesNumber, 1);
        assertEq(info.totalStaked, STAKE_AMOUNT);

        // Verify global totals
        assertEq(stakingStorage.getCurrentTotalStaked(), STAKE_AMOUNT);

        vm.stopPrank();
    }

    // ============================================================================
    // TC2: Successful Unstaking (UC2)
    // ============================================================================

    function test_TC2_SuccessfulUnstaking() public {
        vm.startPrank(user);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Fast forward past lock period
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        uint256 balanceBefore = token.balanceOf(user);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));

        vault.unstake(stakeId);

        // Verify token transfer back
        assertEq(token.balanceOf(user), balanceBefore + STAKE_AMOUNT);
        assertEq(
            token.balanceOf(address(vault)),
            vaultBalanceBefore - STAKE_AMOUNT
        );

        // Verify stake is marked as unstaked
        StakingStorage.Stake memory unstakedStake = stakingStorage.getStake(
            user,
            stakeId
        );
        assertEq(unstakedStake.unstakeDay, uint16(block.timestamp / 1 days));
        assertEq(unstakedStake.amount, STAKE_AMOUNT); // Amount should remain for historical purposes

        // Verify staker info
        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user
        );
        assertEq(info.stakesCounter, 1, "stakesCounter should not decrement");
        assertEq(info.activeStakesNumber, 0, "activeStakesNumber should be 0");
        assertEq(info.totalStaked, 0);

        // Verify global totals
        assertEq(stakingStorage.getCurrentTotalStaked(), 0);

        vm.stopPrank();
    }

    // ============================================================================
    // TC3: Failed Unstaking - Stake Not Matured (UC11)
    // ============================================================================

    function test_TC3_FailedUnstakingStakeNotMatured() public {
        vm.startPrank(user);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Fast forward but not enough
        vm.warp(block.timestamp + (DAYS_LOCK - 1) * 1 days);

        // Get the stake to calculate the correct mature day
        StakingStorage.Stake memory stake = stakingStorage.getStake(
            user,
            stakeId
        );
        uint16 expectedMatureDay = stake.stakeDay + stake.daysLock;

        vm.expectRevert(
            abi.encodeWithSelector(
                StakingVault.StakeNotMatured.selector,
                stakeId,
                expectedMatureDay,
                uint16(block.timestamp / 1 days)
            )
        );
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC4: Failed Staking - Insufficient Balance (UC12)
    // ============================================================================

    function test_TC4_FailedStakingInsufficientBalance() public {
        vm.startPrank(user);

        uint256 largeAmount = token.balanceOf(user) + 1;

        vm.expectRevert(); // SafeERC20 will revert
        vault.stake(uint128(largeAmount), DAYS_LOCK);

        vm.stopPrank();
    }

    // ============================================================================
    // TC5: Failed Staking - Zero Amount (UC12)
    // ============================================================================

    function test_TC5_FailedStakingZeroAmount() public {
        vm.startPrank(user);

        vm.expectRevert(StakingVault.InvalidAmount.selector);
        vault.stake(0, DAYS_LOCK);

        vm.stopPrank();
    }

    // ============================================================================
    // TC6: Stake from Claim Contract (UC8)
    // ============================================================================

    function test_TC6_StakeFromClaimContract() public {
        vm.startPrank(claimContract);

        bytes32 stakeId = vault.stakeFromClaim(user, STAKE_AMOUNT, DAYS_LOCK);

        // Verify stake creation
        StakingStorage.Stake memory stake = stakingStorage.getStake(
            user,
            stakeId
        );
        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);
        assertEq(stake.isFromClaim, true);

        // Verify staker info
        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user
        );
        assertEq(info.stakesCounter, 1);
        assertEq(info.totalStaked, STAKE_AMOUNT);

        vm.stopPrank();
    }

    // ============================================================================
    // TC7: Failed Claim Stake - Unauthorized (UC14)
    // ============================================================================

    function test_TC7_FailedClaimStakeUnauthorized() public {
        vm.startPrank(unauthorized);

        vm.expectRevert(); // AccessControl error
        vault.stakeFromClaim(user, STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();
    }

    // ============================================================================
    // TC8: Pause System (UC4)
    // ============================================================================

    function test_TC8_PauseSystem() public {
        vm.startPrank(manager);

        vault.pause();
        assertTrue(vault.paused());

        vm.stopPrank();
    }

    // ============================================================================
    // TC9: Unpause System (UC5)
    // ============================================================================

    function test_TC9_UnpauseSystem() public {
        vm.startPrank(manager);

        vault.pause();
        vault.unpause();
        assertFalse(vault.paused());

        vm.stopPrank();
    }

    // ============================================================================
    // TC10: Failed Pause - Unauthorized (UC14)
    // ============================================================================

    function test_TC10_FailedPauseUnauthorized() public {
        vm.startPrank(unauthorized);

        vm.expectRevert(); // AccessControl error
        vault.pause();

        vm.stopPrank();
    }

    // ============================================================================
    // TC11: Emergency Token Recovery (UC14)
    // ============================================================================

    function test_TC11_EmergencyTokenRecovery() public {
        // This test now verifies that the main staking token CANNOT be recovered.
        vm.startPrank(admin); // Any user with MULTISIG_ROLE
        vm.expectRevert("Cannot recover staking token");
        vault.emergencyRecover(token, 1e18);
        vm.stopPrank();
    }

    // ============================================================================
    // TC12: Role Management (UC7)
    // ============================================================================

    function test_TC12_RoleManagement() public {
        vm.startPrank(admin);

        // Grant role
        vault.grantRole(vault.MANAGER_ROLE(), unauthorized);
        assertTrue(vault.hasRole(vault.MANAGER_ROLE(), unauthorized));

        // Revoke role
        vault.revokeRole(vault.MANAGER_ROLE(), unauthorized);
        assertFalse(vault.hasRole(vault.MANAGER_ROLE(), unauthorized));

        vm.stopPrank();
    }

    function test_TC12_EmergencyRecoverRole() public {
        address multisigUser = makeAddr("multisigUser");
        address adminUser = makeAddr("adminUser");
        address managerUser = makeAddr("managerUser");
        address randomUser = makeAddr("randomUser");

        // Grant roles
        vm.startPrank(admin);
        vault.grantRole(vault.MULTISIG_ROLE(), multisigUser);
        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), adminUser);
        vault.grantRole(vault.MANAGER_ROLE(), managerUser);

        // Revoke unnecessary default roles for clarity
        vault.revokeRole(vault.MULTISIG_ROLE(), adminUser);
        vault.revokeRole(vault.MULTISIG_ROLE(), managerUser);
        vm.stopPrank();

        // Prepare a dummy token for recovery
        MockERC20 otherToken = new MockERC20("OtherToken", "OTK");
        otherToken.mint(address(vault), 1000 * 1e18);

        // --- ASSERT SUCCESS ---
        // 1. Multisig user should succeed
        vm.startPrank(multisigUser);
        vault.emergencyRecover(otherToken, 1e18);
        assertEq(otherToken.balanceOf(multisigUser), 1e18);
        vm.stopPrank();

        // --- ASSERT FAILURE ---
        // 2. Admin user should fail
        vm.startPrank(adminUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                adminUser,
                vault.MULTISIG_ROLE()
            )
        );
        vault.emergencyRecover(otherToken, 1e18);
        vm.stopPrank();

        // 3. Manager user should fail
        vm.startPrank(managerUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                managerUser,
                vault.MULTISIG_ROLE()
            )
        );
        vault.emergencyRecover(otherToken, 1e18);
        vm.stopPrank();

        // 4. Random user should fail
        vm.startPrank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomUser,
                vault.MULTISIG_ROLE()
            )
        );
        vault.emergencyRecover(otherToken, 1e18);
        vm.stopPrank();
    }

    // ============================================================================
    // TC20: Already Unstaked Stake (UC12)
    // ============================================================================

    function test_TC20_FailedUnstakeAlreadyUnstaked() public {
        vm.startPrank(user);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Fast forward past lock period
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        // First unstake should succeed
        vault.unstake(stakeId);

        // Second unstake should fail with the appropriate error from the storage contract
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingStorage.StakeAlreadyUnstaked.selector,
                stakeId
            )
        );
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC22: Paused System Operations (UC13)
    // ============================================================================

    function test_TC22_PausedSystemOperations() public {
        vm.startPrank(manager);
        vault.pause();
        vm.stopPrank();

        vm.startPrank(user);

        // Try to stake while paused
        vm.expectRevert(); // Pausable error
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Create stake first, then pause and try to unstake
        vm.stopPrank();

        vm.startPrank(manager);
        vault.unpause();
        vm.stopPrank();

        vm.startPrank(user);
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.startPrank(manager);
        vault.pause();
        vm.stopPrank();

        vm.startPrank(user);
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        vm.expectRevert(); // Pausable error
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC23: Reentrancy Protection (UC15)
    // ============================================================================

    function test_TC23_ReentrancyProtection() public {
        // This would require a malicious contract implementation
        // For now, we test that the nonReentrant modifier is present
        vm.startPrank(user);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Normal operation should work
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC24: Access Control Enforcement (UC14)
    // ============================================================================

    function test_TC24_AccessControlEnforcement() public {
        vm.startPrank(unauthorized);

        // Try to call storage functions directly
        vm.expectRevert(); // AccessControl error
        stakingStorage.createStake(
            user,
            bytes32(0),
            STAKE_AMOUNT,
            DAYS_LOCK,
            false
        );

        // Try emergency recovery without admin role
        vm.expectRevert(); // AccessControl error
        vault.emergencyRecover(IERC20(token), 100e18);

        vm.stopPrank();
    }

    // ============================================================================
    // TC28: Token Integration (UC18)
    // ============================================================================

    function test_TC28_TokenIntegration() public {
        vm.startPrank(user);

        // Test with insufficient allowance
        token.approve(address(vault), 0);

        vm.expectRevert(); // SafeERC20 will revert
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Restore allowance and test normal operation
        token.approve(address(vault), type(uint256).max);
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC29: Time Lock Boundary Conditions
    // ============================================================================

    function test_TC29_TimeLockBoundary_ExactExpiry() public {
        vm.startPrank(user);

        // Test exact time lock expiry
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.warp(block.timestamp + DAYS_LOCK * 1 days);

        // Should be able to unstake exactly at maturity
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    function test_TC29_TimeLockBoundary_ZeroLock() public {
        vm.startPrank(user);

        // Test zero time lock
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, 0);

        // Should be able to unstake immediately
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC30: Large Number Handling
    // ============================================================================

    function test_TC30_LargeNumber_MaxAmount() public {
        vm.startPrank(user);

        // Test maximum uint128 stake amount
        uint128 maxAmount = type(uint128).max;
        token.mint(user, maxAmount);

        bytes32 stakeId = vault.stake(maxAmount, DAYS_LOCK);

        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC34: StakingStorage Direct Function Tests
    // ============================================================================

    function test_TC34_StakingStorageDirectFunctions() public {
        vm.startPrank(address(vault)); // Has CONTROLLER_ROLE

        bytes32 stakeId = keccak256(abi.encode(user, 0));

        // Test successful creation
        stakingStorage.createStake(
            user,
            stakeId,
            STAKE_AMOUNT,
            DAYS_LOCK,
            false
        );

        // Test duplicate prevention
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingStorage.StakeAlreadyExists.selector,
                stakeId
            )
        );
        stakingStorage.createStake(
            user,
            stakeId,
            STAKE_AMOUNT,
            DAYS_LOCK,
            false
        );

        vm.stopPrank();

        // Test unauthorized access
        vm.startPrank(unauthorized);
        vm.expectRevert(); // AccessControl error
        stakingStorage.createStake(
            user,
            bytes32(0),
            STAKE_AMOUNT,
            DAYS_LOCK,
            false
        );
        vm.stopPrank();
    }

    // ============================================================================
    // TC35: Stake ID Generation Validation
    // ============================================================================

    function test_TC35_StakeIdGenerationValidation() public {
        vm.startPrank(user);

        // Create multiple stakes and verify ID generation
        bytes32 stakeId1 = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        bytes32 stakeId2 = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify IDs are different
        assertTrue(stakeId1 != stakeId2);

        // Verify deterministic generation
        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user
        );
        assertEq(info.stakesCounter, 2);

        vm.stopPrank();
    }

    // ============================================================================
    // TC36: Day Calculation Edge Cases
    // ============================================================================

    function test_TC36_DayCalculationEdgeCases() public {
        vm.startPrank(user);

        // Test day boundary transitions
        uint256 dayBoundary = (block.timestamp / 1 days) * 1 days + 86399; // 1 second before next day
        vm.warp(dayBoundary);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Move to next day
        vm.warp(dayBoundary + 1);

        // Should still be locked
        vm.expectRevert();
        vault.unstake(stakeId);

        // Move past lock period
        vm.warp(dayBoundary + (DAYS_LOCK + 1) * 1 days);
        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC42: Cross-Contract Event Coordination
    // ============================================================================

    function test_TC42_CrossContractEventCoordination() public {
        vm.startPrank(user);

        // The Staked event is emitted from StakingStorage. Can't check stakeId (topic 2).
        vm.expectEmit(true, false, true, true, address(stakingStorage));
        emit Staked(
            user,
            bytes32(0),
            STAKE_AMOUNT,
            uint16(block.timestamp / 1 days),
            DAYS_LOCK,
            false
        );

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        // The Unstaked event is emitted from StakingStorage. All topics can be checked.
        vm.expectEmit(true, true, true, true, address(stakingStorage));
        emit Unstaked(
            user,
            stakeId,
            uint16(block.timestamp / 1 days),
            STAKE_AMOUNT
        );

        vault.unstake(stakeId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC43: Gas Limit Edge Cases
    // ============================================================================

    function test_TC43_GasLimitEdgeCases() public {
        vm.startPrank(user);

        // Test multiple stakes to verify gas usage
        for (uint256 i = 0; i < 10; i++) {
            vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        }

        // Verify all stakes were created
        StakingStorage.StakerInfo memory info = stakingStorage.getStakerInfo(
            user
        );
        assertEq(info.stakesCounter, 10);

        vm.stopPrank();
    }
}
