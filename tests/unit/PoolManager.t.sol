// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/reward-system/PoolManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

contract PoolManagerTest is Test {
    PoolManager poolManager;
    address admin = makeAddr("admin");
    address manager = makeAddr("manager");
    address controller = makeAddr("controller");
    address user = makeAddr("user");

    uint256 constant POOL_ID = 1;

    function setUp() public {
        vm.prank(admin);
        poolManager = new PoolManager(admin, manager, controller);
    }

    function test_UpsertPool_Success() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 999);
        assertEq(poolId, 1, "Pool ID should be 1");

        PoolManager.Pool memory pool = poolManager.getPool(poolId);
        assertEq(pool.startDay, 10, "Start day mismatch");
        assertEq(pool.endDay, 100, "End day mismatch");
    }

    function test_UpsertPool_Fail_IfPoolAlreadyStarted() public {
        // Setup: create a pool that starts on day 10
        vm.startPrank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        poolManager.announcePool(poolId);

        // Warp time to day 11, after the pool has started
        vm.warp(11 days);

        // Attempt to update the started pool
        vm.expectRevert(PoolManager.PoolAlreadyAnnounced.selector);
        poolManager.upsertPool(poolId, 11, 101, 0);
        vm.stopPrank();
    }

    function test_RemoveStrategy_Fail_IfPoolAlreadyAnnounced() public {
        // Setup: create a pool that starts on day 10
        vm.startPrank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        poolManager.announcePool(poolId);

        // Warp time to day 11
        vm.warp(11 days);

        // Attempt to assign a strategy to the started pool
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.expectRevert(PoolManager.PoolAlreadyAnnounced.selector);
        poolManager.removeStrategyFromPool(poolId, 0, 1);
        vm.stopPrank();
    }

    function test_SetTotalStakeWeight_Success() public {
        // Setup: create a pool that ends on day 100
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        PoolManager.Pool memory poolAfterUpsert = poolManager.getPool(poolId);
        assertEq(
            poolAfterUpsert.endDay,
            100,
            "End day not set correctly after upsert"
        );

        // Warp time to day 101, after the pool has ended
        vm.warp(101 days);

        uint128 totalWeight = 1_000_000 * 1e18;
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(poolId, totalWeight);

        PoolManager.Pool memory pool = poolManager.getPool(poolId);
        assertEq(
            pool.totalPoolWeight,
            totalWeight,
            "Total stake weight mismatch"
        );
    }

    function test_SetTotalStakeWeight_Fail_IfNotEnded() public {
        // Setup: create a pool that ends on day 100
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        // Warp time to day 50, while the pool is still active
        vm.warp(50 days);

        vm.prank(controller);
        vm.expectRevert(PoolManager.PoolNotEnded.selector);
        poolManager.setPoolTotalStakeWeight(poolId, 1_000_000 * 1e18);
    }

    function test_SetTotalStakeWeight_Fail_IfNotController() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.warp(101 days);

        vm.prank(user); // Not a controller
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                poolManager.CONTROLLER_ROLE()
            )
        );
        poolManager.setPoolTotalStakeWeight(poolId, 1_000_000 * 1e18);
    }

    function test_SetPoolLiveWeight_Success() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        uint256 liveWeight = 500 * 1e18;
        vm.prank(controller);
        poolManager.setPoolLiveWeight(poolId, liveWeight);

        assertEq(
            poolManager.poolLiveWeight(poolId),
            liveWeight,
            "Live weight mismatch"
        );
    }

    function test_SetPoolLiveWeight_Fail_IfNotController() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        vm.prank(user); // Not a controller
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                poolManager.CONTROLLER_ROLE()
            )
        );
        poolManager.setPoolLiveWeight(poolId, 500 * 1e18);
    }

    function test_RemoveLayer_Success() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        vm.prank(manager);
        poolManager.removeLayer(poolId, 0);

        assertFalse(poolManager.hasLayer(poolId, 0), "Layer should be removed");
    }

    function test_RemoveLayer_Fail_IfPoolActive() public {
        vm.startPrank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        poolManager.announcePool(poolId);

        vm.warp(11 days);

        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.expectRevert(PoolManager.PoolAlreadyAnnounced.selector);
        poolManager.removeLayer(poolId, 0);
        vm.stopPrank();
    }

    function test_RemoveLayer_Fail_IfNotManager() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                poolManager.MANAGER_ROLE()
            )
        );
        poolManager.removeLayer(poolId, 0);
    }

    function test_RemoveStrategyFromPool_Success() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        vm.prank(manager);
        poolManager.removeStrategyFromPool(poolId, 0, 1);

        assertEq(
            poolManager.getLayerStrategies(poolId, 0).length,
            0,
            "Strategy should be removed"
        );
    }

    function test_RemoveStrategyFromPool_Fail_IfPoolActive() public {
        vm.startPrank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        poolManager.announcePool(poolId);

        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.warp(11 days);

        vm.expectRevert(PoolManager.PoolAlreadyAnnounced.selector);
        poolManager.removeStrategyFromPool(poolId, 0, 1);
        vm.stopPrank();
    }

    function test_RemoveStrategyFromPool_Fail_IfNotManager() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                poolManager.MANAGER_ROLE()
            )
        );
        poolManager.removeStrategyFromPool(poolId, 0, 1);
    }

    function test_GetStrategyLayer() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        assertEq(poolManager.getStrategyLayer(POOL_ID, 1), 0, "Layer mismatch");
    }

    function test_GetStrategyExclusivity() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            POOL_ID,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        assertEq(
            uint8(poolManager.getStrategyExclusivity(poolId, 0, 1)),
            uint8(PoolManager.StrategyExclusivity.NORMAL),
            "Exclusivity mismatch"
        );
    }

    function test_GetLayerStrategies() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            POOL_ID,
            0,
            2,
            PoolManager.StrategyExclusivity.EXCLUSIVE
        );

        uint256[] memory strategies = poolManager.getLayerStrategies(
            POOL_ID,
            0
        );
        assertEq(strategies.length, 2, "Strategy count mismatch");
        assertEq(strategies[0], 1, "Strategy ID mismatch");
        assertEq(strategies[1], 2, "Strategy ID mismatch");
    }

    function test_HasLayer() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        assertTrue(poolManager.hasLayer(POOL_ID, 0), "Layer should exist");
        assertFalse(poolManager.hasLayer(POOL_ID, 1), "Layer should not exist");
    }

    function test_GetPoolsByDateRange() public {
        vm.prank(manager);
        uint256 poolId1 = poolManager.upsertPool(0, 10, 20, 0);
        vm.prank(manager);
        uint256 poolId2 = poolManager.upsertPool(0, 15, 25, 0);
        vm.prank(manager);
        uint256 poolId3 = poolManager.upsertPool(0, 30, 40, 0);

        uint256[] memory poolsInRange = poolManager.getPoolsByDateRange(12, 22);
        assertEq(poolsInRange.length, 2, "Pool count mismatch");
        assertEq(poolsInRange[0], poolId1, "Pool ID mismatch");
        assertEq(poolsInRange[1], poolId2, "Pool ID mismatch");
    }

    function test_GetPools() public {
        vm.prank(manager);
        uint256 poolId1 = poolManager.upsertPool(0, 10, 20, 0);
        vm.prank(manager);
        uint256 poolId2 = poolManager.upsertPool(0, 15, 25, 0);

        uint256[] memory poolIds = new uint256[](2);
        poolIds[0] = poolId1;
        poolIds[1] = poolId2;

        PoolManager.Pool[] memory pools = poolManager.getPools(poolIds);
        assertEq(pools.length, 2, "Pool count mismatch");
        assertEq(pools[0].startDay, 10, "Pool 1 start day mismatch");
        assertEq(pools[1].startDay, 15, "Pool 2 start day mismatch");
        assertEq(pools[0].endDay, 20, "Pool 1 end day mismatch");
        assertEq(pools[1].endDay, 25, "Pool 2 end day mismatch");
    }

    function test_GetPoolCount() public {
        vm.prank(manager);
        uint256 poolId1 = poolManager.upsertPool(0, 10, 20, 0);
        vm.prank(manager);
        uint256 poolId2 = poolManager.upsertPool(0, 15, 25, 0);

        assertEq(poolManager.getPoolsCount(), 2, "Pool count mismatch");
    }

    function test_IsPoolActive() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        vm.warp(11 days);
        assertTrue(poolManager.isPoolActive(poolId), "Pool should be active");

        vm.warp(101 days);
        assertFalse(
            poolManager.isPoolActive(POOL_ID),
            "Pool should not be active"
        );
    }

    function test_IsPoolEnded() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        vm.warp(101 days);
        assertTrue(poolManager.isPoolEnded(poolId), "Pool should be ended");

        vm.warp(50 days);
        assertFalse(
            poolManager.isPoolEnded(poolId),
            "Pool should not be ended"
        );
    }

    function test_IsPoolCalculated() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        assertFalse(
            poolManager.isPoolCalculated(poolId),
            "Pool should not be calculated initially"
        );

        vm.warp(101 days);
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(poolId, 1000);

        assertTrue(
            poolManager.isPoolCalculated(poolId),
            "Pool should be calculated"
        );
    }

    function test_GetPoolLayers() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            1,
            2,
            PoolManager.StrategyExclusivity.EXCLUSIVE
        );

        uint256[] memory layers = poolManager.getPoolLayers(poolId);
        assertEq(layers.length, 2, "Layer count mismatch");
        assertEq(layers[0], 0, "Layer ID mismatch");
        assertEq(layers[1], 1, "Layer ID mismatch");
    }

    function test_GetStrategiesFromLayer() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        // Assign strategies to layer 0
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            2,
            PoolManager.StrategyExclusivity.EXCLUSIVE
        );
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            3,
            PoolManager.StrategyExclusivity.SEMI_EXCLUSIVE
        );

        // Assign a strategy to layer 1
        vm.prank(manager);
        poolManager.assignStrategyToPool(
            poolId,
            1,
            4,
            PoolManager.StrategyExclusivity.NORMAL
        );

        // --- Test Layer 0 ---
        (
            uint256[] memory strategyIds,
            PoolManager.StrategyExclusivity[] memory exclusivities
        ) = poolManager.getStrategiesFromLayer(poolId, 0);

        assertEq(strategyIds.length, 3, "Layer 0: Strategy count mismatch");
        assertEq(
            exclusivities.length,
            3,
            "Layer 0: Exclusivity count mismatch"
        );

        assertEq(strategyIds[0], 1, "Layer 0: Strategy ID 1 mismatch");
        assertEq(strategyIds[1], 2, "Layer 0: Strategy ID 2 mismatch");
        assertEq(strategyIds[2], 3, "Layer 0: Strategy ID 3 mismatch");

        assertEq(
            uint8(exclusivities[0]),
            uint8(PoolManager.StrategyExclusivity.NORMAL),
            "Layer 0: Exclusivity 1 mismatch"
        );
        assertEq(
            uint8(exclusivities[1]),
            uint8(PoolManager.StrategyExclusivity.EXCLUSIVE),
            "Layer 0: Exclusivity 2 mismatch"
        );
        assertEq(
            uint8(exclusivities[2]),
            uint8(PoolManager.StrategyExclusivity.SEMI_EXCLUSIVE),
            "Layer 0: Exclusivity 3 mismatch"
        );

        // --- Test Layer 1 ---
        (strategyIds, exclusivities) = poolManager.getStrategiesFromLayer(
            poolId,
            1
        );

        assertEq(strategyIds.length, 1, "Layer 1: Strategy count mismatch");
        assertEq(
            exclusivities.length,
            1,
            "Layer 1: Exclusivity count mismatch"
        );
        assertEq(strategyIds[0], 4, "Layer 1: Strategy ID mismatch");
        assertEq(
            uint8(exclusivities[0]),
            uint8(PoolManager.StrategyExclusivity.NORMAL),
            "Layer 1: Exclusivity mismatch"
        );

        // --- Test Empty Layer ---
        (strategyIds, exclusivities) = poolManager.getStrategiesFromLayer(
            poolId,
            2
        );
        assertEq(strategyIds.length, 0, "Empty Layer: Strategy count mismatch");
        assertEq(
            exclusivities.length,
            0,
            "Empty Layer: Exclusivity count mismatch"
        );
    }

    function test_SetPoolTotalStakeWeight_Fail_IfAlreadyCalculated() public {
        // Setup: create a pool that ends on day 100
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        // Warp time to day 101, after the pool has ended
        vm.warp(101 days);

        uint128 totalWeight = 1_000_000 * 1e18;
        vm.prank(controller);
        poolManager.setPoolTotalStakeWeight(poolId, totalWeight); // First time, should succeed

        // Attempt to set the total stake weight again
        vm.prank(controller);
        vm.expectRevert(PoolManager.PoolAlreadyCalculated.selector);
        poolManager.setPoolTotalStakeWeight(poolId, totalWeight + 1); // Second time, should revert
    }

    function test_UpsertPool_Fail_PoolDoesNotExist() public {
        uint256 nonExistentPoolId = 999; // Assuming 999 does not exist

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                PoolManager.PoolDoesNotExist.selector,
                nonExistentPoolId
            )
        );
        poolManager.upsertPool(nonExistentPoolId, 10, 100, 0);
    }

    function test_UpsertPool_Fail_ParentPoolIsSelf() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0); // Create a new pool

        vm.prank(manager);
        vm.expectRevert(PoolManager.ParentPoolIsSelf.selector);
        poolManager.upsertPool(poolId, 10, 100, poolId); // Set parent to itself
    }

    function test_UpsertPool_Fail_InvalidDates() public {
        vm.prank(manager);
        vm.expectRevert(PoolManager.InvalidDates.selector);
        poolManager.upsertPool(0, 100, 10, 0); // startDay >= endDay
    }

    function test_MarkStrategyAsIgnored_Success() public {
        vm.startPrank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );

        poolManager.markStrategyAsIgnored(poolId, 0, 1);
        vm.stopPrank();

        // No direct getter for ignored strategies, so we rely on no revert and future integration tests.
        // For now, just ensure it doesn't revert.
        // A more robust test would involve a function that queries ignored status.
    }

    function test_UnmarkStrategyAsIgnored_Success() public {
        vm.startPrank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);
        poolManager.assignStrategyToPool(
            poolId,
            0,
            1,
            PoolManager.StrategyExclusivity.NORMAL
        );
        poolManager.markStrategyAsIgnored(poolId, 0, 1); // Mark it first

        poolManager.unmarkStrategyAsIgnored(poolId, 0, 1);
        vm.stopPrank();

        // No direct getter for ignored strategies, so we rely on no revert.
    }

    function test_TC_R22_GetPool_Fail_IfPoolDoesNotExist() public {
        uint256 nonExistentPoolId = 999;
        vm.expectRevert(
            abi.encodeWithSelector(
                PoolManager.PoolDoesNotExist.selector,
                nonExistentPoolId
            )
        );
        poolManager.getPool(nonExistentPoolId);
    }

    function test_announcePool_Success() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        vm.prank(manager);
        poolManager.announcePool(poolId);

        PoolManager.Pool memory pool = poolManager.getPool(poolId);
        assertTrue(pool.hasAnnounced, "Pool should be announced");
    }

    function test_announcePool_Fail_IfNotManager() public {
        vm.prank(manager);
        uint256 poolId = poolManager.upsertPool(0, 10, 100, 0);

        vm.prank(user); // Not a manager
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                poolManager.MANAGER_ROLE()
            )
        );
        poolManager.announcePool(poolId);
    }
}
