// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../src/lib/Flags.sol";
import "../../src/StakingFlags.sol";

/**
 * @title TestStakeFlags
 * @notice Helper constants and functions for testing stake flags
 */
library TestStakeFlags {
    // Common flag combinations for testing
    uint16 public constant REGULAR_STAKE_FLAGS = 0; // No flags set
    uint16 public constant CLAIM_STAKE_FLAGS =
        uint16(1 << StakingFlags.IS_FROM_CLAIM_BIT);
    uint16 public constant DELEGATED_STAKE_FLAGS = uint16(1 << 1); // Assuming bit 1 for delegated
    uint16 public constant LOCKED_STAKE_FLAGS = uint16(1 << 2); // Assuming bit 2 for locked

    // Combined flags for testing
    uint16 public constant CLAIM_AND_DELEGATED_FLAGS =
        uint16(1 << StakingFlags.IS_FROM_CLAIM_BIT) | uint16(1 << 1); // Assuming bit 1 for delegated

    /**
     * @notice Create flags for a regular stake (not from claim)
     */
    function regularStakeFlags() internal pure returns (uint16) {
        return REGULAR_STAKE_FLAGS;
    }

    /**
     * @notice Create flags for a claim stake
     */
    function claimStakeFlags() internal pure returns (uint16) {
        return CLAIM_STAKE_FLAGS;
    }

    /**
     * @notice Create flags based on isFromClaim boolean (for migration)
     */
    function fromIsFromClaim(bool isFromClaim) internal pure returns (uint16) {
        return isFromClaim ? CLAIM_STAKE_FLAGS : REGULAR_STAKE_FLAGS;
    }

    /**
     * @notice Assert that flags match expected isFromClaim value
     */
    function assertIsFromClaim(
        uint16 flags,
        bool expectedIsFromClaim
    ) internal pure {
        assert(
            Flags.isSet(flags, StakingFlags.IS_FROM_CLAIM_BIT) ==
                expectedIsFromClaim
        );
    }
}
