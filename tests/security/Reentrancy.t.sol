// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {StakingVault} from "../../src/StakingVault.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Malicious contract that attempts a reentrancy attack during unstaking.
// It inherits from MockERC20 to control the token transfer behavior.
contract MaliciousToken is MockERC20 {
    StakingVault public vault;
    bytes32 public stakeId;

    enum AttackStep {
        Idle,
        Staking,
        Unstaking
    }
    AttackStep public step;

    constructor(
        string memory name,
        string memory symbol
    ) MockERC20(name, symbol) {}

    function setVault(address _vault) public {
        vault = StakingVault(_vault);
    }

    function setStakeId(bytes32 _stakeId) public {
        stakeId = _stakeId;
    }

    // Override the transfer function to insert the reentrancy attempt.
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        // The reentrancy attack is triggered when the vault tries to transfer tokens back to this contract during unstake.
        if (step == AttackStep.Unstaking && msg.sender == address(vault)) {
            // Re-enter the unstake function before the original call has completed.
            vault.unstake(stakeId);
        }
        return super.transfer(to, amount);
    }

    function setAttackStep(AttackStep _step) public {
        step = _step;
    }
}

contract ReentrancyTest is Test {
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MaliciousToken public maliciousToken;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public attackerAddress = address(0xBAD);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    function setUp() public {
        // Deploy the malicious token
        maliciousToken = new MaliciousToken("Malicious Token", "EVIL");

        // Deploy contracts with the malicious token
        stakingStorage = new StakingStorage(admin, manager, address(0));
        vault = new StakingVault(
            IERC20(address(maliciousToken)),
            address(stakingStorage),
            admin,
            manager
        );

        // Configure roles
        vm.startPrank(admin);
        stakingStorage.grantRole(
            stakingStorage.CONTROLLER_ROLE(),
            address(vault)
        );
        vm.stopPrank();

        // Configure the attacker contract
        maliciousToken.setVault(address(vault));
        maliciousToken.mint(attackerAddress, STAKE_AMOUNT);
    }

    // ============================================================================
    // TC23: Reentrancy Protection (UC15)
    // ============================================================================

    function test_TC23_ReentrancyOnUnstake() public {
        // The attacker needs to approve the vault
        vm.startPrank(attackerAddress);
        maliciousToken.approve(address(vault), STAKE_AMOUNT);

        // Step 1: Attacker stakes tokens.
        maliciousToken.setAttackStep(MaliciousToken.AttackStep.Staking);
        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        // Update the attacker contract with the stakeId
        maliciousToken.setStakeId(stakeId);

        // Fast forward time to allow unstaking
        vm.warp(block.timestamp + (DAYS_LOCK + 1) * 1 days);

        // Step 2: Attacker initiates unstake, which will trigger the reentrancy attempt.
        vm.startPrank(attackerAddress);
        maliciousToken.setAttackStep(MaliciousToken.AttackStep.Unstaking);

        // We expect the re-entrant call to be blocked by the ReentrancyGuard.
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.unstake(stakeId);
        vm.stopPrank();
    }
}
