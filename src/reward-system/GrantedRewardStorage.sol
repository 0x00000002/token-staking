// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/reward/IBaseRewardStrategy.sol";
import "../interfaces/reward/RewardEnums.sol";

contract GrantedRewardStorage is AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    struct GrantedReward {
        uint128 amount;
        uint32 grantedAt;
        uint32 epochId;
        uint16 strategyId;
        uint16 strategyVersion;
        bool claimed;
    }

    mapping(address => GrantedReward[]) private _userRewards;
    mapping(address => uint256) private _nextClaimableIndex;

    event RewardGranted(
        address indexed user,
        uint256 indexed strategyId,
        uint32 indexed epochId,
        uint256 amount,
        uint16 strategyVersion
    );
    event RewardClaimed(
        address indexed user,
        uint256 indexed rewardIndex,
        uint256 amount
    );
    event BatchRewardsClaimed(
        address indexed user,
        uint256 totalAmount,
        uint256 rewardCount
    );

    error RewardAlreadyClaimed(uint256 rewardIndex);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function grantReward(
        address user,
        uint256 strategyId,
        uint16 strategyVersion,
        uint256 amount,
        uint32 epochId
    ) external onlyRole(CONTROLLER_ROLE) {
        _userRewards[user].push(
            GrantedReward({
                amount: uint128(amount),
                grantedAt: uint32(block.timestamp),
                epochId: epochId,
                strategyId: uint16(strategyId),
                strategyVersion: strategyVersion,
                claimed: false
            })
        );
        emit RewardGranted(user, strategyId, epochId, amount, strategyVersion);
    }

    function markRewardClaimed(
        address user,
        uint256 rewardIndex
    ) external onlyRole(CONTROLLER_ROLE) {
        GrantedReward storage reward = _userRewards[user][rewardIndex];
        require(!reward.claimed, RewardAlreadyClaimed(rewardIndex));
        reward.claimed = true;
        emit RewardClaimed(user, rewardIndex, reward.amount);
    }

    function batchMarkClaimed(
        address user,
        uint256[] calldata rewardIndices
    ) external onlyRole(CONTROLLER_ROLE) {
        uint256 totalAmount = 0;
        uint256 claimedCount = 0;
        for (uint256 i = 0; i < rewardIndices.length; i++) {
            uint256 rewardIndex = rewardIndices[i];
            GrantedReward storage reward = _userRewards[user][rewardIndex];
            if (!reward.claimed) {
                reward.claimed = true;
                totalAmount += reward.amount;
                claimedCount++;
            }
        }
        emit BatchRewardsClaimed(user, totalAmount, claimedCount);
    }

    function getUserRewards(
        address user
    ) external view returns (GrantedReward[] memory) {
        return _userRewards[user];
    }

    function getUserClaimableAmount(
        address user
    ) external view returns (uint256) {
        uint256 claimableAmount = 0;
        for (uint256 i = 0; i < _userRewards[user].length; i++) {
            if (!_userRewards[user][i].claimed)
                claimableAmount += _userRewards[user][i].amount;
        }
        return claimableAmount;
    }

    function getUserClaimableRewards(
        address user
    ) external view returns (GrantedReward[] memory, uint256[] memory) {
        uint256 totalRewards = _userRewards[user].length;
        uint256 startIndex = _nextClaimableIndex[user];

        if (startIndex >= totalRewards)
            return (new GrantedReward[](0), new uint256[](0));

        uint256 maxPossible = totalRewards - startIndex;
        GrantedReward[] memory tempRewards = new GrantedReward[](maxPossible);
        uint256[] memory tempIndices = new uint256[](maxPossible);
        uint256 count = 0;

        for (uint256 i = startIndex; i < totalRewards; i++) {
            if (!_userRewards[user][i].claimed) {
                tempRewards[count] = _userRewards[user][i];
                tempIndices[count] = i;
                count++;
            }
        }

        GrantedReward[] memory claimableRewards = new GrantedReward[](count);
        uint256[] memory claimableIndices = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            claimableRewards[i] = tempRewards[i];
            claimableIndices[i] = tempIndices[i];
        }

        return (claimableRewards, claimableIndices);
    }

    function getUserEpochRewards(
        address user,
        uint32 epochId
    ) external view returns (GrantedReward[] memory) {
        uint256 epochRewardCount = 0;
        for (uint256 i = 0; i < _userRewards[user].length; i++) {
            if (_userRewards[user][i].epochId == epochId) epochRewardCount++;
        }

        GrantedReward[] memory epochRewards = new GrantedReward[](
            epochRewardCount
        );
        uint256 counter = 0;
        for (uint256 i = 0; i < _userRewards[user].length; i++) {
            if (_userRewards[user][i].epochId == epochId) {
                epochRewards[counter] = _userRewards[user][i];
                counter++;
            }
        }
        return epochRewards;
    }

    function getUserRewardsPaginated(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (GrantedReward[] memory) {
        uint256 totalRewards = _userRewards[user].length;
        if (offset >= totalRewards) return new GrantedReward[](0);

        uint256 end = offset + limit;
        if (end > totalRewards) end = totalRewards;

        GrantedReward[] memory paginatedRewards = new GrantedReward[](
            end - offset
        );
        for (uint256 i = offset; i < end; i++) {
            paginatedRewards[i - offset] = _userRewards[user][i];
        }
        return paginatedRewards;
    }

    function updateNextClaimableIndex(
        address user
    ) external onlyRole(CONTROLLER_ROLE) {
        uint256 totalRewards = _userRewards[user].length;
        uint256 currentIndex = _nextClaimableIndex[user];

        for (uint256 i = currentIndex; i < totalRewards; i++) {
            if (!_userRewards[user][i].claimed) {
                _nextClaimableIndex[user] = i;
                return;
            }
        }
        _nextClaimableIndex[user] = totalRewards;
    }
}
