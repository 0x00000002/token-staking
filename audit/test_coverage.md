Compiling 77 files with Solc 0.8.30
Solc 0.8.30 finished in 2.40s
Compiler run successful!
Analysing contracts...
Running tests...

Ran 1 test for tests/security/Reentrancy.t.sol:ReentrancyTest
[PASS] test_TC23_ReentrancyOnUnstake() (gas: 438416)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.81ms (1.09ms CPU time)

Ran 7 tests for tests/integration/TokenIntegration.t.sol:TokenIntegrationTest
[PASS] test_TC28_AllowanceChecks() (gas: 422600)
[PASS] test_TC28_BalanceValidation() (gas: 350149)
[PASS] test_TC28_ClaimContractTokenHandling() (gas: 388805)
[PASS] test_TC28_EmergencyTokenRecovery() (gas: 16820)
[PASS] test_TC28_SafeERC20Usage() (gas: 389792)
[PASS] test_TC28_TokenIntegration() (gas: 386814)
[PASS] test_TC28_TokenRelatedErrors() (gas: 346367)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 3.98ms (2.12ms CPU time)

Ran 12 tests for tests/unit/EpochManager.t.sol:EpochManagerTest
[PASS] test_EpochIdIncrementation() (gas: 689469)
[PASS] test_GetNonExistentEpoch() (gas: 29775)
[PASS] test_MultipleEpochsManagement() (gas: 348073)
[PASS] test_TCR04_AnnounceEpochWithInvalidParameters() (gas: 193316)
[PASS] test_TCR04_AnnounceEpochWithNonExistentStrategy() (gas: 190624)
[PASS] test_TCR04_SuccessfullyAnnounceNewEpoch() (gas: 195750)
[PASS] test_TCR04_UnauthorizedEpochAnnouncement() (gas: 19231)
[PASS] test_TCR05_ActiveToEndedTransition() (gas: 198208)
[PASS] test_TCR05_AnnouncedToActiveTransition() (gas: 209433)
[PASS] test_TCR05_EndedToCalculatedTransition() (gas: 250249)
[PASS] test_TCR06_SetActualPoolSizeForEndedEpoch() (gas: 213761)
[PASS] test_TCR06_SetPoolSizeForNonEndedEpoch() (gas: 187727)
Suite result: ok. 12 passed; 0 failed; 0 skipped; finished in 4.17ms (1.60ms CPU time)

Ran 10 tests for tests/unit/StakingStorage.t.sol:StakingStorageTest
[PASS] test_TC13_GetStakeInformation() (gas: 356600)
[PASS] test_TC14_GetStakerInformation() (gas: 430418)
[PASS] test_TC15_HistoricalBalanceQueries() (gas: 683178)
[PASS] test_TC16_BatchHistoricalQueries() (gas: 843726)
[PASS] test_TC17_GlobalStatistics() (gas: 595243)
[PASS] test_TC18_StakerEnumeration() (gas: 848884)
[PASS] test_TC25_BasicDataIntegrity() (gas: 779945)
[PASS] test_TC26_VaultStorageIntegration() (gas: 387918)
[PASS] test_TC27_TokenIntegration() (gas: 380625)
[PASS] test_TC28_BasicTimeLockValidation() (gas: 381161)
Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 5.69ms (4.01ms CPU time)

Ran 12 tests for tests/unit/StrategiesRegistry.t.sol:StrategiesRegistryTest
[PASS] test_ActiveStrategiesManagement() (gas: 186500)
[PASS] test_GetNonExistentStrategy() (gas: 14322)
[PASS] test_MultipleStrategyRegistration() (gas: 115766)
[PASS] test_TCR01_RegisterStrategyWithInvalidAddress() (gas: 37981)
[PASS] test_TCR01_SuccessfullyRegisterNewRewardStrategy() (gas: 79616)
[PASS] test_TCR01_UnauthorizedStrategyRegistration() (gas: 17776)
[PASS] test_TCR02_ActivateRegisteredStrategy() (gas: 132033)
[PASS] test_TCR02_DeactivateActiveStrategy() (gas: 105208)
[PASS] test_TCR02_UnauthorizedStrategyStatusChange() (gas: 75515)
[PASS] test_TCR03_UnauthorizedVersionUpdate() (gas: 75211)
[PASS] test_TCR03_UpdateStrategyVersion() (gas: 90302)
[PASS] test_TCR03_UpdateVersionOfNonExistentStrategy() (gas: 17539)
Suite result: ok. 12 passed; 0 failed; 0 skipped; finished in 6.26ms (3.59ms CPU time)

