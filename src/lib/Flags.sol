// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title Flags
 * @notice A generic library for handling bitwise flag operations on a uint16.
 */
library Flags {
    /**
     * @notice Sets a specific bit in the flags.
     * @param flags The current flags value.
     * @param bit The bit position to set.
     * @return The updated flags value.
     */
    function set(uint16 flags, uint8 bit) internal pure returns (uint16) {
        return flags | uint16(1 << bit);
    }

    /**
     * @notice Unsets a specific bit in the flags.
     * @param flags The current flags value.
     * @param bit The bit position to unset.
     * @return The updated flags value.
     */
    function unset(uint16 flags, uint8 bit) internal pure returns (uint16) {
        return flags & ~uint16(1 << bit);
    }

    /**
     * @notice Checks if a specific bit is set in the flags.
     * @param flags The current flags value.
     * @param bit The bit position to check.
     * @return True if the bit is set, false otherwise.
     */
    function isSet(uint16 flags, uint8 bit) internal pure returns (bool) {
        return (flags & (1 << bit)) != 0;
    }
}
