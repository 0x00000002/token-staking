# Token Staking: Deployment Guide

## Overview

This guide covers the technical setup and deployment process for the entire Token Staking system, including the core staking and reward management contracts.

## Prerequisites

Foundry is required for testing and deployment. Ensure it is installed and up to date.

- Installation: `curl -L https://foundry.paradigm.xyz | bash`
- Update: `foundryup`

Dependencies are managed via `forge install`.

## Deployed Contracts (Mainnet)

- **StakingVault**: [`0x08071901a5c4d2950888ce2b299bbd0e3087d101`](https://etherscan.io/address/0x08071901a5c4d2950888ce2b299bbd0e3087d101#code)
- **StakingStorage**: [`0xfaa8a501cf7ffd8080b0864f2c959e8cbcf83030`](https://etherscan.io/address/0xfaa8a501cf7ffd8080b0864f2c959e8cbcf83030#code)

---

## Deployment Process

Deploying the system requires a specific sequence due to dependencies between contracts. The process involves deploying contracts in stages and then configuring their roles and inter-dependencies.

### Environment Variables Setup

Before deployment, set up the required environment variables.

```bash
# Network and Keys
export RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
export DEPLOYER_PK=YOUR_DEPLOYER_PRIVATE_KEY
export ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY

# Role Addresses
export ADMIN_ADDRESS=ADDRESS_FOR_ADMIN_ROLE # Should be a MultiSig
export MANAGER_ADDRESS=ADDRESS_FOR_MANAGER_ROLE
export CONTROLLER_ADDRESS=ADDRESS_FOR_CONTROLLER_ROLE # For PoolManager, an off-chain service
export MULTISIG_ADDRESS=ADDRESS_FOR_MULTISIG_ROLE # For StakingVault emergency recovery

# Token Addresses
export STAKING_TOKEN_ADDRESS=EXISTING_STAKING_TOKEN_ADDRESS
export REWARD_TOKEN_ADDRESS=EXISTING_REWARD_TOKEN_ADDRESS
```

### Deployment Order & Steps

The system must be deployed in the following order. It is highly recommended to use the deployment scripts which automate this process.

#### **Step 1: Deploy Core Staking Contracts**

These contracts handle the fundamental logic of staking and are independent of the reward system.

1.  **`StakingStorage.sol`**: Deployed first as it is the data layer.
2.  **`StakingVault.sol`**: Deployed second, linking to the `StakingStorage` address in its constructor.

#### **Step 2: Deploy Core Reward Contracts (Independent)**

These contracts from the reward system can be deployed next as they don't have circular dependencies.

3.  **`PoolManager.sol`**: Manages reward pool schedules.
4.  **`StrategiesRegistry.sol`**: A simple registry for strategy contracts.

#### **Step 3: Deploy Reward Orchestration Contracts (with Circular Dependency)**

This is a critical step that resolves the dependency between `RewardManager` and `ClaimsJournal`.

5.  **Deploy `RewardManager.sol`**:

    - The constructor is called with all required addresses (`PoolManager`, `StrategiesRegistry`, etc.) but with **`address(0)` as the placeholder for the `ClaimsJournal` address**.
    - This is possible because the `claimsJournal` state variable is not `immutable`.

6.  **Deploy `ClaimsJournal.sol`**:

    - The constructor is called with the **actual, now-existing address of the `RewardManager`**. This is valid because `RewardManager` has been deployed in the previous step.

7.  **Finalize the Connection**:
    - Call the **`setClaimsJournal(address)`** function on the deployed `RewardManager` contract.
    - Pass the actual address of the `ClaimsJournal` contract deployed in step 6.
    - This completes the two-way link between the contracts.

#### **Step 4: Deploy Strategy Contracts**

8.  Deploy all `IRewardStrategy` implementation contracts (e.g., `FullStakingStrategy.sol`, `StandardStakingStrategy.sol`).

#### **Step 5: Post-Deployment Configuration (Role Grants)**

After all contracts are deployed, roles must be granted to enable proper interaction.

1.  **Grant `CONTROLLER_ROLE` in `StakingStorage`**:

    - Recipient: `StakingVault` contract address.
    - Purpose: Allows the vault to write stake data.

2.  **Grant `REWARD_MANAGER_ROLE` in `ClaimsJournal`**:

    - Recipient: `RewardManager` contract address.
    - Purpose: Allows the reward manager to record claims in the ledger.

3.  **Grant `CONTROLLER_ROLE` in `PoolManager`**:

    - Recipient: Address of the off-chain service (`$CONTROLLER_ADDRESS`).
    - Purpose: Allows the service to set final pool weights.

4.  **(Optional) Register Strategies**:
    - Call `registerStrategy()` on `StrategiesRegistry` for each deployed strategy contract. This is typically done by the `MANAGER_ROLE`.

### Using Deployment Scripts (Recommended)

The repository contains scripts in the `/scripts` directory to automate this entire process.

- **`DeployStaking.s.sol`**: Deploys the full system, including a new staking token. Useful for testing.
- **`DeployWithExistingToken.s.sol`**: Deploys the full system using pre-existing token addresses (recommended for production).
- **`DeployRewardSystem.s.sol`**: Deploys only the reward system contracts, linking them to an existing, deployed staking system. Useful for upgrades or modular deployments.

To run a script:

```sh
forge script scripts/DeployRewardSystem.s.sol:DeployRewardSystem \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --broadcast \
  --verify
```

### Post-Deployment Verification

After deployment, run these checks:

1.  **Verify Controller Role**:
    ```bash
    cast call $STAKING_STORAGE_ADDRESS "hasRole(bytes32,address)" \
      $(cast keccak "CONTROLLER_ROLE") $STAKING_VAULT_ADDRESS
    ```
2.  **Verify Reward Manager Role**:
    ```bash
    cast call $CLAIMS_JOURNAL_ADDRESS "hasRole(bytes32,address)" \
      $(cast keccak "REWARD_MANAGER_ROLE") $REWARD_MANAGER_ADDRESS
    ```
3.  **Verify `claimsJournal` is set in `RewardManager`**:
    ```bash
    cast call $REWARD_MANAGER_ADDRESS "claimsJournal()"
    # Should return the address of the ClaimsJournal contract, not address(0)
    ```

## Security Notes

- Always use deployment scripts for production to minimize human error.
- Ensure role-holding addresses (`ADMIN_ADDRESS`, `MULTISIG_ADDRESS`) are secure multi-signature wallets.
- Thoroughly test the entire deployment on a testnet before moving to mainnet.
- Verify all deployed contracts on Etherscan for public transparency.
