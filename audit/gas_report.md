No files changed, compilation skipped

Ran 9 tests for tests/unit/Flags.t.sol:FlagsTest
[PASS] test_TCF01_CheckFlagBitStatus() (gas: 19775)
[PASS] test_TCF01_SetFlagBit() (gas: 6690)
[PASS] test_TCF01_UnsetFlagBit() (gas: 5860)
[PASS] test_TCF02_MarkStakeAsFromClaim() (gas: 333302)
[PASS] test_TCF02_MultipleFlagCombinations() (gas: 5565)
[PASS] test_TCF02_RegularStakeFlagHandling() (gas: 363989)
[PASS] test_TCF03_AddNewFlagTypes() (gas: 5183)
[PASS] test_TCF03_FlagBoundaryConditions() (gas: 14171)
[PASS] test_TCF03_FlagPersistenceAndQueries() (gas: 508198)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 138.41ms (48.03ms CPU time)

Ran 1 test for tests/security/Reentrancy.t.sol:ReentrancyTest
[PASS] test_TC23_ReentrancyOnUnstake() (gas: 665916)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 139.64ms (70.72ms CPU time)

Ran 12 tests for tests/unit/StrategiesRegistry.t.sol:StrategiesRegistryTest
[PASS] test_ActiveStrategiesManagement() (gas: 343646)
[PASS] test_GetNonExistentStrategy() (gas: 12400)
[PASS] test_MultipleStrategyRegistration() (gas: 155327)
[PASS] test_TCR01_RegisterStrategyWithInvalidAddress() (gas: 58374)
[PASS] test_TCR01_SuccessfullyRegisterNewRewardStrategy() (gas: 94994)
[PASS] test_TCR01_UnauthorizedStrategyRegistration() (gas: 38240)
[PASS] test_TCR02_ActivateRegisteredStrategy() (gas: 173865)
[PASS] test_TCR02_DeactivateActiveStrategy() (gas: 198626)
[PASS] test_TCR02_UnauthorizedStrategyStatusChange() (gas: 115310)
[PASS] test_TCR03_UnauthorizedVersionUpdate() (gas: 115055)
[PASS] test_TCR03_UpdateStrategyVersion() (gas: 158169)
[PASS] test_TCR03_UpdateVersionOfNonExistentStrategy() (gas: 37444)
Suite result: ok. 12 passed; 0 failed; 0 skipped; finished in 318.39ms (258.23ms CPU time)

Ran 7 tests for tests/integration/TokenIntegration.t.sol:TokenIntegrationTest
[PASS] test_TC28_AllowanceChecks() (gas: 590212)
[PASS] test_TC28_BalanceValidation() (gas: 408268)
[PASS] test_TC28_ClaimContractTokenHandling() (gas: 496797)
[PASS] test_TC28_EmergencyTokenRecovery() (gas: 37181)
[PASS] test_TC28_SafeERC20Usage() (gas: 480487)
[PASS] test_TC28_TokenIntegration() (gas: 539890)
[PASS] test_TC28_TokenRelatedErrors() (gas: 403756)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 366.82ms (275.67ms CPU time)

Ran 10 tests for tests/unit/StakingStorage.t.sol:StakingStorageTest
[PASS] test_TC13_GetStakeInformation() (gas: 364704)
[PASS] test_TC14_GetStakerInformation() (gas: 507903)
[PASS] test_TC15_HistoricalBalanceQueries() (gas: 811425)
[PASS] test_TC16_BatchHistoricalQueries() (gas: 934643)
[PASS] test_TC17_GlobalStatistics() (gas: 646336)
[PASS] test_TC18_StakerEnumeration() (gas: 936847)
[PASS] test_TC25_BasicDataIntegrity() (gas: 956028)
[PASS] test_TC26_VaultStorageIntegration() (gas: 484419)
[PASS] test_TC27_TokenIntegration() (gas: 463776)
[PASS] test_TC28_BasicTimeLockValidation() (gas: 487266)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 400.71ms (284.44ms CPU time)