Ran 7 tests for tests/integration/BasicIntegration.t.sol:BasicIntegrationTest
[PASS] test_TCI01_BasicRewardCalculationUsingStakingData() (gas: 502497)
[PASS] test_TCI02_BasicBatchRewardProcessing() (gas: 1171127)
[PASS] test_TCI03_BasicStakeDuringActiveEpoch() (gas: 707855)
[PASS] test_TCI04_BasicStakeEarnClaimWorkflow() (gas: 592542)
[PASS] test_TCI05_BasicEventCoordination() (gas: 585802)
[PASS] test_TCI06_BasicStateConsistencyValidation() (gas: 970932)
[PASS] test_TCI07_BasicExtensibilityValidation() (gas: 2054289)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 6.56ms (5.48ms CPU time)

Ran 19 tests for tests/unit/StakingVault.t.sol:StakingVaultTest
[PASS] test_TC10_FailedPauseUnauthorized() (gas: 14052)
[PASS] test_TC11_EmergencyTokenRecovery() (gas: 968405)
[PASS] test_TC12_EmergencyRecoverRole() (gas: 1087504)
[PASS] test_TC12_RoleManagement() (gas: 42584)
[PASS] test_TC19_InvalidStakeId() (gas: 27434)
[PASS] test_TC1_SuccessfulDirectStake() (gas: 375586)
[PASS] test_TC20_FailedUnstakeAlreadyUnstaked() (gas: 373525)
[PASS] test_TC22_PausedSystemOperations() (gas: 389536)
[PASS] test_TC23_ReentrancyProtection() (gas: 542233)
[PASS] test_TC24_AccessControlEnforcement() (gas: 30272)
[PASS] test_TC28_TokenIntegration() (gas: 386814)
[PASS] test_TC2_SuccessfulUnstaking() (gas: 392119)
[PASS] test_TC3_FailedUnstakingStakeNotMatured() (gas: 366212)
[PASS] test_TC4_SafeERC20BasicUsage() (gas: 373893)
[PASS] test_TC5_FailedStakingZeroAmount() (gas: 21004)
[PASS] test_TC6_StakeFromClaimContract() (gas: 327471)
[PASS] test_TC7_FailedClaimStakeUnauthorized() (gas: 20605)
[PASS] test_TC8_PauseSystem() (gas: 38909)
[PASS] test_TC9_UnpauseSystem() (gas: 29200)
Suite result: ok. 19 passed; 0 failed; 0 skipped; finished in 6.62ms (6.14ms CPU time)

Ran 11 tests for tests/integration/VaultStorageIntegration.t.sol:VaultStorageIntegrationTest
[PASS] test_ComplexStakeAndUnstakeLifecycle() (gas: 726533)
[PASS] test_MultipleUsersIntegration() (gas: 600370)
[PASS] test_TC15_HistoricalDataConsistency() (gas: 686315)
[PASS] test_TC24_UnauthorizedStorageAccess() (gas: 317308)
[PASS] test_TC25_CheckpointCreationOnBalanceChange() (gas: 352151)
[PASS] test_TC27_CrossContractStateConsistency() (gas: 550483)
[PASS] test_TC27_VaultStorageCoordination() (gas: 451077)
[PASS] test_TC32_EventParameterVerification() (gas: 355315)
[PASS] test_TC3_TC19_ErrorHandlingIntegration() (gas: 368787)
[PASS] test_TC42_CrossContractEventCoordination() (gas: 373196)
[PASS] test_TC6_StakeFromClaimContract() (gas: 326833)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 2.71ms (4.63ms CPU time)

