---
title: KN 构建流程梳理
categories:
  - KN
tags:
  - KN
  - KMP
description: 梳理KN构建流程
published: false
---


## -p dynamic

- produceCLibrary
  - runFrontend
    - FrontendPhase
  - runPsiToIr
    - PsiToIrPhase
    - SpecialBackendChecksPhase
    - CopyDefaultValuesToActualPhase
    - BuildCExports
  - runBackend
    - FunctionsWithoutBoundCheckGenerator
    - splitIntoFragments
    - createGenerationStateAndRunLowerings
      - BuildAdditionalCacheInfoPhase
      - EntryPointPhase
      - lowerModuleWithDependencies
        - validateIrBeforeLowering
        - getLoweringsUpToAndIncludingInlining
        - validateIrAfterInlining
        - getLoweringsAfterInlining
        - validateIrAfterLowering
        - mergeDependencies：所有需要编译的kotlin ir合并到一个IRFragment中
    - runAfterLowerings
      - SaveAdditionalCacheInfoPhase （HEADER_CACHE）
      - FinalizeCachePhase（HEADER_CACHE）
      - compileModule
        - runBackendCodegen
          - runCodegen
            - ReturnsInsertionPhase
            - BuildDFGPhase
            - DevirtualizationAnalysisPhase
            - DCEPhase
            - RemoveRedundantCallsToStaticInitializersPhase
            - DevirtualizationPhase
            - PropertyAccessorInlinePhase
            - InlineClassPropertyAccessorsPhase
            - RedundantCoercionsCleaningPhase
            - UnboxInlinePhase
            - CreateLLVMDeclarationsPhase
            - GHAPhase
            - RTTIPhase
            - EscapeAnalysisPhase
            - CodegenPhase
          - CExportGenerateApiPhase
          - CExportCompileAdapterPhase
          - CStubsPhase
          - VerifyBitcodePhase
          - PrintBitcodePhase
          - LinkBitcodeDependenciesPhase
        - CheckExternalCallsPhase
        - RewriteExternalCallsCheckerGlobals
        - SaveAdditionalCacheInfoPhase
        - WriteBitcodeFilePhase
        - 



kotlin-native/backend.native/compiler/ir/backend.native/src/org/jetbrains/kotlin/backend/konan/driver/phases/TopLevelPhases.kt