Ran 11 tests for tests/integration/VaultStorageIntegration.t.sol:VaultStorageIntegrationTest
[PASS] test_ComplexStakeAndUnstakeLifecycle() (gas: 987574)
[PASS] test_MultipleUsersIntegration() (gas: 650576)
[PASS] test_TC15_HistoricalDataConsistency() (gas: 811882)
[PASS] test_TC24_UnauthorizedStorageAccess() (gas: 374466)
[PASS] test_TC25_CheckpointCreationOnBalanceChange() (gas: 362650)
[PASS] test_TC27_CrossContractStateConsistency() (gas: 679314)
[PASS] test_TC27_VaultStorageCoordination() (gas: 544591)
[PASS] test_TC32_EventParameterVerification() (gas: 363737)
[PASS] test_TC3_TC19_ErrorHandlingIntegration() (gas: 431315)
[PASS] test_TC42_CrossContractEventCoordination() (gas: 454039)
[PASS] test_TC6_StakeFromClaimContract() (gas: 336457)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 347.09ms (296.55ms CPU time)

Ran 7 tests for tests/integration/BasicIntegration.t.sol:BasicIntegrationTest
[PASS] test_TCI01_BasicRewardCalculationUsingStakingData() (gas: 523111)
[PASS] test_TCI02_BasicBatchRewardProcessing() (gas: 1265054)
[PASS] test_TCI03_BasicStakeDuringActiveEpoch() (gas: 945722)
[PASS] test_TCI04_BasicStakeEarnClaimWorkflow() (gas: 720730)
[PASS] test_TCI05_BasicEventCoordination() (gas: 624520)
[PASS] test_TCI06_BasicStateConsistencyValidation() (gas: 1126764)
[PASS] test_TCI07_BasicExtensibilityValidation() (gas: 1880356)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 544.83ms (329.91ms CPU time)

Ran 17 tests for tests/unit/RewardManager.t.sol:RewardManagerTest
[PASS] test_AddRewardFunds() (gas: 144649)
[PASS] test_TCR07_BatchSizeExceedsMaximum() (gas: 39192)
[PASS] test_TCR07_CalculateImmediateRewardsForBatchOfUsers() (gas: 894287)
[PASS] test_TCR07_CalculateRewardsWithInvalidStrategy() (gas: 45442)
[PASS] test_TCR08_CalculateEpochRewardsForParticipants() (gas: 1320309)
[PASS] test_TCR08_CalculateRewardsForNonCalculatedEpoch() (gas: 253430)
[PASS] test_TCR08_EpochWithoutPoolSize() (gas: 427377)
[PASS] test_TCR10_ClaimAllAvailableRewards() (gas: 637897)
[PASS] test_TCR10_ClaimWhenNoRewardsAvailable() (gas: 54743)
[PASS] test_TCR11_ClaimSpecificRewardIndices() (gas: 740713)
[PASS] test_TCR11_ClaimWithInvalidIndices() (gas: 46389)
[PASS] test_TCR12_ClaimFromEpochWithNoRewards() (gas: 247984)
[PASS] test_TCR12_ClaimRewardsFromSpecificEpoch() (gas: 1178686)
[PASS] test_TCR18_AdminFunctionsAccessControl() (gas: 103829)
[PASS] test_TCR18_UserFunctionsPublicAccess() (gas: 27119)
[PASS] test_TCR19_EmergencyPauseRewardSystem() (gas: 140347)
[PASS] test_TCR19_ResumeFromEmergencyPause() (gas: 686614)
Suite result: ok. 17 passed; 0 failed; 0 skipped; finished in 545.13ms (616.56ms CPU time)

Ran 19 tests for tests/unit/StakingVault.t.sol:StakingVaultTest
[PASS] test_TC10_FailedPauseUnauthorized() (gas: 35116)
[PASS] test_TC11_EmergencyTokenRecovery() (gas: 1173703)
[PASS] test_TC12_EmergencyRecoverRole() (gas: 1463366)
[PASS] test_TC12_RoleManagement() (gas: 101128)
[PASS] test_TC19_InvalidStakeId() (gas: 48686)
[PASS] test_TC1_SuccessfulDirectStake() (gas: 400702)
[PASS] test_TC20_FailedUnstakeAlreadyUnstaked() (gas: 498445)
[PASS] test_TC22_PausedSystemOperations() (gas: 541292)
[PASS] test_TC23_ReentrancyProtection() (gas: 691605)
[PASS] test_TC24_AccessControlEnforcement() (gas: 73828)
[PASS] test_TC28_TokenIntegration() (gas: 570922)
[PASS] test_TC2_SuccessfulUnstaking() (gas: 487107)
[PASS] test_TC3_FailedUnstakingStakeNotMatured() (gas: 414760)
[PASS] test_TC4_SafeERC20BasicUsage() (gas: 473381)
[PASS] test_TC5_FailedStakingZeroAmount() (gas: 42336)
[PASS] test_TC6_StakeFromClaimContract() (gas: 349255)
[PASS] test_TC7_FailedClaimStakeUnauthorized() (gas: 42389)
[PASS] test_TC8_PauseSystem() (gas: 59973)
[PASS] test_TC9_UnpauseSystem() (gas: 81093)
Suite result: ok. 19 passed; 0 failed; 0 skipped; finished in 545.37ms (574.35ms CPU time)

