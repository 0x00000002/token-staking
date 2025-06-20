// SPDX-License-Identifier: MIT
// NOTE: This is a legacy deployment script for the old modular architecture
// Use DeployStaking.s.sol for the current StakingVault + StakingStorage architecture

pragma solidity ^0.8.30;

import "forge-std/Script.sol";

/**
 * @title DeployModularStaking
 * @notice DEPRECATED - Legacy deployment script for old modular architecture
 * @dev This script is kept for reference but should not be used
 *      Use DeployStaking.s.sol or DeployWithExistingToken.s.sol instead
 */
contract DeployModularStaking is Script {
    function run() external {
        revert("DEPRECATED: Use DeployStaking.s.sol instead");
    }
}