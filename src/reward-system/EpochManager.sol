// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/reward/IBaseRewardStrategy.sol";
import "../interfaces/reward/RewardEnums.sol";

contract EpochManager is AccessControl {
    struct Epoch {
        uint32 epochId;
        uint32 startDay;
        uint32 endDay;
        uint256 strategyId;
        uint256 estimatedPoolSize;
        uint256 actualPoolSize;
        EpochState state;
        uint32 announcedAt;
        uint32 calculatedAt;
        uint256 totalParticipants;
        uint256 totalStakeWeight;
    }

    mapping(uint32 => Epoch) private _epochs;
    uint32 private _epochCounter;

    uint32[] private _announcedEpochIds;
    mapping(uint32 => uint256) private _announcedEpochIndex;

    uint32[] private _activeEpochIds;
    mapping(uint32 => uint256) private _activeEpochIndex;

    error EpochNotEnded(uint32 epochId);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function announceEpoch(
        uint32 startDay,
        uint32 endDay,
        uint256 strategyId,
        uint256 estimatedPool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint32 epochId) {
        _epochCounter++;
        epochId = _epochCounter;

        _epochs[epochId] = Epoch({
            epochId: epochId,
            startDay: startDay,
            endDay: endDay,
            strategyId: strategyId,
            estimatedPoolSize: estimatedPool,
            actualPoolSize: 0,
            state: EpochState.ANNOUNCED,
            announcedAt: uint32(block.timestamp),
            calculatedAt: 0,
            totalParticipants: 0,
            totalStakeWeight: 0
        });

        _announcedEpochIndex[epochId] = _announcedEpochIds.length;
        _announcedEpochIds.push(epochId);
        return epochId;
    }

    function setEpochPoolSize(
        uint32 epochId,
        uint256 actualPoolSize
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Epoch storage epoch = _epochs[epochId];
        require(epoch.state == EpochState.ENDED, EpochNotEnded(epochId));
        epoch.actualPoolSize = actualPoolSize;
    }

    function updateEpochStates() external {
        uint32 currentDay = getCurrentDay();

        // ANNOUNCED -> ACTIVE
        for (uint256 i = 0; i < _announcedEpochIds.length; ) {
            uint32 epochId = _announcedEpochIds[i];
            Epoch storage epoch = _epochs[epochId];

            if (currentDay >= epoch.startDay) {
                epoch.state = EpochState.ACTIVE;

                // Add to active list
                _activeEpochIndex[epochId] = _activeEpochIds.length;
                _activeEpochIds.push(epochId);

                // Remove from announced list (swap and pop)
                uint32 lastEpochId = _announcedEpochIds[
                    _announcedEpochIds.length - 1
                ];
                _announcedEpochIds[i] = lastEpochId;
                _announcedEpochIndex[lastEpochId] = i;
                _announcedEpochIds.pop();
            } else {
                i++;
            }
        }

        // ACTIVE -> ENDED
        for (uint256 i = 0; i < _activeEpochIds.length; ) {
            uint32 epochId = _activeEpochIds[i];
            Epoch storage epoch = _epochs[epochId];

            if (currentDay > epoch.endDay) {
                epoch.state = EpochState.ENDED;

                // Remove from active list (swap and pop)
                uint32 lastEpochId = _activeEpochIds[
                    _activeEpochIds.length - 1
                ];
                _activeEpochIds[i] = lastEpochId;
                _activeEpochIndex[lastEpochId] = i;
                _activeEpochIds.pop();

                // No need to track ENDED epochs in a list for state updates
            } else {
                i++;
            }
        }
    }

    function finalizeEpoch(
        uint32 epochId,
        uint256 totalParticipants,
        uint256 totalWeight
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Epoch storage epoch = _epochs[epochId];
        require(epoch.state == EpochState.ENDED, EpochNotEnded(epochId));
        epoch.state = EpochState.CALCULATED;
        epoch.calculatedAt = uint32(block.timestamp);
        epoch.totalParticipants = totalParticipants;
        epoch.totalStakeWeight = totalWeight;
    }

    function getEpoch(uint32 epochId) external view returns (Epoch memory) {
        return _epochs[epochId];
    }

    function getActiveEpochs() external view returns (uint32[] memory) {
        return _activeEpochIds;
    }

    function getEpochState(uint32 epochId) external view returns (EpochState) {
        return _epochs[epochId].state;
    }

    function getCurrentDay() public view returns (uint32) {
        return uint32(block.timestamp / 86_400);
    }
}