Ran 12 tests for tests/unit/EpochManager.t.sol:EpochManagerTest
[PASS] test_EpochIdIncrementation() (gas: 845477)
[PASS] test_GetNonExistentEpoch() (gas: 25879)
[PASS] test_MultipleEpochsManagement() (gas: 453891)
[PASS] test_TCR04_AnnounceEpochWithInvalidParameters() (gas: 208071)
[PASS] test_TCR04_AnnounceEpochWithNonExistentStrategy() (gas: 205581)
[PASS] test_TCR04_SuccessfullyAnnounceNewEpoch() (gas: 209904)
[PASS] test_TCR04_UnauthorizedEpochAnnouncement() (gas: 39072)
[PASS] test_TCR05_ActiveToEndedTransition() (gas: 309468)
[PASS] test_TCR05_AnnouncedToActiveTransition() (gas: 282462)
[PASS] test_TCR05_EndedToCalculatedTransition() (gas: 432534)
[PASS] test_TCR06_SetActualPoolSizeForEndedEpoch() (gas: 356374)
[PASS] test_TCR06_SetPoolSizeForNonEndedEpoch() (gas: 230606)
Suite result: ok. 12 passed; 0 failed; 0 skipped; finished in 554.05ms (317.60ms CPU time)

Ran 36 tests for tests/unit/GrantedRewardStorage.t.sol:GrantedRewardStorageTest
[PASS] test_TCR_GRS01_GrantRewardWithMaxAmount() (gas: 90643)
[PASS] test_TCR_GRS01_GrantRewardWithZeroAmount() (gas: 90385)
[PASS] test_TCR_GRS01_SuccessfulGrantReward() (gas: 95948)
[PASS] test_TCR_GRS01_UnauthorizedGrantReward() (gas: 37743)
[PASS] test_TCR_GRS02_MarkAlreadyClaimedReward() (gas: 151261)
[PASS] test_TCR_GRS02_MarkRewardWithInvalidIndex() (gas: 114074)
[PASS] test_TCR_GRS02_SuccessfulMarkRewardClaimed() (gas: 127040)
[PASS] test_TCR_GRS02_UnauthorizedMarkRewardClaimed() (gas: 113896)
[PASS] test_TCR_GRS03_BatchClaimWithDuplicateIndices() (gas: 124973)
[PASS] test_TCR_GRS03_BatchClaimWithEmptyArray() (gas: 41078)
[PASS] test_TCR_GRS03_BatchClaimWithMixedStatus() (gas: 282140)
[PASS] test_TCR_GRS03_SuccessfulBatchMarkClaimed() (gas: 259078)
[PASS] test_TCR_GRS04_GetRewardsForUserWithMultipleRewards() (gas: 209417)
[PASS] test_TCR_GRS04_GetRewardsForUserWithNoRewards() (gas: 13603)
[PASS] test_TCR_GRS04_GetRewardsForUserWithSingleReward() (gas: 91013)
[PASS] test_TCR_GRS04_GetRewardsWithMixedClaimedStatus() (gas: 184238)
[PASS] test_TCR_GRS05_ClaimableAmountForUserWithAllRewardsClaimed() (gas: 215073)
[PASS] test_TCR_GRS05_ClaimableAmountForUserWithAllRewardsUnclaimed() (gas: 206192)
[PASS] test_TCR_GRS05_ClaimableAmountForUserWithNoRewards() (gas: 12957)
[PASS] test_TCR_GRS05_ClaimableAmountWithLargeNumbers() (gas: 148269)
[PASS] test_TCR_GRS05_ClaimableAmountWithMixedStatus() (gas: 239906)
[PASS] test_TCR_GRS06_ClaimableRewardsForUserWithAllRewardsClaimed() (gas: 127398)
[PASS] test_TCR_GRS06_ClaimableRewardsForUserWithNoRewards() (gas: 16775)
[PASS] test_TCR_GRS06_ClaimableRewardsWithMixedStatus() (gas: 342508)
[PASS] test_TCR_GRS07_EpochRewardsForEpochWithNoRewards() (gas: 14003)
[PASS] test_TCR_GRS07_EpochRewardsForSpecificEpoch() (gas: 331298)
[PASS] test_TCR_GRS07_ImmediateRewards() (gas: 213004)
[PASS] test_TCR_GRS08_PaginatedRewardsWithLimitExceedingRemaining() (gas: 324819)
[PASS] test_TCR_GRS08_PaginatedRewardsWithOffsetBeyondLength() (gas: 88635)
[PASS] test_TCR_GRS08_PaginatedRewardsWithValidOffsetAndLimit() (gas: 614963)
[PASS] test_TCR_GRS08_PaginatedRewardsWithZeroLimit() (gas: 88955)
[PASS] test_TCR_GRS08_PaginationBoundaryConditions() (gas: 630432)
[PASS] test_TCR_GRS09_UnauthorizedIndexUpdate() (gas: 36808)
[PASS] test_TCR_GRS09_UpdateIndexAfterClaimingFirstFewRewards() (gas: 394146)
[PASS] test_TCR_GRS09_UpdateIndexForUserWithNoRewards() (gas: 44356)
[PASS] test_TCR_GRS09_UpdateIndexWhenAllRewardsClaimed() (gas: 269573)
Suite result: ok. 36 passed; 0 failed; 0 skipped; finished in 553.92ms (1.06s CPU time)

