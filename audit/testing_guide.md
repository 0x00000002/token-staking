# Token Staking System: Testing Guide

## Overview

This guide establishes the workflow for achieving and validating test coverage using a human/AI/forge collaborative approach. It defines how to use traceability matrices to identify gaps without relying on subjective assessments.

## Testing Philosophy

### Core Principles

1. **Single Source of Truth**: Only `forge coverage` output determines actual coverage
2. **Pure Traceability**: Documentation maps relationships, never claims completion status
3. **Gap-Driven Testing**: Missing mappings = missing tests
4. **Bidirectional Validation**: Business requirements ↔ Implementation functions

### Documentation Hierarchy

```
Business Requirements (use_cases.md)
           ↓
Test Scenarios (test_cases.md)
           ↓
Implementation Mapping (test_coverage_matrix.md)
           ↓
Actual Coverage (test_coverage.md - forge generated)
```

## Workflow Process

### Phase 1: Identify Coverage Gaps

#### Step 1: Extract Function Inventory

```bash
# Generate function list per contract
forge inspect RewardBookkeeper methods > functions.json
# Parse public/external functions only
```

#### Step 2: Check Traceability Matrix

- Open `test_coverage_matrix.md`
- Find functions with "(none)" in test case mapping
- Functions without mapped test cases = potential gaps

#### Step 3: Validate with Forge

```bash
# Generate actual coverage
forge coverage --no-match-coverage "tests/helpers/" > audit/test_coverage.md
# Compare matrix mappings vs actual coverage percentages
```

#### Step 4: Gap Analysis Formula

```
Missing Tests = Functions in Matrix - Functions with Test Cases
Coverage Gap = (100% - Forge Coverage %) = Work Needed
```

### Phase 2: Create Missing Test Cases

#### Step 1: Add Test Cases to test_cases.md

For each unmapped function, create specific test case:

```markdown
### TC_GRS01: Grant Reward Operations (UC26)

**Actor**: System (CONTROLLER_ROLE)
**Description**: Validate reward granting functionality
**Contract**: RewardBookkeeper

**Test Scenarios**:

1. Successful reward granting with valid parameters
2. Unauthorized access attempt (should revert)
3. Event emission verification
4. Data integrity validation
```

#### Step 2: Update Traceability Matrix

Map new test cases to functions:

```markdown
| RewardBookkeeper | `grantReward()` | TC_R16, TC_GRS01 |
```

#### Step 3: Implement Tests

Create test file following mapped test cases.

#### Step 4: Validate Results

```bash
forge coverage --no-match-coverage "tests/helpers/"
# Verify coverage percentage increased
```

### Phase 3: Bidirectional Validation

#### Top-Down: Business to Implementation

1. **Use Case** → **Test Cases** → **Functions**
2. Ensure every business requirement has implementing functions
3. Ensure every function serves a business purpose

#### Bottom-Up: Implementation to Business

1. **Function** → **Test Cases** → **Use Cases**
2. Ensure every public function has test coverage
3. Ensure every function traces to business requirement

## Traceability Matrix Usage

### Three-Level Mapping Structure

#### Level 1: Business to Test Cases

```markdown
| Use Case                        | Description           | Test Cases                          |
| ------------------------------- | --------------------- | ----------------------------------- |
| UC26: Reward Storage Management | Track granted rewards | TC_R16, TC_R17, TC_R18, TC_GRS01-05 |
```

#### Level 2: Test Cases to Functions

```markdown
| Test Case | Contract         | Functions                           |
| --------- | ---------------- | ----------------------------------- |
| TC_GRS01  | RewardBookkeeper | `grantReward()`, `getUserRewards()` |
```

#### Level 3: Functions to Test Cases

```markdown
| Contract         | Function                   | Test Cases       |
| ---------------- | -------------------------- | ---------------- |
| RewardBookkeeper | `grantReward()`            | TC_R16, TC_GRS01 |
| RewardBookkeeper | `getUserClaimableAmount()` | (none)           |
```

### Gap Detection Rules

#### Business Coverage Gaps

- Use Case with no Test Cases = Missing business logic tests
- Test Case with no Use Case = Potentially unnecessary test

#### Implementation Coverage Gaps

- Function with no Test Cases = Missing unit tests
- Test Case with no Functions = Potentially invalid test

#### Integration Coverage Gaps

- Function tested only via other contracts = Missing direct tests
- Function with only unit tests = Missing integration validation

## AI Assistant Guidelines

### DO: Help Identify Gaps

