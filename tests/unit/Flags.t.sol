// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/lib/Flags.sol";
import "../../src/StakingFlags.sol";
import "../../src/StakingVault.sol";
import "../../src/StakingStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../helpers/MockERC20.sol";

contract FlagsTest is Test {
    StakingVault public vault;
    StakingStorage public stakingStorage;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user = address(0x3);
    address public claimContract = address(0x4);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

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
        // Grant CLAIM_CONTRACT_ROLE to claim contract as admin
        vault.grantRole(vault.CLAIM_CONTRACT_ROLE(), claimContract);
        vm.stopPrank();

        // Setup user with tokens
        token.mint(user, 10_000e18);
        token.mint(claimContract, 10_000e18);

        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    // ============================================================================
    // TC_F01: Basic Flag Operations (UC20)
    // ============================================================================

    function test_TCF01_SetFlagBit() public pure {
        uint16 flags = 0;

        // Set bit position 0
        flags = Flags.set(flags, 0);
        assertTrue(Flags.isSet(flags, 0));
        assertEq(flags, 1);

        // Set bit position 1
        flags = Flags.set(flags, 1);
        assertTrue(Flags.isSet(flags, 1));
        assertEq(flags, 3); // 0b11

        // Set bit position 15 (highest bit)
        flags = Flags.set(flags, 15);
        assertTrue(Flags.isSet(flags, 15));
        assertEq(flags, 32771); // 0b1000000000000011

        // Verify other bits remain unchanged
        assertTrue(Flags.isSet(flags, 0));
        assertTrue(Flags.isSet(flags, 1));
        assertFalse(Flags.isSet(flags, 2));
    }

    function test_TCF01_UnsetFlagBit() public pure {
        uint16 flags = 0;

        // Set multiple bits
        flags = Flags.set(flags, 0);
        flags = Flags.set(flags, 1);
        flags = Flags.set(flags, 5);

        // Unset bit 1
        flags = Flags.unset(flags, 1);
        assertTrue(Flags.isSet(flags, 0));
        assertFalse(Flags.isSet(flags, 1));
        assertTrue(Flags.isSet(flags, 5));

        // Unset bit 0
        flags = Flags.unset(flags, 0);
        assertFalse(Flags.isSet(flags, 0));
        assertTrue(Flags.isSet(flags, 5));

        // Unset bit 5
        flags = Flags.unset(flags, 5);
        assertFalse(Flags.isSet(flags, 5));
        assertEq(flags, 0);
    }

    function test_TCF01_CheckFlagBitStatus() public pure {
        uint16 flags = 0;

        // Check all 16 bit positions initially false
        for (uint8 i = 0; i < 16; i++) {
            assertFalse(Flags.isSet(flags, i));
        }

        // Set specific bits
        flags = Flags.set(flags, 0);
        flags = Flags.set(flags, 7);
        flags = Flags.set(flags, 15);

        // Check specific bits are true
        assertTrue(Flags.isSet(flags, 0));
        assertTrue(Flags.isSet(flags, 7));
        assertTrue(Flags.isSet(flags, 15));

        // Check other bits remain false
        for (uint8 i = 1; i < 16; i++) {
            if (i != 7 && i != 15) {
                assertFalse(Flags.isSet(flags, i));
            }
        }
    }

    // ============================================================================
    // TC_F02: Stake Flag Integration (UC20)
    // ============================================================================

    function test_TCF02_MarkStakeAsFromClaim() public {
        vm.startPrank(claimContract);

        bytes32 stakeId = vault.stakeFromClaim(user, STAKE_AMOUNT, DAYS_LOCK);

        // Check stake flags
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);

        // IS_FROM_CLAIM_BIT should be set
        assertTrue(Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT));

        // Stake should be identifiable as claim-originated
        assertEq(stake.amount, STAKE_AMOUNT);
        assertEq(stake.daysLock, DAYS_LOCK);

        vm.stopPrank();
    }

    function test_TCF02_RegularStakeFlagHandling() public {
        vm.startPrank(user);

        bytes32 stakeId = vault.stake(STAKE_AMOUNT, DAYS_LOCK);

        // Check stake flags
        StakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);

        // IS_FROM_CLAIM_BIT should not be set
        assertFalse(Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT));

        // Other flag bits should be available for future use
        assertEq(stake.flags, 0);

        // Flag operations should work correctly
        uint16 testFlags = stake.flags;
        testFlags = Flags.set(testFlags, 5); // Set some other bit
        assertTrue(Flags.isSet(testFlags, 5));
        assertFalse(Flags.isSet(testFlags, StakingFlags.IS_FROM_CLAIM_BIT));

        vm.stopPrank();
    }

    function test_TCF02_MultipleFlagCombinations() public pure {
        // Simulate stake with multiple property flags
        uint16 flags = 0;

        // Set IS_FROM_CLAIM_BIT
        flags = Flags.set(flags, StakingFlags.IS_FROM_CLAIM_BIT);

        // Set hypothetical future flags
        uint8 FUTURE_FLAG_1 = 2;
        uint8 FUTURE_FLAG_2 = 8;

        flags = Flags.set(flags, FUTURE_FLAG_1);
        flags = Flags.set(flags, FUTURE_FLAG_2);

        // All flags should be maintained correctly
        assertTrue(Flags.isSet(flags, StakingFlags.IS_FROM_CLAIM_BIT));
        assertTrue(Flags.isSet(flags, FUTURE_FLAG_1));
        assertTrue(Flags.isSet(flags, FUTURE_FLAG_2));

        // Individual flags should be queryable
        assertFalse(Flags.isSet(flags, 1));
        assertFalse(Flags.isSet(flags, 3));

        // Combinations should work as expected
        assertEq(
            flags,
            (1 << StakingFlags.IS_FROM_CLAIM_BIT) |
                (1 << FUTURE_FLAG_1) |
                (1 << FUTURE_FLAG_2)
        );
    }

    // ============================================================================
    // TC_F03: Flag System Extensibility (UC20)
    // ============================================================================

    function test_TCF03_AddNewFlagTypes() public pure {
        // Define new flag constants
        uint8 NEW_FLAG_TYPE_1 = 3;
        uint8 NEW_FLAG_TYPE_2 = 10;
        uint8 NEW_FLAG_TYPE_3 = 14;

        uint16 flags = 0;

        // Set existing flag
        flags = Flags.set(flags, StakingFlags.IS_FROM_CLAIM_BIT);

        // Add new flag types
        flags = Flags.set(flags, NEW_FLAG_TYPE_1);
        flags = Flags.set(flags, NEW_FLAG_TYPE_2);
        flags = Flags.set(flags, NEW_FLAG_TYPE_3);

        // New flags should work with existing system
        assertTrue(Flags.isSet(flags, NEW_FLAG_TYPE_1));
        assertTrue(Flags.isSet(flags, NEW_FLAG_TYPE_2));
        assertTrue(Flags.isSet(flags, NEW_FLAG_TYPE_3));

        // Should not interfere with existing flags
        assertTrue(Flags.isSet(flags, StakingFlags.IS_FROM_CLAIM_BIT));

        // Should be backward compatible
        uint16 oldFlags = Flags.set(0, StakingFlags.IS_FROM_CLAIM_BIT);
        assertTrue(Flags.isSet(oldFlags, StakingFlags.IS_FROM_CLAIM_BIT));
    }

    function test_TCF03_FlagBoundaryConditions() public pure {
        uint16 flags = 0;

        // Test all 16 available bits
        for (uint8 i = 0; i < 16; i++) {
            flags = Flags.set(flags, i);
        }

        // All bit positions should work correctly
        for (uint8 i = 0; i < 16; i++) {
            assertTrue(Flags.isSet(flags, i));
        }

        // Should handle edge cases (bit 0, bit 15)
        uint16 edgeFlags = 0;
        edgeFlags = Flags.set(edgeFlags, 0);
        edgeFlags = Flags.set(edgeFlags, 15);

        assertTrue(Flags.isSet(edgeFlags, 0));
        assertTrue(Flags.isSet(edgeFlags, 15));
        assertEq(edgeFlags, 32769); // 0b1000000000000001

        // Should not overflow or corrupt data
        assertEq(flags, 65535); // All 16 bits set: 0b1111111111111111
    }

    function test_TCF03_FlagPersistenceAndQueries() public {
        vm.startPrank(claimContract);

        // Create stake with flags
        bytes32 stakeId1 = vault.stakeFromClaim(user, STAKE_AMOUNT, DAYS_LOCK);

        vm.stopPrank();
        vm.startPrank(user);

        // Create regular stake
        bytes32 stakeId2 = vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);

        // Fast forward time
        vm.warp(block.timestamp + 10 days);

        // Query stakes after time - flags should persist correctly
        StakingStorage.Stake memory claimStake = stakingStorage.getStake(
            stakeId1
        );
        StakingStorage.Stake memory regularStake = stakingStorage.getStake(
            stakeId2
        );

        // Flags should persist correctly
        assertTrue(
            Flags.isSet(claimStake.flags, StakingFlags.IS_FROM_CLAIM_BIT)
        );
        assertFalse(
            Flags.isSet(regularStake.flags, StakingFlags.IS_FROM_CLAIM_BIT)
        );

        // Should be queryable efficiently
        assertEq(claimStake.amount, STAKE_AMOUNT);
        assertEq(regularStake.amount, STAKE_AMOUNT * 2);

        // Should support filtering and analytics
        bytes32[] memory allStakeIds = stakingStorage.getStakerStakeIds(user);
        assertEq(allStakeIds.length, 2);

        uint256 claimStakeCount = 0;
        uint256 regularStakeCount = 0;

        for (uint256 i = 0; i < allStakeIds.length; i++) {
            StakingStorage.Stake memory stake = stakingStorage.getStake(
                allStakeIds[i]
            );
            if (Flags.isSet(stake.flags, StakingFlags.IS_FROM_CLAIM_BIT)) {
                claimStakeCount++;
            } else {
                regularStakeCount++;
            }
        }

        assertEq(claimStakeCount, 1);
        assertEq(regularStakeCount, 1);

        vm.stopPrank();
    }
}