╭------------------------------------------------+-----------------+-------+--------+-------+---------╮
| src/StakingStorage.sol:StakingStorage Contract |                 |       |        |       |         |
+=====================================================================================================+
| Deployment Cost                                | Deployment Size |       |        |       |         |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| 3157539                                        | 14937           |       |        |       |         |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                |                 |       |        |       |         |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                  | Min             | Avg   | Median | Max   | # Calls |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| CONTROLLER_ROLE                                | 371             | 371   | 371    | 371   | 20      |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| createStake                                    | 25794           | 25794 | 25794  | 25794 | 1       |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| getCurrentTotalStaked                          | 563             | 563   | 563    | 563   | 2       |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| getStake                                       | 2966            | 4211  | 4966   | 4966  | 14      |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| getStakerInfo                                  | 2849            | 2849  | 2849   | 2849  | 3       |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| grantRole                                      | 51997           | 51997 | 51997  | 51997 | 20      |
╰------------------------------------------------+-----------------+-------+--------+-------+---------╯

╭--------------------------------------------+-----------------+--------+--------+--------+---------╮
| src/StakingVault.sol:StakingVault Contract |                 |        |        |        |         |
+===================================================================================================+
| Deployment Cost                            | Deployment Size |        |        |        |         |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| 1806098                                    | 8655            |        |        |        |         |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
|                                            |                 |        |        |        |         |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| Function Name                              | Min             | Avg    | Median | Max    | # Calls |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| CLAIM_CONTRACT_ROLE                        | 347             | 347    | 347    | 347    | 19      |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| DEFAULT_ADMIN_ROLE                         | 374             | 374    | 374    | 374    | 1       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| MANAGER_ROLE                               | 391             | 391    | 391    | 391    | 5       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| MULTISIG_ROLE                              | 369             | 369    | 369    | 369    | 6       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| emergencyRecover                           | 24849           | 35216  | 25092  | 60650  | 7       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| grantRole                                  | 51684           | 51853  | 51840  | 52068  | 23      |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| hasRole                                    | 1232            | 1232   | 1232   | 1232   | 2       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| pause                                      | 24076           | 42764  | 47437  | 47437  | 5       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| paused                                     | 518             | 518    | 518    | 518    | 2       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| revokeRole                                 | 29790           | 29847  | 29790  | 29963  | 3       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| stake                                      | 24325           | 274282 | 356398 | 356398 | 12      |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| stakeFromClaim                             | 27659           | 184318 | 204875 | 320421 | 3       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| unpause                                    | 25467           | 25467  | 25467  | 25467  | 2       |
|--------------------------------------------+-----------------+--------+--------+--------+---------|
| unstake                                    | 24137           | 89320  | 121920 | 144749 | 10      |
╰--------------------------------------------+-----------------+--------+--------+--------+---------╯