```
AI Task: "Check test_coverage_matrix.md and list all functions with '(none)' in test cases column"
AI Task: "Compare forge coverage output with matrix to find discrepancies"
AI Task: "Identify use cases that don't map to any test cases"
```

### DON'T: Make Coverage Claims

```
❌ "RewardBookkeeper has 100% coverage"
❌ "All security tests are complete"
❌ "System is audit-ready"
```

### DO: Provide Objective Analysis

```
✅ "Function X has no mapped test cases in the matrix"
✅ "Forge reports 67% coverage for Contract Y"
✅ "5 functions need test case mappings"
```

## Human Validation Process

### Before Writing Tests

1. **Gap Identification**: Use matrix to find unmapped functions
2. **Business Validation**: Ensure test cases trace to use cases
3. **Scope Definition**: Define specific test scenarios per function

### After Writing Tests

1. **Coverage Validation**: Run `forge coverage` and verify improvement
2. **Matrix Update**: Add new test case mappings
3. **Integration Check**: Ensure new tests don't break existing functionality

### Audit Preparation

1. **Complete Matrix**: Every function has mapped test cases
2. **High Coverage**: Forge reports >95% for critical contracts
3. **Business Traceability**: Every use case has implementing test cases

## Coverage Targets by Contract Type

### Critical Contracts (Security-Sensitive)

- **Target**: >95% line coverage, >90% branch coverage
- **Contracts**: StakingVault, RewardManager, RewardBookkeeper
- **Priority**: All public functions must have direct unit tests

### Support Contracts (Lower Risk)

- **Target**: >85% line coverage, >80% branch coverage
- **Contracts**: PoolManager, StrategiesRegistry
- **Priority**: Integration tests acceptable for some functions

### Library Contracts (Pure Logic)

- **Target**: >90% line coverage, >85% branch coverage
- **Contracts**: Flags library, Strategy implementations
- **Priority**: Focus on mathematical correctness and edge cases

## Quality Gates

### Before Merge

- [ ] All new functions have test case mappings in matrix
- [ ] Forge coverage maintains or improves current levels
- [ ] New test cases trace to business use cases
- [ ] No functions remain with "(none)" in critical contracts

### Before Audit

- [ ] Matrix shows function → test case mappings
- [ ] Forge coverage >95% for security-critical contracts
- [ ] All use cases have implementing test scenarios
- [ ] Integration and unit tests both present for critical paths

## Tools and Commands

### Coverage Generation

```bash
# Generate detailed coverage report
forge coverage --report lcov

# Generate summary for documentation
forge coverage --no-match-coverage "tests/helpers/" > audit/test_coverage.md

# Check specific contract coverage
forge coverage --match-contract RewardBookkeeper
```

### Function Extraction

```bash
# List all external/public functions
forge inspect ContractName methods

# Get function signatures
cast interface path/to/Contract.sol
```

### Test Execution

```bash
# Run specific test file
forge test --match-path tests/unit/RewardManager.t.sol

# Run tests for specific contract
forge test --match-contract RewardManagerTest

# Run with gas reporting
forge test --gas-report
```

## Example Workflow: Adding PoolManager Tests

### Step 1: Identify Gap

```
Matrix shows: PoolManager.getPoolsByDateRange() → (none)
Forge shows: PoolManager 75% coverage
Gap: Need test for getPoolsByDateRange()
```

### Step 2: Create Test Case

Add to `test_cases.md`:

```markdown
### TC_R11: Query Pools by Date Range

- Test with a date range that includes multiple pools
- Test with a date range that includes no pools
- Test boundary conditions (start/end days matching the range)
```

### Step 3: Update Matrix

Update `test_coverage_matrix.md`:

```markdown
| PoolManager | `getPoolsByDateRange(...)` | TC_R11 |
```

### Step 4: Implement Test

Create or update `tests/unit/PoolManager.t.sol` with TC_R11 implementation.

### Step 5: Validate

```bash
forge coverage --match-contract PoolManager
# Verify coverage improved from 75% to higher percentage
```

## Success Metrics

### Documentation Quality

- Complete bidirectional traceability (Use Cases ↔ Functions)
- No assessment claims in documentation
- Clear gap identification process

### Test Quality

- Forge coverage >95% for critical contracts
- All public functions have mapped test cases
- Business requirements fully tested

### Process Quality

- Repeatable gap identification
- Objective validation via forge
- Clear workflow for humans and AI

---

This guide ensures systematic test coverage without subjective assessments, using forge as the single source of truth while maintaining traceability from business requirements to implementation details.
