## Setting ENV variables

```sh
export ADMIN=0xe58dd2463dfb9d188451bcf1bfae3997b92952aa
export MANAGER=0x70Ac852593D86D7274326cC75473982c8fec7d7b
export RPC_URL=https://sepolia.infura.io/v3/....
export STAKING_STORAGE=0xA71dF04aAC1DC6a0E62bC5a396ECaa976fF29f5A
export STRATEGIES_REGISTRY=0x43c4179cdF783dB5a3fD9F2cDe5E2F77acD487e8
export CLAIMS_JOURNAL=0xEaA00BE4419c377e6a1F633a99F0A1c3554B4F62
export POOL_MANAGER=0x79eF3e3a283F9a8Ef87115Dab32C0AfD206daDE1
```

## Automated deployment

```sh
forge script ./scripts/DeployRewardSystem.s.sol:DeployRewardSystem \
  --rpc-url $RPC_URL \
  --broadcast --verify --verifier sourcify
```

## Manual Deployments

```sh
forge create ./src/reward-system/ClaimsJournal.sol:ClaimsJournal --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $ADMIN

```

```sh
forge create ./src/reward-system/RewardManager.sol:RewardManager --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PK \
  --broadcast --verify --verifier sourcify \
  --constructor-args $ADMIN $MANAGER $STAKING_STORAGE $STRATEGIES_REGISTRY $CLAIMS_JOURNAL $POOL_MANAGER
```

You'll also need to setup roles on etherscan or via forge:

```sh
cast send $CONTRACT_ADRESS "approve(address,uint256)" $ADDRESS $AMOUNT \
  --private-key $DEPLOYER_PK --rpc-url $RPC_URL --gas-limit 750000
```
