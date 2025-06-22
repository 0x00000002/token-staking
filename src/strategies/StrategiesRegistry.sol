// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IRewardStrategy.sol";

contract StrategiesRegistry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping from strategy ID to strategy implementation
    mapping(uint256 => address) public strategies;
    mapping(address user => uint256 strategyId) public userSelectedStrategy;
    uint256 public defaultStrategyId;

    // Mapping to check if a strategy is active
    mapping(uint256 => bool) public isStrategyActive;

    uint256 private _strategyCount;
    uint256[] private _activeStrategyIds;

    // Events

    event DefaultStrategySet(uint256 indexed strategyId);
    event StrategyActivated(uint256 indexed strategyId);
    event StrategyDeactivated(uint256 indexed strategyId);
    event UserStrategySelected(
        address indexed user,
        uint256 indexed strategyId
    );
    event StrategyRegistered(
        uint256 indexed strategyId,
        address strategyAddress,
        string name
    );

    function registerStrategy(
        address strategyAddress
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        strategies[_strategyCount++] = strategyAddress;
        _activeStrategyIds.push(_strategyCount);
        string memory name = IRewardStrategy(strategyAddress)
            .getParameters()
            .name;
        emit StrategyRegistered(_strategyCount, strategyAddress, name);
        return _strategyCount;
    }

    function setStrategyStatus(
        uint256 strategyId,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(
            strategies[strategyId] != address(0),
            "Strategy not registered"
        );
        isStrategyActive[strategyId] = isActive;
        if (isActive) {
            _activeStrategyIds.push(strategyId);
            emit StrategyActivated(strategyId);
        } else {
            emit StrategyDeactivated(strategyId);
        }
    }

    // TODO: discuss:
    // Can user select strategy or not?
    // Strategy storage - separate it.
    function getActiveStrategies() external view returns (uint256[] memory) {
        return _activeStrategyIds;
    }

    function selectStrategy(uint256 strategyId) external {
        require(strategies[strategyId] != address(0), "Strategy doesn't exist");
        userSelectedStrategy[msg.sender] = strategyId;
        emit UserStrategySelected(msg.sender, strategyId);
    }

    function setDefaultStrategy(uint256 strategyId) external {
        require(strategies[strategyId] != address(0), "Strategy doesn't exist");
        defaultStrategyId = strategyId;
        emit DefaultStrategySet(strategyId);
    }

    function getStrategyForUser(address user) public view returns (address) {
        uint256 selectedId = userSelectedStrategy[user];

        // If user hasn't selected a strategy, use default
        if (selectedId == 0) selectedId = defaultStrategyId;

        return strategies[selectedId];
    }
}