╭-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------╮
| src/reward-system/strategies/EpochPoolStrategy.sol:EpochPoolStrategy Contract |                 |     |        |     |         |
+================================================================================================================================+
| Deployment Cost                                                               | Deployment Size |     |        |     |         |
|-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| 803392                                                                        | 4397            |     |        |     |         |
|-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
|                                                                               |                 |     |        |     |         |
|-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| Function Name                                                                 | Min             | Avg | Median | Max | # Calls |
|-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| calculateEpochReward                                                          | 729             | 729 | 729    | 729 | 4       |
|-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------|
| getStrategyType                                                               | 261             | 261 | 261    | 261 | 38      |
╰-------------------------------------------------------------------------------+-----------------+-----+--------+-----+---------╯

╭-------------------------------------------------------------------------------+-----------------+------+--------+------+---------╮
| src/reward-system/strategies/LinearAPRStrategy.sol:LinearAPRStrategy Contract |                 |      |        |      |         |
+==================================================================================================================================+
| Deployment Cost                                                               | Deployment Size |      |        |      |         |
|-------------------------------------------------------------------------------+-----------------+------+--------+------+---------|
| 848007                                                                        | 4353            |      |        |      |         |
|-------------------------------------------------------------------------------+-----------------+------+--------+------+---------|
|                                                                               |                 |      |        |      |         |
|-------------------------------------------------------------------------------+-----------------+------+--------+------+---------|
| Function Name                                                                 | Min             | Avg  | Median | Max  | # Calls |
|-------------------------------------------------------------------------------+-----------------+------+--------+------+---------|
| calculateHistoricalReward                                                     | 3913            | 5379 | 5913   | 5913 | 15      |
|-------------------------------------------------------------------------------+-----------------+------+--------+------+---------|
| getStrategyType                                                               | 282             | 282  | 282    | 282  | 33      |
|-------------------------------------------------------------------------------+-----------------+------+--------+------+---------|
| isApplicable                                                                  | 5326            | 8259 | 9326   | 9326 | 15      |
╰-------------------------------------------------------------------------------+-----------------+------+--------+------+---------╯

╭------------------------------------------------+-----------------+-------+--------+-------+---------╮
| tests/helpers/MockERC20.sol:MockERC20 Contract |                 |       |        |       |         |
+=====================================================================================================+
| Deployment Cost                                | Deployment Size |       |        |       |         |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| 963644                                         | 5397            |       |        |       |         |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                |                 |       |        |       |         |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                  | Min             | Avg   | Median | Max   | # Calls |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| approve                                        | 24956           | 46178 | 47240  | 47240 | 21      |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| balanceOf                                      | 850             | 1271  | 850    | 2850  | 19      |
|------------------------------------------------+-----------------+-------+--------+-------+---------|
| mint                                           | 51619           | 60715 | 68935  | 68947 | 40      |
╰------------------------------------------------+-----------------+-------+--------+-------+---------╯

╭---------------------------------------------------------+-----------------+-------+--------+-------+---------╮
| tests/security/Reentrancy.t.sol:MaliciousToken Contract |                 |       |        |       |         |
+==============================================================================================================+
| Deployment Cost                                         | Deployment Size |       |        |       |         |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| 1228357                                                 | 6626            |       |        |       |         |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                         |                 |       |        |       |         |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                           | Min             | Avg   | Median | Max   | # Calls |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| approve                                                 | 46963           | 46963 | 46963  | 46963 | 1       |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| mint                                                    | 68742           | 68742 | 68742  | 68742 | 1       |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| setAttackStep                                           | 26738           | 35288 | 35288  | 43838 | 2       |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| setStakeId                                              | 43754           | 43754 | 43754  | 43754 | 1       |
|---------------------------------------------------------+-----------------+-------+--------+-------+---------|
| setVault                                                | 44092           | 44092 | 44092  | 44092 | 1       |
╰---------------------------------------------------------+-----------------+-------+--------+-------+---------╯


Ran 11 test suites in 559.82ms (4.45s CPU time): 141 tests passed, 0 failed, 0 skipped (141 total tests)
