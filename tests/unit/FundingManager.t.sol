// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../../src/reward-system/FundingManager.sol";
import "../../src/reward-system/StrategiesRegistry.sol";
import "../helpers/MockERC20.sol";
import "../../src/interfaces/reward/IRewardStrategy.sol";
import "../../src/interfaces/staking/IStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../src/interfaces/reward/RewardErrors.sol";

error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

// Mock IRewardStrategy for testing FundingManager
contract MockRewardStrategy is IRewardStrategy {
    address public rewardToken;
    uint8 public rewardLayer;
    IRewardStrategy.StrategyType public strategyType;

    constructor(
        address _rewardToken,
        uint8 _rewardLayer,
        IRewardStrategy.StrategyType _strategyType
    ) {
        rewardToken = _rewardToken;
        rewardLayer = _rewardLayer;
        strategyType = _strategyType;
    }

    function getName() external pure returns (string memory) {
        return "MockStrategy";
    }
    function getRewardToken() external view returns (address) {
        return rewardToken;
    }
    function getRewardLayer() external view returns (uint8) {
        return rewardLayer;
    }
    function getStrategyType() external view returns (StrategyType) {
        return strategyType;
    }

    function calculateReward(
        address user,
        IStakingStorage.Stake calldata stake,
        uint16 poolStartDay,
        uint16 poolEndDay,
        uint16 lastClaimDay
    ) external view returns (uint256) {
        revert("Not implemented");
    }

    function calculateReward(
        address user,
        IStakingStorage.Stake calldata stake,
        uint256 totalPoolWeight,
        uint256 totalRewardAmount,
        uint16 poolStartDay,
        uint16 poolEndDay
    ) external view returns (uint256) {
        revert("Not implemented");
    }
}