Ran 36 tests for tests/unit/GrantedRewardStorage.t.sol:GrantedRewardStorageTest
[PASS] test_TCR_GRS01_GrantRewardWithMaxAmount() (gas: 73693)
[PASS] test_TCR_GRS01_GrantRewardWithZeroAmount() (gas: 73755)
[PASS] test_TCR_GRS01_SuccessfulGrantReward() (gas: 80915)
[PASS] test_TCR_GRS01_UnauthorizedGrantReward() (gas: 17593)
[PASS] test_TCR_GRS02_MarkAlreadyClaimedReward() (gas: 76555)
[PASS] test_TCR_GRS02_MarkRewardWithInvalidIndex() (gas: 69402)
[PASS] test_TCR_GRS02_SuccessfulMarkRewardClaimed() (gas: 82095)
[PASS] test_TCR_GRS02_UnauthorizedMarkRewardClaimed() (gas: 73468)
[PASS] test_TCR_GRS03_BatchClaimWithDuplicateIndices() (gas: 76956)
[PASS] test_TCR_GRS03_BatchClaimWithEmptyArray() (gas: 21516)
[PASS] test_TCR_GRS03_BatchClaimWithMixedStatus() (gas: 144558)
[PASS] test_TCR_GRS03_SuccessfulBatchMarkClaimed() (gas: 156319)
[PASS] test_TCR_GRS04_GetRewardsForUserWithMultipleRewards() (gas: 144536)
[PASS] test_TCR_GRS04_GetRewardsForUserWithNoRewards() (gas: 14552)
[PASS] test_TCR_GRS04_GetRewardsForUserWithSingleReward() (gas: 74468)
[PASS] test_TCR_GRS04_GetRewardsWithMixedClaimedStatus() (gas: 113991)
[PASS] test_TCR_GRS05_ClaimableAmountForUserWithAllRewardsClaimed() (gas: 111002)
[PASS] test_TCR_GRS05_ClaimableAmountForUserWithAllRewardsUnclaimed() (gas: 133148)
[PASS] test_TCR_GRS05_ClaimableAmountForUserWithNoRewards() (gas: 13855)
[PASS] test_TCR_GRS05_ClaimableAmountWithLargeNumbers() (gas: 101923)
[PASS] test_TCR_GRS05_ClaimableAmountWithMixedStatus() (gas: 137874)
[PASS] test_TCR_GRS06_ClaimableRewardsForUserWithAllRewardsClaimed() (gas: 80149)
[PASS] test_TCR_GRS06_ClaimableRewardsForUserWithNoRewards() (gas: 18492)
[PASS] test_TCR_GRS06_ClaimableRewardsWithMixedStatus() (gas: 191339)
[PASS] test_TCR_GRS07_EpochRewardsForEpochWithNoRewards() (gas: 15326)
[PASS] test_TCR_GRS07_EpochRewardsForSpecificEpoch() (gas: 210797)
[PASS] test_TCR_GRS07_ImmediateRewards() (gas: 145903)
[PASS] test_TCR_GRS08_PaginatedRewardsWithLimitExceedingRemaining() (gas: 203752)
[PASS] test_TCR_GRS08_PaginatedRewardsWithOffsetBeyondLength() (gas: 70103)
[PASS] test_TCR_GRS08_PaginatedRewardsWithValidOffsetAndLimit() (gas: 361382)
[PASS] test_TCR_GRS08_PaginatedRewardsWithZeroLimit() (gas: 70617)
[PASS] test_TCR_GRS08_PaginationBoundaryConditions() (gas: 395180)
[PASS] test_TCR_GRS09_UnauthorizedIndexUpdate() (gas: 16421)
[PASS] test_TCR_GRS09_UpdateIndexAfterClaimingFirstFewRewards() (gas: 211792)
[PASS] test_TCR_GRS09_UpdateIndexForUserWithNoRewards() (gas: 25591)
[PASS] test_TCR_GRS09_UpdateIndexWhenAllRewardsClaimed() (gas: 137623)
Suite result: ok. 36 passed; 0 failed; 0 skipped; finished in 7.17ms (5.67ms CPU time)

Ran 9 tests for tests/unit/Flags.t.sol:FlagsTest
[PASS] test_TCF01_CheckFlagBitStatus() (gas: 25316)
[PASS] test_TCF01_SetFlagBit() (gas: 8402)
[PASS] test_TCF01_UnsetFlagBit() (gas: 7394)
[PASS] test_TCF02_MarkStakeAsFromClaim() (gas: 321068)
[PASS] test_TCF02_MultipleFlagCombinations() (gas: 6683)
[PASS] test_TCF02_RegularStakeFlagHandling() (gas: 355763)
[PASS] test_TCF03_AddNewFlagTypes() (gas: 6124)
[PASS] test_TCF03_FlagBoundaryConditions() (gas: 18204)
[PASS] test_TCF03_FlagPersistenceAndQueries() (gas: 454070)
Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 7.18ms (4.52ms CPU time)

