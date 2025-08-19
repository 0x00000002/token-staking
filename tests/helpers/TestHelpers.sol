// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/StakingVault.sol";
import "../../src/StakingStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MockERC20.sol";

contract TestHelpers is Test {
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);
    address public claimContract = address(0x6);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    function setUpContracts() public {
        token = new MockERC20("Test Token", "TEST");
        stakingStorage = new StakingStorage(admin, manager);
        vault = new StakingVault(
            IERC20(token),
            address(stakingStorage),
            admin,
            manager
        );

        // Grant CONTROLLER_ROLE to vault
        stakingStorage.grantRole(
            stakingStorage.CONTROLLER_ROLE(),
            address(vault)
        );

        // Grant CLAIM_CONTRACT_ROLE to claim contract
        vault.grantRole(vault.CLAIM_CONTRACT_ROLE(), claimContract);
    }

    function setupUsers() public {
        // Setup users with tokens
        token.mint(user1, 10_000e18);
        token.mint(user2, 10_000e18);
        token.mint(user3, 10_000e18);
        token.mint(claimContract, 10_000e18);

        vm.startPrank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function createStake(
        address staker,
        uint128 amount,
        uint16 daysLock
    ) public returns (bytes32) {
        vm.startPrank(staker);
        bytes32 stakeId = vault.stake(amount, daysLock);
        vm.stopPrank();
        return stakeId;
    }

    function fastForwardDays(uint256 numDays) public {
        vm.warp(block.timestamp + numDays * 1 days);
    }

    function getCurrentDay() public view returns (uint16) {
        return uint16(block.timestamp / 1 days);
    }
}