contract FundingManagerTest is Test {
    FundingManager fundingManager;
    StrategiesRegistry strategiesRegistry;
    MockERC20 rewardToken;
    MockRewardStrategy mockStrategy1;
    MockRewardStrategy mockStrategy2;

    address admin = makeAddr("admin");
    address manager = makeAddr("manager");
    address user = makeAddr("user");

    uint32 constant STRATEGY_ID_1 = 1;
    uint32 constant STRATEGY_ID_2 = 2;

    function setUp() public {
        vm.prank(admin);
        strategiesRegistry = new StrategiesRegistry(admin, manager);

        rewardToken = new MockERC20("Reward Token", "RWD");

        mockStrategy1 = new MockRewardStrategy(
            address(rewardToken),
            0,
            IRewardStrategy.StrategyType.POOL_SIZE_INDEPENDENT
        );
        mockStrategy2 = new MockRewardStrategy(
            address(rewardToken),
            1,
            IRewardStrategy.StrategyType.POOL_SIZE_DEPENDENT
        );

        vm.prank(admin);
        fundingManager = new FundingManager(admin, manager, strategiesRegistry);

        vm.startPrank(manager);
        strategiesRegistry.registerStrategy(address(mockStrategy1));
        strategiesRegistry.registerStrategy(address(mockStrategy2));

        // Mint some tokens to the manager for funding
        rewardToken.mint(manager, 1_000_000 ether);
        vm.stopPrank();
    }

    function test_FundStrategy_Success() public {
        uint256 amount = 100 ether;
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), amount);
        fundingManager.fundStrategy(STRATEGY_ID_1, amount);
        vm.stopPrank();

        assertEq(
            fundingManager.strategyBalances(STRATEGY_ID_1),
            amount,
            "Strategy balance mismatch"
        );
        assertEq(
            rewardToken.balanceOf(address(fundingManager)),
            amount,
            "FundingManager token balance mismatch"
        );
    }

    function test_FundStrategy_Fail_NotManager() public {
        uint256 amount = 100 ether;
        vm.startPrank(user);
        rewardToken.approve(address(fundingManager), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                keccak256("MANAGER_ROLE")
            )
        );
        fundingManager.fundStrategy(STRATEGY_ID_1, amount);
        vm.stopPrank();
    }

    function test_WithdrawStrategy_Success() public {
        uint256 fundAmount = 100 ether;
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount);
        vm.stopPrank();

        uint256 withdrawAmount = 50 ether;
        vm.startPrank(manager);
        fundingManager.withdrawStrategy(STRATEGY_ID_1, withdrawAmount);
        vm.stopPrank();
        assertEq(
            fundingManager.strategyBalances(STRATEGY_ID_1),
            fundAmount - withdrawAmount,
            "Strategy balance after withdraw mismatch"
        );
    }

    function test_WithdrawStrategy_Fail_InsufficientBalance() public {
        uint256 fundAmount = 100 ether;

        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount);
        vm.stopPrank();
        uint256 withdrawAmount = 200 ether;
        vm.prank(manager);
        vm.expectRevert(RewardErrors.InsufficientStrategyBalance.selector);
        fundingManager.withdrawStrategy(STRATEGY_ID_1, withdrawAmount);
    }

    function test_WithdrawStrategy_Fail_NotManager() public {
        uint256 fundAmount = 100 ether;
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount);
        vm.stopPrank();

        uint256 withdrawAmount = 50 ether;
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                keccak256("MANAGER_ROLE")
            )
        );
        fundingManager.withdrawStrategy(STRATEGY_ID_1, withdrawAmount);
        vm.stopPrank();
    }

    function test_TransferStrategyBalance_Success() public {
        uint256 fundAmount1 = 100 ether;
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount1);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount1);
        vm.stopPrank();

        uint256 transferAmount = 50 ether;
        vm.startPrank(manager);
        fundingManager.transferStrategyBalance(
            STRATEGY_ID_1,
            STRATEGY_ID_2,
            transferAmount
        );

        assertEq(
            fundingManager.strategyBalances(STRATEGY_ID_1),
            fundAmount1 - transferAmount,
            "Source strategy balance mismatch"
        );
        assertEq(
            fundingManager.strategyBalances(STRATEGY_ID_2),
            transferAmount,
            "Destination strategy balance mismatch"
        );
    }

    function test_TransferStrategyBalance_Fail_InsufficientBalance() public {
        uint256 fundAmount1 = 10 ether;
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount1);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount1);
        vm.stopPrank();

        uint256 transferAmount = 50 ether;
        vm.prank(manager);
        vm.expectRevert(RewardErrors.InsufficientStrategyBalance.selector);
        fundingManager.transferStrategyBalance(
            STRATEGY_ID_1,
            STRATEGY_ID_2,
            transferAmount
        );
    }

    function test_TransferStrategyBalance_Fail_NotManager() public {
        uint256 fundAmount1 = 100 ether;
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount1);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount1);
        vm.stopPrank();

        uint256 transferAmount = 50 ether;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user,
                keccak256("MANAGER_ROLE")
            )
        );
        fundingManager.transferStrategyBalance(
            STRATEGY_ID_1,
            STRATEGY_ID_2,
            transferAmount
        );
    }

    function test_FundStrategy_Fail_StrategyNotExist() public {
        uint256 amount = 100 ether;
        uint256 nonExistentStrategyId = 999; // Assuming 999 does not exist

        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), amount);
        vm.expectRevert(abi.encodeWithSelector(RewardErrors.StrategyNotExist.selector, nonExistentStrategyId));
        fundingManager.fundStrategy(nonExistentStrategyId, amount);
        vm.stopPrank();
    }

    function test_FundStrategy_Fail_AmountMustBeGreaterThanZero() public {
        uint256 amount = 0; // Zero amount

        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), amount); // Approve 0 is fine
        vm.expectRevert(RewardErrors.AmountMustBeGreaterThanZero.selector);
        fundingManager.fundStrategy(STRATEGY_ID_1, amount);
        vm.stopPrank();
    }

    function test_AssignRewardToPool_Success() public {
        uint256 fundAmount = 100 ether;
        uint256 poolId = 1;
        uint256 assignAmount = 50 ether;

        // Fund the strategy first
        vm.startPrank(manager);
        rewardToken.approve(address(fundingManager), fundAmount);
        fundingManager.fundStrategy(STRATEGY_ID_1, fundAmount);
        vm.stopPrank();

        // Assign rewards to a pool
        vm.prank(manager);
        fundingManager.assignRewardToPool(poolId, STRATEGY_ID_1, assignAmount);

        // Assert that the mapping is updated
        assertEq(fundingManager.rewardAssignedToPool(poolId, STRATEGY_ID_1), assignAmount, "Reward assigned to pool mismatch");
    }
}
