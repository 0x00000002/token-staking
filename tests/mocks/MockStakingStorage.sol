// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/interfaces/staking/IStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockStakingStorage is IStakingStorage, AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    mapping(bytes32 => Stake) public stakes;
    uint32 public stakeCounter;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getStake(
        bytes32 _stakeId
    ) external view override returns (Stake memory) {
        return stakes[_stakeId];
    }

    function createStake(
        address staker,
        uint128 amount,
        uint16, // daysLock
        uint16 // flags
    ) external override onlyRole(CONTROLLER_ROLE) returns (bytes32 id) {
        id = bytes32((uint256(uint160(staker)) << 96) | stakeCounter);
        stakes[id] = Stake({
            amount: amount,
            stakeDay: uint16(block.timestamp / 1 days),
            unstakeDay: 0,
            daysLock: 0,
            flags: 0
        });
        stakeCounter++;
    }

    // --- Unused functions ---
    function removeStake(address, bytes32) external override {}
    function isActiveStake(bytes32) external view override returns (bool) {
        return true;
    }
    function getStakerInfo(
        address
    ) external view override returns (StakerInfo memory) {}
    function getStakerBalance(
        address
    ) external view override returns (uint128) {}
    function getStakerBalanceAt(
        address,
        uint16
    ) external view override returns (uint128) {}
    function batchGetStakerBalances(
        address[] memory,
        uint16
    ) external view override returns (uint128[] memory) {}
    function getDailySnapshot(
        uint16
    ) external view override returns (DailySnapshot memory) {}
    function getCurrentTotalStaked() external view override returns (uint128) {}
    function getStakersPaginated(
        uint256,
        uint256
    ) external view override returns (address[] memory) {}
    function getTotalStakersCount() external view override returns (uint256) {}
    function getStakerStakeIds(
        address
    ) external view override returns (bytes32[] memory) {}
}
