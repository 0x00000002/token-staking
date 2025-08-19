// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "../interfaces/reward/RewardErrors.sol";

/**
 * @title ClaimsJournal
 * @notice Stores all user claim history for both DIRECT and SHARED_POOL rewards.
 * @dev This contract is the single source of truth for the RewardManager to determine
 *      if a user is eligible for a future claim based on their past actions.
 *      It knows nothing about reward logic; it is a simple, append-only ledger.
 */
contract ClaimsJournal is AccessControl, RewardErrors {
    bytes32 constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");

    enum LayerClaimType {
        NORMAL,
        EXCLUSIVE,
        SEMI_EXCLUSIVE
    }

    event LayerStateUpdated(
        address indexed user,
        uint256 indexed poolId,
        uint256 indexed layerId,
        LayerClaimType newStateType
    );

    event DirectClaimRecorded(
        bytes32 indexed stakeId,
        uint256 indexed strategyId,
        uint256 claimDay
    );

    // Tracks the state of a user's claim on a specific layer of a pool.
    // User Address => Pool ID => Layer ID => Claim Type
    mapping(address userAddress => mapping(uint256 poolId => mapping(uint256 layerId => LayerClaimType)))
        public layerClaimState;

    // Tracks the last day a reward was claimed for a specific stake and a DIRECT strategy.
    // Stake ID => Strategy ID => Day
    mapping(bytes32 stakeId => mapping(uint256 poolId => mapping(uint256 strategyId => uint16 claimDay)))
        public claimDates;

    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Records a claim, updating the state for the given user, pool, and strategy.
     * @dev To be called ONLY by the RewardManager after a successful reward payment.
     */
    function recordClaim(
        address _user,
        uint256 _poolId,
        uint256 _layerId,
        uint256 _strategyId,
        bytes32 _stakeId,
        LayerClaimType _claimType,
        uint16 _claimDay
    ) external onlyRole(REWARD_MANAGER_ROLE) {
        LayerClaimType currentLayerState = layerClaimState[_user][_poolId][
            _layerId
        ];

        if (_claimType == LayerClaimType.EXCLUSIVE) {
            require(
                currentLayerState == LayerClaimType.NORMAL,
                LayerAlreadyHasClaim(_layerId, _claimDay)
            );
        } else {
            // NORMAL or SEMI_EXCLUSIVE
            require(
                currentLayerState != LayerClaimType.EXCLUSIVE,
                LayerAlreadyHasExclusiveClaim(_layerId, _claimDay)
            );
            if (_claimType == LayerClaimType.SEMI_EXCLUSIVE) {
                require(
                    currentLayerState != LayerClaimType.SEMI_EXCLUSIVE,
                    LayerAlreadyHasSemiExclusiveClaim(_layerId, _claimDay)
                );
            }
        }

        // if current state is absent or normal,
        // update it to the new claim type (normal, semi-exclusive or exclusive)
        if (currentLayerState == LayerClaimType.NORMAL) {
            layerClaimState[_user][_poolId][_layerId] = _claimType;
            emit LayerStateUpdated(_user, _poolId, _layerId, _claimType);
        }
        // if current state is exclusive, update it to the max-level
        // this will override the normal or semi-exclusive claim
        // if it is already exclusive, it is redundant but safe to rewrite
        // but cheaper in terms of gas (no extra checks on all updates)
        if (_claimType == LayerClaimType.EXCLUSIVE) {
            layerClaimState[_user][_poolId][_layerId] = _claimType;
            emit LayerStateUpdated(_user, _poolId, _layerId, _claimType);
        }

        claimDates[_stakeId][_poolId][_strategyId] = _claimDay;
        emit DirectClaimRecorded(_stakeId, _strategyId, _claimDay);
    }

    // ===================================================================
    //                           VIEW FUNCTIONS
    // ===================================================================

    function getLayerClaimState(
        address _user,
        uint256 _poolId,
        uint256 _layerId
    ) external view returns (LayerClaimType) {
        return layerClaimState[_user][_poolId][_layerId];
    }

    function getLastClaimDay(
        bytes32 _stakeId,
        uint256 _poolId,
        uint256 _strategyId
    ) external view returns (uint16) {
        return claimDates[_stakeId][_poolId][_strategyId];
    }
}
