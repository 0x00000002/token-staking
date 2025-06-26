// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IStakingStorage.sol";

/**
 * @title StakingStorage
 * @notice Storage for staking data
 */
contract StakingStorage is IStakingStorage, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    // Core storage mappings
    mapping(address staker => mapping(uint16 day => bytes32[])) public IDs;
    mapping(address staker => mapping(bytes32 id => Stake)) private _stakes;
    mapping(address staker => StakerInfo) private _stakers;
    mapping(address staker => uint16[] checkpoints) private _stakerCheckpoints;
    mapping(address staker => mapping(uint16 => uint128))
        private _stakerBalances;
    mapping(uint16 dayNumber => DailySnapshot) private _dailySnapshots;

    // Global state
    EnumerableSet.AddressSet private _allStakers;
    uint128 private _currentTotalStaked;
    uint16 private _currentDay;

    // Errors
    error StakeNotFound(address staker, bytes32 id);
    error StakeAlreadyExists(bytes32 id);
    error StakeAlreadyUnstaked(bytes32 id);
    error StakerNotFound(address staker);
    error OutOfBounds(uint256 total, uint256 offset);

    constructor(address admin, address manager, address vault) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, manager);
        _grantRole(CONTROLLER_ROLE, vault); // StakingVault
        _currentDay = _getCurrentDay();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        STAKE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════

    function createStake(
        address staker,
        bytes32 id,
        uint128 amount,
        uint16 daysLock,
        bool isFromClaim
    ) external onlyRole(CONTROLLER_ROLE) {
        require(_stakes[staker][id].amount == 0, StakeAlreadyExists(id));

        uint16 today = _getCurrentDay();

        // Create stake
        _stakes[staker][id] = Stake({
            amount: amount,
            stakeDay: today,
            unstakeDay: 0,
            daysLock: daysLock,
            isFromClaim: isFromClaim
        });

        IDs[staker][today].push(id);

        // Add staker to the set. If the staker is new, the .add function returns true.
        if (_allStakers.add(staker)) {
            // New staker, set their initial checkpoint day.
            _stakers[staker].lastCheckpointDay = today;
        }

        // Update staker info
        _stakers[staker].activeStakesNumber++;
        _stakers[staker].stakesCounter++;
        _stakers[staker].totalStaked += amount;

        // Update balances and checkpoints
        _updateStakerCheckpoint(staker, today, int256(uint256(amount)));
        _updateDailySnapshot(today, int256(uint256(amount)), 1);

        emit Staked(staker, id, amount, today, daysLock, isFromClaim);
    }

    function removeStake(
        address staker,
        bytes32 id
    ) external onlyRole(CONTROLLER_ROLE) {
        Stake storage stake = _stakes[staker][id];

        require(stake.amount > 0, StakeNotFound(staker, id));
        require(stake.unstakeDay == 0, StakeAlreadyUnstaked(id));

        uint16 today = _getCurrentDay();
        uint128 amount = stake.amount;

        // Mark as unstaked
        stake.unstakeDay = today;

        // Update staker info
        _stakers[staker].totalStaked -= amount;
        _stakers[staker].activeStakesNumber--;

        // Update balances and checkpoints
        _updateStakerCheckpoint(staker, today, -int256(uint256(amount)));
        _updateDailySnapshot(today, -int256(uint256(amount)), -1);

        emit Unstaked(staker, id, today, amount);
    }

    function getStake(
        address staker,
        bytes32 id
    ) external view returns (Stake memory) {
        Stake memory stake = _stakes[staker][id];
        require(stake.amount > 0, StakeNotFound(staker, id));
        return stake;
    }

    function isActiveStake(
        address staker,
        bytes32 id
    ) external view returns (bool) {
        Stake memory stake = _stakes[staker][id];
        return stake.amount > 0 && stake.unstakeDay == 0;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        STAKER MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════

    function getStakerInfo(
        address staker
    ) external view returns (StakerInfo memory) {
        return _stakers[staker];
    }

    function getStakerBalance(address staker) external view returns (uint128) {
        return _getStakerBalanceAt(staker, _getCurrentDay());
    }

    function getStakerBalanceAt(
        address staker,
        uint16 targetDay
    ) external view returns (uint128) {
        return _getStakerBalanceAt(staker, targetDay);
    }

    function batchGetStakerBalances(
        address[] calldata stakers,
        uint16 targetDay
    ) external view returns (uint128[] memory) {
        uint128[] memory balances = new uint128[](stakers.length);
        for (uint256 i = 0; i < stakers.length; i++) {
            balances[i] = _getStakerBalanceAt(stakers[i], targetDay);
        }
        return balances;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        GLOBAL STATISTICS
    // ═══════════════════════════════════════════════════════════════════

    function getDailySnapshot(
        uint16 day
    ) external view returns (DailySnapshot memory) {
        return _dailySnapshots[day];
    }

    function getCurrentTotalStaked() external view returns (uint128) {
        return _currentTotalStaked;
    }

    function getStakersPaginated(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory) {
        uint256 total = _allStakers.length();
        require(offset < total, OutOfBounds(total, offset));

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = _allStakers.at(i);
        }
        return result;
    }

    function getTotalStakersCount() external view returns (uint256) {
        return _allStakers.length();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                        INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    function _getCurrentDay() internal view returns (uint16) {
        return uint16(block.timestamp / 1 days);
    }

    function _updateStakerCheckpoint(
        address staker,
        uint16 day,
        int256 amountDelta
    ) internal {
        // Get current balance
        uint128 currentBalance = _getStakerBalanceAt(staker, day);

        // Apply delta
        if (amountDelta >= 0) {
            currentBalance += uint128(uint256(amountDelta));
        } else {
            uint128 decrease = uint128(uint256(-amountDelta));
            currentBalance = currentBalance >= decrease
                ? currentBalance - decrease
                : 0;
        }

        // Update balance
        _stakerBalances[staker][day] = currentBalance;

        // Update checkpoint list if needed
        uint16[] storage checkpoints = _stakerCheckpoints[staker];
        if (
            checkpoints.length == 0 ||
            checkpoints[checkpoints.length - 1] != day
        ) {
            checkpoints.push(day);
        }

        // Update staker info
        _stakers[staker].lastCheckpointDay = day;

        emit CheckpointCreated(
            staker,
            day,
            currentBalance,
            _stakers[staker].activeStakesNumber
        );
    }

    function _updateDailySnapshot(
        uint16 day,
        int256 amountDelta,
        int16 countDelta
    ) internal {
        // If we've entered a new day, copy the previous day's snapshot.
        if (day > _currentDay) {
            _dailySnapshots[day] = _dailySnapshots[_currentDay];
            _currentDay = day;
        }

        DailySnapshot storage snapshot = _dailySnapshots[day];

        if (amountDelta >= 0) {
            uint128 increase = uint128(uint256(amountDelta));
            snapshot.totalStakedAmount += increase;
            _currentTotalStaked += increase;
        } else {
            uint128 decrease = uint128(uint256(-amountDelta));
            if (snapshot.totalStakedAmount >= decrease) {
                snapshot.totalStakedAmount -= decrease;
            } else {
                snapshot.totalStakedAmount = 0;
            }
            if (_currentTotalStaked >= decrease) {
                _currentTotalStaked -= decrease;
            } else {
                _currentTotalStaked = 0;
            }
        }

        // Update stakes count
        if (countDelta >= 0) {
            snapshot.totalStakesCount += uint16(countDelta);
        } else {
            uint16 decrease = uint16(-countDelta);
            snapshot.totalStakesCount = snapshot.totalStakesCount >= decrease
                ? snapshot.totalStakesCount - decrease
                : 0;
        }
    }

    function _getStakerBalanceAt(
        address staker,
        uint16 targetDay
    ) internal view returns (uint128) {
        uint16[] memory checkpoints = _stakerCheckpoints[staker];
        uint256 nCheckpoints = checkpoints.length;

        // Return 0 if no checkpoints exist
        if (nCheckpoints == 0) {
            return 0;
        }

        // Quick exact match check
        uint128 exactBalance = _stakerBalances[staker][targetDay];
        if (exactBalance > 0) {
            return exactBalance;
        }

        // Handle edge case: target is before first checkpoint
        if (checkpoints[0] > targetDay) {
            return 0;
        }

        // Binary search for closest checkpoint
        uint256 left = 0;
        uint256 right = nCheckpoints - 1;
        uint16 closest = 0;

        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            uint16 midDay = checkpoints[mid];

            if (midDay <= targetDay) {
                closest = midDay;
                left = mid + 1;
            } else {
                if (mid == 0) break;
                right = mid - 1;
            }
        }

        return _stakerBalances[staker][closest];
    }
}
