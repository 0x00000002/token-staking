# Token Staking System

A secure, modular staking platform for tokens with time-locked commitments and a highly flexible reward system.

_To see the system's structure, view the [**System Architecture Diagram &rarr;**](docs/architecture.md)_

## Getting Started

To get started, find the path that best describes you:

- **I'm a User...**
  - ➡️ **& want to learn how to stake:** [**Start with the User Guide &rarr;**](docs/user_docs.md)
- **I'm a Developer...**
  - ➡️ **& want to integrate with the system:** [**Read the Architecture Overview &rarr;**](docs/architecture_overview.md)
- **I'm a Security Auditor...**
  - ➡️ **& want to review the system's security:** [**Begin with the Audit Dossier &rarr;**](audit/README.md)

---

## System Overview

This staking platform is built with three core principles: security, data integrity, and developer-friendliness.

### Key Features

- **Security First**: Multi-layered security with role-based access control, including a dedicated `MULTISIG_ROLE` for critical recovery operations. It is protected from reentrancy attacks and can be paused in emergencies.
- **Flexible Reward System**: A fully modular reward architecture with distinct contracts for scheduling (`PoolManager`), orchestration (`RewardManager`), and claim history (`ClaimsJournal`). This allows for creating complex reward scenarios with different strategies.
- **Advanced Data Management**: Uses a checkpoint system for highly-efficient historical balance queries (`O(log n)`), which provides the necessary data for fair and accurate reward calculations.
- **Developer Friendly**: A clear separation of concerns between the staking core and the reward system, providing well-defined interfaces to encourage ecosystem expansion.

## 🔗 Live Deployments & Status

### An example: THINK token on Sepolia Testnet

_(Note: These addresses may be from previous development deployments and could be outdated. Always use the latest deployment script for testing.)_

- **StakingVault**: [`0xE9b606be7c543B93D0FF5CE72A0E804d5f4147b2`](https://sepolia.etherscan.io/address/0xE9b606be7c543B93D0FF5CE72A0E804d5f4147b2/#code)
- **StakingStorage**: [`0xA71dF04aAC1DC6a0E62bC5a396ECaa976fF29f5A`](https://sepolia.etherscan.io/address/0xA71dF04aAC1DC6a0E62bC5a396ECaa976fF29f5A/#code)
- **PoolManager**: [`0x4a80D49aEdC75ebD2f6387C5dBb0ecd95F8A53f1`](https://sepolia.etherscan.io/address/0x4a80D49aEdC75ebD2f6387C5dBb0ecd95F8A53f1/#code)
- **StrategiesRegistry**: [`0x34D7377Ae437F4093f379878aa21753266707A7d`](https://sepolia.etherscan.io/address/0x34D7377Ae437F4093f379878aa21753266707A7d/#code)
- **RewardManager**: [`0x206f027fFB82d9daBA0Bb34810a2b6Be2B736788`](https://sepolia.etherscan.io/address/0x206f027fFB82d9daBA0Bb34810a2b6Be2B736788/#code)
- **ClaimsJournal**: [`0xfE2B9626f7e5D2140bF281aC5C521DA59417cF08`](https://sepolia.etherscan.io/address/0xfE2B9626f7e5D2140bF281aC5C521DA59417cF08/#code)
- **StandardStakingStrategy**: [`0xebbc67f2cffcd21d38fb82fa218ef60c42779d29`](https://sepolia.etherscan.io/address/0xebbc67f2cffcd21d38fb82fa218ef60c42779d29/#code)
- **FullStakingStrategy**: [`0xbdf3203f9808e2bc8bdc4c1ed30a2888c8d54787`](https://sepolia.etherscan.io/address/0xbdf3203f9808e2bc8bdc4c1ed30a2888c8d54787/#code)

### Project Status

The core staking and reward systems are feature-complete and ready for audit. The architecture supports two types of reward strategies, `POOL_SIZE_INDEPENDENT` (e.g., APR-based) and `POOL_SIZE_DEPENDENT` (e.g., shared reward pools), providing extensive flexibility for future reward programs.

## 📚 Full Documentation

For a detailed breakdown of all documentation, see the tables below.

### For Users

| Document                                       | Purpose                                              |
| ---------------------------------------------- | ---------------------------------------------------- |
| [User Guide](docs/user_docs.md)                | Basic staking concepts and step-by-step instructions |
| [Checkpoints Guide](docs/checkpoints_guide.md) | How your staking history is tracked for fair rewards |
| [Rewards Guide](docs/rewards_guide.md)         | Complete rewards system explanation                  |

### For Developers & Auditors

| Document                                                   | Purpose                                 |
| ---------------------------------------------------------- | --------------------------------------- |
| [Architecture Overview](docs/architecture_overview.md)     | System design and architecture overview |
| [Contract Specifications](docs/contract_specifications.md) | Detailed technical specifications       |
| [Audit Dossier](audit/README.md)                           | All security-related documentation      |

## 🛠️ Technology Stack

- **Smart Contracts**: Solidity ^0.8.20
- **Testing Framework**: Foundry
- **Security Libraries**: OpenZeppelin

---

# This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.

---

**Need help?** Start with the [User Guide](docs/user_docs.md) or [Architecture Overview](docs/architecture_overview.md) depending on your needs.
