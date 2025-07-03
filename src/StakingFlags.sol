// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title StakingFlags
 * @notice A central place for staking-specific flag definitions.
 */
library StakingFlags {
    uint8 public constant IS_FROM_CLAIM_BIT = 0;
    // Future flags can be added here, e.g.:
    // uint8 public constant IS_DELEGATED_BIT = 1;
    // uint8 public constant IS_LOCKED_BIT = 2;
}