// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PoolManager is AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    enum StrategyExclusivity {
        NORMAL, // can be combined with any other
        EXCLUSIVE, // excludes all other on the layer
        SEMI_EXCLUSIVE // excludes only other SEMI_EXCLUSIVE and EXCLUSIVE
    }

    struct Pool {
        bool hasAnnounced; // if false it is possible to setup pools in the past
        bool toSkipInUI;
        uint16 startDay;
        uint16 endDay;
        uint256 totalPoolWeight;
        uint256 parentPoolId;
    }

    uint256 public nextPoolId;

    mapping(uint256 poolId => Pool) public pools;
    // poolLiveWeight is used to calculate the preliminary rewards for the pool
    mapping(uint256 poolId => uint256) public poolLiveWeight;
    mapping(uint256 poolId => EnumerableSet.UintSet) internal _poolLayers;
    mapping(uint256 poolId => EnumerableSet.UintSet) internal _poolStrategies;
    mapping(uint256 poolId => mapping(uint256 layer => EnumerableSet.UintSet))
        internal _poolLayerStrategies;
    mapping(uint256 poolId => mapping(uint256 layer => mapping(uint256 strategyId => StrategyExclusivity)))
        public exclusivity;

    mapping(uint256 poolId => mapping(uint256 layer => EnumerableSet.UintSet))
        private _ignoredStrategies; // ignored strategies for UI

    // Cache for quick search of strategy layer
    mapping(uint256 poolId => mapping(uint256 strategyId => uint256))
        public strategyLayer;

    mapping(uint256 poolId => mapping(uint256 layer => bool))
        public hasExclusiveStrategies;

    event PoolUpserted(
        uint256 indexed poolId,
        uint16 startDay,
        uint16 endDay,
        uint256 totalPoolWeight,
        uint256 indexed parentPoolId
    );
    event StrategyAddedToLayer(
        uint256 poolId,
        uint256 layer,
        uint256 strategyId
    );
    event AnnouncePool(uint256 indexed poolId, uint16 startDay, uint16 endDay);
    event StrategyRemovedFromLayer(
        uint256 indexed poolId,
        uint256 layer,
        uint256 strategyId
    );

    error PoolNotEnded();
    error PoolAlreadyCalculated();
    error InvalidDates();
    error ParentPoolIsSelf();
    error PoolDoesNotExist(uint256 poolId);
    error PoolAlreadyAnnounced();

    constructor(address admin, address manager, address controller) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, manager);
        _grantRole(CONTROLLER_ROLE, controller);
        nextPoolId = 1;
    }

    /** ------------------------------------------------
     *  ! Pool Management
     * ------------------------------------------------ */

    function upsertPool(
        uint256 _poolId, // 0 for new pool
        uint16 _startDay,
        uint16 _endDay,
        uint256 _parentPoolId
    ) external onlyRole(MANAGER_ROLE) returns (uint256 poolId) {
        require(!_hasAnnounced(_poolId), PoolAlreadyAnnounced()); // never revert for new pools as poolIds start from 1

        if (_poolId == 0) {
            poolId = nextPoolId;
            nextPoolId++;
        } else {
            poolId = _poolId;
            require(
                pools[poolId].startDay > 0 || pools[poolId].endDay > 0,
                PoolDoesNotExist(poolId)
            );
        }

        require(_parentPoolId != poolId, ParentPoolIsSelf());
        require(_startDay < _endDay, InvalidDates());

        Pool storage p = pools[poolId];
        p.startDay = _startDay;
        p.endDay = _endDay;
        p.parentPoolId = _parentPoolId;

        emit PoolUpserted(poolId, p.startDay, p.endDay, 0, p.parentPoolId);
    }

    function announcePool(uint256 poolId) external onlyRole(MANAGER_ROLE) {
        pools[poolId].hasAnnounced = true;
        emit AnnouncePool(poolId, pools[poolId].startDay, pools[poolId].endDay);
    }

    function setPoolTotalStakeWeight(
        uint256 poolId,
        uint256 totalPoolWeight
    ) external onlyRole(CONTROLLER_ROLE) {
        require(_hasEnded(poolId), PoolNotEnded());
        require(!_isCalculated(poolId), PoolAlreadyCalculated());

        Pool storage p = pools[poolId];

        p.totalPoolWeight = totalPoolWeight;
        emit PoolUpserted(
            poolId,
            p.startDay,
            p.endDay,
            p.totalPoolWeight,
            p.parentPoolId
        );
    }

    function setPoolLiveWeight(
        uint256 poolId,
        uint256 liveWeight
    ) external onlyRole(CONTROLLER_ROLE) {
        poolLiveWeight[poolId] = liveWeight;
    }

    /**
     * Assigns a strategy to a pool layer.
     * @notice The strategy can be assigned even to an active or calculated pool, retroactively
     * @param poolId The ID of the pool to assign the strategy to.
     * @param layer The layer to assign the strategy to.
     * @param strategyId The ID of the strategy to assign.
     * @param strategyExclusivity The exclusivity of the strategy.
     */
    function assignStrategyToPool(
        uint256 poolId,
        uint256 layer,
        uint256 strategyId,
        StrategyExclusivity strategyExclusivity
    ) external onlyRole(MANAGER_ROLE) {
        _poolLayers[poolId].add(layer);
        _poolLayerStrategies[poolId][layer].add(strategyId);
        exclusivity[poolId][layer][strategyId] = strategyExclusivity;
        strategyLayer[poolId][strategyId] = layer;
        _poolStrategies[poolId].add(strategyId);
    }

    function removeLayer(
        uint256 poolId,
        uint8 layer
    ) external onlyRole(MANAGER_ROLE) {
        if (_hasAnnounced(poolId)) revert PoolAlreadyAnnounced();
        _poolLayers[poolId].remove(layer);
    }

    // We are not allowing to alter announced pools,
    // but we can mark those strategies which are not in use by UI.
    // The same time, since we can't alter them, we can guarantee
    // that users will always be able to claim their rewards (e.g. via Etherscan's UI).

    function markStrategyAsIgnored(
        uint256 poolId,
        uint256 layer,
        uint256 strategyId
    ) external onlyRole(MANAGER_ROLE) {
        _ignoredStrategies[poolId][layer].add(strategyId);
    }

    function unmarkStrategyAsIgnored(
        uint256 poolId,
        uint256 layer,
        uint256 strategyId
    ) external onlyRole(MANAGER_ROLE) {
        _ignoredStrategies[poolId][layer].remove(strategyId);
    }

    function removeStrategyFromPool(
        uint256 poolId,
        uint256 layer,
        uint256 strategyId
    ) external onlyRole(MANAGER_ROLE) {
        if (_hasAnnounced(poolId)) revert PoolAlreadyAnnounced();

        delete strategyLayer[poolId][strategyId];
        delete exclusivity[poolId][layer][strategyId];
        _poolStrategies[poolId].remove(strategyId);
        _poolLayerStrategies[poolId][layer].remove(strategyId);
        emit StrategyRemovedFromLayer(poolId, layer, strategyId);
    }

    /** ------------------------------------------------
     *  ! Getters
     * ------------------------------------------------ */

    function getPoolsByDateRange(
        uint16 _fromDay,
        uint16 _toDay
    ) public view returns (uint256[] memory poolIds) {
        // This can be gas-intensive if there are many pools.
        uint256[] memory tempPools = new uint256[](nextPoolId - 1);
        uint256 count = 0;
        for (uint256 i = 1; i < nextPoolId; i++) {
            if (pools[i].startDay <= _toDay && pools[i].endDay >= _fromDay) {
                tempPools[count] = i;
                count++;
            }
        }

        poolIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            poolIds[i] = tempPools[i];
        }
    }

    function getPoolsCount() external view returns (uint256) {
        return nextPoolId - 1;
    }

    function getPools(
        uint256[] memory poolIds
    ) external view returns (Pool[] memory result) {
        result = new Pool[](poolIds.length);
        for (uint256 i = 0; i < poolIds.length; i++) {
            result[i] = pools[poolIds[i]];
        }
    }

    function getPool(uint256 poolId) external view returns (Pool memory) {
        require(
            pools[poolId].startDay != 0 && pools[poolId].endDay != 0,
            PoolDoesNotExist(poolId)
        );
        return pools[poolId];
    }

    function getPoolLayers(
        uint256 poolId // it is uint256 because of EnumerableSet.UintSet. We don't convert to save gas
    ) external view returns (uint256[] memory) {
        return _poolLayers[poolId].values();
    }

    function getLayerStrategies(
        uint256 poolId,
        uint8 layerId
    ) external view returns (uint256[] memory) {
        return _poolLayerStrategies[poolId][layerId].values();
    }

    function getAllStrategiesForPool(
        uint256 poolId
    ) external view returns (uint256[] memory) {
        return _poolStrategies[poolId].values();
    }

    function getStrategyLayer(
        uint256 poolId,
        uint256 strategyId
    ) external view returns (uint256) {
        return strategyLayer[poolId][strategyId];
    }

    function getStrategyExclusivity(
        uint256 poolId,
        uint256 layerId,
        uint256 strategyId
    ) external view returns (StrategyExclusivity) {
        return exclusivity[poolId][layerId][strategyId];
    }

    function getStrategiesFromLayer(
        uint256 poolId,
        uint256 layerId
    )
        public
        view
        returns (
            uint256[] memory strategyIds,
            StrategyExclusivity[] memory _exclusivity
        )
    {
        // Get the number of strategies on this pool/layer
        uint256 numStrategies = _poolLayerStrategies[poolId][layerId].length();
        // Initialize arrays to store the results
        strategyIds = new uint256[](numStrategies);
        _exclusivity = new StrategyExclusivity[](numStrategies);

        // Iterate over all strategies on this pool/layer
        for (uint256 i = 0; i < numStrategies; ++i) {
            uint256 strategyId = _poolLayerStrategies[poolId][layerId].at(i);
            strategyIds[i] = strategyId;
            _exclusivity[i] = exclusivity[poolId][layerId][strategyId];
        }
    }

    /** ------------------------------------------------
     *  ! Helpers
     * ------------------------------------------------ */

    function isPoolActive(uint256 poolId) external view returns (bool) {
        return _isActive(poolId);
    }

    function isPoolEnded(uint256 poolId) external view returns (bool) {
        return _hasEnded(poolId);
    }

    function isPoolCalculated(uint256 poolId) external view returns (bool) {
        return _isCalculated(poolId);
    }

    function hasLayer(
        uint256 poolId,
        uint256 layer
    ) external view returns (bool) {
        return _poolLayers[poolId].contains(layer);
    }

    function hasStarted(uint256 poolId) external view returns (bool) {
        return _hasStarted(poolId);
    }

    /** ------------------------------------------------
     *  ! Internal Helpers
     * ------------------------------------------------ */

    function _hasStarted(uint256 poolId) internal view returns (bool) {
        return
            _getCurrentDay() >= pools[poolId].startDay &&
            pools[poolId].startDay > 0;
    }

    function _hasAnnounced(uint256 poolId) internal view returns (bool) {
        return pools[poolId].hasAnnounced;
    }

    function _hasEnded(uint256 poolId) internal view returns (bool) {
        return
            _getCurrentDay() > pools[poolId].endDay &&
            pools[poolId].endDay != 0;
    }

    function _isActive(uint256 poolId) internal view returns (bool) {
        return _hasStarted(poolId) && !_hasEnded(poolId);
    }

    function _isCalculated(uint256 poolId) internal view returns (bool) {
        return pools[poolId].totalPoolWeight > 0;
    }

    function _getCurrentDay() internal view virtual returns (uint16) {
        return uint16(block.timestamp / 1 days);
    }
}
