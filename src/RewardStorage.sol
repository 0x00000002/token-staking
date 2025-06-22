// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IRewardStorage.sol";

contract RewardStorage is IRewardStorage, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    mapping(address staker => uint256) public stakeCount;
    // stakeId = keccak256(abi.encoded(stakerAddress, stakeCount)
    mapping(address staker => mapping(uint256 stakeId => Reward))
        public rewards;

    address public controller;
    address public manager;
    address public admin;

    mapping(address staker => uint256) public rewardsCount;
    mapping(address staker => uint224) public totalRewards;
    mapping(uint32 timestamp => Reward[] rewards) public rewardsByTimestamp;

    event ControllerSet(address indexed controller);

    error ArrayMismatch();

    constructor(address _admin, address _manager) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _manager);
        admin = _admin;
        manager = _manager;
    }

    /**
     * @notice Set the controller address
     * @param _controller The address of the controller
     */
    function setController(
        address _controller
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(CONTROLLER_ROLE, _controller);
        controller = _controller;
        emit ControllerSet(_controller);
    }

    function setReward(
        address staker,
        uint256 stakeId,
        uint224 rewardAmount,
        uint32 blockNumber
    ) external onlyRole(CONTROLLER_ROLE) {
        rewards[staker][stakeId] = Reward(blockNumber, rewardAmount, stakeId);
    }

    function deleteReward(address staker, uint256 stakeId) external {
        delete rewards[staker][stakeId];
    }

    function getReward(
        address staker,
        uint256 stakeId
    ) external view returns (Reward memory) {
        return rewards[staker][stakeId];
    }

    function getRewards(
        address[] calldata stakers,
        uint256[] calldata stakeIds
    ) external view returns (Reward[] memory) {
        require(stakers.length == stakeIds.length, ArrayMismatch());

        Reward[] memory _rewards = new Reward[](stakers.length);
        for (uint256 i = 0; i < stakers.length; i++) {
            _rewards[i] = rewards[stakers[i]][stakeIds[i]];
        }
        return _rewards;
    }

    function getRewardsCount(
        address staker
    ) external view override returns (uint256) {
        return rewardsCount[staker];
    }

    function getTotalRewards(
        address staker
    ) external view override returns (uint224) {
        return totalRewards[staker];
    }

    function getRewardsByTimestamp(
        address staker,
        uint32 timestamp
    ) external view override returns (Reward[] memory) {
        return rewardsByTimestamp[timestamp];
    }
}
