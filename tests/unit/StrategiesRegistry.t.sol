// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {StrategiesRegistry} from "../../src/reward-system/StrategiesRegistry.sol";
import {LinearAPRStrategy} from "../../src/reward-system/strategies/LinearAPRStrategy.sol";
import {EpochPoolStrategy} from "../../src/reward-system/strategies/EpochPoolStrategy.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {RewardErrors} from "../../src/interfaces/reward/RewardErrors.sol";
import {StrategyType, EpochState} from "../../src/interfaces/reward/RewardEnums.sol";
import {IBaseRewardStrategy} from "../../src/interfaces/reward/IBaseRewardStrategy.sol";

contract StrategiesRegistryTest is Test {
    StrategiesRegistry public registry;
    StakingStorage public stakingStorage;
    LinearAPRStrategy public linearStrategy;
    EpochPoolStrategy public epochStrategy;
    MockERC20 public token;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public unauthorized = address(0x3);

    event StrategyRegistered(
        uint256 indexed strategyId,
        address indexed strategyAddress,
        StrategyType strategyType
    );

    event StrategyStatusChanged(
        uint256 indexed strategyId,
        bool isActive
    );

    event StrategyVersionUpdated(
        uint256 indexed strategyId,
        uint16 newVersion
    );

    function setUp() public {
        token = new MockERC20("Test Token", "TEST");
        stakingStorage = new StakingStorage(admin, manager, address(0));
        registry = new StrategiesRegistry(admin);

        // Create strategy instances
        IBaseRewardStrategy.StrategyParameters memory params = IBaseRewardStrategy.StrategyParameters({
            name: "Test Linear Strategy",
            description: "Test strategy for linear rewards",
            startDay: 1,
            endDay: 365,
            strategyType: StrategyType.IMMEDIATE
        });

        linearStrategy = new LinearAPRStrategy(
            params,
            manager,
            1000, // 10% APR
            stakingStorage
        );

        IBaseRewardStrategy.StrategyParameters memory epochParams = IBaseRewardStrategy.StrategyParameters({
            name: "Test Epoch Strategy",
            description: "Test strategy for epoch rewards",
            startDay: 1,
            endDay: 365,
            strategyType: StrategyType.EPOCH_BASED
        });

        epochStrategy = new EpochPoolStrategy(
            epochParams,
            manager,
            30, // 30 day epochs
            stakingStorage
        );
    }

    // ============================================================================
    // TC_R01: Strategy Registration (UC21)
    // ============================================================================

    function test_TCR01_SuccessfullyRegisterNewRewardStrategy() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, false, true);
        emit StrategyRegistered(1, address(linearStrategy), StrategyType.IMMEDIATE);

        uint256 strategyId = registry.registerStrategy(address(linearStrategy));

        // Strategy should be registered with new strategyId
        assertEq(strategyId, 1);

        // Strategy should be inactive by default
        StrategiesRegistry.RegistryEntry memory entry = registry.getStrategy(strategyId);
        assertEq(entry.strategyAddress, address(linearStrategy));
        assertEq(uint8(entry.strategyType), uint8(StrategyType.IMMEDIATE));
        assertFalse(entry.isActive);
        assertEq(entry.version, 1);

        // Strategy should be queryable by ID
        assertTrue(entry.strategyAddress != address(0));

        vm.stopPrank();
    }

    function test_TCR01_RegisterStrategyWithInvalidAddress() public {
        vm.startPrank(admin);

        // Register strategy with invalid address
        vm.expectRevert();
        registry.registerStrategy(address(0));

        vm.stopPrank();
    }

    function test_TCR01_UnauthorizedStrategyRegistration() public {
        vm.startPrank(unauthorized);

        vm.expectRevert(); // AccessControl error
        registry.registerStrategy(address(linearStrategy));

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R02: Strategy Status Management (UC21)
    // ============================================================================

    function test_TCR02_ActivateRegisteredStrategy() public {
        vm.startPrank(admin);

        // Register strategy first
        uint256 strategyId = registry.registerStrategy(address(linearStrategy));

        vm.expectEmit(true, false, false, true);
        emit StrategyStatusChanged(strategyId, true);

        // Activate strategy
        registry.setStrategyStatus(strategyId, true);

        // Strategy should be marked as active
        StrategiesRegistry.RegistryEntry memory entry = registry.getStrategy(strategyId);
        assertTrue(entry.isActive);

        // Strategy should appear in active strategies list
        uint256[] memory activeStrategies = registry.getActiveStrategies();
        assertEq(activeStrategies.length, 1);
        assertEq(activeStrategies[0], strategyId);

        vm.stopPrank();
    }

    function test_TCR02_DeactivateActiveStrategy() public {
        vm.startPrank(admin);

        // Register and activate strategy
        uint256 strategyId = registry.registerStrategy(address(linearStrategy));
        registry.setStrategyStatus(strategyId, true);

        vm.expectEmit(true, false, false, true);
        emit StrategyStatusChanged(strategyId, false);

        // Deactivate strategy
        registry.setStrategyStatus(strategyId, false);

        // Strategy should be marked as inactive
        StrategiesRegistry.RegistryEntry memory entry = registry.getStrategy(strategyId);
        assertFalse(entry.isActive);

        // Strategy should be removed from active list
        uint256[] memory activeStrategies = registry.getActiveStrategies();
        assertEq(activeStrategies.length, 0);

        vm.stopPrank();
    }

    function test_TCR02_UnauthorizedStrategyStatusChange() public {
        vm.startPrank(admin);
        uint256 strategyId = registry.registerStrategy(address(linearStrategy));
        vm.stopPrank();

        vm.startPrank(unauthorized);

        vm.expectRevert(); // AccessControl error
        registry.setStrategyStatus(strategyId, true);

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R03: Strategy Versioning (UC21)
    // ============================================================================

    function test_TCR03_UpdateStrategyVersion() public {
        vm.startPrank(admin);

        // Register strategy
        uint256 strategyId = registry.registerStrategy(address(linearStrategy));

        vm.expectEmit(true, false, false, true);
        emit StrategyVersionUpdated(strategyId, 2);

        // Update strategy version
        registry.updateStrategyVersion(strategyId);

        // Strategy version should be incremented
        StrategiesRegistry.RegistryEntry memory entry = registry.getStrategy(strategyId);
        assertEq(entry.version, 2);

        // Update again
        registry.updateStrategyVersion(strategyId);
        entry = registry.getStrategy(strategyId);
        assertEq(entry.version, 3);

        vm.stopPrank();
    }

    function test_TCR03_UpdateVersionOfNonExistentStrategy() public {
        vm.startPrank(admin);

        // Update version of non-existent strategy
        vm.expectRevert(
            abi.encodeWithSelector(RewardErrors.StrategyNotFound.selector, 999)
        );
        registry.updateStrategyVersion(999);

        vm.stopPrank();
    }

    function test_TCR03_UnauthorizedVersionUpdate() public {
        vm.startPrank(admin);
        uint256 strategyId = registry.registerStrategy(address(linearStrategy));
        vm.stopPrank();

        vm.startPrank(unauthorized);

        vm.expectRevert(); // AccessControl error
        registry.updateStrategyVersion(strategyId);

        vm.stopPrank();
    }

    // ============================================================================
    // Additional Registry Functionality Tests
    // ============================================================================

    function test_MultipleStrategyRegistration() public {
        vm.startPrank(admin);

        // Register multiple strategies
        uint256 linearId = registry.registerStrategy(address(linearStrategy));
        uint256 epochId = registry.registerStrategy(address(epochStrategy));

        assertEq(linearId, 1);
        assertEq(epochId, 2);

        // Verify both strategies are registered correctly
        StrategiesRegistry.RegistryEntry memory linearEntry = registry.getStrategy(linearId);
        StrategiesRegistry.RegistryEntry memory epochEntry = registry.getStrategy(epochId);

        assertEq(linearEntry.strategyAddress, address(linearStrategy));
        assertEq(uint8(linearEntry.strategyType), uint8(StrategyType.IMMEDIATE));

        assertEq(epochEntry.strategyAddress, address(epochStrategy));
        assertEq(uint8(epochEntry.strategyType), uint8(StrategyType.EPOCH_BASED));

        vm.stopPrank();
    }

    function test_GetNonExistentStrategy() public {
        vm.expectRevert(
            abi.encodeWithSelector(RewardErrors.StrategyNotFound.selector, 999)
        );
        registry.getStrategy(999);
    }

    function test_ActiveStrategiesManagement() public {
        vm.startPrank(admin);

        // Register multiple strategies
        uint256 linearId = registry.registerStrategy(address(linearStrategy));
        uint256 epochId = registry.registerStrategy(address(epochStrategy));

        // Initially no active strategies
        uint256[] memory activeStrategies = registry.getActiveStrategies();
        assertEq(activeStrategies.length, 0);

        // Activate first strategy
        registry.setStrategyStatus(linearId, true);
        activeStrategies = registry.getActiveStrategies();
        assertEq(activeStrategies.length, 1);
        assertEq(activeStrategies[0], linearId);

        // Activate second strategy
        registry.setStrategyStatus(epochId, true);
        activeStrategies = registry.getActiveStrategies();
        assertEq(activeStrategies.length, 2);

        // Deactivate first strategy
        registry.setStrategyStatus(linearId, false);
        activeStrategies = registry.getActiveStrategies();
        assertEq(activeStrategies.length, 1);
        assertEq(activeStrategies[0], epochId);

        vm.stopPrank();
    }
}