Ran 17 tests for tests/unit/RewardManager.t.sol:RewardManagerTest
[PASS] test_AddRewardFunds() (gas: 66694)
[PASS] test_TCR07_BatchSizeExceedsMaximum() (gas: 19987)
[PASS] test_TCR07_CalculateImmediateRewardsForBatchOfUsers() (gas: 839020)
[PASS] test_TCR07_CalculateRewardsWithInvalidStrategy() (gas: 28177)
[PASS] test_TCR08_CalculateEpochRewardsForParticipants() (gas: 1045369)
[PASS] test_TCR08_CalculateRewardsForNonCalculatedEpoch() (gas: 201261)
[PASS] test_TCR08_EpochWithoutPoolSize() (gas: 237263)
[PASS] test_TCR10_ClaimAllAvailableRewards() (gas: 596881)
[PASS] test_TCR10_ClaimWhenNoRewardsAvailable() (gas: 32627)
[PASS] test_TCR11_ClaimSpecificRewardIndices() (gas: 656043)
[PASS] test_TCR11_ClaimWithInvalidIndices() (gas: 26910)
[PASS] test_TCR12_ClaimFromEpochWithNoRewards() (gas: 210150)
[PASS] test_TCR12_ClaimRewardsFromSpecificEpoch() (gas: 892208)
[PASS] test_TCR18_AdminFunctionsAccessControl() (gas: 47166)
[PASS] test_TCR18_UserFunctionsPublicAccess() (gas: 32507)
[PASS] test_TCR19_EmergencyPauseRewardSystem() (gas: 81698)
[PASS] test_TCR19_ResumeFromEmergencyPause() (gas: 580324)
Suite result: ok. 17 passed; 0 failed; 0 skipped; finished in 7.20ms (7.58ms CPU time)

Ran 11 test suites in 252.60ms (61.36ms CPU time): 141 tests passed, 0 failed, 0 skipped (141 total tests)

╭----------------------------------------------------+------------------+------------------+-----------------+-----------------╮
| File                                               | % Lines          | % Statements     | % Branches      | % Funcs         |
+==============================================================================================================================+
| src/StakingStorage.sol                             | 92.54% (124/134) | 92.03% (127/138) | 65.62% (21/32)  | 90.48% (19/21)  |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/StakingVault.sol                               | 100.00% (39/39)  | 100.00% (35/35)  | 83.33% (10/12)  | 100.00% (8/8)   |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/lib/Flags.sol                                  | 100.00% (6/6)    | 100.00% (7/7)    | 100.00% (0/0)   | 100.00% (3/3)   |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/reward-system/EpochManager.sol                 | 92.31% (48/52)   | 95.65% (44/46)   | 87.50% (7/8)    | 77.78% (7/9)    |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/reward-system/GrantedRewardStorage.sol         | 100.00% (76/76)  | 100.00% (92/92)  | 100.00% (9/9)   | 100.00% (10/10) |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/reward-system/RewardManager.sol                | 96.46% (109/113) | 97.06% (132/136) | 81.08% (30/37)  | 93.75% (15/16)  |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/reward-system/StrategiesRegistry.sol           | 88.89% (40/45)   | 90.91% (40/44)   | 72.73% (8/11)   | 75.00% (6/8)    |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/reward-system/strategies/EpochPoolStrategy.sol | 38.46% (10/26)   | 34.78% (8/23)    | 0.00% (0/4)     | 37.50% (3/8)    |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| src/reward-system/strategies/LinearAPRStrategy.sol | 68.75% (22/32)   | 76.47% (26/34)   | 0.00% (0/6)     | 57.14% (4/7)    |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| tests/security/Reentrancy.t.sol                    | 90.00% (9/10)    | 77.78% (7/9)     | 100.00% (1/1)   | 100.00% (4/4)   |
|----------------------------------------------------+------------------+------------------+-----------------+-----------------|
| Total                                              | 90.62% (483/533) | 91.84% (518/564) | 71.67% (86/120) | 84.04% (79/94)  |
╰----------------------------------------------------+------------------+------------------+-----------------+-----------------╯
