// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

enum StrategyType {
    IMMEDIATE,     // Can calculate anytime (APR-style)
    EPOCH_BASED    // Fixed pools after epoch ends
}

enum EpochState {
    ANNOUNCED,     // Rules published, users can prepare
    ACTIVE,        // Epoch running, tracking participants
    ENDED,         // Finished, awaiting admin pool size
    CALCULATED,    // Rewards calculated, ready to claim
    FINALIZED      // All rewards claimed, epoch closed
}