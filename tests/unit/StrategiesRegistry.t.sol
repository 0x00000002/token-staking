// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/reward-system/StrategiesRegistry.sol";
import "../../src/interfaces/reward/RewardErrors.sol";

error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

contract StrategiesRegistryTest is Test {
    StrategiesRegistry public registry;

    address public admin = address(0xA1);
    address public manager = address(0xB1);
    address public strategyAddress = address(0xD1);

    function setUp() public {
        registry = new StrategiesRegistry(admin, manager);
    }

    function test_RegisterAndGetStrategy() public {
        vm.startPrank(manager);
        uint256 strategyId = registry.registerStrategy(strategyAddress);
        assertEq(strategyId, 0);
        vm.stopPrank();

        assertEq(registry.getStrategyAddress(0), strategyAddress);
        assertTrue(registry.isStrategyRegistered(0));
    }

    function test_TC_SR01_DisableStrategy_Success() public {
        vm.startPrank(manager);
        registry.registerStrategy(strategyAddress);

        assertTrue(registry.isStrategyRegistered(0));

        registry.disableStrategy(0);

        assertFalse(registry.getStrategyStatus(0));
        assertEq(
            registry.getStrategyStatus(0),
            false,
            "Strategy should be disabled"
        );
        vm.stopPrank();
    }

    function test_DisableStrategy_Fail_NotRegistered() public {
        vm.startPrank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(RewardErrors.StrategyNotExist.selector, 0)
        );
        registry.disableStrategy(0);
        vm.stopPrank();
    }

    function test_TC_SR02_EnableStrategy_Success() public {
        vm.startPrank(manager);
        uint256 strategyId = registry.registerStrategy(strategyAddress); // Get the actual ID
        assertEq(strategyId, 0); // Ensure it's ID 0 for consistency

        // Initially, it should be enabled
        assertTrue(registry.getStrategyStatus(strategyId), "Strategy should be enabled initially");
        uint256[] memory activeStrategiesInitial = registry.getListOfActiveStrategies();
        assertEq(activeStrategiesInitial.length, 1, "Should have 1 active strategy initially");
        assertEq(activeStrategiesInitial[0], strategyId, "Initial active strategy ID mismatch");

        // Disable the strategy
        registry.disableStrategy(strategyId);
        assertFalse(registry.getStrategyStatus(strategyId), "Strategy should be disabled after disableCall");
        uint256[] memory activeStrategiesAfterDisable = registry.getListOfActiveStrategies();
        assertEq(activeStrategiesAfterDisable.length, 0, "Should have 0 active strategies after disable");

        // Enable the strategy
        registry.enableStrategy(strategyId);
        assertTrue(registry.getStrategyStatus(strategyId), "Strategy should be enabled after enableCall");
        uint256[] memory activeStrategiesAfterEnable = registry.getListOfActiveStrategies();
        assertEq(activeStrategiesAfterEnable.length, 1, "Should have 1 active strategy after enable");
        assertEq(activeStrategiesAfterEnable[0], strategyId, "Active strategy ID mismatch after enable");

        vm.stopPrank();

        // Original assertions (still valid)
        assertTrue(registry.isStrategyRegistered(strategyId), "Strategy should still be registered");
        assertEq(registry.getStrategyAddress(strategyId), strategyAddress, "Strategy address mismatch");
    }

    function test_RegisterStrategy_Fail_NotManager() public {
        vm.startPrank(admin); // Not manager
        bytes32 managerRole = registry.MANAGER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                admin,
                managerRole
            )
        );
        registry.registerStrategy(strategyAddress);
        vm.stopPrank();
    }
}
