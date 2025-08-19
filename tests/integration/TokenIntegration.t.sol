// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/StakingVault.sol";
import "../../src/StakingStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../helpers/MockERC20.sol";
import "../../src/lib/Flags.sol";
import "../../src/StakingFlags.sol";
import "../../src/interfaces/staking/StakingErrors.sol";

contract TokenIntegrationTest is Test {
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user = address(0x3);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    event Transfer(address indexed from, address indexed to, uint256 value);

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
        // Grant CLAIM_CONTRACT_ROLE to user for testing as admin
        vault.grantRole(vault.CLAIM_CONTRACT_ROLE(), user);
        vm.stopPrank();

        // Setup users with tokens
        token.mint(user, 10_000e18);
        token.mint(address(vault), 10_000e18);

        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
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

    function test_TC28_SafeERC20Usage() public {
        vm.startPrank(user);

        // Test token transfer during stake
        uint256 balanceBefore = token.balanceOf(user);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));

        token.approve(address(vault), type(uint256).max);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user, address(vault), STAKE_AMOUNT);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Verify balances
        assertEq(token.balanceOf(user), balanceBefore - STAKE_AMOUNT);
        assertEq(
            token.balanceOf(address(vault)),
            vaultBalanceBefore + STAKE_AMOUNT
        );

        // Test token transfer during unstake
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(vault), user, STAKE_AMOUNT);

        vault.unstake(stakeId);

        // Verify balances restored
        assertEq(token.balanceOf(user), balanceBefore);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore);

        vm.stopPrank();
    }

    function test_TC28_AllowanceChecks() public {
        vm.startPrank(user);

        // Test with exact allowance
        token.approve(address(vault), STAKE_AMOUNT);

        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Try to stake again with insufficient allowance
        vm.expectRevert(); // SafeERC20 will revert
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Approve more and try again
        token.approve(address(vault), STAKE_AMOUNT);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();
    }

    function test_TC28_BalanceValidation() public {
        vm.startPrank(user);

        // Test with insufficient balance
        uint256 largeAmount = token.balanceOf(user) + 1;

        token.approve(address(vault), type(uint256).max);

        vm.expectRevert(); // SafeERC20 will revert
        vault.stake(uint128(largeAmount), DAYS_LOCK);

        // Test with exact balance
        uint256 exactBalance = token.balanceOf(user);
        vault.stake(uint128(exactBalance), DAYS_LOCK);

        // Verify balance is zero
        assertEq(token.balanceOf(user), 0);

        vm.stopPrank();
    }

    function test_TC28_TokenRelatedErrors() public {
        vm.startPrank(user);

        // Test with zero amount
        token.approve(address(vault), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(StakingErrors.InvalidAmount.selector)
        );
        vault.stake(0, DAYS_LOCK);

        // Test with valid amount
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();
    }

    function test_TC28_ClaimContractTokenHandling() public {
        // Grant CLAIM_CONTRACT_ROLE to user for testing
        vm.startPrank(admin);
        vault.grantRole(vault.CLAIM_CONTRACT_ROLE(), user);
        vm.stopPrank();

        vm.startPrank(user);

        // Transfer tokens to vault first
        token.transfer(address(vault), STAKE_AMOUNT);

        // Stake from claim (no token transfer needed)
        bytes32 stakeId = vault.stakeFromClaim(user, STAKE_AMOUNT, DAYS_LOCK);

        // Verify stake was created
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        assertEq(stake.amount, STAKE_AMOUNT);
        assertTrue(Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT));

        // Unstake and verify token transfer
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        uint256 balanceBefore = token.balanceOf(user);
        vault.unstake(stakeId);

        // Verify tokens were transferred back
        assertEq(token.balanceOf(user), balanceBefore + STAKE_AMOUNT);

        vm.stopPrank();
    }

    function test_TC28_EmergencyTokenRecovery() public {
        // This test verifies that the main staking token CAN be recovered.
        token.mint(address(vault), 1000e18);

        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        uint256 adminBalanceBefore = token.balanceOf(admin);

        vm.prank(admin);
        vault.emergencyRecover(IERC20(address(token)), 500e18);

        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - 500e18);
        assertEq(token.balanceOf(admin), adminBalanceBefore + 500e18);
    }
}
