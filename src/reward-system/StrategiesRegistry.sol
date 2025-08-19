// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/reward/RewardErrors.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title StrategiesRegistry
 * @author @Tudmotu
 * @notice A simple registry for mapping a strategy ID to a contract address.
 */
contract StrategiesRegistry is RewardErrors, AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public nextStrategyId;

    mapping(uint256 id => address contractAddress) public strategies;
    EnumerableSet.UintSet internal _enabledStrategies;

    event StrategyDisabled(
        uint256 indexed strategyId,
        address indexed strategyAddress
    );
    event StrategyEnabled(
        uint256 indexed strategyId,
        address indexed strategyAddress
    );

    constructor(address _admin, address _manager) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _manager);
    }

    /**
     * @notice Registers a new strategy or updates an existing one.
     * @param _strategyAddress The address of the deployed strategy contract.
     */
    function registerStrategy(
        address _strategyAddress
    ) external onlyRole(MANAGER_ROLE) returns (uint256) {
        require(_strategyAddress != address(0), RewardErrors.InvalidAddress());
        strategies[nextStrategyId] = _strategyAddress;
        _enabledStrategies.add(nextStrategyId);
        emit StrategyEnabled(nextStrategyId, _strategyAddress);
        return nextStrategyId++;
    }

    /**
     * @notice Removes a strategy from the registry.
     * @param _strategyId The ID of the strategy to remove.
     */
    function disableStrategy(
        uint256 _strategyId
    ) external onlyRole(MANAGER_ROLE) {
        require(
            strategies[_strategyId] != address(0),
            RewardErrors.StrategyNotExist(_strategyId)
        );
        _enabledStrategies.remove(_strategyId);
        emit StrategyDisabled(_strategyId, strategies[_strategyId]);
    }

    function enableStrategy(
        uint256 _strategyId
    ) external onlyRole(MANAGER_ROLE) {
        require(
            strategies[_strategyId] != address(0),
            RewardErrors.StrategyNotExist(_strategyId)
        );
        _enabledStrategies.add(_strategyId);
        emit StrategyEnabled(_strategyId, strategies[_strategyId]);
    }

    /**
     * @notice Gets the address of a registered strategy.
     * @param _strategyId The ID of the strategy.
     * @return The contract address of the strategy.
     */
    function getStrategyAddress(
        uint256 _strategyId
    ) external view returns (address) {
        return strategies[_strategyId];
    }

    /**
     * @notice Checks if a strategy is registered.
     * @param _strategyId The ID of the strategy to check.
     * @return True if the strategy is registered, false otherwise.
     */
    function isStrategyRegistered(
        uint256 _strategyId
    ) external view returns (bool) {
        return strategies[_strategyId] != address(0);
    }

    function getStrategyStatus(
        uint256 _strategyId
    ) external view returns (bool) {
        return _enabledStrategies.contains(_strategyId);
    }

    function getListOfActiveStrategies()
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = _enabledStrategies.length();
        uint256[] memory activeStrategies = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            activeStrategies[i] = _enabledStrategies.at(i);
        }
        return activeStrategies;
    }
}
