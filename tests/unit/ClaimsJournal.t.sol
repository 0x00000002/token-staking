// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/reward-system/ClaimsJournal.sol";

contract ClaimsJournalTest is Test {
    ClaimsJournal claimsJournal;
    address admin = makeAddr("admin");
    address rewardManager = makeAddr("rewardManager");
    address user = makeAddr("user");

    bytes32 constant STAKE_ID = keccak256("stake_id");
    uint32 constant POOL_ID = 1;
    uint8 constant LAYER_ID = 0;
    uint32 constant STRATEGY_ID_1 = 1;
    uint32 constant STRATEGY_ID_2 = 2;

    function setUp() public {
        vm.prank(admin);
        claimsJournal = new ClaimsJournal(admin);

        vm.prank(admin);
        claimsJournal.grantRole(
            keccak256("REWARD_MANAGER_ROLE"),
            rewardManager
        );
    }

    function test_RecordClaim_ExclusiveBlocksAll() public {
        // First, record an EXCLUSIVE claim
        vm.prank(rewardManager);
        claimsJournal.recordClaim(
            user,
            POOL_ID,
            LAYER_ID,
            STRATEGY_ID_1,
            STAKE_ID,
            ClaimsJournal.LayerClaimType.EXCLUSIVE,
            100
        );

        assertEq(
            uint(claimsJournal.getLayerClaimState(user, POOL_ID, LAYER_ID)),
            uint(ClaimsJournal.LayerClaimType.EXCLUSIVE)
        );

        // Attempt to record a NORMAL claim on the same layer, should fail
        vm.prank(rewardManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.LayerAlreadyHasExclusiveClaim.selector,
                LAYER_ID,
                101
            )
        );
        claimsJournal.recordClaim(
            user,
            POOL_ID,
            LAYER_ID,
            STRATEGY_ID_2,
            STAKE_ID,
            ClaimsJournal.LayerClaimType.NORMAL,
            101
        );
    }

    function test_RecordClaim_SemiExclusiveLogic() public {
        // First, record a SEMI_EXCLUSIVE claim
        vm.prank(rewardManager);
        claimsJournal.recordClaim(
            user,
            POOL_ID,
            LAYER_ID,
            STRATEGY_ID_1,
            STAKE_ID,
            ClaimsJournal.LayerClaimType.SEMI_EXCLUSIVE,
            100
        );

        assertEq(
            uint(claimsJournal.getLayerClaimState(user, POOL_ID, LAYER_ID)),
            uint(ClaimsJournal.LayerClaimType.SEMI_EXCLUSIVE)
        );

        // Attempt to record another SEMI_EXCLUSIVE claim, should fail
        vm.prank(rewardManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.LayerAlreadyHasSemiExclusiveClaim.selector,
                LAYER_ID,
                101
            )
        );
        claimsJournal.recordClaim(
            user,
            POOL_ID,
            LAYER_ID,
            STRATEGY_ID_2,
            STAKE_ID,
            ClaimsJournal.LayerClaimType.SEMI_EXCLUSIVE,
            101
        );

        // Attempt to record a NORMAL claim, should succeed
        vm.prank(rewardManager);
        claimsJournal.recordClaim(
            user,
            POOL_ID,
            LAYER_ID,
            STRATEGY_ID_2,
            STAKE_ID,
            ClaimsJournal.LayerClaimType.NORMAL,
            101
        );

        // State should remain SEMI_EXCLUSIVE
        assertEq(
            uint(claimsJournal.getLayerClaimState(user, POOL_ID, LAYER_ID)),
            uint(ClaimsJournal.LayerClaimType.SEMI_EXCLUSIVE)
        );
    }
}
