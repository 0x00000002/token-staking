# Token Rewards System: A Guide

## Overview

The rewards system works with the staking mechanism to provide various earning opportunities for token holders. The system is designed to be flexible and transparent, supporting different types of reward strategies through a unified interface.

## How Rewards Work: Pools, Layers, and Strategies

The rewards system is built around three core concepts:

1.  **Pools**: A pool represents a reward opportunity for a specific time period. It is defined by a `startDay` and an `endDay`. All reward calculations for strategies within a pool are confined to this period. For example, a "Q3 Bonus Pool" might run from day 90 to day 180.

2.  **Strategies**: A strategy is a contract containing the specific logic for calculating a reward. Each strategy assigned to a pool calculates a particular type of bonus. For example, one strategy might offer a bonus for loyalty, while another gives a bonus for holding a certain amount of tokens.

3.  **Layers**: Within a single pool, strategies can be organized into "layers". Layers have exclusivity rules that govern how you can claim rewards from them. This allows for creating sophisticated reward structures, such as choosing between one large, exclusive bonus or several smaller, non-exclusive ones.

## Two Types of Reward Strategies

While the claiming process is unified for the user, the underlying strategies fall into two categories, which affect _when_ a reward can be claimed.

### 1. Pool Size Independent Strategies

These are rewards that can be calculated at any time based on your personal staking data and fixed parameters (like an APR).

- **How it Works**: The reward calculation does not depend on the actions of other stakers in the pool. The rules are self-contained. For example, a "5% APR" strategy calculates your reward based solely on your stake's duration within the pool's timeframe.
- **Claiming**: You can claim rewards from these strategies **at any time** after the pool starts. The system tracks your `lastClaimDay` to calculate rewards accrued since your previous claim.
- **Use Case**: Perfect for simple, continuous APR-style rewards.

### 2. Pool Size Dependent Strategies

These are rewards where your share is determined by your stake's weight relative to the _total weight of all participants_ in the pool.

- **How it Works**: Your final reward can only be calculated _after_ the pool has ended. This is because the system needs to know the `totalStakeWeight` from all eligible participants to determine your proportional share of a fixed reward pot. This total weight is calculated and set by a trusted off-chain service after the pool concludes.
- **Claiming**: You can only claim rewards from these strategies **after the pool has ended** and been finalized. Any attempt to claim before that will fail. Since it's a one-time claim of a final share, you can only claim it once.
- **Use Case**: Ideal for distributing a fixed number of tokens among all active participants in an epoch or promotional event.

## Unified Claiming Process

Regardless of the strategy type, all rewards are claimed through a single function: `claimReward(poolId, strategyId, ...)`. The `RewardManager` contract handles all the complexity, automatically checking the pool's status, the strategy's type, and your eligibility before calculating and paying out the reward.

## How Staking Data Powers Rewards

The reward system is built directly on top of the staking system's data.

#### Day-Based Calculations

The core of the system's fairness comes from its use of **days** as the unit for all calculations.

- When you stake, the system records the `stakeDay`.
- All reward calculations are based on the number of full days your stake has been active within a pool's period.
- This ensures that rewards are predictable and not affected by the specific time of day you stake or claim.

#### Checkpoints

The staking system uses automatic "snapshots" called checkpoints every time you stake or unstake. This provides a secure and efficient way for the reward system to access your historical staking data, ensuring all calculations are accurate and fair.

## Getting Started

To begin earning rewards, simply stake your tokens. Your active stakes will automatically be eligible for any reward strategies that are running. Monitor the project's official announcements to learn about reward pools and strategies as they become available.
