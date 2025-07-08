// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./StrategiesRegistry.sol";
import "./GrantedRewardStorage.sol";
import "./EpochManager.sol";
import "../interfaces/staking/IStakingStorage.sol";
import "../interfaces/reward/RewardErrors.sol";
import "../interfaces/reward/RewardEnums.sol";
import "../interfaces/reward/IImmediateRewardStrategy.sol";
import "../interfaces/reward/IEpochRewardStrategy.sol";

contract RewardManager is
    AccessControl,
    ReentrancyGuard,
    Pausable,
    RewardErrors
{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant MAX_BATCH_SIZE = 100;

    StrategiesRegistry public immutable strategyRegistry;
    GrantedRewardStorage public immutable grantedRewardStorage;
    EpochManager public immutable epochManager;
    IStakingStorage public immutable stakingStorage;
    IERC20 public immutable rewardToken;

    constructor(
        address admin,
        address _strategyRegistry,
        address _grantedRewardStorage,
        address _epochManager,
        address _stakingStorage,
        address _rewardToken
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        strategyRegistry = StrategiesRegistry(_strategyRegistry);
        grantedRewardStorage = GrantedRewardStorage(_grantedRewardStorage);
        epochManager = EpochManager(_epochManager);
        stakingStorage = IStakingStorage(_stakingStorage);
        rewardToken = IERC20(_rewardToken);
    }

    function calculateImmediateRewards(
        uint256 strategyId,
        uint32 fromDay,
        uint32 toDay,
        uint256 batchStart,
        uint256 batchSize
    ) external onlyRole(ADMIN_ROLE) {
        require(batchSize <= MAX_BATCH_SIZE, BatchSizeExceeded(batchSize));

        StrategiesRegistry.RegistryEntry memory strategyEntry = strategyRegistry
            .getStrategy(strategyId);
        require(
            strategyEntry.strategyAddress != address(0),
            StrategyNotFound(strategyId)
        );
        require(
            strategyEntry.strategyType == StrategyType.IMMEDIATE,
            InvalidStrategyType(strategyId)
        );

        IImmediateRewardStrategy strategy = IImmediateRewardStrategy(
            strategyEntry.strategyAddress
        );
        uint16 strategyVersion = strategyEntry.version;

        address[] memory stakers = stakingStorage.getStakersPaginated(
            batchStart,
            batchSize
        );

        for (uint256 i = 0; i < stakers.length; i++) {
            _processImmediateRewardsForStaker(
                stakers[i],
                strategy,
                strategyId,
                strategyVersion,
                fromDay,
                toDay
            );
        }
    }

    function _processImmediateRewardsForStaker(
        address staker,
        IImmediateRewardStrategy strategy,
        uint256 strategyId,
        uint16 strategyVersion,
        uint32 fromDay,
        uint32 toDay
    ) internal {
        bytes32[] memory stakeIds = stakingStorage.getStakerStakeIds(staker);

        for (uint256 j = 0; j < stakeIds.length; j++) {
            bytes32 stakeId = stakeIds[j];
            if (strategy.isApplicable(stakeId)) {
                uint256 reward = strategy.calculateHistoricalReward(
                    stakeId,
                    fromDay,
                    toDay
                );
                if (reward > 0)
                    grantedRewardStorage.grantReward(
                        staker,
                        strategyId,
                        strategyVersion,
                        reward,
                        0
                    );
            }
        }
    }

    function calculateEpochRewards(
        uint32 epochId,
        uint256 batchStart,
        uint256 batchSize
    ) external onlyRole(ADMIN_ROLE) {
        require(batchSize <= MAX_BATCH_SIZE, BatchSizeExceeded(batchSize));

        EpochManager.Epoch memory epoch = epochManager.getEpoch(epochId);
        require(
            epoch.state == EpochState.CALCULATED,
            EpochNotCalculated(epochId)
        );
        require(epoch.actualPoolSize > 0, EpochPoolSizeNotSet(epochId));

        StrategiesRegistry.RegistryEntry memory strategyEntry = strategyRegistry
            .getStrategy(epoch.strategyId);
        require(
            strategyEntry.strategyAddress != address(0),
            StrategyNotFound(epoch.strategyId)
        );
        require(
            strategyEntry.strategyType == StrategyType.EPOCH_BASED,
            InvalidStrategyType(epoch.strategyId)
        );

        address[] memory stakers = stakingStorage.getStakersPaginated(
            batchStart,
            batchSize
        );

        for (uint256 i = 0; i < stakers.length; i++) {
            _processEpochRewardsForStaker(stakers[i], epoch, strategyEntry);
        }
    }

    function _processEpochRewardsForStaker(
        address staker,
        EpochManager.Epoch memory epoch,
        StrategiesRegistry.RegistryEntry memory strategyEntry
    ) internal {
        uint256 userStakeWeight = calculateUserEpochWeight(
            staker,
            epoch.startDay,
            epoch.endDay
        );

        if (userStakeWeight > 0) {
            IEpochRewardStrategy strategy = IEpochRewardStrategy(
                strategyEntry.strategyAddress
            );
            uint256 totalEpochWeight = epoch.totalStakeWeight;

            uint256 reward = strategy.calculateEpochReward(
                epoch.epochId,
                userStakeWeight,
                totalEpochWeight,
                epoch.actualPoolSize
            );
            if (reward > 0) {
                grantedRewardStorage.grantReward(
                    staker,
                    epoch.strategyId,
                    strategyEntry.version,
                    reward,
                    epoch.epochId
                );
            }
        }
    }

    function claimAllRewards() external nonReentrant returns (uint256) {
        (, uint256[] memory indices) = grantedRewardStorage
            .getUserClaimableRewards(msg.sender);
        require(indices.length > 0, NoRewardsToClaim(msg.sender));
        return _claimRewards(indices);
    }

    function claimSpecificRewards(
        uint256[] calldata rewardIndices
    ) external nonReentrant returns (uint256) {
        require(rewardIndices.length > 0, NoRewardsToClaim(msg.sender));
        return _claimRewards(rewardIndices);
    }

    function claimEpochRewards(
        uint32 epochId
    ) external nonReentrant returns (uint256) {
        (
            GrantedRewardStorage.GrantedReward[] memory allClaimableRewards,
            uint256[] memory allClaimableIndices
        ) = grantedRewardStorage.getUserClaimableRewards(msg.sender);

        uint256 epochRewardCount = 0;
        for (uint256 i = 0; i < allClaimableRewards.length; i++) {
            if (allClaimableRewards[i].epochId == epochId) epochRewardCount++;
        }

        require(epochRewardCount > 0, NoClaimableRewardsForEpoch(epochId));

        uint256[] memory epochRewardIndices = new uint256[](epochRewardCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < allClaimableRewards.length; i++) {
            if (allClaimableRewards[i].epochId == epochId) {
                epochRewardIndices[counter] = allClaimableIndices[i];
                counter++;
            }
        }

        return _claimRewards(epochRewardIndices);
    }

    function getClaimableRewards(address user) external view returns (uint256) {
        return grantedRewardStorage.getUserClaimableAmount(user);
    }

    function getUserRewardSummary(
        address user
    )
        external
        view
        returns (
            uint256 totalGranted,
            uint256 totalClaimed,
            uint256 totalClaimable
        )
    {
        GrantedRewardStorage.GrantedReward[]
            memory userRewards = grantedRewardStorage.getUserRewards(user);

        for (uint256 i = 0; i < userRewards.length; i++) {
            uint128 amount = userRewards[i].amount;
            totalGranted += amount;
            if (userRewards[i].claimed) totalClaimed += amount;
        }
        totalClaimable = totalGranted - totalClaimed;
    }

    function addRewardFunds(uint256 amount) external {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function emergencyResume() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _claimRewards(
        uint256[] memory rewardIndices
    ) internal returns (uint256) {
        uint256 totalAmount = 0;
        GrantedRewardStorage.GrantedReward[]
            memory userRewards = grantedRewardStorage.getUserRewards(
                msg.sender
            );

        for (uint256 i = 0; i < rewardIndices.length; i++) {
            uint256 index = rewardIndices[i];
            require(index < userRewards.length, InvalidRewardIndex(index));
            GrantedRewardStorage.GrantedReward memory reward = userRewards[
                index
            ];
            require(!reward.claimed, RewardAlreadyClaimed(index));
            totalAmount += reward.amount;
        }

        require(totalAmount > 0, NoRewardsToClaim(msg.sender));

        grantedRewardStorage.batchMarkClaimed(msg.sender, rewardIndices);
        rewardToken.safeTransfer(msg.sender, totalAmount);

        grantedRewardStorage.updateNextClaimableIndex(msg.sender);

        return totalAmount;
    }

    /**
     * @notice Calculate user's total stake weight during an epoch period
     * @param user The user address
     * @param epochStartDay Epoch start day
     * @param epochEndDay Epoch end day
     * @return totalWeight User's total weight (amount × days staked during epoch)
     */
    function calculateUserEpochWeight(
        address user,
        uint32 epochStartDay,
        uint32 epochEndDay
    ) public view returns (uint256) {
        uint256 totalWeight = 0;
        bytes32[] memory stakeIds = stakingStorage.getStakerStakeIds(user);

        for (uint256 i = 0; i < stakeIds.length; i++) {
            IStakingStorage.Stake memory stake = stakingStorage.getStake(
                stakeIds[i]
            );

            // Check if stake overlaps with epoch period
            if (
                stake.stakeDay <= epochEndDay &&
                (stake.unstakeDay == 0 || stake.unstakeDay >= epochStartDay)
            ) {
                uint32 effectiveStart = stake.stakeDay > epochStartDay
                    ? stake.stakeDay
                    : epochStartDay;
                uint32 effectiveEnd = (stake.unstakeDay == 0 ||
                    stake.unstakeDay > epochEndDay)
                    ? epochEndDay
                    : stake.unstakeDay;

                if (effectiveEnd > effectiveStart) {
                    uint256 effectiveDays = effectiveEnd - effectiveStart;
                    totalWeight += stake.amount * effectiveDays;
                }
            }
        }

        return totalWeight;
    }

    /**
     * @notice Get the effective period a stake was active within a time range
     * @param stakeId The stake identifier
     * @param fromDay Start day of the period
     * @param toDay End day of the period
     * @return effectiveStart The effective start day
     * @return effectiveEnd The effective end day
     */
    function getStakeEffectivePeriod(
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    ) public view returns (uint32 effectiveStart, uint32 effectiveEnd) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        effectiveStart = stake.stakeDay > fromDay ? stake.stakeDay : fromDay;
        effectiveEnd = stake.unstakeDay > 0 && stake.unstakeDay < toDay
            ? stake.unstakeDay
            : toDay;
    }
}
