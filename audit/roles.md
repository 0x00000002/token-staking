# Access Control System: Developer Notes for Auditors

## Our Approach to Access Control

The Token Staking system implements a carefully designed access control architecture using OpenZeppelin's AccessControl pattern. We've structured roles across two main contracts - StakingVault and StakingStorage - to achieve separation of concerns and granular permission management.

## System Architecture Overview

Our role system is distributed across two contracts:

1. **StakingVault**: Main user interface and business logic
2. **StakingStorage**: Data persistence and historical tracking

Each contract maintains its own set of roles while working together through the CONTROLLER_ROLE mechanism.

## Role Architecture and Rationale

### DEFAULT_ADMIN_ROLE (`0x00`)

**Available in:** Both StakingVault and StakingStorage

This role serves as the role manager, responsible for assigning other roles and critical system configurations. In production, this role will be assigned to a secure multi-signature wallet controlled by our core team.

**StakingVault Permissions:**

**Design rationale:** We've intentionally limited this role to role management rather than day-to-day operations or emergency recovery. This ensures that even if the admin role is compromised, the attacker cannot directly manipulate stakes without first granting themselves additional roles (which should be noticeable through events).

### MANAGER_ROLE (`keccak256("MANAGER_ROLE")`)

**Available in:** Both StakingVault and StakingStorage

The manager role handles day-to-day operational adjustments and system maintenance.

**StakingVault Permissions:**

```solidity
function pause() external onlyRole(MANAGER_ROLE)
function unpause() external onlyRole(MANAGER_ROLE)
```

**Design rationale:** We separated these functions into a dedicated role to allow our operations team to make routine adjustments without requiring admin intervention. This reduces friction for necessary operational changes while maintaining security boundaries.

### MULTISIG_ROLE (`keccak256("MULTISIG_ROLE")`)

**Available in:** StakingVault only

This is a highly specialized and powerful role intended exclusively for a secure, multi-signature wallet. Its sole purpose is to execute the emergency token recovery, providing a safeguard against accidentally sent funds.

**StakingVault Permissions:**

```solidity
function emergencyRecover(IERC20 token_, uint256 amount) external onlyRole(MULTISIG_ROLE)
```

**Design rationale:** We have isolated the `emergencyRecover` function from the `DEFAULT_ADMIN_ROLE` to enforce the principle of least privilege. By requiring a unique, hardware-secured role, we significantly reduce the risk associated with the compromise of any single administrative or operational key. This ensures that the recovery of funds is a deliberate, multi-party action.

### CONTROLLER_ROLE (`keccak256("CONTROLLER_ROLE")`)

**Available in:** StakingStorage only

This role allows the StakingVault to modify storage state. This is the key integration point between our two contracts.

**StakingStorage Permissions:**

```solidity
function createStake(address staker, bytes32 id, uint128 amount, uint16 daysLock, bool isFromClaim) external onlyRole(CONTROLLER_ROLE)
function removeStake(bytes32 id) external onlyRole(CONTROLLER_ROLE)
```

**Design rationale:** We've created a dedicated controller role to maintain strict boundaries between the vault (business logic) and storage (data persistence). Only the designated controller (StakingVault) can modify stake records, preventing unauthorized state manipulation while enabling clean separation of concerns.

### CLAIM_CONTRACT_ROLE (`keccak256("CLAIM_CONTRACT_ROLE")`)

**Available in:** StakingVault only

This role enables external claiming contracts to stake on behalf of users through our integration system.

**StakingVault Permissions:**

```solidity
function stakeFromClaim(address staker, uint128 amount, uint16 daysLock) external onlyRole(CLAIM_CONTRACT_ROLE)
```

**Design rationale:** We've isolated the claim-to-stake functionality to enable integration with external claiming systems while maintaining security. Only authorized claiming contracts can stake on behalf of users, and these stakes are properly marked for tracking purposes.

## Production Deployment Plans

In our production environment:

1. **DEFAULT_ADMIN_ROLE**: Assigned to a secure multisig wallet (core team members)
2. **MANAGER_ROLE**: Assigned to a dedicated operations wallet with enhanced security
3. **MULTISIG_ROLE**: Assigned to a separate, highly secure multisig wallet, distinct from the admin multisig.
4. **CONTROLLER_ROLE**: Assigned exclusively to the StakingVault contract address
5. **CLAIM_CONTRACT_ROLE**: Assigned to authorized external claiming contracts

## Contract Integration and Setup

### Initial Deployment Sequence

1. **Deploy StakingStorage** with admin and manager addresses
2. **Deploy StakingVault** with token, storage, admin, and manager addresses
3. **Grant CONTROLLER_ROLE** to StakingVault in StakingStorage

### Constructor Role Assignments

**StakingVault Constructor:**

