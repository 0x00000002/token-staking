# Staking Reward System: Approach and Workflow

## Overview

This document defines the comprehensive approach for implementing a retroactive, gas-efficient reward system for the Token staking platform. The system supports both immediate and epoch-based reward strategies while maintaining full historical accuracy and user affordability.

## Core Concepts and Vocabulary

#### Pool

- **Definition**: The total amount of rewards available for distribution by a specific strategy during a defined period. Pool size determination varies by strategy type:
  - Immediate Strategies: Formula-based or unlimited (e.g., "10% APR on all stakes")
  - Epoch-Based Strategies: Fixed amount set by admin after epoch ends (e.g., "$100K distributed among epoch participants")

### **Strategy Types**

#### **Immediate Strategies**

- **Definition**: Reward strategies that can be calculated at any time using historical staking data
- **Characteristics**:
  - Formula-based calculations (e.g., APR, time-weighted bonuses)
  - Predictable outcomes for users
  - Can be applied retroactively to any time period
  - Pool size is unlimited or formula-determined
- **Examples**:
  - Linear APR Strategy: "10% annual return for all stakes"
  - Time-weighted Strategy: "Base 5% + 1% bonus per month staked"
  - Tiered Strategy: "8% for stakes under 1000, 12% for stakes over 1000"

#### **Epoch-Based Strategies**

- **Definition**: Reward strategies with fixed time periods where total rewards are distributed among epoch participants
- **Characteristics**:
  - Fixed pool size distributed among participants
  - Competitive nature (more participants = smaller individual rewards)
  - Must wait for epoch completion before calculation
  - Pool size determined after epoch ends
- **Examples**:
  - Monthly Pool Strategy: "$100K distributed monthly among all stakers"
  - Quarterly Tournament: "$500K divided based on stake duration and amount"
  - Early Adopter Bonus: "First 1000 stakers share $50K pool"

### **Epochs**

- **Definition**: Discrete time periods with specific start and end dates for epoch-based strategies
- **Purpose**:
  - Announce reward rules in advance
  - Allow users to plan staking strategy across multiple epochs
  - Enable competitive pool-based rewards
  - Provide budget control for admins

### **Reward Granting vs Claiming**

- **Granting**: Admin process of calculating and assigning rewards to users (pre-calculation)
- **Claiming**: User process of withdrawing granted rewards from the contract
- **Benefit**: Separates expensive calculations (paid by admin) from cheap claims (paid by users)

### **Retroactive Rewards**

- **Definition**: Calculating and granting rewards for historical staking periods
- **Scope**: Can apply both immediate and epoch-based strategies to past staking activity
- **Limitation**: Epoch-based strategies can only be applied retroactively if epoch parameters are defined

## System Architecture Principles

### **1. Pre-Calculation Philosophy**

- **Problem Solved**: Eliminates expensive real-time calculations during user interactions
- **Approach**: Admin triggers batch calculations, users get O(1) lookups
- **Benefit**: 30× gas reduction for users, unlimited strategy complexity

### **2. Dual Calculation Mechanics**

- **Immediate Strategies**: Can be calculated anytime using historical checkpoint data
- **Epoch-Based Strategies**: Must wait for epoch completion and admin-set pool sizes
- **Unified Interface**: Same claiming mechanism regardless of strategy type

### **3. Historical Data Integration**

- **Leverages Existing Checkpoints**: Uses the sophisticated checkpoint system already built
- **Binary Search Optimization**: Efficient historical balance queries
- **Immutable Records**: Ensures fair and verifiable reward calculations

### **4. Gas Efficiency Design**

- **Admin Pays Once**: Expensive calculations funded by project, not users
- **User Pays Little**: Simple lookups and transfers for claiming
- **Batch Processing**: Spreads calculation costs across multiple transactions

## Reward Workflow

### **Immediate Strategy Workflow**

#### **Phase 1: Strategy Deployment**

1. **Admin deploys strategy contract** (e.g., LinearAPRStrategy)
2. **Admin registers strategy** in StrategiesRegistry
3. **Strategy becomes available** for retroactive calculation

#### **Phase 2: Reward Calculation (Can Happen Anytime)**

1. **Admin triggers calculation** for specific time period
2. **System processes all eligible stakes** using checkpoint data
3. **Rewards are granted** to user accounts
4. **Users notified** that rewards are available

#### **Phase 3: User Claiming**

1. **Users query claimable rewards** (cheap O(1) lookup)
2. **Users submit claim transaction** (efficient token transfer)
3. **Rewards marked as claimed** in storage

### **Epoch-Based Strategy Workflow**

#### **Phase 1: Epoch Announcement**

1. **Admin announces new epoch** with rules and estimated pool size
2. **Epoch rules published** (start date, end date, participation criteria)
3. **Users prepare staking strategy** based on announced rules

