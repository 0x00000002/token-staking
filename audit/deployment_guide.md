# Token Staking: Deployment Guide

## Overview

This guide covers the technical setup, testing, and deployment of the Token Staking system. This documentation is intended for developers and system administrators.

## Development Setup

### Prerequisites

We use Foundry for testing and deployment. To install Foundry:

1. `$ curl -L https://foundry.paradigm.xyz | bash`
2. Restart terminal
3. `$ foundryup`
4. `$ cargo install --git https://github.com/gakonst/foundry --bin forge --locked`
5. `$ forge install`

More details on installation here: https://github.com/foundry-rs/foundry

### Dependencies

Install required OpenZeppelin libraries:

```sh
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

## Testing

Tests are located in the `/tests` folder and written in Solidity.

To run tests: `forge test -vvv`

## Deployment Process

The deployment consists of 3 main steps:

1. Deploy StakingStorage.sol
2. Deploy StakingVault.sol
3. Grant CONTROLLER_ROLE to vault in storage contract

### Environment Variables Setup

```bash
export RPC_URL=https://sepolia.infura.io/v3/**********
export DEPLOYER_PK=0x42aa06dc8c320e0255df8d95494f6a7b66e10fa30919a24ad910a6c2bdbcc8ee
export ADMIN=0xeb24a849E6C908D4166D34D7E3133B452CB627D2
export MANAGER=0x1Fb0E85b7Ba55F0384d0E06D81DF915aeb3baca3
export MULTISIG=0x... # Address for the separate, secure multisig wallet (granted separately after deployment)
export TOKEN=0x....
export REWARD_TOKEN=0x... # Reward token address (can be same as staking token)
export ETHERSCAN_API_KEY=
```

### Deployment Order

**IMPORTANT**: The complete system requires deploying components in this specific order:

1. **Core Staking System** (StakingStorage + StakingVault)
2. **Reward System** (StrategiesRegistry, EpochManager, GrantedRewardStorage, RewardManager)
3. **Strategy Implementations** (LinearAPRStrategy, EpochPoolStrategy)
4. **Integration Setup** (Role grants, strategy registrations)

### Method 1: Using Deployment Scripts (Recommended)

#### Option A: Deploy Complete System with Existing Token

```sh
forge script scripts/DeployCompleteSystem.s.sol:DeployCompleteSystem \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --broadcast \
  --verify
```

#### Option B: Deploy Core Staking Only (Legacy)

```sh
forge script scripts/DeployStaking.s.sol:DeployStaking \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --broadcast \
  --verify
```

### Method 2: Manual Deployment

#### Deploy StakingStorage

```sh
forge create --broadcast ./src/StakingStorage.sol:StakingStorage --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --constructor-args $ADMIN $MANAGER "0x0000000000000000000000000000000000000000"
```

Set the deployed contract address: `export STAKING_STORAGE=0x...`

#### Verify StakingStorage

```sh
forge verify-contract $STAKING_STORAGE \
  src/StakingStorage.sol:StakingStorage \
  --chain sepolia \
  --compiler-version v0.8.30 \
  --num-of-optimizations 200 \
  --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" $ADMIN $MANAGER "0x0000000000000000000000000000000000000000")
```

#### Deploy StakingVault

```sh
forge create --broadcast ./src/StakingVault.sol:StakingVault --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --constructor-args $TOKEN $STAKING_STORAGE $ADMIN $MANAGER
```

Set the vault address: `export STAKING_VAULT=0x....`

#### Verify StakingVault

```sh
forge verify-contract $STAKING_VAULT \
  src/StakingVault.sol:StakingVault \
  --chain sepolia \
  --compiler-version v0.8.30 \
  --num-of-optimizations 200 \
  --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address)" $TOKEN $STAKING_STORAGE $ADMIN $MANAGER)
```

#### Setup Roles

Grant CONTROLLER_ROLE to vault in storage contract:

```bash
cast send $STAKING_STORAGE "grantRole(bytes32,address)" \
  0x7b765e0e932d348852a6f810bfa1ab891615cb53504089c3e26b8c96ca14c3d5 $STAKING_VAULT \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PK
```

Grant MULTISIG_ROLE to secure multisig wallet:

```bash
cast send $STAKING_VAULT "grantRole(bytes32,address)" \
  0xa5a0b70b385ff7611cd3840916bd08b10829e5bf9e6637cf79dd9a427fc0e2ab $MULTISIG \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PK
```

Grant claiming contract role (if needed):

```bash
export CLAIMING=0x0b9f301DB9cDA7C8B736927eF3E745De12b81581
cast send $STAKING_VAULT "grantRole(bytes32,address)" \
  0x7b86e74b5b2cbeb359a5556f7b8aa26ec9fb74773c1c7b2dc16e82d368c70627 $CLAIMING \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PK
```

## Testing Deployment

### Basic Functionality Test

```bash
# Check if roles are properly set
cast call $STAKING_STORAGE "hasRole(bytes32,address)" \
  0x7b765e0e932d348852a6f810bfa1ab891615cb53504089c3e26b8c96ca14c3d5 $STAKING_VAULT \
  --rpc-url $RPC_URL

# Should return true (0x0000000000000000000000000000000000000000000000000000000000000001)
```

### Test Staking (if you have tokens)

```bash
# First approve tokens
cast send $TOKEN "approve(address,uint256)" $STAKING_VAULT 1000000000000000000 \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PK

# Stake tokens (1 token, 30 days lock)
cast send $STAKING_VAULT "stake(uint128,uint16)" 1000000000000000000 30 \
  --rpc-url $RPC_URL --private-key $DEPLOYER_PK
```

## Available Deployment Scripts

### 1. DeployStaking.s.sol

- Deploys new token and complete staking system
- Good for testing and new deployments
- Automatically sets up all roles, including the `MULTISIG_ROLE`

### 2. DeployWithExistingToken.s.sol

- Uses existing token (like USDC)
- Reads configuration from environment variables
- Provides verification commands
- Automatically sets up all roles, including the `MULTISIG_ROLE`
- **Recommended for production deployments**

### 3. DeployModularStaking.s.sol

- **DEPRECATED** - Legacy script for old architecture
- Do not use for current system

## Security Notes

- Always verify contract addresses before interacting
- Keep private keys secure and never commit them to version control
- Test thoroughly on testnets before mainnet deployment
- Ensure proper role assignments are completed after deployment
- Verify all contracts on Etherscan for transparency
- Use deployment scripts instead of manual deployment when possible
- Test basic functionality after deployment before going live
