# Staking System: Audit Dossier

| Document                                            | Purpose                                                                                       |
| :-------------------------------------------------- | :-------------------------------------------------------------------------------------------- |
| **[System Architecture](system_architecture.md)**   | A detailed technical breakdown of the contracts, data structures, and their interactions.     |
| **[Security Roles](roles.md)**                      | Description of the access control system, roles, and their specific permissions.              |
| **[Use Cases](use_cases.md)**                       | Functional requirements and user scenarios that define the system's expected behavior.        |
| **[Test Cases](test_cases.md)**                     | List of test cases derived from the use cases.                                                |
| **[Test Coverage Matrix](test_coverage_matrix.md)** | A matrix that maps requirements and functions to specific test cases, ensuring full coverage. |
| **[Gas Report](gas_report.md)**                     | Automatically generated gas usage report for all contract functions.                          |
| **[Test Coverage Report](test_coverage.md)**        | Automatically generated test coverage report from `forge coverage`.                           |
| **[Deployment Guide](deployment_guide.md)**         | Instructions for deploying the contracts and configuring all roles correctly.                 |

## Recommended Audit Workflow

1.  **Understand the Big Picture**: Start with the **[System Architecture](system_architecture.md)** to grasp the overall design and separation of concerns.
2.  **Review Access Controls**: Read the **[Security Roles](roles.md)** guide to understand the permission model.
3.  **Analyze Expected Behavior**: Review the **[Use Cases](use_cases.md)** and **[Test Cases](test_cases.md)** to see how the system is intended to function and handle errors.
4.  **Verify Test Coverage**: Use the **[Test Coverage Matrix](test_coverage_matrix.md)** to trace requirements to their corresponding tests and identify any potential gaps.
5.  **Check Deployment Security**: Refer to the **[Deployment Guide](deployment_guide.md)** to ensure the production setup process is secure.
