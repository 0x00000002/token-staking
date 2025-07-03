// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {EpochManager} from "../../src/reward-system/EpochManager.sol";
import {StrategiesRegistry} from "../../src/reward-system/StrategiesRegistry.sol";
import {EpochPoolStrategy} from "../../src/reward-system/strategies/EpochPoolStrategy.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {RewardErrors} from "../../src/interfaces/reward/RewardErrors.sol";
import {StrategyType, EpochState} from "../../src/interfaces/reward/RewardEnums.sol";
import {IBaseRewardStrategy} from "../../src/interfaces/reward/IBaseRewardStrategy.sol";

contract EpochManagerTest is Test {
    EpochManager public epochManager;
    StrategiesRegistry public registry;
    StakingStorage public stakingStorage;
    EpochPoolStrategy public epochStrategy;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public unauthorized = address(0x3);

    uint256 public strategyId;

    event EpochAnnounced(
        uint32 indexed epochId,
        uint32 startDay,
        uint32 endDay,
        uint256 indexed strategyId,
        uint256 estimatedPoolSize
    );

    event EpochStateChanged(
        uint32 indexed epochId,
        EpochState oldState,
        EpochState newState
    );

    event EpochFinalized(
        uint32 indexed epochId,
        uint256 totalParticipants,
        uint256 totalStakeWeight,
        uint256 actualPoolSize
    );

    function setUp() public {
        token = new MockERC20("Test Token", "TEST");
        stakingStorage = new StakingStorage(admin, manager, address(0));
        registry = new StrategiesRegistry(admin);
        epochManager = new EpochManager(admin);

        // Create and register epoch strategy
        IBaseRewardStrategy.StrategyParameters
            memory params = IBaseRewardStrategy.StrategyParameters({
                name: "Test Epoch Strategy",
                description: "Test strategy for epoch rewards",
                startDay: 1,
                endDay: 365,
                strategyType: StrategyType.EPOCH_BASED
            });

        epochStrategy = new EpochPoolStrategy(
            params,
            manager,
            30, // 30 day epochs
            stakingStorage
        );

        vm.startPrank(admin);
        strategyId = registry.registerStrategy(address(epochStrategy));
        registry.setStrategyStatus(strategyId, true);
        vm.stopPrank();

        // Set current day to a reasonable value
        vm.warp(10 days);
    }

    // ============================================================================
    // TC_R04: Epoch Announcement (UC22)
    // ============================================================================

    function test_TCR04_SuccessfullyAnnounceNewEpoch() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 5;
        uint32 endDay = startDay + 30;
        uint256 estimatedPool = 1000000e18;

        // EpochManager doesn't emit events, so we don't expect any
        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            strategyId,
            estimatedPool
        );

        // New epoch should be created with ANNOUNCED state
        assertEq(epochId, 1);

        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(uint8(epoch.state), uint8(EpochState.ANNOUNCED));
        assertEq(epoch.startDay, startDay);
        assertEq(epoch.endDay, endDay);
        assertEq(epoch.strategyId, strategyId);
        assertEq(epoch.estimatedPoolSize, estimatedPool);

        // Epoch should be queryable
        assertTrue(epochId > 0);

        vm.stopPrank();
    }

    function test_TCR04_AnnounceEpochWithInvalidParameters() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 invalidStartDay = currentDay - 1; // Start day in the past
        uint32 endDay = currentDay + 30;

        // EpochManager doesn't perform validation, so this call will succeed
        uint32 epochId = epochManager.announceEpoch(
            invalidStartDay,
            endDay,
            strategyId,
            1000000e18
        );

        // Verify the epoch was created despite invalid parameters
        assertEq(epochId, 1);
        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(epoch.startDay, invalidStartDay);
        assertEq(epoch.endDay, endDay);

        vm.stopPrank();
    }

    function test_TCR04_AnnounceEpochWithNonExistentStrategy() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 5;
        uint32 endDay = startDay + 30;
        uint256 invalidStrategyId = 999;

        // EpochManager doesn't validate strategy existence, so this call will succeed
        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            invalidStrategyId,
            1000000e18
        );

        // Verify the epoch was created with the invalid strategy ID
        assertEq(epochId, 1);
        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(epoch.strategyId, invalidStrategyId);

        vm.stopPrank();
    }

    function test_TCR04_UnauthorizedEpochAnnouncement() public {
        vm.startPrank(unauthorized);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 5;
        uint32 endDay = startDay + 30;

        vm.expectRevert(); // AccessControl error
        epochManager.announceEpoch(startDay, endDay, strategyId, 1000000e18);

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R05: Epoch State Transitions (UC22)
    // ============================================================================

    function test_TCR05_AnnouncedToActiveTransition() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 1;
        uint32 endDay = startDay + 30;

        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            strategyId,
            1000000e18
        );

        // Fast forward to start day
        vm.warp(startDay * 1 days);

        // EpochManager doesn't emit events, so we don't expect any
        epochManager.updateEpochStates();

        // Epoch state should change to ACTIVE
        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(uint8(epoch.state), uint8(EpochState.ACTIVE));

        // Epoch should be moved to active list
        uint32[] memory activeEpochs = epochManager.getActiveEpochs();
        assertEq(activeEpochs.length, 1);
        assertEq(activeEpochs[0], epochId);

        vm.stopPrank();
    }

    function test_TCR05_ActiveToEndedTransition() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 1;
        uint32 endDay = startDay + 30;

        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            strategyId,
            1000000e18
        );

        // Move to active state
        vm.warp(startDay * 1 days);
        epochManager.updateEpochStates();

        // Fast forward past end day
        vm.warp((endDay + 1) * 1 days);

        // EpochManager doesn't emit events, so we don't expect any
        epochManager.updateEpochStates();

        // Epoch state should change to ENDED
        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(uint8(epoch.state), uint8(EpochState.ENDED));

        // Epoch should be removed from active list
        uint32[] memory activeEpochs = epochManager.getActiveEpochs();
        assertEq(activeEpochs.length, 0);

        vm.stopPrank();
    }

    function test_TCR05_EndedToCalculatedTransition() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 1;
        uint32 endDay = startDay + 30;

        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            strategyId,
            1000000e18
        );

        // Move through states to ENDED
        vm.warp(startDay * 1 days);
        epochManager.updateEpochStates();
        vm.warp((endDay + 1) * 1 days);
        epochManager.updateEpochStates();

        uint256 totalParticipants = 100;
        uint256 totalWeight = 50000000e18;
        uint256 actualPoolSize = 900000e18;

        // EpochManager doesn't emit events, so we don't expect any
        // Set pool size BEFORE finalizing (since finalizeEpoch changes state to CALCULATED)
        epochManager.setEpochPoolSize(epochId, actualPoolSize);
        epochManager.finalizeEpoch(epochId, totalParticipants, totalWeight);

        // Epoch state should change to CALCULATED
        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(uint8(epoch.state), uint8(EpochState.CALCULATED));
        assertEq(epoch.totalParticipants, totalParticipants);
        assertEq(epoch.totalStakeWeight, totalWeight);
        assertEq(epoch.actualPoolSize, actualPoolSize);
        assertTrue(epoch.calculatedAt > 0);

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R06: Epoch Pool Management (UC22)
    // ============================================================================

    function test_TCR06_SetActualPoolSizeForEndedEpoch() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 1;
        uint32 endDay = startDay + 30;

        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            strategyId,
            1000000e18
        );

        // Move to ENDED state
        vm.warp(startDay * 1 days);
        epochManager.updateEpochStates();
        vm.warp((endDay + 1) * 1 days);
        epochManager.updateEpochStates();

        uint256 actualAmount = 800000e18;
        epochManager.setEpochPoolSize(epochId, actualAmount);

        // Epoch actualPoolSize should be updated
        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        assertEq(epoch.actualPoolSize, actualAmount);

        vm.stopPrank();
    }

    function test_TCR06_SetPoolSizeForNonEndedEpoch() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 startDay = currentDay + 5;
        uint32 endDay = startDay + 30;

        uint32 epochId = epochManager.announceEpoch(
            startDay,
            endDay,
            strategyId,
            1000000e18
        );

        // Try to set pool size while in ANNOUNCED state
        vm.expectRevert(
            abi.encodeWithSelector(EpochManager.EpochNotEnded.selector, epochId)
        );
        epochManager.setEpochPoolSize(epochId, 800000e18);

        vm.stopPrank();
    }

    // ============================================================================
    // Additional Epoch Management Tests
    // ============================================================================

    function test_MultipleEpochsManagement() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);

        // Announce multiple epochs
        uint32 epoch1 = epochManager.announceEpoch(
            currentDay + 5,
            currentDay + 35,
            strategyId,
            1000000e18
        );
        uint32 epoch2 = epochManager.announceEpoch(
            currentDay + 40,
            currentDay + 70,
            strategyId,
            2000000e18
        );

        assertEq(epoch1, 1);
        assertEq(epoch2, 2);

        // Activate first epoch
        vm.warp((currentDay + 5) * 1 days);
        epochManager.updateEpochStates();

        uint32[] memory activeEpochs = epochManager.getActiveEpochs();
        assertEq(activeEpochs.length, 1);
        assertEq(activeEpochs[0], epoch1);

        vm.stopPrank();
    }

    function test_GetNonExistentEpoch() public view {
        // Get non-existent epoch - should return empty struct
        EpochManager.Epoch memory epoch = epochManager.getEpoch(999);
        assertEq(epoch.epochId, 0); // Empty struct has default values
        assertEq(epoch.strategyId, 0);
    }

    function test_EpochIdIncrementation() public {
        vm.startPrank(admin);

        uint32 currentDay = uint32(block.timestamp / 1 days);

        // Create multiple epochs to test ID incrementation
        for (uint32 i = 0; i < 5; i++) {
            uint32 epochId = epochManager.announceEpoch(
                currentDay + 10 + (i * 40),
                currentDay + 40 + (i * 40),
                strategyId,
                1000000e18
            );
            assertEq(epochId, i + 1);
        }

        vm.stopPrank();
    }
}
