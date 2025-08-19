// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/staking/IStakingStorage.sol";
import "../interfaces/reward/IRewardStrategy.sol";

import "./ClaimsJournal.sol";
import "./PoolManager.sol";
import "./FundingManager.sol";

import "../interfaces/reward/RewardErrors.sol";

/**
 * @title RewardManager
 * @author @Tudmotu & Gemini
 * @notice A stateless orchestrator for all reward claims, inheriting funding logic.
 * @dev This contract holds no state about users' claims. It reads from storage contracts,
 *      executes business logic from strategy contracts, and coordinates payments and state updates.
 */
contract RewardManager is
    FundingManager,
    Pausable,
    RewardErrors,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // --- Immutable contract dependencies ---
    IStakingStorage public immutable stakingStorage;
    ClaimsJournal public claimsJournal;
    PoolManager public immutable poolManager;

    event RewardClaimed(
        address indexed user,
        bytes32 stakeId,
        uint256 indexed poolId,
        uint256 indexed strategyId,
        uint256 rewardAmount,
        uint16 claimDay
    );

    constructor(
        address _admin,
        address _manager,
        IStakingStorage _stakingStorage,
        StrategiesRegistry _strategiesRegistry,
        ClaimsJournal _claimsJournal,
        PoolManager _poolManager
    ) FundingManager(_admin, _manager, _strategiesRegistry) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _manager);

        stakingStorage = _stakingStorage;
        claimsJournal = _claimsJournal;
        poolManager = _poolManager;
    }

    function setClaimsJournal(
        ClaimsJournal _newClaimsJournal
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimsJournal = _newClaimsJournal;
    }

    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    function batchClaimReward(
        bytes32[] calldata stakeIds,
        uint256[] calldata poolIds,
        uint256[] calldata strategyIds
    ) external {
        for (uint256 i = 0; i < stakeIds.length; i++) {
            claimReward(stakeIds[i], poolIds[i], strategyIds[i]);
        }
    }

    function batchCalculateReward(
        bytes32[] calldata stakeIds,
        uint256[] calldata poolIds,
        uint256[] calldata strategyIds
    ) external view returns (uint256[] memory) {
        uint256[] memory rewardAmounts = new uint256[](stakeIds.length);
        for (uint256 i = 0; i < stakeIds.length; i++) {
            rewardAmounts[i] = _calculateReward(
                _getStakerFromId(stakeIds[i]),
                stakeIds[i],
                poolIds[i],
                strategyIds[i]
            );
        }
        return rewardAmounts;
    }

    // ===================================================================
    //                      USER CLAIM FUNCTIONS
    // ===================================================================
    function claimReward(
        bytes32 stakeId,
        uint256 poolId,
        uint256 strategyId
    ) public nonReentrant whenNotPaused {
        // --- 1. Validation & Data Fetching ---
        (
            address staker,
            address strategyAddress,
            uint256 layerId
        ) = _validateAndGetData(stakeId, poolId, strategyId);

        // --- 2. Reward Calculation ---
        uint256 rewardAmount = _calculateReward(
            staker,
            stakeId,
            poolId,
            strategyId
        );
        require(rewardAmount > 0, RewardErrors.NoRewardToClaim());

        // --- 3. Payout ---
        _payout(staker, strategyId, strategyAddress, rewardAmount);

        // --- 4. Record Keeping ---
        _recordClaim(staker, poolId, strategyId, layerId, stakeId);

        // --- 5. Emit Event ---
        emit RewardClaimed(
            staker,
            stakeId,
            poolId,
            strategyId,
            rewardAmount,
            _getCurrentDay()
        );
    }

    function calculateReward(
        address staker,
        bytes32 stakeId,
        uint256 poolId,
        uint256 strategyId
    ) external view returns (uint256) {
        return _calculateReward(staker, stakeId, poolId, strategyId);
    }

    /**
     * @notice This function is to be called by FrontEnd UI (mostly),
     * in order to display list of Pool/stake pairs,
     * and against each pair, the rewards the user can claim.
     * Pools can have multiple layers, each layer can have multiple strategies.
     * Some strategies on the same layer can be exclusive to each other.
     * UI displays to the user a reward which can be claimed for each strategy.
     * In case of exclusive strategies, UI displays two or more rewards,
     * and when user clicks on the reward, FE disable other rewards,
     * that can not be claimed after user confirmed the selection.
     * Confirming selection will call `claimReward()` function for the
     * chosen strategy.
     *
     *  Use case example:
     *  For Pool 1 (cycle 1, 30 days) we have just 1 strategy:
     *  StandardRewardStrategy on layer 1:
     *  [1],
     *  [100], // amount of reward for pool
     *  [NORMAL]
     *
     *  For Pool 4 (90 days) we have just 2 strategies on layer 0:
     *  FullStaking and Whitelisted:
     *  [4,5],
     *  [100,100], // Even if the rewards is the same, the conditions could be different
     *  [NORMAL, EXCLUSIVE]
     *
     * @param stakeId The ID of the stake.
     * @param poolId The ID of the pool.
     * @param layerId The ID of the layer.
     * @return strategyIds An array of strategy IDs.
     * @return amounts An array of amounts for each strategy.
     * @return exclusivity An array of exclusivity for each strategy.
     */
    function calculateRewardsForPool(
        bytes32 stakeId,
        uint256 poolId,
        uint256 layerId
    )
        external
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            PoolManager.StrategyExclusivity[] memory
        )
    {
        (
            uint256[] memory _strategyIds,
            PoolManager.StrategyExclusivity[] memory _exclusivity
        ) = poolManager.getStrategiesFromLayer(poolId, layerId);
        uint256[] memory amounts = new uint256[](_strategyIds.length);

        address staker = _getStakerFromId(stakeId);

        for (uint256 i = 0; i < _strategyIds.length; ++i) {
            uint256 strategyId = _strategyIds[i];
            amounts[i] = _calculateReward(staker, stakeId, poolId, strategyId);
        }
        return (_strategyIds, amounts, _exclusivity);
    }

    // ===================================================================
    //                      Internal Functions
    // ===================================================================

    function _validateAndGetData(
        bytes32 stakeId,
        uint256 poolId,
        uint256 strategyId
    )
        internal
        view
        returns (address staker, address strategyAddress, uint256 layerId)
    {
        staker = _getStakerFromId(stakeId);
        require(
            staker == _msgSender(),
            RewardErrors.NotStakeOwner(_msgSender(), staker)
        );

        strategyAddress = strategiesRegistry.getStrategyAddress(strategyId);
        require(
            strategyAddress != address(0),
            RewardErrors.StrategyNotExist(strategyId)
        );

        layerId = poolManager.getStrategyLayer(poolId, strategyId);
        _validateExclusivity(staker, poolId, layerId, strategyId);

        // Strategy-dependent validation
        IRewardStrategy.StrategyType strategyType = IRewardStrategy(
            strategyAddress
        ).getStrategyType();

        if (strategyType == IRewardStrategy.StrategyType.POOL_SIZE_DEPENDENT) {
            require(
                poolManager.isPoolEnded(poolId),
                RewardErrors.PoolNotEnded(poolId)
            );
        } else {
            require(
                poolManager.hasStarted(poolId),
                RewardErrors.PoolNotStarted(poolId)
            );
        }
    }

    function _validateExclusivity(
        address staker,
        uint256 poolId,
        uint256 layerId,
        uint256 strategyId
    ) internal view {
        PoolManager.StrategyExclusivity strategyType = poolManager
            .getStrategyExclusivity(poolId, layerId, strategyId);
        ClaimsJournal.LayerClaimType layerClaimState = claimsJournal
            .getLayerClaimState(staker, poolId, layerId);

        if (strategyType == PoolManager.StrategyExclusivity.EXCLUSIVE) {
            require(
                layerClaimState == ClaimsJournal.LayerClaimType.NORMAL,
                RewardErrors.LayerAlreadyHasClaim(layerId, _getCurrentDay())
            );
        } else {
            require(
                layerClaimState != ClaimsJournal.LayerClaimType.EXCLUSIVE,
                RewardErrors.LayerAlreadyHasExclusiveClaim(
                    layerId,
                    _getCurrentDay()
                )
            );
            if (
                strategyType == PoolManager.StrategyExclusivity.SEMI_EXCLUSIVE
            ) {
                require(
                    layerClaimState !=
                        ClaimsJournal.LayerClaimType.SEMI_EXCLUSIVE,
                    RewardErrors.LayerAlreadyHasSemiExclusiveClaim(
                        layerId,
                        _getCurrentDay()
                    )
                );
            }
        }
    }

    function _calculateReward(
        address staker,
        bytes32 stakeId,
        uint256 poolId,
        uint256 strategyId
    ) internal view returns (uint256 rewardAmount) {
        address strategyAddress = strategiesRegistry.getStrategyAddress(
            strategyId
        );
        IRewardStrategy strategyContract = IRewardStrategy(strategyAddress);
        IRewardStrategy.StrategyType strategyType = strategyContract
            .getStrategyType();
        IStakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        PoolManager.Pool memory pool = poolManager.getPool(poolId);

        uint16 lastClaimDay = claimsJournal.getLastClaimDay(
            stakeId,
            poolId,
            strategyId
        );

        if (strategyType == IRewardStrategy.StrategyType.POOL_SIZE_DEPENDENT) {
            // CRITICAL: Prevent re-claiming a one-time reward.
            require(lastClaimDay == 0, RewardErrors.RewardAlreadyClaimed(0)); // TODO : for the stake/pool/strategy combination
            require(
                poolManager.isPoolCalculated(poolId),
                RewardErrors.PoolNotInitializedOrCalculated(poolId)
            );

            rewardAmount = strategyContract.calculateReward(
                staker,
                stake,
                pool.totalPoolWeight,
                rewardAssignedToPool[poolId][strategyId],
                pool.startDay,
                pool.endDay
            );
        } else if (
            strategyType == IRewardStrategy.StrategyType.POOL_SIZE_INDEPENDENT
        ) {
            // For this type, lastClaimDay is a checkpoint, not a blocker.
            rewardAmount = strategyContract.calculateReward(
                staker,
                stake,
                pool.startDay,
                pool.endDay,
                lastClaimDay
            );
        }
    }
    function _payout(
        address staker,
        uint256 strategyId,
        address strategyAddress,
        uint256 rewardAmount
    ) internal {
        _decreaseStrategyBalance(strategyId, rewardAmount);

        address rewardToken = IRewardStrategy(strategyAddress).getRewardToken();
        IERC20(rewardToken).safeTransfer(staker, rewardAmount);
    }

    function _recordClaim(
        address staker,
        uint256 poolId,
        uint256 strategyId,
        uint256 layerId,
        bytes32 stakeId
    ) internal {
        PoolManager.StrategyExclusivity strategyType = poolManager
            .getStrategyExclusivity(poolId, layerId, strategyId);

        ClaimsJournal.LayerClaimType claimType;
        if (strategyType == PoolManager.StrategyExclusivity.NORMAL) {
            claimType = ClaimsJournal.LayerClaimType.NORMAL;
        } else if (
            strategyType == PoolManager.StrategyExclusivity.SEMI_EXCLUSIVE
        ) {
            claimType = ClaimsJournal.LayerClaimType.SEMI_EXCLUSIVE;
        } else {
            claimType = ClaimsJournal.LayerClaimType.EXCLUSIVE;
        }

        claimsJournal.recordClaim(
            staker,
            poolId,
            layerId,
            strategyId,
            stakeId,
            claimType,
            _getCurrentDay()
        );
    }

    function _getStakerFromId(bytes32 stakeId) internal pure returns (address) {
        return address(uint160(uint256(stakeId) >> 96));
    }

    function _getCurrentDay() internal view returns (uint16) {
        return uint16(block.timestamp / 1 days);
    }
}