#### **Phase 2: Epoch Execution**

1. **Epoch starts automatically** on specified date
2. **System tracks all participants** using checkpoint system
3. **Users can stake/unstake** during epoch (affects their participation)
4. **Epoch ends automatically** on specified date

#### **Phase 3: Pool Determination**

1. **Admin reviews epoch participation** and determines final pool size
2. **Pool size may differ** from estimated size based on participation/budget
3. **Pool size locked** for calculation

#### **Phase 4: Reward Calculation**

1. **Admin triggers epoch calculation** using actual pool size
2. **System calculates user shares** based on their epoch participation
3. **Rewards granted** to all epoch participants
4. **Epoch marked as finalized**

#### **Phase 5: User Claiming**

1. **Users query claimable epoch rewards**
2. **Users claim rewards** (same mechanism as immediate strategies)

## User Experience Patterns

### **For Immediate Strategies**

- **Predictable Returns**: Users know exact formula before staking
- **Instant Gratification**: Rewards appear immediately after admin calculation
- **Retroactive Benefits**: Can receive rewards for past staking periods
- **Planning**: Users can calculate expected returns in advance

### **For Epoch-Based Strategies**

- **Competitive Elements**: Rewards depend on total participation
- **Advance Planning**: Users can plan across multiple epochs
- **Variable Returns**: Actual rewards depend on pool size and competition
- **Community Aspect**: Rewards tied to overall ecosystem participation

## Admin Responsibilities

### **Strategy Management**

- **Deploy new strategies** as smart contracts
- **Register strategies** in the system
- **Configure strategy parameters** (rates, criteria, etc.)
- **Activate/deactivate strategies** as needed

### **Reward Calculation**

- **Trigger immediate strategy calculations** for any time period
- **Manage epoch lifecycles** (announce, monitor, finalize)
- **Set epoch pool sizes** based on budget and participation
- **Execute batch calculations** efficiently to minimize gas costs

### **System Maintenance**

- **Monitor system health** and gas usage
- **Handle emergency situations** (pause/resume capabilities)
- **Manage reward token funding** for distributions
- **Coordinate with community** on reward strategy updates

## Security and Risk Management

### **Calculation Integrity**

- **Immutable historical data** via checkpoint system
- **Verifiable calculations** using transparent formulas
- **Audit trails** for all reward grants and claims
- **Multiple verification methods** for critical calculations

### **Access Controls**

- **Role-based permissions** for different admin functions
- **Multi-sig requirements** for critical operations
- **Emergency pause mechanisms** for system protection
- **Gradual rollout capabilities** for new features

### **Economic Safeguards**

- **Budget controls** for epoch-based strategies
- **Rate limits** on immediate strategies
- **Pool size validation** before epoch calculations
- **Overflow protection** in all mathematical operations

## Technical Foundations

### **Checkpoint System Integration**

- **Leverages existing infrastructure** for historical data
- **Binary search optimization** for efficient queries
- **Automatic snapshot creation** on every stake/unstake
- **Gas-efficient historical lookups**

### **Storage Optimization**

- **Struct packing** for minimal storage costs
- **Efficient mappings** for quick user lookups
- **Batch processing** to amortize gas costs
- **Event emission** for off-chain tracking

### **Scalability Design**

- **Paginated processing** for large user sets
- **Parallel strategy execution** where possible
- **Incremental calculation** for large time periods
- **Caching mechanisms** for repeated calculations

## Future Extensibility

### **Multi-Token Rewards**

- **Framework ready** for different reward tokens
- **Strategy-specific tokens** for ecosystem partnerships
- **Governance token distribution** through reward strategies

### **Advanced Features**

- **Compound reward options** (auto-restaking)
- **Cross-strategy interactions** (bonus multipliers)
- **Governance integration** (voting-based strategy selection)
- **Analytics dashboard** for reward **optimization**

### **Integration Capabilities**

- **External protocol rewards** through strategy framework
- **DeFi yield farming** integration possibilities
- **Cross-chain reward distribution** potential
- **Partnership reward programs** through epoch system

## Success Metrics

### **Gas Efficiency**

- **Target: 30× reduction** in user gas costs for reward queries
- **Target: 4× reduction** in user gas costs for claiming
- **Target: <2M gas** for admin calculations per epoch

### **User Experience**

- **<5 second response time** for reward queries
- **<30 second transaction time** for claiming
- **>95% uptime** for reward calculation system

### **System Performance**

- **Support 10,000+ concurrent users** without degradation
- **Process 100+ strategies** simultaneously
- **Handle 1 year+ historical data** efficiently

---

This approach provides the foundation for a sophisticated, efficient, and user-friendly reward system that scales with the platform's growth while maintaining fairness and transparency for all participants.