```solidity
constructor(
    IERC20 _token,
    address _storage,
    address _admin,
    address _manager
) {
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(MANAGER_ROLE, _manager);
    _grantRole(CONTROLLER_ROLE, _admin);
    _grantRole(MULTISIG_ROLE, _admin);
    // ... other initialization
}
```

**StakingStorage Constructor:**

```solidity
constructor(address admin, address manager, address vault) {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(MANAGER_ROLE, manager);
    _grantRole(CONTROLLER_ROLE, vault); // StakingVault
    // ... other initialization
}
```

### Post-Deployment Setup

1. **Verify Controller Role**: Ensure StakingVault has CONTROLLER_ROLE in StakingStorage
2. **Grant Claim Role**: Admin grants CLAIM_CONTRACT_ROLE to authorized claiming contracts
3. **Role Verification**: Test that all role assignments work correctly

## Common Operations and Workflow

### Operational Workflows

1. **Regular Operations** (pause/unpause): Performed by MANAGER_ROLE
2. **Emergency Recovery** (stuck token recovery): Requires the dedicated `MULTISIG_ROLE`.
3. **Role Management** (adding/removing roles): Requires DEFAULT_ADMIN_ROLE
4. **Stake Operations** (create/remove stakes): Performed by CONTROLLER_ROLE (StakingVault)
5. **Claim Integration** (staking from external claims): Performed by CLAIM_CONTRACT_ROLE

### Security Boundaries

- **Business Logic ↔ Data Layer**: Enforced through CONTROLLER_ROLE
- **User Operations ↔ Admin Operations**: Separated through role-based access
- **External Integrations ↔ Core System**: Controlled through CLAIM_CONTRACT_ROLE

## Security Considerations for Auditors

When reviewing our role implementation, we'd appreciate focus on:

### 1. Role Separation and Boundaries

- **Cross-Contract Security**: Are the interactions between StakingVault and StakingStorage properly secured?
- **CONTROLLER_ROLE Isolation**: Is the controller role properly restricted to prevent unauthorized storage access?
- **Role Escalation**: Are there any vectors where a lower-privileged role could gain higher privileges?

### 2. Integration Security

- **Claim Contract Integration**: Is the CLAIM_CONTRACT_ROLE properly restricted and validated?
- **Storage Contract Trust**: Are we making appropriate trust assumptions about the storage contract?

### 3. Access Control Implementation

- **Missing Access Controls**: Have we overlooked any sensitive functions that should be role-protected?
- **Role Assignment Logic**: Are initial role assignments in constructors secure?
- **Event Emissions**: Should we add events for role-related actions to improve transparency?

### 4. Operational Security

- **Emergency Procedures**: Are emergency functions (pause, recovery) properly protected?
- **Role Management**: Is the role management system secure against misuse?

## Role Hash Values

For verification and integration purposes:

```solidity
DEFAULT_ADMIN_ROLE = 0x0000000000000000000000000000000000000000000000000000000000000000
MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08
CONTROLLER_ROLE = 0x7b765e0e932d348852a6f810bfa1ab891615cb53504089c3e26b8c96ca14c3d5
CLAIM_CONTRACT_ROLE = 0x7b86e74b5b2cbeb359a5556f7b8aa26ec9fb74773c1c7b2dc16e82d368c70627
MULTISIG_ROLE = 0xa5a0b70b385ff7611cd3840916bd08b10829e5bf9e6637cf79dd9a427fc0e2ab
```

## Testing and Verification

### Role Assignment Verification

```bash
# Check if StakingVault has CONTROLLER_ROLE in StakingStorage
cast call $STAKING_STORAGE "hasRole(bytes32,address)" \
  0x7b765e0e932d348852a6f810bfa1ab891615cb53504089c3e26b8c96ca14c3d5 $STAKING_VAULT

# Check if claim contract has CLAIM_CONTRACT_ROLE in StakingVault
cast call $STAKING_VAULT "hasRole(bytes32,address)" \
  0x7b86e74b5b2cbeb359a5556f7b8aa26ec9fb74773c1c7b2dc16e82d368c70627 $CLAIM_CONTRACT
```

### Functional Testing

We recommend testing:

1. Role-protected functions reject unauthorized callers
2. Cross-contract role validation works correctly
3. Role assignment and revocation function properly
4. Emergency functions are properly protected

## Design Philosophy

Our role system balances security, operational efficiency, and architectural clarity:

- **Minimal Privilege**: Each role has only the permissions necessary for its function
- **Clear Boundaries**: Roles clearly separate different operational concerns
- **Defense in Depth**: Multiple layers of protection prevent unauthorized access
- **Operational Flexibility**: Roles enable secure delegation of operational tasks

We believe this design provides robust security while maintaining the flexibility needed for a production staking system.
