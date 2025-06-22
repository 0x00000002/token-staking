# Staking System: Audit Dossier

This document is the central entry point for security auditors. It contains a curated list of all documentation relevant to understanding the system's architecture, security controls, and test coverage.

## Core Audit Documents

| Document                                            | Purpose                                                                                          |
| :-------------------------------------------------- | :----------------------------------------------------------------------------------------------- |
| **[System Architecture](system_architecture.md)**   | A detailed technical breakdown of the contracts, data structures, and their interactions.        |
| **[Security Roles](roles.md)**                      | A comprehensive description of the access control system, roles, and their specific permissions. |
| **[Use Cases](use_cases.md)**                       | Functional requirements and user scenarios that define the system's expected behavior.           |
| **[Test Cases](test_cases.md)**                     | A complete list of test cases derived from the use cases.                                        |
| **[Test Coverage Matrix](test_coverage_matrix.md)** | A matrix that maps requirements and functions to specific test cases, ensuring full coverage.    |
| **[Deployment Guide](deployment_guide.md)**         | Instructions for deploying the contracts and configuring all roles correctly.                    |

## Recommended Audit Workflow

1.  **Understand the Big Picture**: Start with the **[System Architecture](system_architecture.md)** to grasp the overall design and separation of concerns.
2.  **Review Access Controls**: Read the **[Security Roles](roles.md)** guide to understand the permission model.
3.  **Analyze Expected Behavior**: Review the **[Use Cases](use_cases.md)** and **[Test Cases](test_cases.md)** to see how the system is intended to function and handle errors.
4.  **Verify Test Coverage**: Use the **[Test Coverage Matrix](test_coverage_matrix.md)** to trace requirements to their corresponding tests and identify any potential gaps.
5.  **Check Deployment Security**: Refer to the **[Deployment Guide](deployment_guide.md)** to ensure the production setup process is secure.
