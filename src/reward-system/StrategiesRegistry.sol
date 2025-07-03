// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/reward/IBaseRewardStrategy.sol";
import "../interfaces/reward/RewardEnums.sol";

contract StrategiesRegistry is AccessControl {
    struct RegistryEntry {
        address strategyAddress;
        StrategyType strategyType;
        uint32 registeredAt;
        uint16 version;
        bool isActive;
    }

    mapping(uint256 => RegistryEntry) private _strategies;
    uint256 private _strategyCounter;

    mapping(StrategyType => uint256[]) private _activeStrategiesByType;

    event StrategyRegistered(
        uint256 indexed strategyId,
        address indexed strategyAddress,
        StrategyType strategyType
    );
    event StrategyStatusChanged(uint256 indexed strategyId, bool isActive);
    event StrategyVersionUpdated(uint256 indexed strategyId, uint16 newVersion);

    error StrategyNotFound(uint256 strategyId);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerStrategy(
        address strategyAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 strategyId) {
        _strategyCounter++;
        strategyId = _strategyCounter;

        IBaseRewardStrategy strategy = IBaseRewardStrategy(strategyAddress);
        StrategyType strategyType = strategy.getStrategyType();

        _strategies[strategyId] = RegistryEntry({
            strategyAddress: strategyAddress,
            strategyType: strategyType,
            registeredAt: uint32(block.timestamp),
            version: 1,
            isActive: false
        });

        emit StrategyRegistered(strategyId, strategyAddress, strategyType);
        return strategyId;
    }

    function setStrategyStatus(
        uint256 strategyId,
        bool isActive
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _strategies[strategyId].strategyAddress != address(0),
            StrategyNotFound(strategyId)
        );

        RegistryEntry storage entry = _strategies[strategyId];
        if (entry.isActive == isActive) return; // No change

        entry.isActive = isActive;

        uint256[] storage activeList = _activeStrategiesByType[
            entry.strategyType
        ];
        if (isActive) {
            activeList.push(strategyId);
        } else {
            for (uint256 i = 0; i < activeList.length; i++) {
                if (activeList[i] == strategyId) {
                    activeList[i] = activeList[activeList.length - 1];
                    activeList.pop();
                    break;
                }
            }
        }

        emit StrategyStatusChanged(strategyId, isActive);
    }

    function updateStrategyVersion(
        uint256 strategyId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _strategies[strategyId].strategyAddress != address(0),
            StrategyNotFound(strategyId)
        );
        _strategies[strategyId].version++;
        emit StrategyVersionUpdated(
            strategyId,
            _strategies[strategyId].version
        );
    }

    function getActiveStrategies() external view returns (uint256[] memory) {
        uint256[] memory immediate = _activeStrategiesByType[
            StrategyType.IMMEDIATE
        ];
        uint256[] memory epoch = _activeStrategiesByType[
            StrategyType.EPOCH_BASED
        ];
        uint256[] memory allActive = new uint256[](
            immediate.length + epoch.length
        );
        for (uint256 i = 0; i < immediate.length; i++) {
            allActive[i] = immediate[i];
        }
        for (uint256 i = 0; i < epoch.length; i++) {
            allActive[immediate.length + i] = epoch[i];
        }
        return allActive;
    }

    function getActiveStrategiesByType(
        StrategyType strategyType
    ) external view returns (uint256[] memory) {
        return _activeStrategiesByType[strategyType];
    }

    function getStrategy(
        uint256 strategyId
    ) external view returns (RegistryEntry memory) {
        require(
            _strategies[strategyId].strategyAddress != address(0),
            StrategyNotFound(strategyId)
        );
        return _strategies[strategyId];
    }

    function getStrategyAddress(
        uint256 strategyId
    ) external view returns (address) {
        require(
            _strategies[strategyId].strategyAddress != address(0),
            StrategyNotFound(strategyId)
        );
        return _strategies[strategyId].strategyAddress;
    }
}
