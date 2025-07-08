# Off-Chain Epoch Calculation Service Guide

## 1. Objective

This guide provides the definitive plan for implementing an **Off-Chain Calculation Service**. This service is essential for calculating epoch-based rewards in a scalable and gas-efficient manner.

This new architecture leverages the existing design of `StakingStorage.sol` and the reversible compound `stakeId`. **No further on-chain changes are required.** The on-chain contracts are already sufficient to support this model.

The goal is to use an off-chain script to process the complete history of staking activity, calculate all participant weights for a given epoch, and then feed this data to the `RewardManager` contract for on-chain distribution.

This document should be used as the source of truth for an AI developer to implement the required off-chain service.

---

## 2. Architectural Overview

The core principle is to use the blockchain as a secure and verifiable database but perform all heavy, iterative calculations off-chain where computation is cheap.

- **On-Chain Contracts (`StakingStorage.sol`):** Provide efficient, direct-lookup functions (`getStakerInfo`, `getStake`).
- **Off-Chain Service (Node.js/Ethers.js):** Is responsible for discovery and iteration. It will:
  1.  Discover all stakers.
  2.  Iterate through every stake each staker has ever made.
  3.  Calculate epoch-specific weights for all participants.
  4.  Submit the final, aggregated data to the on-chain contracts.

---

## 3. Off-Chain Service Implementation Guide

**Technology:** Node.js, Ethers.js (or Viem).

- Consider merkle tree proofs for large-scale reward distributions and it's support by reward distribution contracts.

### **A. Script Configuration**

The script should be configured via a `.env` file or similar mechanism:

- `RPC_URL`: An RPC endpoint for the target network (e.g., from Infura/Alchemy).
- `STAKING_STORAGE_ADDRESS`: The deployed address of the `StakingStorage` contract.
- `REWARD_MANAGER_ADDRESS`: The deployed address of the `RewardManager`.
- `EPOCH_ID`: The ID of the epoch to process.
- `EPOCH_START_DAY`: The start day of the target epoch.
- `EPOCH_END_DAY`: The end day of the target epoch.
- `PRIVATE_KEY`: The private key of the admin wallet that will send the transactions.

### **B. Core Script Logic**

The script should be implemented as a class or a series of functions that perform the following steps in order.

**Step 1: Fetch All Staker Addresses**

- Connect to the blockchain using the RPC_URL.
- Instantiate the `StakingStorage` contract object.
- Call `getTotalStakersCount()` to get the total number of stakers.
- Call `getStakersPaginated()` in a loop, adjusting the `offset`, until all staker addresses have been fetched and stored in a local array.

**Step 2: Reconstruct and Fetch Full Stake History**

- Initialize an empty array to hold all stake data: `const allStakes = []`.
- For each `stakerAddress` fetched in Step 1:
  - Call `getStakerInfo(stakerAddress)` to get that user's `stakesCounter`.
  - Loop from `i = 0` to `stakesCounter - 1`.
  - Inside the loop, **locally reconstruct the `stakeId`** using the compound key formula: `const stakeId = generateCompoundId(stakerAddress, i)`. _(This helper function performs the same bitwise shifting as the on-chain `_generateStakeId` function)_.
  - Make a free `eth_call` to `getStake(stakeId)` to fetch the `Stake` struct data.
  - Push an object containing `{ staker: stakerAddress, stakeId: stakeId, ...stakeData }` into the `allStakes` array.
- At the end of this step, `allStakes` contains the complete history of every stake ever made.

**Step 3: Calculate Epoch-Specific Weights**

- Initialize an empty map to store the results: `const epochParticipants = new Map<stakerAddress, { totalWeight: BigNumber }>()`.
- Iterate through the `allStakes` array from Step 2.
- For each `stake`, calculate its effective duration within the target epoch:
  - `effectiveStart = Math.max(stake.stakeDay, EPOCH_START_DAY)`
  - `effectiveEnd = Math.min(stake.unstakeDay > 0 ? stake.unstakeDay : Infinity, EPOCH_END_DAY)`
  - `duration = effectiveEnd > effectiveStart ? effectiveEnd - effectiveStart : 0`
- If `duration > 0`, calculate the stake's weight: `weight = stake.amount * duration`.
- Add this `weight` to the staker's `totalWeight` in the `epochParticipants` map.

**Step 4: Prepare Transaction Data**

- Calculate the `totalEpochWeight` by summing all `totalWeight` values from the `epochParticipants` map.
- Get the array of `participant` addresses from the keys of the `epochParticipants` map.
- Store the final results in a local JSON file for auditing and reuse.

### **C. On-Chain Execution Logic**

Once the data is prepared, the script interacts with the `RewardManager` and `EpochManager`. The `RewardManager` function signature for `calculateEpochRewards` must be updated to accept the pre-calculated participant list.

**Step 5: Finalize the Epoch**

- Instantiate the `EpochManager` contract.
- Call `epochManager.finalizeEpoch(EPOCH_ID, participants.length, totalEpochWeight)`.
- This transaction must be sent first and complete successfully.

**Step 6: Distribute Rewards in Batches**

- **Modify `RewardManager.sol`:** The `calculateEpochRewards` function must be changed to accept the participant list directly.
  ```solidity
  // New signature in RewardManager.sol
  function calculateEpochRewards(uint32 epochId, address[] memory participants) external onlyRole(ADMIN_ROLE) {
      // ... loop over the provided `participants` array instead of paginating ...
  }
  ```
- **Off-Chain Script Action:**
  - Instantiate the `RewardManager` contract.
  - Break the `participants` array into batches of a reasonable size (e.g., 100).
  - Loop through the batches and call `rewardManager.calculateEpochRewards(EPOCH_ID, participant_batch_array)` for each one.
  - The script should wait for each transaction to be mined before sending the next one.

By following this revised guide, an AI developer can build an efficient and robust off-chain service that works in perfect harmony with the existing on-chain contracts.
