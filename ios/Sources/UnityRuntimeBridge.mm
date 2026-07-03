#import "UnityRuntimeBridge.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <cxxabi.h>
#include <exception>
#include <typeinfo>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#if __has_include(<ptrauth.h>)
#include <ptrauth.h>
#endif

typedef void *(*SBUnityStringAllocLenFn)(uint32_t length);
typedef bool (*SBUnityStringIsNullOrEmptyFn)(void *string);
typedef void *(*SBUnityBattleReservationDetailFromJsonFn)(void *jsonString, const void *method);
typedef void *(*SBUnityMetadataInitFn)(void *typeInfoGlobal);
typedef void *(*SBUnityObjectNewFn)(void *typeInfo);
typedef void (*SBUnityObjectCtorFn)(void *self, const void *method);
typedef void *(*SBUnityMainStoryCreateFinishReqFn)(void *self, void *battle, const void *method);
typedef void *(*SBUnityMasterDataProtectorGenerateKeyFn)(void *serverVersionHash, const void *method);
typedef void *(*SBUnityMasterDataProtectorDecryptFn)(void *protectionKey, void *encryptedBytes, const void *method);
typedef void *(*SBUnityFileReadAllBytesFn)(void *path, const void *method);
typedef void *(*SBUnityFileReadAllTextFn)(void *path, const void *method);
typedef void (*SBUnityTsvDocumentCtorFn)(void *self,
                                         void *documentString,
                                         void *fileName,
                                         void *errorCollector,
                                         const void *method);
typedef void (*SBUnityTsvKeyValueDocumentCtorFn)(void *self,
                                                 void *document,
                                                 void *keyColumnName,
                                                 void *valueColumnName,
                                                 const void *method);
typedef int32_t (*SBUnityTsvDocumentGetCountFn)(void *self, const void *method);
typedef void *(*SBUnityTsvDocumentToStringFn)(void *self, const void *method);
typedef void (*SBUnityDirectoryInfoCtorFn)(void *self, void *path, const void *method);
typedef void *(*SBUnityFileSystemInfoGetFullNameFn)(void *self, const void *method);
typedef void *(*SBUnityDirectoryGetFilesFn)(void *path, void *searchPattern, const void *method);
typedef void *(*SBUnityLoadMasterFileFn)(void *filename, void *displayClass, const void *method);
typedef bool (*SBUnityInstanceGetBoolFn)(void *self, const void *method);
typedef void *(*SBUnityInstanceToStringFn)(void *self, const void *method);
typedef void *(*SBUnityStageMasterGetByBattleTypeFn)(int32_t battleType, int32_t code, const void *method);
typedef void (*SBUnityFileSourceMasterLoaderLoadAllFn)(void *logger, const void *method);
typedef void (*SBUnityFileSourceMasterLoaderLoadMasterDataFn)(void *logger,
                                                             void *masterDataDirOverride,
                                                             void *protectionKey,
                                                             const void *method);
typedef void (*SBUnityFileSourceMasterLoaderLoadMasterDataPrivateFn)(void *events,
                                                                    void *masterDataDirOverride,
                                                                    void *errorCollector,
                                                                    void *protectionKey,
                                                                    const void *method);
typedef bool (*SBUnityStageBattleReservationDetailGetBoolFn)(void *detail, const void *method);
typedef void *(*SBUnityStageBattleReservationDetailGetObjectFn)(void *detail, const void *method);
typedef void (*SBUnityOperationListMoveSelectorCtorFn)(void *self, void *randomOverride, const void *method);
typedef int32_t (*SBUnityEnvironmentGetTickCountFn)(const void *method);
typedef void (*SBUnitySystemRandomCtorFn)(void *self, int32_t seed, const void *method);
typedef void (*SBUnityFuncIntIntIntCtorFn)(void *self, void *target, intptr_t invoke, const void *method);
typedef void (*SBUnityFuncDoubleCtorFn)(void *self, void *target, intptr_t invoke, const void *method);
typedef void (*SBUnityOperationListRandomFuncCtorFn)(void *self,
                                                     void *randomRange,
                                                     void *randomDouble,
                                                     const void *method);
typedef void (*SBUnitySoccerBattleCtorFn)(void *self,
                                          void *logger,
                                          int32_t battleType,
                                          int32_t seed,
                                          bool isAlwaysVictory,
                                          void *startSituation,
                                          void *specialFinishCondition,
                                          void *aTeam,
                                          void *bTeam,
                                          void *teamAMoveSelector,
                                          void *fieldTerrain,
                                          int32_t backgroundCode,
                                          void *fieldMaster,
                                          void *playwrightBook,
                                          const void *method);
typedef int32_t (*SBUnitySoccerBattleGetResultFn)(void *battle, const void *method);
typedef void *(*SBUnitySoccerBattleRunCoroutineFn)(void *battle, const void *method);
typedef void *(*SBUnitySoccerBattleCreateReplayFn)(void *battle,
                                                   void *reservationDetail,
                                                   void *releaseVersion,
                                                   void *playwrightBook,
                                                   const void *method);
typedef void *(*SBUnitySoccerBattleCreateForReplayFn)(void *logger,
                                                      void *replay,
                                                      const void *method);
typedef void *(*SBUnitySoccerBattleReplayToJsonFn)(void *replay, const void *method);
typedef void *(*SBUnitySoccerBattleReplayFromJsonFn)(void *json, const void *method);
typedef void *(*SBUnityResourcesFindObjectsOfTypeAllFn)(void *systemType, const void *method);

typedef void *(*SBIl2CppDomainGetFn)(void);
typedef void *(*SBIl2CppThreadAttachFn)(void *domain);
typedef void *(*SBIl2CppDomainAssemblyOpenFn)(void *domain, const char *name);
typedef void *(*SBIl2CppAssemblyGetImageFn)(void *assembly);
typedef void *(*SBIl2CppClassFromNameFn)(void *image, const char *namespaze, const char *name);
typedef void *(*SBIl2CppClassGetTypeFn)(void *klass);
typedef void *(*SBIl2CppTypeGetObjectFn)(void *type);
typedef void *(*SBCxaCurrentPrimaryExceptionFn)(void);
typedef void (*SBCxaDecrementExceptionRefcountFn)(void *exception);

struct SBUnityCancellationToken {
    void *source;
};

struct SBUnityValueTaskBool {
    void *object;
    bool result;
    int16_t token;
    bool continueOnCapturedContext;
};

typedef void *(*SBUnityRunCoroutineGetAsyncEnumeratorFn)(void *self,
                                                         SBUnityCancellationToken cancellationToken,
                                                         const void *method);
typedef SBUnityValueTaskBool (*SBUnityRunCoroutineMoveNextAsyncFn)(void *self, const void *method);
typedef void *(*SBUnityRunCoroutineGetCurrentFn)(void *self, const void *method);
typedef bool (*SBUnityRunCoroutineValueTaskSourceGetResultFn)(void *self, int16_t token, const void *method);
typedef int32_t (*SBUnityRunCoroutineValueTaskSourceGetStatusFn)(void *self, int16_t token, const void *method);

struct Il2CppExceptionWrapper {
    void *exception;
};

struct SBUnityFileSourceMasterLoaderDisplayClass4_0 {
    void *masterDataDir;
    void *errorCollector;
    void *protectionKey;
};

static const uintptr_t SBUnityMetadataInitRVA = 0x371A68;
static const uintptr_t SBUnityObjectNewRVA = 0x371D24;
static const uintptr_t SBUnityStringAllocLenRVA = 0x3BD87C;
static const uintptr_t SBUnityStringIsNullOrEmptyRVA = 0x655C334;
static const uintptr_t SBUnityFileReadAllBytesRVA = 0x66E3D30;
static const uintptr_t SBUnityFileReadAllTextRVA = 0x66E37C4;
static const uintptr_t SBUnityDirectoryGetFilesRVA = 0x66E1E3C;
static const uintptr_t SBUnityDirectoryInfoCtorRVA = 0x66E2828;
static const uintptr_t SBUnityFileSystemInfoGetFullNameRVA = 0x66E6C1C;
static const uintptr_t SBUnitySystemExceptionToStringRVA = 0x676F6E8;
static const uintptr_t SBUnityBattleReservationDetailFromJsonRVA = 0x69CA948;
static const uintptr_t SBUnityStageBattleReservationDetailGetIsAlwaysVictoryRVA = 0x69CAB94;
static const uintptr_t SBUnityStageBattleReservationDetailGetBattleStartSituationRVA = 0x69CABF4;
static const uintptr_t SBUnityStageBattleReservationDetailGetBattleSpecialFinishConditionRVA = 0x69CAC24;
static const uintptr_t SBUnityStageBattleReservationDetailGetBackgroundMasterRVA = 0x69CAC54;
static const uintptr_t SBUnityStageBattleReservationDetailGetFieldMasterRVA = 0x69CAC84;
static const uintptr_t SBUnityStageMasterGetByBattleTypeRVA = 0x69491F8;
static const uintptr_t SBUnityStageMasterGetByBattleTypeMethodInfoRVA = 0x9BA1F80;
static const uintptr_t SBUnityFileSourceMasterLoaderTypeInfoGlobalRVA = 0x9B4ACC8;
static const uintptr_t SBUnityMasterDataEventsTypeInfoGlobalRVA = 0x9B4E4B0;
static const uintptr_t SBUnityMasterModelTypeInfoGlobalRVA = 0x9B4E4B8;
static const uintptr_t SBUnityDirectoryInfoTypeInfoGlobalRVA = 0x9B4A258;
static const uintptr_t SBUnityTsvDocumentTypeInfoGlobalRVA = 0x9B528F0;
static const uintptr_t SBUnityTsvKeyValueDocumentTypeInfoGlobalRVA = 0x9B52918;
static const uintptr_t SBUnityTsvErrorCollectorTypeInfoGlobalRVA = 0x9B52900;
static const uintptr_t SBUnityFileSourceMasterLoaderLoadAllMasterDataWithoutTestRVA = 0x6A23058;
static const uintptr_t SBUnityFileSourceMasterLoaderLoadMasterDataRVA = 0x6A230C0;
static const uintptr_t SBUnityFileSourceMasterLoaderLoadMasterDataPrivateRVA = 0x6A2365C;
static const uintptr_t SBUnityFileSourceMasterLoaderLoadMasterFileRVA = 0x6A269B0;
static const uintptr_t SBUnityLoadMasterFilePathConstantAGlobalRVA = 0x9BD5780;
static const uintptr_t SBUnityLoadMasterFilePathConstantBGlobalRVA = 0x9BC59F8;
static const uintptr_t SBUnityMasterDataEventsCtorRVA = 0x6A5A514;
static const uintptr_t SBUnityMasterDataProtectorGenerateKeyRVA = 0x6A5A690;
static const uintptr_t SBUnityMasterDataProtectorDecryptRVA = 0x6A5A8BC;
static const uintptr_t SBUnityTsvDocumentCtorRVA = 0x697D928;
static const uintptr_t SBUnityTsvKeyValueDocumentCtorRVA = 0x697F13C;
static const uintptr_t SBUnityTsvDocumentGetCountRVA = 0x697D8DC;
static const uintptr_t SBUnityTsvDocumentToStringRVA = 0x697DF84;
static const uintptr_t SBUnityTsvErrorCollectorGetHasErrorRVA = 0x697C0CC;
static const uintptr_t SBUnityTsvErrorCollectorToStringRVA = 0x697C288;
static const uintptr_t SBUnityTsvErrorCollectorCtorRVA = 0x697D6A8;
static const uintptr_t SBUnityOperationListMoveSelectorCtorRVA = 0x69208EC;
static const uintptr_t SBUnityOperationListRandomFuncCtorRVA = 0x6921668;
static const uintptr_t SBUnitySystemRandomCtorRVA = 0x673F1A0;
static const uintptr_t SBUnityEnvironmentGetTickCountRVA = 0x677F1F0;
static const uintptr_t SBUnityFuncIntIntIntCtorRVA = 0x39282C4;
static const uintptr_t SBUnityFuncDoubleCtorRVA = 0x387EA38;
static const uintptr_t SBUnitySoccerBattleCtorRVA = 0x6904738;
static const uintptr_t SBUnitySoccerBattleCreateForReplayRVA = 0x6905414;
static const uintptr_t SBUnitySoccerBattleCreateReplayRVA = 0x6905580;
static const uintptr_t SBUnitySoccerBattleGetResultRVA = 0x69056AC;
static const uintptr_t SBUnitySoccerBattleRunCoroutineRVA = 0x6906884;
static const uintptr_t SBUnitySoccerBattleRunCoroutineGetAsyncEnumeratorRVA = 0x6916644;
static const uintptr_t SBUnitySoccerBattleRunCoroutineMoveNextAsyncRVA = 0x6916760;
static const uintptr_t SBUnitySoccerBattleRunCoroutineGetCurrentRVA = 0x69168F8;
static const uintptr_t SBUnitySoccerBattleRunCoroutineValueTaskGetResultRVA = 0x6916900;
static const uintptr_t SBUnitySoccerBattleRunCoroutineValueTaskGetStatusRVA = 0x691695C;
static const uintptr_t SBUnitySoccerBattleReplayToJsonRVA = 0x69ADB14;
static const uintptr_t SBUnitySoccerBattleReplayFromJsonRVA = 0x69ADC20;
static const uintptr_t SBUnityResourcesFindObjectsOfTypeAllRVA = 0x7992D40;
static const uintptr_t SBUnitySystemRandomTypeInfoGlobalRVA = 0x9B4FFC8;
static const uintptr_t SBUnityFuncIntIntIntTypeInfoGlobalRVA = 0x9B40100;
static const uintptr_t SBUnityFuncDoubleTypeInfoGlobalRVA = 0x9B3C498;
static const uintptr_t SBUnityOperationListRandomFuncTypeInfoGlobalRVA = 0x9B5A110;
static const uintptr_t SBUnityOperationListMoveSelectorTypeInfoGlobalRVA = 0x9B4F230;
static const uintptr_t SBUnitySoccerBattleTypeInfoGlobalRVA = 0x9B51418;
static const uintptr_t SBUnityMainStoryStageContextTypeInfoGlobalRVA = 0x9B4B710;
static const uintptr_t SBUnityMainStoryStageContextCtorRVA = 0x1FF4C1C;
static const uintptr_t SBUnityMainStoryCreateFinishReqRVA = 0x1FF4924;

static const int32_t SBUnityBridgeProbeStageGetStartSituation = 21;
static const int32_t SBUnityBridgeProbeStageGetSpecialFinishCondition = 22;
static const int32_t SBUnityBridgeProbeStageGetBackgroundMaster = 23;
static const int32_t SBUnityBridgeProbeStageGetFieldMaster = 24;
static const int32_t SBUnityBridgeProbeStageGetIsAlwaysVictory = 25;
static const int32_t SBUnityBridgeProbeStageMasterStatics = 26;
static const int32_t SBUnityBridgeProbeStageMasterDirect = 27;
static const int32_t SBUnityBridgeProbeStageMasterLoadAll = 28;
static const int32_t SBUnityBridgeProbeStageBattleRunCoroutine = 29;
static const int32_t SBUnityBridgeProbeStageBattleReplayRoundTrip = 30;

static SBUnityBridgeProgressHandler SBUnityBridgeProgress = NULL;

void SBUnityBridgeSetProgressHandler(SBUnityBridgeProgressHandler handler) {
    SBUnityBridgeProgress = handler;
}

static BOOL SBUnityBridgeIsSingleGetterStage(int32_t stage) {
    return stage >= SBUnityBridgeProbeStageGetStartSituation &&
           stage <= SBUnityBridgeProbeStageGetIsAlwaysVictory;
}

static BOOL SBUnityBridgeIsDirectStageMasterStage(int32_t stage) {
    return stage == SBUnityBridgeProbeStageMasterDirect;
}

static BOOL SBUnityBridgeIsRawStageMasterStaticsStage(int32_t stage) {
    return stage == SBUnityBridgeProbeStageMasterStatics;
}

static BOOL SBUnityBridgeIsMasterLoadStage(int32_t stage) {
    return stage == SBUnityBridgeProbeStageMasterLoadAll;
}

static BOOL SBUnityBridgeIsBattleRunCoroutineStage(int32_t stage) {
    return stage == SBUnityBridgeProbeStageBattleRunCoroutine ||
           stage == SBUnityBridgeProbeStageBattleReplayRoundTrip;
}

static BOOL SBUnityBridgeIsBattleReplayRoundTripStage(int32_t stage) {
    return stage == SBUnityBridgeProbeStageBattleReplayRoundTrip;
}

static int32_t SBUnityBridgeStageMasterCollectionOffset(int32_t battleType) {
    switch (battleType) {
        case 0:
            return 0x118;
        case 2:
            return 0x148;
        case 3:
            return 0x140;
        case 4:
            return 0x1B0;
        case 5:
            return 0x130;
        case 7:
            return 0x338;
        case 8:
            return 0x348;
        default:
            return 0;
    }
}

static void SBUnityBridgeReadMasterModelStatics(SBUnityBridgeBattleConstructResult *result,
                                                SBUnityMetadataInitFn metadataInit,
                                                uintptr_t unityBase,
                                                int32_t battleType) {
    if (!result || !unityBase) {
        return;
    }

    uintptr_t globalAddress = unityBase + SBUnityMasterModelTypeInfoGlobalRVA;
    result->masterModelTypeInfoGlobal = globalAddress;
    if (metadataInit) {
        metadataInit((void *)globalAddress);
    }

    void *typeInfo = *(void **)globalAddress;
    result->masterModelTypeInfo = (uintptr_t)typeInfo;
    result->masterModelTypeReady = typeInfo != NULL;
    if (!typeInfo) {
        return;
    }

    void *staticFields = *(void **)((uint8_t *)typeInfo + 0xB8);
    result->masterModelStaticFields = (uintptr_t)staticFields;
    result->masterModelStaticFieldsReady = staticFields != NULL;
    if (!staticFields) {
        return;
    }
    result->masterModelLoaded = *(uint8_t *)staticFields != 0;

    int32_t collectionOffset = SBUnityBridgeStageMasterCollectionOffset(battleType);
    result->stageMasterCollectionOffset = collectionOffset;
    if (collectionOffset == 0) {
        return;
    }

    void *collection = *(void **)((uint8_t *)staticFields + collectionOffset);
    result->stageMasterCollection = (uintptr_t)collection;
    result->stageMasterCollectionReady = collection != NULL;
}

static void SBUnityBridgeEmitProgress(NSString *event, NSString *format, ...) {
    SBUnityBridgeProgressHandler handler = SBUnityBridgeProgress;
    if (!handler) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *detail = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    handler(event ?: @"unity-bridge", detail ?: @"");
}

static void SBUnityBridgeSetBattleConstructStep(SBUnityBridgeBattleConstructResult *result, const char *step) {
    if (!result || !step) {
        return;
    }
    snprintf(result->lastStep, sizeof(result->lastStep), "%s", step);
}

static uintptr_t SBUnityBridgeFindImageBase(const char *needle) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, needle)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

static void *SBUnityBridgeFunctionAtRVA(uintptr_t imageBase, uintptr_t rva) {
    if (!imageBase || !rva) {
        return NULL;
    }

    void *ptr = (void *)(imageBase + rva);
#if __has_feature(ptrauth_calls)
    ptr = ptrauth_sign_unauthenticated(ptr, ptrauth_key_function_pointer, 0);
#endif
    return ptr;
}

static void *SBUnityBridgeResolveSymbol(const char *symbol) {
    if (!symbol || !symbol[0]) {
        return NULL;
    }
    void *value = dlsym(RTLD_DEFAULT, symbol);
    if (value) {
        return value;
    }

    void *handle = dlopen(NULL, RTLD_NOW);
    return handle ? dlsym(handle, symbol) : NULL;
}

static int32_t SBUnityBridgeArrayCount(void *arrayObject, int32_t maxCount) {
    if (!arrayObject) {
        return 0;
    }

    uintptr_t length = *(uintptr_t *)((uint8_t *)arrayObject + 0x18);
    if (length > (uintptr_t)INT32_MAX) {
        length = (uintptr_t)INT32_MAX;
    }
    int32_t count = (int32_t)length;
    if (maxCount > 0 && count > maxCount) {
        count = maxCount;
    }
    return count;
}

static void *SBUnityBridgeArrayItem(void *arrayObject, int32_t index) {
    if (!arrayObject || index < 0) {
        return NULL;
    }
    return *(void **)((uint8_t *)arrayObject + 0x20 + ((uintptr_t)index * sizeof(void *)));
}

static void SBUnityBridgeSetError(SBUnityBridgeReadyResult *result, const char *error) {
    if (!result || !error) {
        return;
    }
    snprintf(result->error, sizeof(result->error), "%s", error);
}

static void SBUnityBridgeSetBattleDetailError(SBUnityBridgeBattleDetailResult *result, const char *error) {
    if (!result || !error) {
        return;
    }
    snprintf(result->error, sizeof(result->error), "%s", error);
}

static BOOL SBUnityBridgeReadString(void *managedString,
                                    char *out,
                                    size_t outSize,
                                    int32_t *lengthOut);
static BOOL SBUnityBridgeReadStringPreview(void *managedString,
                                           char *out,
                                           size_t outSize,
                                           int32_t *lengthOut,
                                           NSUInteger maxCharacters);

static void SBUnityBridgeSetBattleConstructError(SBUnityBridgeBattleConstructResult *result, const char *error) {
    if (!result || !error) {
        return;
    }
    snprintf(result->error, sizeof(result->error), "%s", error);
}

static void SBUnityBridgeSetSceneProbeStep(SBUnityBridgeSceneProbeResult *result, const char *step) {
    if (!result || !step) {
        return;
    }
    snprintf(result->lastStep, sizeof(result->lastStep), "%s", step);
}

static void SBUnityBridgeSetSceneProbeError(SBUnityBridgeSceneProbeResult *result, const char *error) {
    if (!result || !error) {
        return;
    }
    snprintf(result->error, sizeof(result->error), "%s", error);
}

static void SBUnityBridgeCaptureCurrentExceptionType(SBUnityBridgeBattleConstructResult *result) {
    if (!result) {
        return;
    }

    const std::type_info *exceptionType = __cxxabiv1::__cxa_current_exception_type();
    const char *name = exceptionType ? exceptionType->name() : "unknown";
    int status = 0;
    char *demangled = exceptionType ? abi::__cxa_demangle(name, NULL, NULL, &status) : NULL;
    snprintf(result->masterDataLoadExceptionType,
             sizeof(result->masterDataLoadExceptionType),
             "%s",
             (status == 0 && demangled) ? demangled : name);
    if (demangled) {
        free(demangled);
    }
}

static void SBUnityBridgeReadManagedException(SBUnityBridgeBattleConstructResult *result,
                                              void *exception) {
    if (!result || !exception) {
        return;
    }

    result->masterDataLoadException = (uintptr_t)exception;
    void *className = *(void **)((uint8_t *)exception + 0x10);
    void *message = *(void **)((uint8_t *)exception + 0x18);
    SBUnityBridgeReadString(className,
                            result->masterDataLoadExceptionClass,
                            sizeof(result->masterDataLoadExceptionClass),
                            NULL);
    SBUnityBridgeReadString(message,
                            result->masterDataLoadExceptionMessage,
                            sizeof(result->masterDataLoadExceptionMessage),
                            NULL);
}

static void SBUnityBridgeReadCurrentIl2CppExceptionWrapper(SBUnityBridgeBattleConstructResult *result) {
    if (!result || strcmp(result->masterDataLoadExceptionType, "Il2CppExceptionWrapper") != 0) {
        return;
    }

    SBCxaCurrentPrimaryExceptionFn currentPrimaryException =
        (SBCxaCurrentPrimaryExceptionFn)SBUnityBridgeResolveSymbol("__cxa_current_primary_exception");
    SBCxaDecrementExceptionRefcountFn decrementExceptionRefcount =
        (SBCxaDecrementExceptionRefcountFn)SBUnityBridgeResolveSymbol("__cxa_decrement_exception_refcount");
    if (!currentPrimaryException || !decrementExceptionRefcount) {
        return;
    }

    void *wrapper = currentPrimaryException();
    result->masterDataLoadExceptionWrapper = (uintptr_t)wrapper;
    if (!wrapper) {
        return;
    }

    void *managedException = *(void **)wrapper;
    SBUnityBridgeReadManagedException(result, managedException);
    decrementExceptionRefcount(wrapper);
}

static void SBUnityBridgeReadManagedExceptionString(SBUnityBridgeBattleConstructResult *result,
                                                    SBUnityInstanceToStringFn exceptionToString) {
    if (!result || !result->masterDataLoadException || !exceptionToString) {
        return;
    }

    try {
        void *exceptionString = exceptionToString((void *)result->masterDataLoadException, NULL);
        SBUnityBridgeReadString(exceptionString,
                                result->masterDataLoadExceptionString,
                                sizeof(result->masterDataLoadExceptionString),
                                NULL);
    } catch (...) {
        snprintf(result->masterDataLoadExceptionString,
                 sizeof(result->masterDataLoadExceptionString),
                 "Exception.ToString raised an exception");
    }
}

static void SBUnityBridgeReadTsvErrorCollector(SBUnityBridgeBattleConstructResult *result,
                                               void *collector,
                                               SBUnityInstanceGetBoolFn getHasError,
                                               SBUnityInstanceToStringFn toString) {
    if (!result || !collector) {
        return;
    }

    try {
        if (getHasError) {
            result->tsvErrorCollectorHasError = getHasError(collector, NULL);
        }
        if (toString) {
            void *reportString = toString(collector, NULL);
            SBUnityBridgeReadString(reportString,
                                    result->tsvErrorCollectorReport,
                                    sizeof(result->tsvErrorCollectorReport),
                                    NULL);
        }
    } catch (...) {
        snprintf(result->tsvErrorCollectorReport,
                 sizeof(result->tsvErrorCollectorReport),
                 "TsvErrorCollector inspection raised an exception");
    }
}

struct SBUnityNullableInt32Value {
    BOOL hasValue;
    int32_t value;
};

static SBUnityNullableInt32Value SBUnityBridgeReadNullableInt32(void *nullableField) {
    SBUnityNullableInt32Value value = {NO, 0};
    if (!nullableField) {
        return value;
    }
    uint8_t *bytes = (uint8_t *)nullableField;
    value.hasValue = *(bool *)(bytes + 0x0);
    value.value = *(int32_t *)(bytes + 0x4);
    return value;
}

static id SBUnityBridgeJSONObjectForNullableInt32(SBUnityNullableInt32Value value) {
    return value.hasValue ? @(value.value) : (id)NSNull.null;
}

static NSString *SBUnityBridgeJSONStringForNullableInt32(SBUnityNullableInt32Value value) {
    return value.hasValue ? [NSString stringWithFormat:@"%d", value.value] : @"null";
}

static NSArray<NSDictionary *> *SBUnityBridgeMoveSelectionDictionariesFromList(uintptr_t listAddress) {
    if (!listAddress) {
        return @[];
    }

    uint8_t *listBytes = (uint8_t *)listAddress;
    void *itemsArray = *(void **)(listBytes + 0x10);
    int32_t size = *(int32_t *)(listBytes + 0x18);
    if (!itemsArray || size <= 0) {
        return @[];
    }

    uint8_t *arrayBytes = (uint8_t *)itemsArray;
    uintptr_t maxLength = *(uintptr_t *)(arrayBytes + 0x18);
    int32_t count = size;
    if (maxLength < (uintptr_t)count) {
        count = maxLength <= INT32_MAX ? (int32_t)maxLength : INT32_MAX;
    }
    if (count > 512) {
        count = 512;
    }

    NSMutableArray<NSDictionary *> *moves = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + 0x20 + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            continue;
        }

        uint8_t *moveBytes = (uint8_t *)moveSelection;
        int32_t teamId = (int32_t)*(uint8_t *)(moveBytes + 0x10);
        int32_t playerIndex = *(int32_t *)(moveBytes + 0x14);
        SBUnityNullableInt32Value moveIndex = SBUnityBridgeReadNullableInt32(moveBytes + 0x18);
        SBUnityNullableInt32Value moveCode = SBUnityBridgeReadNullableInt32(moveBytes + 0x20);
        BOOL hasMove = moveIndex.hasValue && moveCode.hasValue;

        [moves addObject:@{
            @"HasMove": @(hasMove),
            @"TeamId": @(teamId),
            @"PlayerIndex": @(playerIndex),
            @"MoveIndex": SBUnityBridgeJSONObjectForNullableInt32(moveIndex),
            @"MoveCode": SBUnityBridgeJSONObjectForNullableInt32(moveCode)
        }];
    }
    return moves;
}

static NSDictionary *SBUnityBridgeFinishMainStoryBattleRequestBody(SBUnityBridgeBattleConstructResult result) {
    NSArray<NSDictionary *> *moves = SBUnityBridgeMoveSelectionDictionariesFromList(result.moveSelections);
    return @{
        @"$type": @"FinishMainStoryBattleReq",
        @"ExpectedResult": @(result.finalResult),
        @"ExpectedAScore": @(result.aScore),
        @"ExpectedBScore": @(result.bScore),
        @"MoveSelections": moves ?: @[]
    };
}

static NSString *SBUnityBridgeFinishMainStoryBattleRequestRawBody(SBUnityBridgeBattleConstructResult result) {
    if (!result.moveSelections) {
        return @"";
    }

    uint8_t *listBytes = (uint8_t *)result.moveSelections;
    void *itemsArray = *(void **)(listBytes + 0x10);
    int32_t size = *(int32_t *)(listBytes + 0x18);
    if (!itemsArray || size < 0) {
        return @"";
    }

    uint8_t *arrayBytes = (uint8_t *)itemsArray;
    uintptr_t maxLength = *(uintptr_t *)(arrayBytes + 0x18);
    int32_t count = size;
    if (maxLength < (uintptr_t)count) {
        count = maxLength <= INT32_MAX ? (int32_t)maxLength : INT32_MAX;
    }
    if (count > 512) {
        count = 512;
    }

    NSMutableString *raw = [NSMutableString stringWithFormat:
        @"{\"$type\":\"FinishMainStoryBattleReq\",\"ExpectedResult\":%d,\"ExpectedAScore\":%d,\"ExpectedBScore\":%d,\"MoveSelections\":[",
        result.finalResult,
        result.aScore,
        result.bScore];
    BOOL first = YES;
    for (int32_t i = 0; i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + 0x20 + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            continue;
        }

        uint8_t *moveBytes = (uint8_t *)moveSelection;
        int32_t teamId = (int32_t)*(uint8_t *)(moveBytes + 0x10);
        int32_t playerIndex = *(int32_t *)(moveBytes + 0x14);
        SBUnityNullableInt32Value moveIndex = SBUnityBridgeReadNullableInt32(moveBytes + 0x18);
        SBUnityNullableInt32Value moveCode = SBUnityBridgeReadNullableInt32(moveBytes + 0x20);
        BOOL hasMove = moveIndex.hasValue && moveCode.hasValue;

        if (!first) {
            [raw appendString:@","];
        }
        first = NO;
        [raw appendFormat:
            @"{\"HasMove\":%@,\"TeamId\":%d,\"PlayerIndex\":%d,\"MoveIndex\":%@,\"MoveCode\":%@}",
            hasMove ? @"true" : @"false",
            teamId,
            playerIndex,
            SBUnityBridgeJSONStringForNullableInt32(moveIndex),
            SBUnityBridgeJSONStringForNullableInt32(moveCode)];
    }
    [raw appendString:@"]}"];
    return raw;
}

static NSArray<NSDictionary *> *SBUnityBridgeMoveSelectionDictionariesFromArray(void *array) {
    if (!array) {
        return @[];
    }

    uint8_t *arrayBytes = (uint8_t *)array;
    uintptr_t length = *(uintptr_t *)(arrayBytes + 0x18);
    int32_t count = length <= INT32_MAX ? (int32_t)length : INT32_MAX;
    if (count > 512) {
        count = 512;
    }

    NSMutableArray<NSDictionary *> *moves = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    for (int32_t i = 0; i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + 0x20 + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            continue;
        }

        uint8_t *moveBytes = (uint8_t *)moveSelection;
        int32_t teamId = (int32_t)*(uint8_t *)(moveBytes + 0x10);
        int32_t playerIndex = *(int32_t *)(moveBytes + 0x14);
        SBUnityNullableInt32Value moveIndex = SBUnityBridgeReadNullableInt32(moveBytes + 0x18);
        SBUnityNullableInt32Value moveCode = SBUnityBridgeReadNullableInt32(moveBytes + 0x20);
        BOOL hasMove = moveIndex.hasValue && moveCode.hasValue;

        [moves addObject:@{
            @"HasMove": @(hasMove),
            @"TeamId": @(teamId),
            @"PlayerIndex": @(playerIndex),
            @"MoveIndex": SBUnityBridgeJSONObjectForNullableInt32(moveIndex),
            @"MoveCode": SBUnityBridgeJSONObjectForNullableInt32(moveCode)
        }];
    }
    return moves;
}

static NSDictionary *SBUnityBridgeFinishMainStoryBattleRequestBodyFromReq(void *req) {
    if (!req) {
        return @{};
    }

    uint8_t *reqBytes = (uint8_t *)req;
    void *movesArray = *(void **)(reqBytes + 0x28);
    return @{
        @"$type": @"FinishMainStoryBattleReq",
        @"ExpectedResult": @(*(int32_t *)(reqBytes + 0x1C)),
        @"ExpectedAScore": @(*(int32_t *)(reqBytes + 0x20)),
        @"ExpectedBScore": @(*(int32_t *)(reqBytes + 0x24)),
        @"MoveSelections": SBUnityBridgeMoveSelectionDictionariesFromArray(movesArray)
    };
}

static NSString *SBUnityBridgeFinishMainStoryBattleRequestRawBodyFromReq(void *req) {
    if (!req) {
        return @"";
    }

    uint8_t *reqBytes = (uint8_t *)req;
    void *movesArray = *(void **)(reqBytes + 0x28);
    uint8_t *arrayBytes = (uint8_t *)movesArray;
    uintptr_t length = arrayBytes ? *(uintptr_t *)(arrayBytes + 0x18) : 0;
    int32_t count = length <= INT32_MAX ? (int32_t)length : INT32_MAX;
    if (count > 512) {
        count = 512;
    }

    NSMutableString *raw = [NSMutableString stringWithFormat:
        @"{\"$type\":\"FinishMainStoryBattleReq\",\"ExpectedResult\":%d,\"ExpectedAScore\":%d,\"ExpectedBScore\":%d,\"MoveSelections\":[",
        *(int32_t *)(reqBytes + 0x1C),
        *(int32_t *)(reqBytes + 0x20),
        *(int32_t *)(reqBytes + 0x24)];
    BOOL first = YES;
    for (int32_t i = 0; arrayBytes && i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + 0x20 + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            continue;
        }

        uint8_t *moveBytes = (uint8_t *)moveSelection;
        int32_t teamId = (int32_t)*(uint8_t *)(moveBytes + 0x10);
        int32_t playerIndex = *(int32_t *)(moveBytes + 0x14);
        SBUnityNullableInt32Value moveIndex = SBUnityBridgeReadNullableInt32(moveBytes + 0x18);
        SBUnityNullableInt32Value moveCode = SBUnityBridgeReadNullableInt32(moveBytes + 0x20);
        BOOL hasMove = moveIndex.hasValue && moveCode.hasValue;

        if (!first) {
            [raw appendString:@","];
        }
        first = NO;
        [raw appendFormat:
            @"{\"HasMove\":%@,\"TeamId\":%d,\"PlayerIndex\":%d,\"MoveIndex\":%@,\"MoveCode\":%@}",
            hasMove ? @"true" : @"false",
            teamId,
            playerIndex,
            SBUnityBridgeJSONStringForNullableInt32(moveIndex),
            SBUnityBridgeJSONStringForNullableInt32(moveCode)];
    }
    [raw appendString:@"]}"];
    return raw;
}

static uintptr_t SBUnityBridgeUnityBase(void) {
    uintptr_t unityBase = SBUnityBridgeFindImageBase("/UnityFramework.framework/UnityFramework");
    if (!unityBase) {
        unityBase = SBUnityBridgeFindImageBase("UnityFramework");
    }
    return unityBase;
}

static BOOL SBUnityBridgeReadString(void *managedString,
                                    char *out,
                                    size_t outSize,
                                    int32_t *lengthOut) {
    if (!managedString || !out || outSize == 0) {
        return NO;
    }

    int32_t length = *(int32_t *)((uint8_t *)managedString + 16);
    if (length < 0 || length > 8192) {
        return NO;
    }

    const unichar *chars = (const unichar *)((const uint8_t *)managedString + 20);
    NSString *text = [[NSString alloc] initWithCharacters:chars length:(NSUInteger)length];
    snprintf(out, outSize, "%s", text.UTF8String ?: "");
    if (lengthOut) {
        *lengthOut = length;
    }
    return YES;
}

static BOOL SBUnityBridgeReadStringPreview(void *managedString,
                                           char *out,
                                           size_t outSize,
                                           int32_t *lengthOut,
                                           NSUInteger maxCharacters) {
    if (!managedString || !out || outSize == 0) {
        return NO;
    }

    int32_t length = *(int32_t *)((uint8_t *)managedString + 16);
    if (length < 0 || length > 4 * 1024 * 1024) {
        return NO;
    }

    NSUInteger previewLength = MIN((NSUInteger)length, maxCharacters);
    const unichar *chars = (const unichar *)((const uint8_t *)managedString + 20);
    NSString *text = [[NSString alloc] initWithCharacters:chars length:previewLength];
    snprintf(out, outSize, "%s", text.UTF8String ?: "");
    if (lengthOut) {
        *lengthOut = length;
    }
    return YES;
}

static void *SBUnityBridgeCreateManagedString(SBUnityStringAllocLenFn allocString, NSString *text) {
    if (!allocString || !text) {
        return NULL;
    }

    NSUInteger length = text.length;
    if (length > UINT32_MAX) {
        return NULL;
    }

    void *managed = allocString((uint32_t)length);
    if (!managed) {
        return NULL;
    }

    if (length > 0) {
        [text getCharacters:(unichar *)((uint8_t *)managed + 20)
                      range:NSMakeRange(0, length)];
    }
    return managed;
}

static void *SBUnityBridgeResolveTypeInfo(SBUnityMetadataInitFn metadataInit,
                                          uintptr_t unityBase,
                                          uintptr_t typeInfoGlobalRVA,
                                          uintptr_t *globalAddressOut) {
    if (!metadataInit || !unityBase || !typeInfoGlobalRVA) {
        return NULL;
    }

    uintptr_t globalAddress = unityBase + typeInfoGlobalRVA;
    if (globalAddressOut) {
        *globalAddressOut = globalAddress;
    }

    metadataInit((void *)globalAddress);
    return *(void **)globalAddress;
}

SBUnityBridgeReadyResult SBUnityBridgeRunReadyProbe(void) {
    SBUnityBridgeReadyResult result = {0};

    uintptr_t unityBase = SBUnityBridgeUnityBase();
    result.unityBase = unityBase;
    result.unityFound = unityBase != 0;
    if (!unityBase) {
        SBUnityBridgeSetError(&result, "UnityFramework image not found");
        return result;
    }

    SBUnityStringAllocLenFn allocString =
        (SBUnityStringAllocLenFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityStringAllocLenRVA);
    SBUnityStringIsNullOrEmptyFn isNullOrEmpty =
        (SBUnityStringIsNullOrEmptyFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityStringIsNullOrEmptyRVA);

    result.stringAllocAddress = (uintptr_t)allocString;
    result.isNullOrEmptyAddress = (uintptr_t)isNullOrEmpty;
    if (!allocString || !isNullOrEmpty) {
        SBUnityBridgeSetError(&result, "UnityFramework runtime function missing");
        return result;
    }

    static const uint16_t readyText[] = {'r', 'e', 'a', 'd', 'y'};
    void *managed = allocString(5);
    result.managedString = (uintptr_t)managed;
    result.stringAllocated = managed != NULL;
    if (!managed) {
        SBUnityBridgeSetError(&result, "System.String allocation failed");
        return result;
    }

    memcpy((uint8_t *)managed + 20, readyText, sizeof(readyText));

    result.roundTripOK = SBUnityBridgeReadString(managed,
                                                 result.roundTrip,
                                                 sizeof(result.roundTrip),
                                                 &result.managedLength);
    if (result.roundTripOK) {
        result.roundTripOK = strcmp(result.roundTrip, "ready") == 0 && result.managedLength == 5;
    }

    bool nullIsEmpty = isNullOrEmpty(NULL);
    bool readyIsEmpty = isNullOrEmpty(managed);
    result.nullCheckOK = nullIsEmpty;
    result.readyCheckOK = !readyIsEmpty;
    result.ok = result.unityFound &&
                result.stringAllocated &&
                result.roundTripOK &&
                result.nullCheckOK &&
                result.readyCheckOK;
    if (!result.ok) {
        SBUnityBridgeSetError(&result, "Unity runtime string probe failed");
    }
    return result;
}

NSDictionary *SBUnityBridgeReadyResultDictionary(SBUnityBridgeReadyResult result) {
    return @{
        @"ok": @(result.ok),
        @"unityFound": @(result.unityFound),
        @"stringAllocated": @(result.stringAllocated),
        @"roundTripOK": @(result.roundTripOK),
        @"nullCheckOK": @(result.nullCheckOK),
        @"readyCheckOK": @(result.readyCheckOK),
        @"unityBase": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.unityBase],
        @"stringAllocRVA": @"0x3BD87C",
        @"stringAlloc": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stringAllocAddress],
        @"isNullOrEmptyRVA": @"0x655C334",
        @"isNullOrEmpty": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.isNullOrEmptyAddress],
        @"managedString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.managedString],
        @"managedLength": @(result.managedLength),
        @"roundTrip": [NSString stringWithUTF8String:result.roundTrip] ?: @"",
        @"error": [NSString stringWithUTF8String:result.error] ?: @""
    };
}

SBUnityBridgeSceneProbeResult SBUnityBridgeRunSceneProbe(void) {
    SBUnityBridgeSceneProbeResult result = {0};
    SBUnityBridgeSetSceneProbeStep(&result, "start");

    uintptr_t unityBase = SBUnityBridgeUnityBase();
    result.unityBase = unityBase;
    result.unityFound = unityBase != 0;
    if (!unityBase) {
        SBUnityBridgeSetSceneProbeError(&result, "UnityFramework image not found");
        return result;
    }

    SBUnityResourcesFindObjectsOfTypeAllFn findObjectsOfTypeAll =
        (SBUnityResourcesFindObjectsOfTypeAllFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                          SBUnityResourcesFindObjectsOfTypeAllRVA);
    result.resourcesFindObjectsOfTypeAllAddress = (uintptr_t)findObjectsOfTypeAll;
    result.resourcesFindReady = findObjectsOfTypeAll != NULL;
    if (!findObjectsOfTypeAll) {
        SBUnityBridgeSetSceneProbeError(&result, "UnityEngine.Resources.FindObjectsOfTypeAll missing");
        return result;
    }

    SBIl2CppDomainGetFn domainGet =
        (SBIl2CppDomainGetFn)SBUnityBridgeResolveSymbol("il2cpp_domain_get");
    SBIl2CppThreadAttachFn threadAttach =
        (SBIl2CppThreadAttachFn)SBUnityBridgeResolveSymbol("il2cpp_thread_attach");
    SBIl2CppDomainAssemblyOpenFn domainAssemblyOpen =
        (SBIl2CppDomainAssemblyOpenFn)SBUnityBridgeResolveSymbol("il2cpp_domain_assembly_open");
    SBIl2CppAssemblyGetImageFn assemblyGetImage =
        (SBIl2CppAssemblyGetImageFn)SBUnityBridgeResolveSymbol("il2cpp_assembly_get_image");
    SBIl2CppClassFromNameFn classFromName =
        (SBIl2CppClassFromNameFn)SBUnityBridgeResolveSymbol("il2cpp_class_from_name");
    SBIl2CppClassGetTypeFn classGetType =
        (SBIl2CppClassGetTypeFn)SBUnityBridgeResolveSymbol("il2cpp_class_get_type");
    SBIl2CppTypeGetObjectFn typeGetObject =
        (SBIl2CppTypeGetObjectFn)SBUnityBridgeResolveSymbol("il2cpp_type_get_object");
    if (!domainGet || !threadAttach || !domainAssemblyOpen || !assemblyGetImage ||
        !classFromName || !classGetType || !typeGetObject) {
        SBUnityBridgeSetSceneProbeError(&result, "required il2cpp exported API missing");
        return result;
    }

    SBUnityBridgeSetSceneProbeStep(&result, "before il2cpp domain");
    void *domain = domainGet();
    result.domain = (uintptr_t)domain;
    result.domainReady = domain != NULL;
    if (!domain) {
        SBUnityBridgeSetSceneProbeError(&result, "il2cpp_domain_get returned null");
        return result;
    }

    result.threadAttached = threadAttach(domain) != NULL;

    void *assembly = domainAssemblyOpen(domain, "Assembly-CSharp");
    if (!assembly) {
        assembly = domainAssemblyOpen(domain, "Assembly-CSharp.dll");
    }
    result.assembly = (uintptr_t)assembly;
    result.assemblyReady = assembly != NULL;
    if (!assembly) {
        SBUnityBridgeSetSceneProbeError(&result, "Assembly-CSharp assembly not found");
        return result;
    }

    void *image = assemblyGetImage(assembly);
    result.image = (uintptr_t)image;
    result.imageReady = image != NULL;
    if (!image) {
        SBUnityBridgeSetSceneProbeError(&result, "Assembly-CSharp image not found");
        return result;
    }

    void *battleStarterClass = classFromName(image, "Soccer", "BattleStarterVM");
    void *soccerBattleVMClass = classFromName(image, "Soccer", "SoccerBattleVM");
    result.battleStarterClass = (uintptr_t)battleStarterClass;
    result.soccerBattleVMClass = (uintptr_t)soccerBattleVMClass;
    result.battleStarterClassReady = battleStarterClass != NULL;
    result.soccerBattleVMClassReady = soccerBattleVMClass != NULL;
    if (!battleStarterClass || !soccerBattleVMClass) {
        SBUnityBridgeSetSceneProbeError(&result, "BattleStarterVM or SoccerBattleVM class not found");
        return result;
    }

    void *battleStarterType = classGetType(battleStarterClass);
    void *soccerBattleVMType = classGetType(soccerBattleVMClass);
    result.battleStarterType = (uintptr_t)battleStarterType;
    result.soccerBattleVMType = (uintptr_t)soccerBattleVMType;
    result.battleStarterTypeReady = battleStarterType != NULL;
    result.soccerBattleVMTypeReady = soccerBattleVMType != NULL;
    if (!battleStarterType || !soccerBattleVMType) {
        SBUnityBridgeSetSceneProbeError(&result, "managed class type missing");
        return result;
    }

    void *battleStarterSystemType = typeGetObject(battleStarterType);
    void *soccerBattleVMSystemType = typeGetObject(soccerBattleVMType);
    result.battleStarterSystemType = (uintptr_t)battleStarterSystemType;
    result.soccerBattleVMSystemType = (uintptr_t)soccerBattleVMSystemType;
    result.battleStarterSystemTypeReady = battleStarterSystemType != NULL;
    result.soccerBattleVMSystemTypeReady = soccerBattleVMSystemType != NULL;
    if (!battleStarterSystemType || !soccerBattleVMSystemType) {
        SBUnityBridgeSetSceneProbeError(&result, "System.Type object missing");
        return result;
    }

    SBUnityBridgeSetSceneProbeStep(&result, "before FindObjectsOfTypeAll");
    void *battleStarterArray = NULL;
    void *soccerBattleVMArray = NULL;
    try {
        battleStarterArray = findObjectsOfTypeAll(battleStarterSystemType, NULL);
        soccerBattleVMArray = findObjectsOfTypeAll(soccerBattleVMSystemType, NULL);
    } catch (...) {
        SBUnityBridgeSetSceneProbeError(&result, "FindObjectsOfTypeAll raised an exception");
        return result;
    }

    result.battleStarterArray = (uintptr_t)battleStarterArray;
    result.soccerBattleVMArray = (uintptr_t)soccerBattleVMArray;
    result.battleStarterArrayReady = battleStarterArray != NULL;
    result.soccerBattleVMArrayReady = soccerBattleVMArray != NULL;
    result.battleStarterCount = SBUnityBridgeArrayCount(battleStarterArray, INT32_MAX);
    result.soccerBattleVMCount = SBUnityBridgeArrayCount(soccerBattleVMArray, INT32_MAX);

    int32_t starterScanCount = SBUnityBridgeArrayCount(battleStarterArray, 64);
    for (int32_t i = 0; i < starterScanCount; i++) {
        void *candidate = SBUnityBridgeArrayItem(battleStarterArray, i);
        if (!candidate) {
            continue;
        }
        void *candidateBattleVM = *(void **)((uint8_t *)candidate + 0x20);
        void *candidatePageOpenRequestStore = *(void **)((uint8_t *)candidate + 0x28);
        void *candidateBattleModel = *(void **)((uint8_t *)candidate + 0x58);
        void *candidateOpenReq = *(void **)((uint8_t *)candidate + 0x70);
        void *candidateStageContext = candidateOpenReq ? *(void **)((uint8_t *)candidateOpenReq + 0x28) : NULL;
        if (!result.battleStarter) {
            result.battleStarter = (uintptr_t)candidate;
            result.battleStarterCachedPtr = *(uintptr_t *)((uint8_t *)candidate + 0x10);
            result.pageOpenRequestStore = (uintptr_t)candidatePageOpenRequestStore;
            result.battleOpenReq = (uintptr_t)candidateOpenReq;
            result.battleOpenReqStageContext = (uintptr_t)candidateStageContext;
            result.soccerBattleVMFromStarter = (uintptr_t)candidateBattleVM;
            result.soccerBattleModel = (uintptr_t)candidateBattleModel;
        }
        if (candidateBattleVM && candidateBattleModel &&
            (!result.battleOpenReqStageContext || candidateStageContext)) {
            result.battleStarter = (uintptr_t)candidate;
            result.battleStarterCachedPtr = *(uintptr_t *)((uint8_t *)candidate + 0x10);
            result.pageOpenRequestStore = (uintptr_t)candidatePageOpenRequestStore;
            result.battleOpenReq = (uintptr_t)candidateOpenReq;
            result.battleOpenReqStageContext = (uintptr_t)candidateStageContext;
            result.soccerBattleVMFromStarter = (uintptr_t)candidateBattleVM;
            result.soccerBattleModel = (uintptr_t)candidateBattleModel;
            if (candidateStageContext) {
                break;
            }
        }
    }

    void *pageOpenRequestStore = (void *)result.pageOpenRequestStore;
    if (pageOpenRequestStore) {
        result.pageOpenRequestStoreUILayerManager = *(uintptr_t *)((uint8_t *)pageOpenRequestStore + 0x18);
        result.pageOpenRequestStoreReq = *(uintptr_t *)((uint8_t *)pageOpenRequestStore + 0x20);
    }

    void *openReq = (void *)result.battleOpenReq;
    if (openReq) {
        result.battleOpenReqBackRequest = *(uintptr_t *)((uint8_t *)openReq + 0x18);
        result.battleOpenReqBattlePlayMode = *(int32_t *)((uint8_t *)openReq + 0x20);
        result.battleOpenReqFormationDeckCode = *(int32_t *)((uint8_t *)openReq + 0x24);
        result.battleOpenReqStageContext = *(uintptr_t *)((uint8_t *)openReq + 0x28);
        result.battleOpenReqRetryRequest = *(uintptr_t *)((uint8_t *)openReq + 0x30);
        result.battleOpenReqReplay = *(uintptr_t *)((uint8_t *)openReq + 0x38);
        result.battleOpenReqDebugPlaywrightBook = *(uintptr_t *)((uint8_t *)openReq + 0x40);
    }

    void *stageContext = (void *)result.battleOpenReqStageContext;
    if (stageContext) {
        result.stageContextField10 = *(uintptr_t *)((uint8_t *)stageContext + 0x10);
        result.stageContextField18 = *(uintptr_t *)((uint8_t *)stageContext + 0x18);
        result.stageContextField20 = *(uintptr_t *)((uint8_t *)stageContext + 0x20);
        result.stageContextField28 = *(uintptr_t *)((uint8_t *)stageContext + 0x28);
        result.stageContextAreaChanged = *(BOOL *)((uint8_t *)stageContext + 0x30);
        result.stageContextInitialAction = *(int32_t *)((uint8_t *)stageContext + 0x34);
    }

    void *soccerBattleVM = (void *)result.soccerBattleVMFromStarter;
    if (!soccerBattleVM) {
        soccerBattleVM = SBUnityBridgeArrayItem(soccerBattleVMArray, 0);
        result.soccerBattleVMFirst = (uintptr_t)soccerBattleVM;
    } else {
        result.soccerBattleVMFirst = (uintptr_t)SBUnityBridgeArrayItem(soccerBattleVMArray, 0);
    }
    if (soccerBattleVM) {
        result.soccerBattleVMCachedPtr = *(uintptr_t *)((uint8_t *)soccerBattleVM + 0x10);
        result.soccerBattleVMStadium = *(uintptr_t *)((uint8_t *)soccerBattleVM + 0x40);
        result.soccerBattleVMBall = *(uintptr_t *)((uint8_t *)soccerBattleVM + 0x48);
        result.soccerBattleVMInBattleUIVM = *(uintptr_t *)((uint8_t *)soccerBattleVM + 0xA8);
        result.soccerBattleVMWipeManager = *(uintptr_t *)((uint8_t *)soccerBattleVM + 0xC0);
    }

    result.battleStarterInstanceReady = result.battleStarter != 0;
    result.soccerBattleVMInstanceReady = result.soccerBattleVMFromStarter != 0 || soccerBattleVM != NULL;
    result.soccerBattleModelReady = result.soccerBattleModel != 0;
    result.pageOpenRequestStoreReady = result.pageOpenRequestStore != 0;
    result.pageOpenRequestStoreReqReady = result.pageOpenRequestStoreReq != 0;
    result.battleOpenReqReady = result.battleOpenReq != 0;
    result.openReqStageContextReady = result.battleOpenReqStageContext != 0;
    result.ok = result.unityFound &&
                result.domainReady &&
                result.assemblyReady &&
                result.imageReady &&
                result.resourcesFindReady &&
                result.battleStarterClassReady &&
                result.soccerBattleVMClassReady &&
                result.battleStarterSystemTypeReady &&
                result.soccerBattleVMSystemTypeReady &&
                result.battleStarterInstanceReady &&
                result.soccerBattleVMInstanceReady &&
                result.soccerBattleModelReady;
    SBUnityBridgeSetSceneProbeStep(&result, "done");
    if (!result.ok && result.error[0] == '\0') {
        SBUnityBridgeSetSceneProbeError(&result, "scene objects incomplete");
    }
    return result;
}

NSDictionary *SBUnityBridgeSceneProbeResultDictionary(SBUnityBridgeSceneProbeResult result) {
    return @{
        @"ok": @(result.ok),
        @"unityFound": @(result.unityFound),
        @"domainReady": @(result.domainReady),
        @"threadAttached": @(result.threadAttached),
        @"assemblyReady": @(result.assemblyReady),
        @"imageReady": @(result.imageReady),
        @"resourcesFindReady": @(result.resourcesFindReady),
        @"battleStarterClassReady": @(result.battleStarterClassReady),
        @"soccerBattleVMClassReady": @(result.soccerBattleVMClassReady),
        @"battleStarterTypeReady": @(result.battleStarterTypeReady),
        @"soccerBattleVMTypeReady": @(result.soccerBattleVMTypeReady),
        @"battleStarterSystemTypeReady": @(result.battleStarterSystemTypeReady),
        @"soccerBattleVMSystemTypeReady": @(result.soccerBattleVMSystemTypeReady),
        @"battleStarterArrayReady": @(result.battleStarterArrayReady),
        @"soccerBattleVMArrayReady": @(result.soccerBattleVMArrayReady),
        @"battleStarterInstanceReady": @(result.battleStarterInstanceReady),
        @"soccerBattleVMInstanceReady": @(result.soccerBattleVMInstanceReady),
        @"soccerBattleModelReady": @(result.soccerBattleModelReady),
        @"pageOpenRequestStoreReady": @(result.pageOpenRequestStoreReady),
        @"pageOpenRequestStoreReqReady": @(result.pageOpenRequestStoreReqReady),
        @"battleOpenReqReady": @(result.battleOpenReqReady),
        @"openReqStageContextReady": @(result.openReqStageContextReady),
        @"unityBase": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.unityBase],
        @"domain": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.domain],
        @"assembly": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.assembly],
        @"image": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.image],
        @"resourcesFindObjectsOfTypeAllRVA": @"0x7992D40",
        @"resourcesFindObjectsOfTypeAll": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.resourcesFindObjectsOfTypeAllAddress],
        @"battleStarterClass": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleStarterClass],
        @"soccerBattleVMClass": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMClass],
        @"battleStarterType": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleStarterType],
        @"soccerBattleVMType": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMType],
        @"battleStarterSystemType": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleStarterSystemType],
        @"soccerBattleVMSystemType": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMSystemType],
        @"battleStarterArray": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleStarterArray],
        @"soccerBattleVMArray": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMArray],
        @"battleStarter": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleStarter],
        @"battleStarterCachedPtr": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleStarterCachedPtr],
        @"pageOpenRequestStore": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.pageOpenRequestStore],
        @"pageOpenRequestStoreUILayerManager": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.pageOpenRequestStoreUILayerManager],
        @"pageOpenRequestStoreReq": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.pageOpenRequestStoreReq],
        @"battleOpenReq": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleOpenReq],
        @"battleOpenReqBackRequest": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleOpenReqBackRequest],
        @"battleOpenReqStageContext": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleOpenReqStageContext],
        @"battleOpenReqRetryRequest": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleOpenReqRetryRequest],
        @"battleOpenReqReplay": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleOpenReqReplay],
        @"battleOpenReqDebugPlaywrightBook": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleOpenReqDebugPlaywrightBook],
        @"stageContextField10": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageContextField10],
        @"stageContextField18": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageContextField18],
        @"stageContextField20": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageContextField20],
        @"stageContextField28": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageContextField28],
        @"soccerBattleVMFromStarter": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMFromStarter],
        @"soccerBattleModel": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleModel],
        @"soccerBattleVMFirst": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMFirst],
        @"soccerBattleVMCachedPtr": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMCachedPtr],
        @"soccerBattleVMStadium": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMStadium],
        @"soccerBattleVMBall": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMBall],
        @"soccerBattleVMInBattleUIVM": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMInBattleUIVM],
        @"soccerBattleVMWipeManager": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleVMWipeManager],
        @"battleOpenReqBattlePlayMode": @(result.battleOpenReqBattlePlayMode),
        @"battleOpenReqFormationDeckCode": @(result.battleOpenReqFormationDeckCode),
        @"stageContextAreaChanged": @(result.stageContextAreaChanged),
        @"stageContextInitialAction": @(result.stageContextInitialAction),
        @"battleStarterCount": @(result.battleStarterCount),
        @"soccerBattleVMCount": @(result.soccerBattleVMCount),
        @"battleStarterSoccerBattleVMOffset": @"0x20",
        @"battleStarterPageOpenRequestStoreOffset": @"0x28",
        @"battleStarterSoccerBattleModelOffset": @"0x58",
        @"battleStarterOpenReqOffset": @"0x70",
        @"pageOpenRequestStoreReqOffset": @"0x20",
        @"battleOpenReqBattlePlayModeOffset": @"0x20",
        @"battleOpenReqFormationDeckCodeOffset": @"0x24",
        @"battleOpenReqStageContextOffset": @"0x28",
        @"soccerBattleVMStadiumOffset": @"0x40",
        @"soccerBattleVMBallOffset": @"0x48",
        @"soccerBattleVMInBattleUIVMOffset": @"0xA8",
        @"soccerBattleVMWipeManagerOffset": @"0xC0",
        @"lastStep": [NSString stringWithUTF8String:result.lastStep] ?: @"",
        @"error": [NSString stringWithUTF8String:result.error] ?: @""
    };
}

SBUnityBridgeBattleDetailResult SBUnityBridgeRunBattleDetailProbe(NSString *detailJson) {
    SBUnityBridgeBattleDetailResult result = {0};

    if (detailJson.length == 0) {
        SBUnityBridgeSetBattleDetailError(&result, "empty DetailJson");
        return result;
    }

    uintptr_t unityBase = SBUnityBridgeUnityBase();
    result.unityBase = unityBase;
    result.unityFound = unityBase != 0;
    if (!unityBase) {
        SBUnityBridgeSetBattleDetailError(&result, "UnityFramework image not found");
        return result;
    }

    SBUnityStringAllocLenFn allocString =
        (SBUnityStringAllocLenFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityStringAllocLenRVA);
    SBUnityBattleReservationDetailFromJsonFn fromJson =
        (SBUnityBattleReservationDetailFromJsonFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                             SBUnityBattleReservationDetailFromJsonRVA);

    result.stringAllocAddress = (uintptr_t)allocString;
    result.fromJsonAddress = (uintptr_t)fromJson;
    if (!allocString || !fromJson) {
        SBUnityBridgeSetBattleDetailError(&result, "UnityFramework battle detail function missing");
        return result;
    }

    void *managedJson = SBUnityBridgeCreateManagedString(allocString, detailJson);
    result.managedJsonString = (uintptr_t)managedJson;
    result.stringAllocated = managedJson != NULL;
    result.jsonLength = (int32_t)MIN(detailJson.length, (NSUInteger)INT32_MAX);
    if (!managedJson) {
        SBUnityBridgeSetBattleDetailError(&result, "DetailJson System.String allocation failed");
        return result;
    }

    void *detail = fromJson(managedJson, NULL);
    result.reservationDetail = (uintptr_t)detail;
    result.detailParsed = detail != NULL;
    if (!detail) {
        SBUnityBridgeSetBattleDetailError(&result, "BattleReservationDetail.FromJson returned null");
        return result;
    }

    uint8_t *bytes = (uint8_t *)detail;
    result.battleType = *(int32_t *)(bytes + 0x10);
    result.seed = *(int32_t *)(bytes + 0x14);
    result.stageCode = *(int32_t *)(bytes + 0x30);
    result.ok = result.stageCode != 0 && result.seed != 0;
    if (!result.ok) {
        SBUnityBridgeSetBattleDetailError(&result, "BattleReservationDetail parsed but fields look invalid");
    }
    return result;
}

NSDictionary *SBUnityBridgeBattleDetailResultDictionary(SBUnityBridgeBattleDetailResult result) {
    return @{
        @"ok": @(result.ok),
        @"unityFound": @(result.unityFound),
        @"stringAllocated": @(result.stringAllocated),
        @"detailParsed": @(result.detailParsed),
        @"unityBase": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.unityBase],
        @"stringAllocRVA": @"0x3BD87C",
        @"stringAlloc": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stringAllocAddress],
        @"fromJsonRVA": @"0x69CA948",
        @"fromJson": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fromJsonAddress],
        @"managedJsonString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.managedJsonString],
        @"reservationDetail": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.reservationDetail],
        @"jsonLength": @(result.jsonLength),
        @"battleType": @(result.battleType),
        @"seed": @(result.seed),
        @"stageCode": @(result.stageCode),
        @"error": [NSString stringWithUTF8String:result.error] ?: @""
    };
}

SBUnityBridgeBattleConstructResult SBUnityBridgeRunBattleConstructProbe(NSString *detailJson,
                                                                        int32_t maxStage,
                                                                        NSString *serverVersionHash,
                                                                        NSString *masterDataPathOverride) {
    SBUnityBridgeBattleConstructResult result = {0};
    BOOL singleGetterStage = SBUnityBridgeIsSingleGetterStage(maxStage);
    BOOL rawStageMasterStaticsStage = SBUnityBridgeIsRawStageMasterStaticsStage(maxStage);
    BOOL directStageMasterStage = SBUnityBridgeIsDirectStageMasterStage(maxStage);
    BOOL masterLoadStage = SBUnityBridgeIsMasterLoadStage(maxStage);
    BOOL battleRunCoroutineStage = SBUnityBridgeIsBattleRunCoroutineStage(maxStage);
    if (!singleGetterStage &&
        !rawStageMasterStaticsStage &&
        !directStageMasterStage &&
        !masterLoadStage &&
        !battleRunCoroutineStage) {
        if (maxStage < 1) {
            maxStage = 1;
        }
        if (maxStage > 6) {
            maxStage = 6;
        }
    }
    result.maxStage = maxStage;
    result.initialResult = -1;

    if (detailJson.length == 0) {
        SBUnityBridgeSetBattleConstructError(&result, "empty DetailJson");
        return result;
    }

    uintptr_t unityBase = SBUnityBridgeUnityBase();
    result.unityBase = unityBase;
    result.unityFound = unityBase != 0;
    if (!unityBase) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework image not found");
        return result;
    }

    SBUnityStringAllocLenFn allocString =
        (SBUnityStringAllocLenFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityStringAllocLenRVA);
    SBUnityBattleReservationDetailFromJsonFn fromJson =
        (SBUnityBattleReservationDetailFromJsonFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                             SBUnityBattleReservationDetailFromJsonRVA);
    SBUnityMetadataInitFn metadataInit =
        (SBUnityMetadataInitFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityMetadataInitRVA);
    SBUnityObjectNewFn objectNew =
        (SBUnityObjectNewFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityObjectNewRVA);
    SBUnityStageMasterGetByBattleTypeFn getStageMasterByBattleType =
        (SBUnityStageMasterGetByBattleTypeFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                        SBUnityStageMasterGetByBattleTypeRVA);
    uintptr_t getStageMasterByBattleTypeMethodInfo = unityBase + SBUnityStageMasterGetByBattleTypeMethodInfoRVA;
    const void *getStageMasterByBattleTypeMethod = NULL;
    SBUnityFileSourceMasterLoaderLoadAllFn loadAllMasterDataWithoutTest =
        (SBUnityFileSourceMasterLoaderLoadAllFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                          SBUnityFileSourceMasterLoaderLoadAllMasterDataWithoutTestRVA);
    SBUnityFileSourceMasterLoaderLoadMasterDataFn loadMasterData =
        (SBUnityFileSourceMasterLoaderLoadMasterDataFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                 SBUnityFileSourceMasterLoaderLoadMasterDataRVA);
    SBUnityFileSourceMasterLoaderLoadMasterDataPrivateFn loadMasterDataPrivate =
        (SBUnityFileSourceMasterLoaderLoadMasterDataPrivateFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                        SBUnityFileSourceMasterLoaderLoadMasterDataPrivateRVA);
    SBUnityMasterDataProtectorGenerateKeyFn generateProtectionKey =
        (SBUnityMasterDataProtectorGenerateKeyFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                           SBUnityMasterDataProtectorGenerateKeyRVA);
    SBUnityMasterDataProtectorDecryptFn decryptMasterData =
        (SBUnityMasterDataProtectorDecryptFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                       SBUnityMasterDataProtectorDecryptRVA);
    SBUnityFileReadAllBytesFn readAllBytes =
        (SBUnityFileReadAllBytesFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                             SBUnityFileReadAllBytesRVA);
    SBUnityFileReadAllTextFn readAllText =
        (SBUnityFileReadAllTextFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                            SBUnityFileReadAllTextRVA);
    SBUnityDirectoryGetFilesFn directoryGetFiles =
        (SBUnityDirectoryGetFilesFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                              SBUnityDirectoryGetFilesRVA);
    SBUnityDirectoryInfoCtorFn directoryInfoCtor =
        (SBUnityDirectoryInfoCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                              SBUnityDirectoryInfoCtorRVA);
    SBUnityFileSystemInfoGetFullNameFn fileSystemInfoGetFullName =
        (SBUnityFileSystemInfoGetFullNameFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                      SBUnityFileSystemInfoGetFullNameRVA);
    SBUnityTsvDocumentCtorFn tsvDocumentCtor =
        (SBUnityTsvDocumentCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                            SBUnityTsvDocumentCtorRVA);
    SBUnityTsvKeyValueDocumentCtorFn tsvKeyValueDocumentCtor =
        (SBUnityTsvKeyValueDocumentCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                    SBUnityTsvKeyValueDocumentCtorRVA);
    SBUnityTsvDocumentGetCountFn tsvDocumentGetCount =
        (SBUnityTsvDocumentGetCountFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                SBUnityTsvDocumentGetCountRVA);
    SBUnityTsvDocumentToStringFn tsvDocumentToString =
        (SBUnityTsvDocumentToStringFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                SBUnityTsvDocumentToStringRVA);
    SBUnityLoadMasterFileFn loadMasterFile =
        (SBUnityLoadMasterFileFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                           SBUnityFileSourceMasterLoaderLoadMasterFileRVA);
    SBUnityObjectCtorFn masterDataEventsCtor =
        (SBUnityObjectCtorFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityMasterDataEventsCtorRVA);
    SBUnityObjectCtorFn tsvErrorCollectorCtor =
        (SBUnityObjectCtorFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnityTsvErrorCollectorCtorRVA);
    SBUnityInstanceGetBoolFn tsvErrorCollectorGetHasError =
        (SBUnityInstanceGetBoolFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                            SBUnityTsvErrorCollectorGetHasErrorRVA);
    SBUnityInstanceToStringFn tsvErrorCollectorToString =
        (SBUnityInstanceToStringFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                             SBUnityTsvErrorCollectorToStringRVA);
    SBUnityInstanceToStringFn exceptionToString =
        (SBUnityInstanceToStringFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                             SBUnitySystemExceptionToStringRVA);
    SBUnityStageBattleReservationDetailGetBoolFn getIsAlwaysVictory =
        (SBUnityStageBattleReservationDetailGetBoolFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                SBUnityStageBattleReservationDetailGetIsAlwaysVictoryRVA);
    SBUnityStageBattleReservationDetailGetObjectFn getStartSituation =
        (SBUnityStageBattleReservationDetailGetObjectFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                  SBUnityStageBattleReservationDetailGetBattleStartSituationRVA);
    SBUnityStageBattleReservationDetailGetObjectFn getSpecialFinishCondition =
        (SBUnityStageBattleReservationDetailGetObjectFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                  SBUnityStageBattleReservationDetailGetBattleSpecialFinishConditionRVA);
    SBUnityStageBattleReservationDetailGetObjectFn getBackgroundMaster =
        (SBUnityStageBattleReservationDetailGetObjectFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                  SBUnityStageBattleReservationDetailGetBackgroundMasterRVA);
    SBUnityStageBattleReservationDetailGetObjectFn getFieldMaster =
        (SBUnityStageBattleReservationDetailGetObjectFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                  SBUnityStageBattleReservationDetailGetFieldMasterRVA);
    SBUnityOperationListMoveSelectorCtorFn selectorCtor =
        (SBUnityOperationListMoveSelectorCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                          SBUnityOperationListMoveSelectorCtorRVA);
    SBUnityOperationListRandomFuncCtorFn selectorRandomFuncCtor =
        (SBUnityOperationListRandomFuncCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                         SBUnityOperationListRandomFuncCtorRVA);
    SBUnityEnvironmentGetTickCountFn environmentGetTickCount =
        (SBUnityEnvironmentGetTickCountFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                     SBUnityEnvironmentGetTickCountRVA);
    SBUnitySystemRandomCtorFn systemRandomCtor =
        (SBUnitySystemRandomCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                             SBUnitySystemRandomCtorRVA);
    SBUnityFuncIntIntIntCtorFn funcIntIntIntCtor =
        (SBUnityFuncIntIntIntCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                              SBUnityFuncIntIntIntCtorRVA);
    SBUnityFuncDoubleCtorFn funcDoubleCtor =
        (SBUnityFuncDoubleCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                           SBUnityFuncDoubleCtorRVA);
    SBUnitySoccerBattleCtorFn battleCtor =
        (SBUnitySoccerBattleCtorFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnitySoccerBattleCtorRVA);
    SBUnitySoccerBattleGetResultFn getResult =
        (SBUnitySoccerBattleGetResultFn)SBUnityBridgeFunctionAtRVA(unityBase, SBUnitySoccerBattleGetResultRVA);
    SBUnitySoccerBattleCreateReplayFn createReplay =
        (SBUnitySoccerBattleCreateReplayFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                      SBUnitySoccerBattleCreateReplayRVA);
    SBUnitySoccerBattleCreateForReplayFn createForReplay =
        (SBUnitySoccerBattleCreateForReplayFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                         SBUnitySoccerBattleCreateForReplayRVA);
    SBUnitySoccerBattleReplayToJsonFn replayToJson =
        (SBUnitySoccerBattleReplayToJsonFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                      SBUnitySoccerBattleReplayToJsonRVA);
    SBUnitySoccerBattleReplayFromJsonFn replayFromJson =
        (SBUnitySoccerBattleReplayFromJsonFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                        SBUnitySoccerBattleReplayFromJsonRVA);
    SBUnitySoccerBattleRunCoroutineFn runCoroutine =
        (SBUnitySoccerBattleRunCoroutineFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                     SBUnitySoccerBattleRunCoroutineRVA);
    SBUnityObjectCtorFn mainStoryStageContextCtor =
        (SBUnityObjectCtorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                       SBUnityMainStoryStageContextCtorRVA);
    SBUnityMainStoryCreateFinishReqFn mainStoryCreateFinishReq =
        (SBUnityMainStoryCreateFinishReqFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                     SBUnityMainStoryCreateFinishReqRVA);
    SBUnityRunCoroutineGetAsyncEnumeratorFn runCoroutineGetAsyncEnumerator =
        (SBUnityRunCoroutineGetAsyncEnumeratorFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                            SBUnitySoccerBattleRunCoroutineGetAsyncEnumeratorRVA);
    SBUnityRunCoroutineMoveNextAsyncFn runCoroutineMoveNextAsync =
        (SBUnityRunCoroutineMoveNextAsyncFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                       SBUnitySoccerBattleRunCoroutineMoveNextAsyncRVA);
    SBUnityRunCoroutineGetCurrentFn runCoroutineGetCurrent =
        (SBUnityRunCoroutineGetCurrentFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                    SBUnitySoccerBattleRunCoroutineGetCurrentRVA);
    SBUnityRunCoroutineValueTaskSourceGetResultFn runCoroutineValueTaskGetResult =
        (SBUnityRunCoroutineValueTaskSourceGetResultFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                  SBUnitySoccerBattleRunCoroutineValueTaskGetResultRVA);
    SBUnityRunCoroutineValueTaskSourceGetStatusFn runCoroutineValueTaskGetStatus =
        (SBUnityRunCoroutineValueTaskSourceGetStatusFn)SBUnityBridgeFunctionAtRVA(unityBase,
                                                                                  SBUnitySoccerBattleRunCoroutineValueTaskGetStatusRVA);

    result.stringAllocAddress = (uintptr_t)allocString;
    result.fromJsonAddress = (uintptr_t)fromJson;
    result.metadataInitAddress = (uintptr_t)metadataInit;
    result.objectNewAddress = (uintptr_t)objectNew;
    result.getIsAlwaysVictoryAddress = (uintptr_t)getIsAlwaysVictory;
    result.getStartSituationAddress = (uintptr_t)getStartSituation;
    result.getSpecialFinishConditionAddress = (uintptr_t)getSpecialFinishCondition;
    result.getBackgroundMasterAddress = (uintptr_t)getBackgroundMaster;
    result.getFieldMasterAddress = (uintptr_t)getFieldMaster;
    result.stageMasterGetByBattleTypeAddress = (uintptr_t)getStageMasterByBattleType;
    result.stageMasterGetByBattleTypeMethodInfo = getStageMasterByBattleTypeMethodInfo;
    result.masterDataLoadAllAddress = (uintptr_t)loadAllMasterDataWithoutTest;
    result.masterDataLoadMasterAddress = (uintptr_t)loadMasterData;
    result.masterDataLoadPrivateAddress = (uintptr_t)loadMasterDataPrivate;
    result.masterDataProtectionGenerateKeyAddress = (uintptr_t)generateProtectionKey;
    result.masterDataProtectionDecryptAddress = (uintptr_t)decryptMasterData;
    result.fileReadAllBytesAddress = (uintptr_t)readAllBytes;
    result.fileReadAllTextAddress = (uintptr_t)readAllText;
    result.tsvDocumentCtorAddress = (uintptr_t)tsvDocumentCtor;
    result.tsvKeyValueDocumentCtorAddress = (uintptr_t)tsvKeyValueDocumentCtor;
    result.tsvDocumentGetCountAddress = (uintptr_t)tsvDocumentGetCount;
    result.tsvDocumentToStringAddress = (uintptr_t)tsvDocumentToString;
    result.directoryGetFilesAddress = (uintptr_t)directoryGetFiles;
    result.directoryInfoCtorAddress = (uintptr_t)directoryInfoCtor;
    result.fileSystemInfoGetFullNameAddress = (uintptr_t)fileSystemInfoGetFullName;
    result.loadMasterFileAddress = (uintptr_t)loadMasterFile;
    result.tsvErrorCollectorGetHasErrorAddress = (uintptr_t)tsvErrorCollectorGetHasError;
    result.tsvErrorCollectorToStringAddress = (uintptr_t)tsvErrorCollectorToString;
    result.masterDataLoadExceptionToStringAddress = (uintptr_t)exceptionToString;
    result.selectorCtorAddress = (uintptr_t)selectorCtor;
    result.battleCtorAddress = (uintptr_t)battleCtor;
    result.getResultAddress = (uintptr_t)getResult;
    result.battleCreateReplayAddress = (uintptr_t)createReplay;
    result.battleCreateForReplayAddress = (uintptr_t)createForReplay;
    result.battleReplayToJsonAddress = (uintptr_t)replayToJson;
    result.battleReplayFromJsonAddress = (uintptr_t)replayFromJson;
    result.battleRunCoroutineAddress = (uintptr_t)runCoroutine;
    result.mainStoryStageContextCtorAddress = (uintptr_t)mainStoryStageContextCtor;
    result.mainStoryCreateFinishReqAddress = (uintptr_t)mainStoryCreateFinishReq;
    result.battleRunCoroutineGetAsyncEnumeratorAddress = (uintptr_t)runCoroutineGetAsyncEnumerator;
    result.battleRunCoroutineMoveNextAsyncAddress = (uintptr_t)runCoroutineMoveNextAsync;
    result.battleRunCoroutineGetCurrentAddress = (uintptr_t)runCoroutineGetCurrent;
    result.battleRunCoroutineValueTaskGetResultAddress = (uintptr_t)runCoroutineValueTaskGetResult;
    result.battleRunCoroutineValueTaskGetStatusAddress = (uintptr_t)runCoroutineValueTaskGetStatus;

    if (!allocString || !fromJson) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework battle parse function missing");
        return result;
    }

    void *managedJson = SBUnityBridgeCreateManagedString(allocString, detailJson);
    result.managedJsonString = (uintptr_t)managedJson;
    result.stringAllocated = managedJson != NULL;
    result.jsonLength = (int32_t)MIN(detailJson.length, (NSUInteger)INT32_MAX);
    if (!managedJson) {
        SBUnityBridgeSetBattleConstructError(&result, "DetailJson System.String allocation failed");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "before BattleReservationDetail.FromJson");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d before=BattleReservationDetail.FromJson jsonLen=%d",
                              maxStage,
                              result.jsonLength);
    void *detail = NULL;
    try {
        detail = fromJson(managedJson, NULL);
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "BattleReservationDetail.FromJson raised a managed exception");
        return result;
    } catch (...) {
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "BattleReservationDetail.FromJson raised a C++/managed exception");
        return result;
    }
    SBUnityBridgeSetBattleConstructStep(&result, "after BattleReservationDetail.FromJson");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d after=BattleReservationDetail.FromJson detail=0x%llx",
                              maxStage,
                              (unsigned long long)(uintptr_t)detail);
    result.reservationDetail = (uintptr_t)detail;
    result.detailParsed = detail != NULL;
    if (!detail) {
        SBUnityBridgeSetBattleConstructError(&result, "BattleReservationDetail.FromJson returned null");
        return result;
    }

    uint8_t *detailBytes = (uint8_t *)detail;
    result.battleType = *(int32_t *)(detailBytes + 0x10);
    result.seed = *(int32_t *)(detailBytes + 0x14);
    result.aTeam = (uintptr_t)*(void **)(detailBytes + 0x18);
    result.bTeam = (uintptr_t)*(void **)(detailBytes + 0x20);
    result.fieldTerrain = (uintptr_t)*(void **)(detailBytes + 0x28);
    result.stageCode = *(int32_t *)(detailBytes + 0x30);
    result.completedStage = 1;
    if (maxStage <= 1) {
        result.ok = result.stageCode != 0 && result.seed != 0;
        if (!result.ok) {
            SBUnityBridgeSetBattleConstructError(&result, "BattleReservationDetail parsed but fields look invalid");
        }
        return result;
    }

    if (masterLoadStage || battleRunCoroutineStage) {
        if (!metadataInit || !loadMasterData) {
            SBUnityBridgeSetBattleConstructError(&result, "UnityFramework public master loader dependencies missing");
            return result;
        }

        SBUnityBridgeSetBattleConstructStep(&result, "before MasterModel static fields");
        uintptr_t fileSourceMasterLoaderTypeInfoGlobal = unityBase + SBUnityFileSourceMasterLoaderTypeInfoGlobalRVA;
        metadataInit((void *)fileSourceMasterLoaderTypeInfoGlobal);
        SBUnityBridgeReadMasterModelStatics(&result, metadataInit, unityBase, result.battleType);
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=LoadMasterDataPrivate loaded=%d collection=0x%llx",
                                  maxStage,
                                  result.masterModelLoaded,
                                  (unsigned long long)result.stageMasterCollection);

        if (!result.stageMasterCollectionReady) {
            NSString *trimmedMasterDataPath =
                [masterDataPathOverride ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSString *inputMasterDataPath = trimmedMasterDataPath.length > 0
                ? trimmedMasterDataPath
                : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/MasterData"];
            NSString *masterDataPath = inputMasterDataPath;
            NSString *masterDataAllPath = [inputMasterDataPath stringByAppendingPathComponent:@"Runtime/All"];
            BOOL isRuntimeAllPath = [inputMasterDataPath.lastPathComponent isEqualToString:@"All"] &&
                                    [inputMasterDataPath.stringByDeletingLastPathComponent.lastPathComponent isEqualToString:@"Runtime"];
            BOOL allPathIsDirectory = NO;
            BOOL allPathExists = [[NSFileManager defaultManager] fileExistsAtPath:masterDataAllPath
                                                                      isDirectory:&allPathIsDirectory];
            if (isRuntimeAllPath) {
                masterDataAllPath = inputMasterDataPath;
                masterDataPath = inputMasterDataPath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
            } else if (!allPathExists || !allPathIsDirectory) {
                masterDataAllPath = inputMasterDataPath;
            }
            snprintf(result.masterDataPath,
                     sizeof(result.masterDataPath),
                     "%s",
                     masterDataPath.UTF8String ?: "");

            BOOL isDirectory = NO;
            result.masterDataPathExists = [[NSFileManager defaultManager] fileExistsAtPath:masterDataPath
                                                                               isDirectory:&isDirectory];
            result.masterDataPathIsDirectory = isDirectory;
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d path=MasterData exists=%d dir=%d path=%@",
                                      maxStage,
                                      result.masterDataPathExists,
                                      result.masterDataPathIsDirectory,
                                      masterDataPath);

            if (!result.masterDataPathExists || !result.masterDataPathIsDirectory) {
                SBUnityBridgeSetBattleConstructError(&result, "MasterData Runtime/All directory is missing");
                return result;
            }

            void *managedMasterDataPath = SBUnityBridgeCreateManagedString(allocString, masterDataPath);
            result.masterDataPathString = (uintptr_t)managedMasterDataPath;
            result.masterDataPathStringAllocated = managedMasterDataPath != NULL;
            if (!managedMasterDataPath) {
                SBUnityBridgeSetBattleConstructError(&result, "MasterData path System.String allocation failed");
                return result;
            }

            NSString *trimmedServerVersionHash =
                [serverVersionHash ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            snprintf(result.serverVersionHash,
                     sizeof(result.serverVersionHash),
                     "%s",
                     trimmedServerVersionHash.UTF8String ?: "");
            void *protectionKey = NULL;
            if (trimmedServerVersionHash.length > 0) {
                if (!generateProtectionKey) {
                    SBUnityBridgeSetBattleConstructError(&result, "MasterDataProtector.GenerateKey function missing");
                    return result;
                }

                void *managedServerVersionHash = SBUnityBridgeCreateManagedString(allocString, trimmedServerVersionHash);
                result.serverVersionHashString = (uintptr_t)managedServerVersionHash;
                result.serverVersionHashStringAllocated = managedServerVersionHash != NULL;
                if (!managedServerVersionHash) {
                    SBUnityBridgeSetBattleConstructError(&result, "serverVersionHash System.String allocation failed");
                    return result;
                }

                SBUnityBridgeSetBattleConstructStep(&result, "before MasterDataProtector.GenerateKey");
                SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                          @"stage=%d before=GenerateKey serverVersionHash=%@",
                                          maxStage,
                                          trimmedServerVersionHash);
                try {
                    protectionKey = generateProtectionKey(managedServerVersionHash, NULL);
                } catch (Il2CppExceptionWrapper &wrappedException) {
                    result.masterDataLoadCaughtException = YES;
                    SBUnityBridgeCaptureCurrentExceptionType(&result);
                    result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
                    SBUnityBridgeReadManagedException(&result, wrappedException.exception);
                    SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                    SBUnityBridgeSetBattleConstructError(&result, "MasterDataProtector.GenerateKey raised a managed exception");
                    return result;
                } catch (...) {
                    result.masterDataLoadCaughtException = YES;
                    SBUnityBridgeCaptureCurrentExceptionType(&result);
                    SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
                    SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                    SBUnityBridgeSetBattleConstructError(&result, "MasterDataProtector.GenerateKey raised a C++/managed exception");
                    return result;
                }
                result.masterDataProtectionKey = (uintptr_t)protectionKey;
                result.masterDataProtectionKeyGenerated = protectionKey != NULL;
                if (protectionKey) {
                    uintptr_t keyLength = *(uintptr_t *)((uint8_t *)protectionKey + 0x18);
                    result.masterDataProtectionKeyLength = keyLength <= INT32_MAX ? (int32_t)keyLength : -1;
                }
                SBUnityBridgeSetBattleConstructStep(&result, "after MasterDataProtector.GenerateKey");
                SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                          @"stage=%d after=GenerateKey key=0x%llx keyLen=%d",
                                          maxStage,
                                          (unsigned long long)(uintptr_t)protectionKey,
                                          result.masterDataProtectionKeyLength);
                if (!protectionKey || result.masterDataProtectionKeyLength <= 0) {
                    SBUnityBridgeSetBattleConstructError(&result, "MasterDataProtector.GenerateKey returned invalid key");
                    return result;
                }
            } else {
                SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                          @"stage=%d use=plaintext-master-data path=%@",
                                          maxStage,
                                          masterDataPath);
            }

            NSString *parameterMasterFileName = @"LGAマスター - パラメータ.tsv";
            NSString *parameterMasterPath = [masterDataAllPath stringByAppendingPathComponent:parameterMasterFileName];
            snprintf(result.parameterMasterPath,
                     sizeof(result.parameterMasterPath),
                     "%s",
                     parameterMasterPath.UTF8String ?: "");
            void *managedParameterMasterPath = SBUnityBridgeCreateManagedString(allocString, parameterMasterPath);
            result.parameterMasterPathString = (uintptr_t)managedParameterMasterPath;
            result.parameterMasterPathStringAllocated = managedParameterMasterPath != NULL;
            if (!managedParameterMasterPath) {
                SBUnityBridgeSetBattleConstructError(&result, "Parameter master path System.String allocation failed");
                return result;
            }

            void *parameterMasterText = NULL;
            SBUnityBridgeSetBattleConstructStep(&result, "before ParameterMaster text probe");
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d before=ParameterText path=%@ key=0x%llx",
                                      maxStage,
                                      parameterMasterPath,
                                      (unsigned long long)(uintptr_t)protectionKey);
            try {
                if (protectionKey) {
                    if (!readAllBytes || !decryptMasterData) {
                        SBUnityBridgeSetBattleConstructError(&result, "Parameter encrypted text probe dependencies missing");
                        return result;
                    }
                    void *encryptedBytes = readAllBytes(managedParameterMasterPath, NULL);
                    result.parameterMasterEncryptedBytes = (uintptr_t)encryptedBytes;
                    result.parameterMasterEncryptedBytesRead = encryptedBytes != NULL;
                    if (encryptedBytes) {
                        uintptr_t encryptedLength = *(uintptr_t *)((uint8_t *)encryptedBytes + 0x18);
                        result.parameterMasterEncryptedLength =
                            encryptedLength <= INT32_MAX ? (int32_t)encryptedLength : -1;
                    }
                    parameterMasterText = encryptedBytes ? decryptMasterData(protectionKey, encryptedBytes, NULL) : NULL;
                    result.parameterMasterDecryptedString = (uintptr_t)parameterMasterText;
                    result.parameterMasterDecrypted = parameterMasterText != NULL;
                } else {
                    if (!readAllText) {
                        SBUnityBridgeSetBattleConstructError(&result, "Parameter plaintext text probe dependencies missing");
                        return result;
                    }
                    parameterMasterText = readAllText(managedParameterMasterPath, NULL);
                    result.parameterMasterTextString = (uintptr_t)parameterMasterText;
                    result.parameterMasterTextRead = parameterMasterText != NULL;
                }
                if (parameterMasterText) {
                    SBUnityBridgeReadStringPreview(parameterMasterText,
                                                   result.parameterMasterPreview,
                                                   sizeof(result.parameterMasterPreview),
                                                   &result.parameterMasterDecryptedLength,
                                                   512);
                }
            } catch (Il2CppExceptionWrapper &wrappedException) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
                SBUnityBridgeReadManagedException(&result, wrappedException.exception);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeSetBattleConstructError(&result, "Parameter master text probe raised a managed exception");
                return result;
            } catch (...) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeSetBattleConstructError(&result, "Parameter master text probe raised a C++/managed exception");
                return result;
            }
            SBUnityBridgeSetBattleConstructStep(&result, "after ParameterMaster text probe");
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d after=ParameterText encryptedLen=%d textLen=%d preview=%s",
                                      maxStage,
                                      result.parameterMasterEncryptedLength,
                                      result.parameterMasterDecryptedLength,
                                      result.parameterMasterPreview);

            if (!parameterMasterText) {
                SBUnityBridgeSetBattleConstructError(&result, "Parameter master text probe returned null");
                return result;
            }

            if (!objectNew || !tsvDocumentCtor || !tsvKeyValueDocumentCtor || !tsvErrorCollectorCtor) {
                SBUnityBridgeSetBattleConstructError(&result, "Parameter manual TSV parse dependencies missing");
                return result;
            }

            void *tsvDocumentTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                     unityBase,
                                                                     SBUnityTsvDocumentTypeInfoGlobalRVA,
                                                                     &result.tsvDocumentTypeInfoGlobal);
            result.tsvDocumentTypeInfo = (uintptr_t)tsvDocumentTypeInfo;
            result.tsvDocumentTypeReady = tsvDocumentTypeInfo != NULL;
            void *tsvKeyValueDocumentTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                             unityBase,
                                                                             SBUnityTsvKeyValueDocumentTypeInfoGlobalRVA,
                                                                             &result.tsvKeyValueDocumentTypeInfoGlobal);
            result.tsvKeyValueDocumentTypeInfo = (uintptr_t)tsvKeyValueDocumentTypeInfo;
            result.tsvKeyValueDocumentTypeReady = tsvKeyValueDocumentTypeInfo != NULL;
            void *manualTsvErrorCollectorTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                                 unityBase,
                                                                                 SBUnityTsvErrorCollectorTypeInfoGlobalRVA,
                                                                                 &result.tsvErrorCollectorTypeInfoGlobal);
            result.tsvErrorCollectorTypeInfo = (uintptr_t)manualTsvErrorCollectorTypeInfo;
            result.tsvErrorCollectorTypeReady = manualTsvErrorCollectorTypeInfo != NULL;
            if (!tsvDocumentTypeInfo || !tsvKeyValueDocumentTypeInfo || !manualTsvErrorCollectorTypeInfo) {
                SBUnityBridgeSetBattleConstructError(&result, "Parameter manual TSV parse TypeInfo unavailable");
                return result;
            }

            void *manualTsvErrorCollector = objectNew(manualTsvErrorCollectorTypeInfo);
            result.tsvErrorCollector = (uintptr_t)manualTsvErrorCollector;
            result.tsvErrorCollectorAllocated = manualTsvErrorCollector != NULL;
            if (!manualTsvErrorCollector) {
                SBUnityBridgeSetBattleConstructError(&result, "Parameter manual TSV parse TsvErrorCollector allocation failed");
                return result;
            }
            tsvErrorCollectorCtor(manualTsvErrorCollector, NULL);
            result.tsvErrorCollectorConstructed = YES;

            void *managedParameterMasterFileName = SBUnityBridgeCreateManagedString(allocString, parameterMasterFileName);
            void *managedKeyColumnName = SBUnityBridgeCreateManagedString(allocString, @"パラメータ名");
            void *managedValueColumnName = SBUnityBridgeCreateManagedString(allocString, @"値");
            if (!managedParameterMasterFileName ||
                !managedKeyColumnName ||
                !managedValueColumnName) {
                SBUnityBridgeSetBattleConstructError(&result, "Parameter manual TSV parse string allocation failed");
                return result;
            }

            SBUnityBridgeSetBattleConstructStep(&result, "before ParameterMaster manual TSV parse");
            try {
                void *tsvDocument = objectNew(tsvDocumentTypeInfo);
                result.tsvDocument = (uintptr_t)tsvDocument;
                result.tsvDocumentAllocated = tsvDocument != NULL;
                if (!tsvDocument) {
                    SBUnityBridgeSetBattleConstructError(&result, "TsvDocument allocation failed");
                    return result;
                }
                tsvDocumentCtor(tsvDocument,
                                parameterMasterText,
                                managedParameterMasterFileName,
                                manualTsvErrorCollector,
                                NULL);
                result.tsvDocumentConstructed = YES;

                void *tsvKeyValueDocument = objectNew(tsvKeyValueDocumentTypeInfo);
                result.tsvKeyValueDocument = (uintptr_t)tsvKeyValueDocument;
                result.tsvKeyValueDocumentAllocated = tsvKeyValueDocument != NULL;
                if (!tsvKeyValueDocument) {
                    SBUnityBridgeSetBattleConstructError(&result, "TsvKeyValueDocument allocation failed");
                    return result;
                }
                tsvKeyValueDocumentCtor(tsvKeyValueDocument,
                                        tsvDocument,
                                        managedKeyColumnName,
                                        managedValueColumnName,
                                        NULL);
                result.tsvKeyValueDocumentConstructed = YES;
                result.parameterMasterManualParsed = YES;
            } catch (Il2CppExceptionWrapper &wrappedException) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
                SBUnityBridgeReadManagedException(&result, wrappedException.exception);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeReadTsvErrorCollector(&result,
                                                   manualTsvErrorCollector,
                                                   tsvErrorCollectorGetHasError,
                                                   tsvErrorCollectorToString);
                SBUnityBridgeSetBattleConstructError(&result, "Parameter manual TSV parse raised a managed exception");
                return result;
            } catch (...) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeReadTsvErrorCollector(&result,
                                                   manualTsvErrorCollector,
                                                   tsvErrorCollectorGetHasError,
                                                   tsvErrorCollectorToString);
                SBUnityBridgeSetBattleConstructError(&result, "Parameter manual TSV parse raised a C++/managed exception");
                return result;
            }
            SBUnityBridgeReadTsvErrorCollector(&result,
                                               manualTsvErrorCollector,
                                               tsvErrorCollectorGetHasError,
                                               tsvErrorCollectorToString);
            SBUnityBridgeSetBattleConstructStep(&result, "after ParameterMaster manual TSV parse");
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d after=ParameterManualParse doc=0x%llx kv=0x%llx collectorHasError=%d",
                                      maxStage,
                                      (unsigned long long)result.tsvDocument,
                                      (unsigned long long)result.tsvKeyValueDocument,
                                      result.tsvErrorCollectorHasError);

            uintptr_t loadMasterFilePathConstantAGlobal =
                unityBase + SBUnityLoadMasterFilePathConstantAGlobalRVA;
            uintptr_t loadMasterFilePathConstantBGlobal =
                unityBase + SBUnityLoadMasterFilePathConstantBGlobalRVA;
            metadataInit((void *)loadMasterFilePathConstantAGlobal);
            metadataInit((void *)loadMasterFilePathConstantBGlobal);
            void *loadMasterFilePathConstantA = *(void **)loadMasterFilePathConstantAGlobal;
            void *loadMasterFilePathConstantB = *(void **)loadMasterFilePathConstantBGlobal;
            result.loadMasterFilePathConstantAString = (uintptr_t)loadMasterFilePathConstantA;
            result.loadMasterFilePathConstantBString = (uintptr_t)loadMasterFilePathConstantB;
            SBUnityBridgeReadString(loadMasterFilePathConstantA,
                                    result.loadMasterFilePathConstantA,
                                    sizeof(result.loadMasterFilePathConstantA),
                                    NULL);
            SBUnityBridgeReadString(loadMasterFilePathConstantB,
                                    result.loadMasterFilePathConstantB,
                                    sizeof(result.loadMasterFilePathConstantB),
                                    NULL);

            if (!directoryInfoCtor || !loadMasterFile) {
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterFile probe dependencies missing");
                return result;
            }

            void *directoryInfoTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                       unityBase,
                                                                       SBUnityDirectoryInfoTypeInfoGlobalRVA,
                                                                       &result.directoryInfoTypeInfoGlobal);
            result.directoryInfoTypeInfo = (uintptr_t)directoryInfoTypeInfo;
            result.directoryInfoTypeReady = directoryInfoTypeInfo != NULL;
            if (!directoryInfoTypeInfo) {
                SBUnityBridgeSetBattleConstructError(&result, "DirectoryInfo TypeInfo unavailable");
                return result;
            }

            void *directoryInfo = objectNew(directoryInfoTypeInfo);
            result.directoryInfo = (uintptr_t)directoryInfo;
            result.directoryInfoAllocated = directoryInfo != NULL;
            if (!directoryInfo) {
                SBUnityBridgeSetBattleConstructError(&result, "DirectoryInfo allocation failed");
                return result;
            }

            SBUnityBridgeSetBattleConstructStep(&result, "before LoadMasterFile probe");
            try {
                directoryInfoCtor(directoryInfo, managedMasterDataPath, NULL);
                result.directoryInfoConstructed = YES;
                if (fileSystemInfoGetFullName) {
                    void *directoryInfoFullName = fileSystemInfoGetFullName(directoryInfo, NULL);
                    result.directoryInfoFullNameString = (uintptr_t)directoryInfoFullName;
                    SBUnityBridgeReadString(directoryInfoFullName,
                                            result.directoryInfoFullName,
                                            sizeof(result.directoryInfoFullName),
                                            NULL);
                }

                if (directoryGetFiles) {
                    void *matchedFiles = directoryGetFiles(managedMasterDataPath,
                                                          managedParameterMasterFileName,
                                                          NULL);
                    result.directoryGetFilesCalled = YES;
                    result.directoryGetFilesArray = (uintptr_t)matchedFiles;
                    if (matchedFiles) {
                        uintptr_t matchedCount = *(uintptr_t *)((uint8_t *)matchedFiles + 0x18);
                        result.directoryGetFilesCount = matchedCount <= INT32_MAX ? (int32_t)matchedCount : -1;
                        if (matchedCount > 0) {
                            void *firstPath = *(void **)((uint8_t *)matchedFiles + 0x20);
                            SBUnityBridgeReadString(firstPath,
                                                    result.directoryGetFilesFirst,
                                                    sizeof(result.directoryGetFilesFirst),
                                                    NULL);
                        }
                    } else {
                        result.directoryGetFilesCount = -1;
                    }
                }

                SBUnityFileSourceMasterLoaderDisplayClass4_0 display = {
                    directoryInfo,
                    manualTsvErrorCollector,
                    protectionKey
                };
                result.loadMasterFileCalled = YES;
                void *loadedParameterDocument = loadMasterFile(managedParameterMasterFileName,
                                                               &display,
                                                               NULL);
                result.loadMasterFileDocument = (uintptr_t)loadedParameterDocument;
                result.loadMasterFileReturned = loadedParameterDocument != NULL;
                if (!loadedParameterDocument) {
                    SBUnityBridgeSetBattleConstructError(&result, "LoadMasterFile probe returned null");
                    return result;
                }
                if (tsvDocumentGetCount) {
                    result.loadMasterFileDocumentCount = tsvDocumentGetCount(loadedParameterDocument, NULL);
                }
                if (tsvDocumentToString) {
                    void *loadMasterFileDocumentString = tsvDocumentToString(loadedParameterDocument, NULL);
                    result.loadMasterFileDocumentString = (uintptr_t)loadMasterFileDocumentString;
                    if (loadMasterFileDocumentString) {
                        SBUnityBridgeReadStringPreview(loadMasterFileDocumentString,
                                                       result.loadMasterFileDocumentPreview,
                                                       sizeof(result.loadMasterFileDocumentPreview),
                                                       &result.loadMasterFileDocumentStringLength,
                                                       512);
                    }
                }

                void *loadMasterFileKeyValueDocument = objectNew(tsvKeyValueDocumentTypeInfo);
                result.loadMasterFileKeyValueDocument = (uintptr_t)loadMasterFileKeyValueDocument;
                if (!loadMasterFileKeyValueDocument) {
                    SBUnityBridgeSetBattleConstructError(&result, "LoadMasterFile probe key-value allocation failed");
                    return result;
                }
                tsvKeyValueDocumentCtor(loadMasterFileKeyValueDocument,
                                        loadedParameterDocument,
                                        managedKeyColumnName,
                                        managedValueColumnName,
                                        NULL);
                result.loadMasterFileManualParsed = YES;
            } catch (Il2CppExceptionWrapper &wrappedException) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
                SBUnityBridgeReadManagedException(&result, wrappedException.exception);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeReadTsvErrorCollector(&result,
                                                   manualTsvErrorCollector,
                                                   tsvErrorCollectorGetHasError,
                                                   tsvErrorCollectorToString);
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterFile probe raised a managed exception");
                return result;
            } catch (...) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeReadTsvErrorCollector(&result,
                                                   manualTsvErrorCollector,
                                                   tsvErrorCollectorGetHasError,
                                                   tsvErrorCollectorToString);
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterFile probe raised a C++/managed exception");
                return result;
            }
            SBUnityBridgeReadTsvErrorCollector(&result,
                                               manualTsvErrorCollector,
                                               tsvErrorCollectorGetHasError,
                                               tsvErrorCollectorToString);
            SBUnityBridgeSetBattleConstructStep(&result, "after LoadMasterFile probe");
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d after=LoadMasterFile matches=%d first=%s document=0x%llx parsed=%d",
                                      maxStage,
                                      result.directoryGetFilesCount,
                                      result.directoryGetFilesFirst,
                                      (unsigned long long)result.loadMasterFileDocument,
                                      result.loadMasterFileManualParsed);

            SBUnityBridgeSetBattleConstructStep(&result, "before LoadMasterData public");
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d call=LoadMasterDataPublic pathString=0x%llx key=0x%llx",
                                      maxStage,
                                      (unsigned long long)(uintptr_t)managedMasterDataPath,
                                      (unsigned long long)(uintptr_t)protectionKey);
            result.masterDataLoadCalled = YES;
            try {
                loadMasterData(NULL, managedMasterDataPath, protectionKey, NULL);
            } catch (Il2CppExceptionWrapper &wrappedException) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
                SBUnityBridgeReadManagedException(&result, wrappedException.exception);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterData public raised a managed exception");
                return result;
            } catch (...) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterData public raised a C++/managed exception");
                return result;
            }
            result.masterDataLoadReturned = YES;
            SBUnityBridgeSetBattleConstructStep(&result, "after LoadMasterData public");
            SBUnityBridgeReadMasterModelStatics(&result, metadataInit, unityBase, result.battleType);
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d after=LoadMasterDataPublic loaded=%d typeInfo=0x%llx static=0x%llx offset=0x%x collection=0x%llx",
                                      maxStage,
                                      result.masterModelLoaded,
                                      (unsigned long long)result.masterModelTypeInfo,
                                      (unsigned long long)result.masterModelStaticFields,
                                      result.stageMasterCollectionOffset,
                                      (unsigned long long)result.stageMasterCollection);
            result.ok = result.masterModelTypeReady &&
                        result.masterModelStaticFieldsReady &&
                        result.masterModelLoaded &&
                        result.stageMasterCollectionReady;
            if (!result.ok) {
                SBUnityBridgeSetBattleConstructError(&result, "MasterModel stage collection is not loaded after LoadMasterData public");
                return result;
            }
            if (masterLoadStage) {
                return result;
            }
            goto SBUnityBridgeMasterDataReady;

            void *masterDataEventsTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                          unityBase,
                                                                          SBUnityMasterDataEventsTypeInfoGlobalRVA,
                                                                          &result.masterDataEventsTypeInfoGlobal);
            result.masterDataEventsTypeInfo = (uintptr_t)masterDataEventsTypeInfo;
            result.masterDataEventsTypeReady = masterDataEventsTypeInfo != NULL;
            if (!masterDataEventsTypeInfo) {
                SBUnityBridgeSetBattleConstructError(&result, "MasterDataEvents TypeInfo unavailable");
                return result;
            }

            void *tsvErrorCollectorTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                           unityBase,
                                                                           SBUnityTsvErrorCollectorTypeInfoGlobalRVA,
                                                                           &result.tsvErrorCollectorTypeInfoGlobal);
            result.tsvErrorCollectorTypeInfo = (uintptr_t)tsvErrorCollectorTypeInfo;
            result.tsvErrorCollectorTypeReady = tsvErrorCollectorTypeInfo != NULL;
            if (!tsvErrorCollectorTypeInfo) {
                SBUnityBridgeSetBattleConstructError(&result, "TsvErrorCollector TypeInfo unavailable");
                return result;
            }

            void *masterDataEvents = objectNew(masterDataEventsTypeInfo);
            result.masterDataEvents = (uintptr_t)masterDataEvents;
            result.masterDataEventsAllocated = masterDataEvents != NULL;
            if (!masterDataEvents) {
                SBUnityBridgeSetBattleConstructError(&result, "MasterDataEvents allocation failed");
                return result;
            }
            masterDataEventsCtor(masterDataEvents, NULL);
            result.masterDataEventsConstructed = YES;

            void *tsvErrorCollector = objectNew(tsvErrorCollectorTypeInfo);
            result.tsvErrorCollector = (uintptr_t)tsvErrorCollector;
            result.tsvErrorCollectorAllocated = tsvErrorCollector != NULL;
            if (!tsvErrorCollector) {
                SBUnityBridgeSetBattleConstructError(&result, "TsvErrorCollector allocation failed");
                return result;
            }
            tsvErrorCollectorCtor(tsvErrorCollector, NULL);
            result.tsvErrorCollectorConstructed = YES;

            SBUnityBridgeSetBattleConstructStep(&result, "before LoadMasterData private");
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d call=LoadMasterDataPrivate events=0x%llx collector=0x%llx pathString=0x%llx",
                                      maxStage,
                                      (unsigned long long)(uintptr_t)masterDataEvents,
                                      (unsigned long long)(uintptr_t)tsvErrorCollector,
                                      (unsigned long long)(uintptr_t)managedMasterDataPath);
            result.masterDataLoadCalled = YES;
            try {
                loadMasterDataPrivate(masterDataEvents, managedMasterDataPath, tsvErrorCollector, protectionKey, NULL);
            } catch (Il2CppExceptionWrapper &wrappedException) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
                SBUnityBridgeReadManagedException(&result, wrappedException.exception);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeReadTsvErrorCollector(&result,
                                                   tsvErrorCollector,
                                                   tsvErrorCollectorGetHasError,
                                                   tsvErrorCollectorToString);
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterData private raised a managed exception");
                return result;
            } catch (...) {
                result.masterDataLoadCaughtException = YES;
                SBUnityBridgeCaptureCurrentExceptionType(&result);
                SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
                SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
                SBUnityBridgeReadTsvErrorCollector(&result,
                                                   tsvErrorCollector,
                                                   tsvErrorCollectorGetHasError,
                                                   tsvErrorCollectorToString);
                SBUnityBridgeSetBattleConstructError(&result, "LoadMasterData private raised a C++/managed exception");
                return result;
            }
            result.masterDataLoadReturned = YES;
        }

        SBUnityBridgeSetBattleConstructStep(&result, "after LoadMasterData private");
        SBUnityBridgeReadMasterModelStatics(&result, metadataInit, unityBase, result.battleType);
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=LoadMasterDataPrivate loaded=%d typeInfo=0x%llx static=0x%llx offset=0x%x collection=0x%llx",
                                  maxStage,
                                  result.masterModelLoaded,
                                  (unsigned long long)result.masterModelTypeInfo,
                                  (unsigned long long)result.masterModelStaticFields,
                                  result.stageMasterCollectionOffset,
                                  (unsigned long long)result.stageMasterCollection);
        result.ok = result.masterModelTypeReady &&
                    result.masterModelStaticFieldsReady &&
                    result.masterModelLoaded &&
                    result.stageMasterCollectionReady;
        if (!result.ok) {
            SBUnityBridgeSetBattleConstructError(&result, "MasterModel stage collection is not loaded after LoadMasterData private");
            return result;
        }
        if (masterLoadStage) {
            return result;
        }
    }

SBUnityBridgeMasterDataReady:
    void *startSituation = NULL;
    void *specialFinishCondition = NULL;
    void *backgroundMaster = NULL;
    void *fieldMaster = NULL;
    bool isAlwaysVictory = false;

    if (rawStageMasterStaticsStage) {
        SBUnityBridgeSetBattleConstructStep(&result, "before MasterModel static fields");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=MasterModelStatics battleType=%d",
                                  maxStage,
                                  result.battleType);
        SBUnityBridgeReadMasterModelStatics(&result, metadataInit, unityBase, result.battleType);
        SBUnityBridgeSetBattleConstructStep(&result, "after MasterModel static fields");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=MasterModelStatics typeInfo=0x%llx static=0x%llx offset=0x%x collection=0x%llx",
                                  maxStage,
                                  (unsigned long long)result.masterModelTypeInfo,
                                  (unsigned long long)result.masterModelStaticFields,
                                  result.stageMasterCollectionOffset,
                                  (unsigned long long)result.stageMasterCollection);
        result.ok = result.masterModelTypeReady &&
                    result.masterModelStaticFieldsReady &&
                    result.stageMasterCollectionReady;
        if (!result.ok) {
            SBUnityBridgeSetBattleConstructError(&result, "MasterModel stage collection is not loaded");
        }
        return result;
    }

    BOOL useDirectStageMasterInputs = !singleGetterStage && !battleRunCoroutineStage;
    if (useDirectStageMasterInputs) {
        if (!getStageMasterByBattleType) {
            SBUnityBridgeSetBattleConstructError(&result, "UnityFramework StageMaster.GetByBattleType function missing");
            return result;
        }

        SBUnityBridgeReadMasterModelStatics(&result, metadataInit, unityBase, result.battleType);
        if (!result.stageMasterCollectionReady) {
            SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                      @"stage=%d skip=StageMaster.GetByBattleType typeInfo=0x%llx static=0x%llx offset=0x%x collection=0x%llx",
                                      maxStage,
                                      (unsigned long long)result.masterModelTypeInfo,
                                      (unsigned long long)result.masterModelStaticFields,
                                      result.stageMasterCollectionOffset,
                                      (unsigned long long)result.stageMasterCollection);
            SBUnityBridgeSetBattleConstructError(&result, "MasterModel stage collection is not loaded");
            return result;
        }

        SBUnityBridgeSetBattleConstructStep(&result, "before StageMaster.GetByBattleType");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=StageMaster.GetByBattleType battleType=%d stageCode=%d method=0x0 methodInfo=0x%llx",
                                  maxStage,
                                  result.battleType,
                                  result.stageCode,
                                  (unsigned long long)result.stageMasterGetByBattleTypeMethodInfo);
        void *stageMaster = getStageMasterByBattleType(result.battleType,
                                                       result.stageCode,
                                                       getStageMasterByBattleTypeMethod);
        result.stageMaster = (uintptr_t)stageMaster;
        result.stageMasterLoaded = stageMaster != NULL;
        SBUnityBridgeSetBattleConstructStep(&result, "after StageMaster.GetByBattleType");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=StageMaster.GetByBattleType stageMaster=0x%llx",
                                  maxStage,
                                  (unsigned long long)(uintptr_t)stageMaster);
        if (!stageMaster) {
            SBUnityBridgeSetBattleConstructError(&result, "StageMaster.GetByBattleType returned null");
            return result;
        }

        uint8_t *stageBytes = (uint8_t *)stageMaster;
        startSituation = *(void **)(stageBytes + 0x28);
        specialFinishCondition = *(void **)(stageBytes + 0x30);
        isAlwaysVictory = *(uint8_t *)(stageBytes + 0x3D) != 0;
        backgroundMaster = *(void **)(stageBytes + 0x58);
        fieldMaster = *(void **)(stageBytes + 0x60);

        result.startSituation = (uintptr_t)startSituation;
        result.specialFinishCondition = (uintptr_t)specialFinishCondition;
        result.backgroundMaster = (uintptr_t)backgroundMaster;
        result.fieldMaster = (uintptr_t)fieldMaster;
        result.isAlwaysVictory = isAlwaysVictory ? 1 : 0;
        result.backgroundCode = backgroundMaster ? *(int32_t *)((uint8_t *)backgroundMaster + 0x10) : 0;
        result.fieldCode = fieldMaster ? *(int32_t *)((uint8_t *)fieldMaster + 0x10) : 0;
        result.stageMasterFieldsReady = startSituation != NULL &&
                                        specialFinishCondition != NULL &&
                                        backgroundMaster != NULL &&
                                        fieldMaster != NULL &&
                                        result.backgroundCode != 0 &&
                                        result.fieldCode != 0;

        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d read=StageMasterFields start=0x%llx special=0x%llx bg=0x%llx bgCode=%d field=0x%llx fieldCode=%d always=%d",
                                  maxStage,
                                  (unsigned long long)(uintptr_t)startSituation,
                                  (unsigned long long)(uintptr_t)specialFinishCondition,
                                  (unsigned long long)(uintptr_t)backgroundMaster,
                                  result.backgroundCode,
                                  (unsigned long long)(uintptr_t)fieldMaster,
                                  result.fieldCode,
                                  result.isAlwaysVictory);

        result.stageInputsReady = detail &&
                                  result.aTeam != 0 &&
                                  result.bTeam != 0 &&
                                  result.fieldTerrain != 0 &&
                                  result.stageMasterFieldsReady;
        result.completedStage = 2;
        if (directStageMasterStage || maxStage <= 2) {
            result.ok = result.stageInputsReady;
            if (!result.ok) {
                SBUnityBridgeSetBattleConstructError(&result, "StageMaster direct inputs are incomplete");
            }
            return result;
        }

        if (!result.stageInputsReady) {
            SBUnityBridgeSetBattleConstructError(&result, "StageMaster direct inputs are incomplete");
            return result;
        }
        goto SBUnityBridgeStageInputsReady;
    }

    if (!getIsAlwaysVictory || !getStartSituation || !getSpecialFinishCondition ||
        !getBackgroundMaster || !getFieldMaster) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework stage getter function missing");
        return result;
    }

    if (!singleGetterStage || maxStage == SBUnityBridgeProbeStageGetStartSituation) {
        SBUnityBridgeSetBattleConstructStep(&result, "before GetBattleStartSituation");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=GetBattleStartSituation detail=0x%llx",
                                  maxStage,
                                  (unsigned long long)result.reservationDetail);
        startSituation = getStartSituation(detail, NULL);
        result.startSituation = (uintptr_t)startSituation;
        result.completedGetter = SBUnityBridgeProbeStageGetStartSituation;
        SBUnityBridgeSetBattleConstructStep(&result, "after GetBattleStartSituation");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=GetBattleStartSituation value=0x%llx",
                                  maxStage,
                                  (unsigned long long)(uintptr_t)startSituation);
        if (singleGetterStage) {
            result.completedStage = 2;
            result.stageInputsReady = startSituation != NULL;
            result.ok = result.stageInputsReady;
            if (!result.ok) {
                SBUnityBridgeSetBattleConstructError(&result, "GetBattleStartSituation returned null");
            }
            return result;
        }
    }

    if (!singleGetterStage || maxStage == SBUnityBridgeProbeStageGetSpecialFinishCondition) {
        SBUnityBridgeSetBattleConstructStep(&result, "before GetBattleSpecialFinishCondition");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=GetBattleSpecialFinishCondition detail=0x%llx",
                                  maxStage,
                                  (unsigned long long)result.reservationDetail);
        specialFinishCondition = getSpecialFinishCondition(detail, NULL);
        result.specialFinishCondition = (uintptr_t)specialFinishCondition;
        result.completedGetter = SBUnityBridgeProbeStageGetSpecialFinishCondition;
        SBUnityBridgeSetBattleConstructStep(&result, "after GetBattleSpecialFinishCondition");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=GetBattleSpecialFinishCondition value=0x%llx",
                                  maxStage,
                                  (unsigned long long)(uintptr_t)specialFinishCondition);
        if (singleGetterStage) {
            result.completedStage = 2;
            result.stageInputsReady = specialFinishCondition != NULL;
            result.ok = result.stageInputsReady;
            if (!result.ok) {
                SBUnityBridgeSetBattleConstructError(&result, "GetBattleSpecialFinishCondition returned null");
            }
            return result;
        }
    }

    if (!singleGetterStage || maxStage == SBUnityBridgeProbeStageGetBackgroundMaster) {
        SBUnityBridgeSetBattleConstructStep(&result, "before GetBackgroundMaster");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=GetBackgroundMaster detail=0x%llx",
                                  maxStage,
                                  (unsigned long long)result.reservationDetail);
        backgroundMaster = getBackgroundMaster(detail, NULL);
        result.backgroundMaster = (uintptr_t)backgroundMaster;
        result.backgroundCode = backgroundMaster ? *(int32_t *)((uint8_t *)backgroundMaster + 0x10) : 0;
        result.completedGetter = SBUnityBridgeProbeStageGetBackgroundMaster;
        SBUnityBridgeSetBattleConstructStep(&result, "after GetBackgroundMaster");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=GetBackgroundMaster value=0x%llx code=%d",
                                  maxStage,
                                  (unsigned long long)(uintptr_t)backgroundMaster,
                                  result.backgroundCode);
        if (singleGetterStage) {
            result.completedStage = 2;
            result.stageInputsReady = backgroundMaster != NULL && result.backgroundCode != 0;
            result.ok = result.stageInputsReady;
            if (!result.ok) {
                SBUnityBridgeSetBattleConstructError(&result, "GetBackgroundMaster returned invalid master");
            }
            return result;
        }
    }

    if (!singleGetterStage || maxStage == SBUnityBridgeProbeStageGetFieldMaster) {
        SBUnityBridgeSetBattleConstructStep(&result, "before GetFieldMaster");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=GetFieldMaster detail=0x%llx",
                                  maxStage,
                                  (unsigned long long)result.reservationDetail);
        fieldMaster = getFieldMaster(detail, NULL);
        result.fieldMaster = (uintptr_t)fieldMaster;
        result.fieldCode = fieldMaster ? *(int32_t *)((uint8_t *)fieldMaster + 0x10) : 0;
        result.completedGetter = SBUnityBridgeProbeStageGetFieldMaster;
        SBUnityBridgeSetBattleConstructStep(&result, "after GetFieldMaster");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=GetFieldMaster value=0x%llx code=%d",
                                  maxStage,
                                  (unsigned long long)(uintptr_t)fieldMaster,
                                  result.fieldCode);
        if (singleGetterStage) {
            result.completedStage = 2;
            result.stageInputsReady = fieldMaster != NULL && result.fieldCode != 0;
            result.ok = result.stageInputsReady;
            if (!result.ok) {
                SBUnityBridgeSetBattleConstructError(&result, "GetFieldMaster returned invalid master");
            }
            return result;
        }
    }

    if (!singleGetterStage || maxStage == SBUnityBridgeProbeStageGetIsAlwaysVictory) {
        SBUnityBridgeSetBattleConstructStep(&result, "before GetIsAlwaysVictory");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d before=GetIsAlwaysVictory detail=0x%llx",
                                  maxStage,
                                  (unsigned long long)result.reservationDetail);
        isAlwaysVictory = getIsAlwaysVictory(detail, NULL);
        result.isAlwaysVictory = isAlwaysVictory ? 1 : 0;
        result.completedGetter = SBUnityBridgeProbeStageGetIsAlwaysVictory;
        SBUnityBridgeSetBattleConstructStep(&result, "after GetIsAlwaysVictory");
        SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                                  @"stage=%d after=GetIsAlwaysVictory value=%d",
                                  maxStage,
                                  result.isAlwaysVictory);
        if (singleGetterStage) {
            result.completedStage = 2;
            result.stageInputsReady = YES;
            result.ok = YES;
            return result;
        }
    }

    result.startSituation = (uintptr_t)startSituation;
    result.specialFinishCondition = (uintptr_t)specialFinishCondition;
    result.backgroundMaster = (uintptr_t)backgroundMaster;
    result.fieldMaster = (uintptr_t)fieldMaster;
    result.isAlwaysVictory = isAlwaysVictory ? 1 : 0;
    result.backgroundCode = backgroundMaster ? *(int32_t *)((uint8_t *)backgroundMaster + 0x10) : 0;
    result.fieldCode = fieldMaster ? *(int32_t *)((uint8_t *)fieldMaster + 0x10) : 0;

    result.stageInputsReady = detail &&
                              result.aTeam != 0 &&
                              result.bTeam != 0 &&
                              result.fieldTerrain != 0 &&
                              startSituation != NULL &&
                              specialFinishCondition != NULL &&
                              backgroundMaster != NULL &&
                              fieldMaster != NULL &&
                              result.backgroundCode != 0 &&
                              result.fieldCode != 0;
    if (!result.stageInputsReady) {
        SBUnityBridgeSetBattleConstructError(&result, "Stage battle inputs are incomplete");
        return result;
    }
    result.completedStage = 2;
    if (maxStage <= 2) {
        result.ok = YES;
        return result;
    }

SBUnityBridgeStageInputsReady:
    if (!metadataInit) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework metadata init function missing");
        return result;
    }

    void *selectorTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                          unityBase,
                                                          SBUnityOperationListMoveSelectorTypeInfoGlobalRVA,
                                                          &result.selectorTypeInfoGlobal);
    result.selectorTypeInfo = (uintptr_t)selectorTypeInfo;
    result.selectorTypeReady = selectorTypeInfo != NULL;
    if (!selectorTypeInfo) {
        SBUnityBridgeSetBattleConstructError(&result, "OperationListMoveSelector TypeInfo unavailable");
        return result;
    }

    void *systemRandomTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                              unityBase,
                                                              SBUnitySystemRandomTypeInfoGlobalRVA,
                                                              &result.systemRandomTypeInfoGlobal);
    result.systemRandomTypeInfo = (uintptr_t)systemRandomTypeInfo;
    void *funcIntIntIntTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                               unityBase,
                                                               SBUnityFuncIntIntIntTypeInfoGlobalRVA,
                                                               &result.funcIntIntIntTypeInfoGlobal);
    result.funcIntIntIntTypeInfo = (uintptr_t)funcIntIntIntTypeInfo;
    void *funcDoubleTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                            unityBase,
                                                            SBUnityFuncDoubleTypeInfoGlobalRVA,
                                                            &result.funcDoubleTypeInfoGlobal);
    result.funcDoubleTypeInfo = (uintptr_t)funcDoubleTypeInfo;
    void *operationListRandomFuncTypeInfo =
        SBUnityBridgeResolveTypeInfo(metadataInit,
                                     unityBase,
                                     SBUnityOperationListRandomFuncTypeInfoGlobalRVA,
                                     &result.operationListRandomFuncTypeInfoGlobal);
    result.operationListRandomFuncTypeInfo = (uintptr_t)operationListRandomFuncTypeInfo;
    if (!systemRandomTypeInfo ||
        !funcIntIntIntTypeInfo ||
        !funcDoubleTypeInfo ||
        !operationListRandomFuncTypeInfo) {
        SBUnityBridgeSetBattleConstructError(&result, "OperationListMoveSelector RandomFunc TypeInfo unavailable");
        return result;
    }

    void *battleTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                        unityBase,
                                                        SBUnitySoccerBattleTypeInfoGlobalRVA,
                                                        &result.soccerBattleTypeInfoGlobal);
    result.soccerBattleTypeInfo = (uintptr_t)battleTypeInfo;
    result.battleTypeReady = battleTypeInfo != NULL;
    if (!battleTypeInfo) {
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle TypeInfo unavailable");
        return result;
    }

    void *mainStoryStageContextTypeInfo = SBUnityBridgeResolveTypeInfo(metadataInit,
                                                                       unityBase,
                                                                       SBUnityMainStoryStageContextTypeInfoGlobalRVA,
                                                                       &result.mainStoryStageContextTypeInfoGlobal);
    result.mainStoryStageContextTypeInfo = (uintptr_t)mainStoryStageContextTypeInfo;
    if (!mainStoryStageContextTypeInfo) {
        SBUnityBridgeSetBattleConstructError(&result, "MainStoryStageContext TypeInfo unavailable");
        return result;
    }
    result.completedStage = 3;
    if (maxStage <= 3) {
        result.ok = YES;
        return result;
    }

    if (!objectNew ||
        !selectorCtor ||
        !selectorRandomFuncCtor ||
        !environmentGetTickCount ||
        !systemRandomCtor ||
        !funcIntIntIntCtor ||
        !funcDoubleCtor) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework selector construct function missing");
        return result;
    }

    void *selector = NULL;
    SBUnityBridgeSetBattleConstructStep(&result, "before OperationListMoveSelector RandomFunc");
    try {
        int32_t selectorRandomSeed = environmentGetTickCount(NULL);
        result.selectorRandomSeed = selectorRandomSeed;

        void *selectorRandom = objectNew(systemRandomTypeInfo);
        result.selectorRandom = (uintptr_t)selectorRandom;
        if (!selectorRandom) {
            SBUnityBridgeSetBattleConstructError(&result, "System.Random allocation failed");
            return result;
        }
        systemRandomCtor(selectorRandom, selectorRandomSeed, NULL);

        uintptr_t randomVtable = *(uintptr_t *)selectorRandom;
        intptr_t randomRangeInvoke = randomVtable ? (intptr_t)*(void **)(randomVtable + 416) : 0;
        intptr_t randomDoubleInvoke = randomVtable ? (intptr_t)*(void **)(randomVtable + 448) : 0;
        if (!randomRangeInvoke || !randomDoubleInvoke) {
            SBUnityBridgeSetBattleConstructError(&result, "System.Random delegate targets unavailable");
            return result;
        }

        void *randomRangeFunc = objectNew(funcIntIntIntTypeInfo);
        result.selectorRandomRangeFunc = (uintptr_t)randomRangeFunc;
        if (!randomRangeFunc) {
            SBUnityBridgeSetBattleConstructError(&result, "Func<int,int,int> allocation failed");
            return result;
        }
        funcIntIntIntCtor(randomRangeFunc, selectorRandom, randomRangeInvoke, NULL);

        void *randomDoubleFunc = objectNew(funcDoubleTypeInfo);
        result.selectorRandomDoubleFunc = (uintptr_t)randomDoubleFunc;
        if (!randomDoubleFunc) {
            SBUnityBridgeSetBattleConstructError(&result, "Func<double> allocation failed");
            return result;
        }
        funcDoubleCtor(randomDoubleFunc, selectorRandom, randomDoubleInvoke, NULL);

        void *randomFunc = objectNew(operationListRandomFuncTypeInfo);
        result.selectorRandomFunc = (uintptr_t)randomFunc;
        if (!randomFunc) {
            SBUnityBridgeSetBattleConstructError(&result, "OperationListMoveSelector.RandomFunc allocation failed");
            return result;
        }
        selectorRandomFuncCtor(randomFunc, randomRangeFunc, randomDoubleFunc, NULL);

        selector = objectNew(selectorTypeInfo);
        result.selector = (uintptr_t)selector;
        result.selectorAllocated = selector != NULL;
        if (!selector) {
            SBUnityBridgeSetBattleConstructError(&result, "OperationListMoveSelector allocation failed");
            return result;
        }

        selectorCtor(selector, randomFunc, NULL);
        result.selectorConstructed = YES;
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "OperationListMoveSelector RandomFunc construction raised a managed exception");
        return result;
    } catch (...) {
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "OperationListMoveSelector RandomFunc construction raised a C++/managed exception");
        return result;
    }
    SBUnityBridgeSetBattleConstructStep(&result, "after OperationListMoveSelector RandomFunc");
    result.completedStage = 4;
    if (maxStage <= 4) {
        result.ok = YES;
        return result;
    }

    if (!objectNew) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework object allocation function missing");
        return result;
    }

    void *battle = objectNew(battleTypeInfo);
    result.battle = (uintptr_t)battle;
    result.battleAllocated = battle != NULL;
    if (!battle) {
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle allocation failed");
        return result;
    }
    result.completedStage = 5;
    if (maxStage <= 5) {
        result.ok = YES;
        return result;
    }

    if (!battleCtor || !getResult) {
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework SoccerBattle runtime function missing");
        return result;
    }

    battleCtor(battle,
               NULL,
               result.battleType,
               result.seed,
               isAlwaysVictory,
               startSituation,
               specialFinishCondition,
               (void *)result.aTeam,
               (void *)result.bTeam,
               selector,
               (void *)result.fieldTerrain,
               result.backgroundCode,
               fieldMaster,
               NULL,
               NULL);
    result.battleConstructed = YES;
    result.completedStage = 6;

    uint8_t *battleBytes = (uint8_t *)battle;
    result.constructedBattleType = *(int32_t *)(battleBytes + 0x30);
    result.constructedSeed = *(int32_t *)(battleBytes + 0x70);
    result.constructedBackgroundCode = *(int32_t *)(battleBytes + 0xA8);
    void *moveSelections = *(void **)(battleBytes + 0x90);
    result.moveSelections = (uintptr_t)moveSelections;
    result.moveSelectionsCount = moveSelections ? *(int32_t *)((uint8_t *)moveSelections + 0x18) : -1;
    void *phaseResults = *(void **)(battleBytes + 0xE8);
    result.phaseResults = (uintptr_t)phaseResults;
    result.phaseResultsCount = phaseResults ? *(int32_t *)((uint8_t *)phaseResults + 0x18) : -1;
    result.initialResult = getResult(battle, NULL);

    result.ok = result.battleConstructed &&
                result.constructedBattleType == result.battleType &&
                result.constructedSeed == result.seed &&
                result.constructedBackgroundCode == result.backgroundCode &&
                result.moveSelections != 0 &&
                result.moveSelectionsCount == 0;
    if (!result.ok) {
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle constructed but fields look invalid");
        return result;
    }
    if (!battleRunCoroutineStage) {
        return result;
    }

    if (!runCoroutine ||
        !runCoroutineGetAsyncEnumerator ||
        !runCoroutineMoveNextAsync ||
        !runCoroutineGetCurrent ||
        !runCoroutineValueTaskGetResult ||
        !runCoroutineValueTaskGetStatus) {
        result.ok = NO;
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework SoccerBattle coroutine function missing");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "before SoccerBattle.RunCoroutine");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d before=RunCoroutine battle=0x%llx",
                              maxStage,
                              (unsigned long long)(uintptr_t)battle);
    try {
        void *coroutineEnumerable = runCoroutine(battle, NULL);
        result.battleCoroutineEnumerable = (uintptr_t)coroutineEnumerable;
        result.battleCoroutineCreated = coroutineEnumerable != NULL;
        if (!coroutineEnumerable) {
            result.ok = NO;
            SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine returned null");
            return result;
        }

        SBUnityCancellationToken cancellationToken = {0};
        void *coroutineEnumerator = runCoroutineGetAsyncEnumerator(coroutineEnumerable,
                                                                   cancellationToken,
                                                                   NULL);
        result.battleCoroutineEnumerator = (uintptr_t)coroutineEnumerator;
        result.battleEnumeratorCreated = coroutineEnumerator != NULL;
        if (!coroutineEnumerator) {
            result.ok = NO;
            SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine GetAsyncEnumerator returned null");
            return result;
        }

        static const int32_t SBUnityBridgeMaxCoroutineIterations = 512;
        for (int32_t i = 0; i < SBUnityBridgeMaxCoroutineIterations; i++) {
            SBUnityValueTaskBool nextTask = runCoroutineMoveNextAsync(coroutineEnumerator, NULL);
            bool hasNext = false;
            if (!nextTask.object) {
                result.coroutineLastStatus = 1;
                hasNext = nextTask.result;
            } else {
                int32_t status = runCoroutineValueTaskGetStatus(nextTask.object,
                                                                nextTask.token,
                                                                NULL);
                result.coroutineLastStatus = status;
                if (status == 0) {
                    result.battleCoroutinePending = YES;
                    result.ok = NO;
                    SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine MoveNextAsync is pending");
                    return result;
                }
                if (status != 1) {
                    (void)runCoroutineValueTaskGetResult(nextTask.object,
                                                         nextTask.token,
                                                         NULL);
                    result.ok = NO;
                    SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine MoveNextAsync failed");
                    return result;
                }
                hasNext = runCoroutineValueTaskGetResult(nextTask.object,
                                                         nextTask.token,
                                                         NULL);
            }

            if (!hasNext) {
                result.battleCoroutineCompleted = YES;
                break;
            }

            result.coroutineIterations++;
            void *current = runCoroutineGetCurrent(coroutineEnumerator, NULL);
            result.battleLastPhaseResult = (uintptr_t)current;
        }
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.ok = NO;
        result.battleCoroutineCaughtException = YES;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine raised a managed exception");
        return result;
    } catch (...) {
        result.ok = NO;
        result.battleCoroutineCaughtException = YES;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine raised a C++/managed exception");
        return result;
    }

    result.finalResult = getResult(battle, NULL);
    result.finalTurn = *(int32_t *)(battleBytes + 0x1C);
    phaseResults = *(void **)(battleBytes + 0xE8);
    result.phaseResults = (uintptr_t)phaseResults;
    result.phaseResultsCount = phaseResults ? *(int32_t *)((uint8_t *)phaseResults + 0x18) : -1;
    moveSelections = *(void **)(battleBytes + 0x90);
    result.moveSelections = (uintptr_t)moveSelections;
    result.moveSelectionsCount = moveSelections ? *(int32_t *)((uint8_t *)moveSelections + 0x18) : -1;

    void *battleATeam = *(void **)(battleBytes + 0x38);
    void *battleBTeam = *(void **)(battleBytes + 0x40);
    void *aScore = battleATeam ? *(void **)((uint8_t *)battleATeam + 0x38) : NULL;
    void *bScore = battleBTeam ? *(void **)((uint8_t *)battleBTeam + 0x38) : NULL;
    if (aScore) {
        result.aFirstHalfScore = *(int32_t *)((uint8_t *)aScore + 0x10);
        result.aSecondHalfScore = *(int32_t *)((uint8_t *)aScore + 0x14);
        result.aScore = result.aFirstHalfScore + result.aSecondHalfScore;
    }
    if (bScore) {
        result.bFirstHalfScore = *(int32_t *)((uint8_t *)bScore + 0x10);
        result.bSecondHalfScore = *(int32_t *)((uint8_t *)bScore + 0x14);
        result.bScore = result.bFirstHalfScore + result.bSecondHalfScore;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "after SoccerBattle.RunCoroutine");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d after=RunCoroutine completed=%d iterations=%d result=%d score=%d-%d turn=%d phases=%d selections=%d",
                              maxStage,
                              result.battleCoroutineCompleted,
                              result.coroutineIterations,
                              result.finalResult,
                              result.aScore,
                              result.bScore,
                              result.finalTurn,
                              result.phaseResultsCount,
                              result.moveSelectionsCount);

    result.ok = result.battleCoroutineCompleted &&
                !result.battleCoroutinePending &&
                result.finalTurn > 0 &&
                result.phaseResultsCount > 0;
    if (!result.ok) {
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.RunCoroutine did not complete cleanly");
        return result;
    }

    if (!objectNew || !mainStoryStageContextCtor || !mainStoryCreateFinishReq) {
        result.ok = NO;
        SBUnityBridgeSetBattleConstructError(&result, "MainStoryStageContext finish request function missing");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "before MainStoryStageContext.CreateFinishBattleReq");
    void *stageContext = objectNew(mainStoryStageContextTypeInfo);
    result.mainStoryStageContext = (uintptr_t)stageContext;
    if (!stageContext) {
        result.ok = NO;
        SBUnityBridgeSetBattleConstructError(&result, "MainStoryStageContext allocation failed");
        return result;
    }

    try {
        mainStoryStageContextCtor(stageContext, NULL);
        void *finishReq = mainStoryCreateFinishReq(stageContext, battle, NULL);
        result.finishReq = (uintptr_t)finishReq;
        if (!finishReq) {
            result.ok = NO;
            SBUnityBridgeSetBattleConstructError(&result, "MainStoryStageContext.CreateFinishBattleReq returned null");
            return result;
        }
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "MainStoryStageContext.CreateFinishBattleReq raised a managed exception");
        return result;
    } catch (...) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "MainStoryStageContext.CreateFinishBattleReq raised a C++/managed exception");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "after MainStoryStageContext.CreateFinishBattleReq");
    if (!SBUnityBridgeIsBattleReplayRoundTripStage(maxStage)) {
        return result;
    }

    if (!createReplay || !createForReplay || !replayToJson) {
        result.ok = NO;
        SBUnityBridgeSetBattleConstructError(&result, "UnityFramework SoccerBattle replay function missing");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "before SoccerBattle.CreateReplay");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d before=CreateReplay battle=0x%llx detail=0x%llx",
                              maxStage,
                              (unsigned long long)(uintptr_t)battle,
                              (unsigned long long)(uintptr_t)detail);
    void *battleReplay = NULL;
    try {
        battleReplay = createReplay(battle, detail, NULL, NULL, NULL);
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.CreateReplay raised a managed exception");
        return result;
    } catch (...) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.CreateReplay raised a C++/managed exception");
        return result;
    }
    result.battleReplay = (uintptr_t)battleReplay;
    result.battleReplayCreated = battleReplay != NULL;
    if (!battleReplay) {
        result.ok = NO;
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.CreateReplay returned null");
        return result;
    }

    try {
        void *replayJson = replayToJson(battleReplay, NULL);
        result.battleReplayJsonString = (uintptr_t)replayJson;
        result.battleReplayJsonCreated = replayJson != NULL;
        if (replayJson) {
            SBUnityBridgeReadStringPreview(replayJson,
                                           result.battleReplayJsonPreview,
                                           sizeof(result.battleReplayJsonPreview),
                                           &result.battleReplayJsonLength,
                                           512);
        }
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattleReplay.ToJson raised a managed exception");
        return result;
    } catch (...) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattleReplay.ToJson raised a C++/managed exception");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "before SoccerBattle.CreateForReplay");
    void *replayBattle = NULL;
    try {
        replayBattle = createForReplay(NULL, battleReplay, NULL);
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.CreateForReplay raised a managed exception");
        return result;
    } catch (...) {
        result.ok = NO;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.CreateForReplay raised a C++/managed exception");
        return result;
    }
    result.replayBattle = (uintptr_t)replayBattle;
    result.replayBattleCreated = replayBattle != NULL;
    if (!replayBattle) {
        result.ok = NO;
        SBUnityBridgeSetBattleConstructError(&result, "SoccerBattle.CreateForReplay returned null");
        return result;
    }

    SBUnityBridgeSetBattleConstructStep(&result, "before replay SoccerBattle.RunCoroutine");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d before=ReplayRunCoroutine replayBattle=0x%llx replayJsonLen=%d",
                              maxStage,
                              (unsigned long long)(uintptr_t)replayBattle,
                              result.battleReplayJsonLength);
    try {
        void *coroutineEnumerable = runCoroutine(replayBattle, NULL);
        result.replayBattleCoroutineEnumerable = (uintptr_t)coroutineEnumerable;
        if (!coroutineEnumerable) {
            result.ok = NO;
            SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle.RunCoroutine returned null");
            return result;
        }

        SBUnityCancellationToken cancellationToken = {0};
        void *coroutineEnumerator = runCoroutineGetAsyncEnumerator(coroutineEnumerable,
                                                                   cancellationToken,
                                                                   NULL);
        result.replayBattleCoroutineEnumerator = (uintptr_t)coroutineEnumerator;
        if (!coroutineEnumerator) {
            result.ok = NO;
            SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle.RunCoroutine GetAsyncEnumerator returned null");
            return result;
        }

        static const int32_t SBUnityBridgeMaxReplayCoroutineIterations = 512;
        for (int32_t i = 0; i < SBUnityBridgeMaxReplayCoroutineIterations; i++) {
            SBUnityValueTaskBool nextTask = runCoroutineMoveNextAsync(coroutineEnumerator, NULL);
            bool hasNext = false;
            if (!nextTask.object) {
                result.replayCoroutineLastStatus = 1;
                hasNext = nextTask.result;
            } else {
                int32_t status = runCoroutineValueTaskGetStatus(nextTask.object,
                                                                nextTask.token,
                                                                NULL);
                result.replayCoroutineLastStatus = status;
                if (status == 0) {
                    result.replayBattleCoroutinePending = YES;
                    result.ok = NO;
                    SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle.RunCoroutine MoveNextAsync is pending");
                    return result;
                }
                if (status != 1) {
                    (void)runCoroutineValueTaskGetResult(nextTask.object,
                                                         nextTask.token,
                                                         NULL);
                    result.ok = NO;
                    SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle.RunCoroutine MoveNextAsync failed");
                    return result;
                }
                hasNext = runCoroutineValueTaskGetResult(nextTask.object,
                                                         nextTask.token,
                                                         NULL);
            }

            if (!hasNext) {
                result.replayBattleCoroutineCompleted = YES;
                break;
            }

            result.replayCoroutineIterations++;
            void *current = runCoroutineGetCurrent(coroutineEnumerator, NULL);
            result.replayBattleLastPhaseResult = (uintptr_t)current;
        }
    } catch (Il2CppExceptionWrapper &wrappedException) {
        result.ok = NO;
        result.replayBattleCoroutineCaughtException = YES;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        result.masterDataLoadExceptionWrapper = (uintptr_t)&wrappedException;
        SBUnityBridgeReadManagedException(&result, wrappedException.exception);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle.RunCoroutine raised a managed exception");
        return result;
    } catch (...) {
        result.ok = NO;
        result.replayBattleCoroutineCaughtException = YES;
        result.masterDataLoadCaughtException = YES;
        SBUnityBridgeCaptureCurrentExceptionType(&result);
        SBUnityBridgeReadCurrentIl2CppExceptionWrapper(&result);
        SBUnityBridgeReadManagedExceptionString(&result, exceptionToString);
        SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle.RunCoroutine raised a C++/managed exception");
        return result;
    }

    uint8_t *replayBattleBytes = (uint8_t *)replayBattle;
    result.replayFinalResult = getResult(replayBattle, NULL);
    result.replayFinalTurn = *(int32_t *)(replayBattleBytes + 0x1C);
    void *replayPhaseResults = *(void **)(replayBattleBytes + 0xE8);
    result.replayPhaseResults = (uintptr_t)replayPhaseResults;
    result.replayPhaseResultsCount = replayPhaseResults ? *(int32_t *)((uint8_t *)replayPhaseResults + 0x18) : -1;
    void *replayMoveSelections = *(void **)(replayBattleBytes + 0x90);
    result.replayMoveSelections = (uintptr_t)replayMoveSelections;
    result.replayMoveSelectionsCount = replayMoveSelections ? *(int32_t *)((uint8_t *)replayMoveSelections + 0x18) : -1;

    void *replayBattleATeam = *(void **)(replayBattleBytes + 0x38);
    void *replayBattleBTeam = *(void **)(replayBattleBytes + 0x40);
    void *replayAScore = replayBattleATeam ? *(void **)((uint8_t *)replayBattleATeam + 0x38) : NULL;
    void *replayBScore = replayBattleBTeam ? *(void **)((uint8_t *)replayBattleBTeam + 0x38) : NULL;
    if (replayAScore) {
        result.replayAFirstHalfScore = *(int32_t *)((uint8_t *)replayAScore + 0x10);
        result.replayASecondHalfScore = *(int32_t *)((uint8_t *)replayAScore + 0x14);
        result.replayAScore = result.replayAFirstHalfScore + result.replayASecondHalfScore;
    }
    if (replayBScore) {
        result.replayBFirstHalfScore = *(int32_t *)((uint8_t *)replayBScore + 0x10);
        result.replayBSecondHalfScore = *(int32_t *)((uint8_t *)replayBScore + 0x14);
        result.replayBScore = result.replayBFirstHalfScore + result.replayBSecondHalfScore;
    }

    result.replayMatchesInitial =
        result.replayBattleCoroutineCompleted &&
        !result.replayBattleCoroutinePending &&
        result.replayFinalResult == result.finalResult &&
        result.replayFinalTurn == result.finalTurn &&
        result.replayAScore == result.aScore &&
        result.replayBScore == result.bScore &&
        result.replayMoveSelectionsCount == result.moveSelectionsCount;

    SBUnityBridgeSetBattleConstructStep(&result, "after replay SoccerBattle.RunCoroutine");
    SBUnityBridgeEmitProgress(@"unity-battle-probe-step",
                              @"stage=%d after=ReplayRunCoroutine completed=%d iterations=%d result=%d score=%d-%d turn=%d selections=%d match=%d",
                              maxStage,
                              result.replayBattleCoroutineCompleted,
                              result.replayCoroutineIterations,
                              result.replayFinalResult,
                              result.replayAScore,
                              result.replayBScore,
                              result.replayFinalTurn,
                              result.replayMoveSelectionsCount,
                              result.replayMatchesInitial);

    result.ok = result.replayMatchesInitial;
    if (!result.ok) {
        SBUnityBridgeSetBattleConstructError(&result, "Replay SoccerBattle result did not match initial run");
    }
    return result;
}

NSDictionary *SBUnityBridgeBattleConstructResultDictionary(SBUnityBridgeBattleConstructResult result) {
    return @{
        @"ok": @(result.ok),
        @"maxStage": @(result.maxStage),
        @"completedStage": @(result.completedStage),
        @"completedGetter": @(result.completedGetter),
        @"unityFound": @(result.unityFound),
        @"stringAllocated": @(result.stringAllocated),
        @"detailParsed": @(result.detailParsed),
        @"stageInputsReady": @(result.stageInputsReady),
        @"stageMasterLoaded": @(result.stageMasterLoaded),
        @"stageMasterFieldsReady": @(result.stageMasterFieldsReady),
        @"masterModelTypeReady": @(result.masterModelTypeReady),
        @"masterModelStaticFieldsReady": @(result.masterModelStaticFieldsReady),
        @"masterModelLoaded": @(result.masterModelLoaded),
        @"stageMasterCollectionReady": @(result.stageMasterCollectionReady),
        @"masterDataLoadCalled": @(result.masterDataLoadCalled),
        @"masterDataLoadReturned": @(result.masterDataLoadReturned),
        @"masterDataPathStringAllocated": @(result.masterDataPathStringAllocated),
        @"masterDataPathExists": @(result.masterDataPathExists),
        @"masterDataPathIsDirectory": @(result.masterDataPathIsDirectory),
        @"masterDataEventsTypeReady": @(result.masterDataEventsTypeReady),
        @"masterDataEventsAllocated": @(result.masterDataEventsAllocated),
        @"masterDataEventsConstructed": @(result.masterDataEventsConstructed),
        @"tsvErrorCollectorTypeReady": @(result.tsvErrorCollectorTypeReady),
        @"tsvErrorCollectorAllocated": @(result.tsvErrorCollectorAllocated),
        @"tsvErrorCollectorConstructed": @(result.tsvErrorCollectorConstructed),
        @"tsvErrorCollectorHasError": @(result.tsvErrorCollectorHasError),
        @"masterDataLoadCaughtException": @(result.masterDataLoadCaughtException),
        @"serverVersionHashStringAllocated": @(result.serverVersionHashStringAllocated),
        @"masterDataProtectionKeyGenerated": @(result.masterDataProtectionKeyGenerated),
        @"parameterMasterPathStringAllocated": @(result.parameterMasterPathStringAllocated),
        @"parameterMasterEncryptedBytesRead": @(result.parameterMasterEncryptedBytesRead),
        @"parameterMasterDecrypted": @(result.parameterMasterDecrypted),
        @"parameterMasterTextRead": @(result.parameterMasterTextRead),
        @"parameterMasterManualParsed": @(result.parameterMasterManualParsed),
        @"tsvDocumentTypeReady": @(result.tsvDocumentTypeReady),
        @"tsvDocumentAllocated": @(result.tsvDocumentAllocated),
        @"tsvDocumentConstructed": @(result.tsvDocumentConstructed),
        @"tsvKeyValueDocumentTypeReady": @(result.tsvKeyValueDocumentTypeReady),
        @"tsvKeyValueDocumentAllocated": @(result.tsvKeyValueDocumentAllocated),
        @"tsvKeyValueDocumentConstructed": @(result.tsvKeyValueDocumentConstructed),
        @"directoryInfoTypeReady": @(result.directoryInfoTypeReady),
        @"directoryInfoAllocated": @(result.directoryInfoAllocated),
        @"directoryInfoConstructed": @(result.directoryInfoConstructed),
        @"directoryGetFilesCalled": @(result.directoryGetFilesCalled),
        @"loadMasterFileCalled": @(result.loadMasterFileCalled),
        @"loadMasterFileReturned": @(result.loadMasterFileReturned),
        @"loadMasterFileManualParsed": @(result.loadMasterFileManualParsed),
        @"selectorTypeReady": @(result.selectorTypeReady),
        @"selectorAllocated": @(result.selectorAllocated),
        @"selectorConstructed": @(result.selectorConstructed),
        @"battleTypeReady": @(result.battleTypeReady),
        @"battleAllocated": @(result.battleAllocated),
        @"battleConstructed": @(result.battleConstructed),
        @"battleCoroutineCreated": @(result.battleCoroutineCreated),
        @"battleEnumeratorCreated": @(result.battleEnumeratorCreated),
        @"battleCoroutineCompleted": @(result.battleCoroutineCompleted),
        @"battleCoroutinePending": @(result.battleCoroutinePending),
        @"battleCoroutineCaughtException": @(result.battleCoroutineCaughtException),
        @"battleReplayCreated": @(result.battleReplayCreated),
        @"battleReplayJsonCreated": @(result.battleReplayJsonCreated),
        @"replayBattleCreated": @(result.replayBattleCreated),
        @"replayBattleCoroutineCompleted": @(result.replayBattleCoroutineCompleted),
        @"replayBattleCoroutinePending": @(result.replayBattleCoroutinePending),
        @"replayBattleCoroutineCaughtException": @(result.replayBattleCoroutineCaughtException),
        @"replayMatchesInitial": @(result.replayMatchesInitial),
        @"unityBase": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.unityBase],
        @"stringAllocRVA": @"0x3BD87C",
        @"stringAlloc": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stringAllocAddress],
        @"fromJsonRVA": @"0x69CA948",
        @"fromJson": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fromJsonAddress],
        @"metadataInitRVA": @"0x371A68",
        @"metadataInit": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.metadataInitAddress],
        @"objectNewRVA": @"0x371D24",
        @"objectNew": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.objectNewAddress],
        @"selectorCtorRVA": @"0x69208EC",
        @"selectorCtor": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorCtorAddress],
        @"battleCtorRVA": @"0x6904738",
        @"battleCtor": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleCtorAddress],
        @"getIsAlwaysVictoryRVA": @"0x69CAB94",
        @"getIsAlwaysVictory": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.getIsAlwaysVictoryAddress],
        @"getStartSituationRVA": @"0x69CABF4",
        @"getStartSituation": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.getStartSituationAddress],
        @"getSpecialFinishConditionRVA": @"0x69CAC24",
        @"getSpecialFinishCondition": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.getSpecialFinishConditionAddress],
        @"getBackgroundMasterRVA": @"0x69CAC54",
        @"getBackgroundMaster": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.getBackgroundMasterAddress],
        @"getFieldMasterRVA": @"0x69CAC84",
        @"getFieldMaster": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.getFieldMasterAddress],
        @"stageMasterGetByBattleTypeRVA": @"0x69491F8",
        @"stageMasterGetByBattleType": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageMasterGetByBattleTypeAddress],
        @"stageMasterGetByBattleTypeMethodInfoRVA": @"0x9BA1F80",
        @"stageMasterGetByBattleTypeMethodInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageMasterGetByBattleTypeMethodInfo],
        @"masterDataLoadAllRVA": @"0x6A23058",
        @"masterDataLoadAll": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataLoadAllAddress],
        @"masterDataLoadMasterRVA": @"0x6A230C0",
        @"masterDataLoadMaster": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataLoadMasterAddress],
        @"masterDataLoadPrivateRVA": @"0x6A2365C",
        @"masterDataLoadPrivate": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataLoadPrivateAddress],
        @"masterDataProtectionGenerateKeyRVA": @"0x6A5A690",
        @"masterDataProtectionGenerateKey": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataProtectionGenerateKeyAddress],
        @"masterDataProtectionDecryptRVA": @"0x6A5A8BC",
        @"masterDataProtectionDecrypt": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataProtectionDecryptAddress],
        @"fileReadAllBytesRVA": @"0x66E3D30",
        @"fileReadAllBytes": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fileReadAllBytesAddress],
        @"fileReadAllTextRVA": @"0x66E37C4",
        @"fileReadAllText": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fileReadAllTextAddress],
        @"tsvDocumentCtorRVA": @"0x697D928",
        @"tsvDocumentCtor": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvDocumentCtorAddress],
        @"tsvKeyValueDocumentCtorRVA": @"0x697F13C",
        @"tsvKeyValueDocumentCtor": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvKeyValueDocumentCtorAddress],
        @"tsvDocumentGetCountRVA": @"0x697D8DC",
        @"tsvDocumentGetCount": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvDocumentGetCountAddress],
        @"tsvDocumentToStringRVA": @"0x697DF84",
        @"tsvDocumentToString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvDocumentToStringAddress],
        @"directoryInfoCtorRVA": @"0x66E2828",
        @"directoryInfoCtor": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryInfoCtorAddress],
        @"fileSystemInfoGetFullNameRVA": @"0x66E6C1C",
        @"fileSystemInfoGetFullName": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fileSystemInfoGetFullNameAddress],
        @"directoryGetFilesRVA": @"0x66E1E3C",
        @"directoryGetFiles": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryGetFilesAddress],
        @"loadMasterFileRVA": @"0x6A269B0",
        @"loadMasterFile": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.loadMasterFileAddress],
        @"masterDataPathString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataPathString],
        @"serverVersionHashString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.serverVersionHashString],
        @"masterDataProtectionKey": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataProtectionKey],
        @"parameterMasterPathString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.parameterMasterPathString],
        @"parameterMasterEncryptedBytes": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.parameterMasterEncryptedBytes],
        @"parameterMasterDecryptedString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.parameterMasterDecryptedString],
        @"parameterMasterTextString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.parameterMasterTextString],
        @"tsvDocumentTypeInfoGlobalRVA": @"0x9B528F0",
        @"tsvDocumentTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvDocumentTypeInfoGlobal],
        @"tsvDocumentTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvDocumentTypeInfo],
        @"tsvDocument": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvDocument],
        @"tsvKeyValueDocumentTypeInfoGlobalRVA": @"0x9B52918",
        @"tsvKeyValueDocumentTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvKeyValueDocumentTypeInfoGlobal],
        @"tsvKeyValueDocumentTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvKeyValueDocumentTypeInfo],
        @"tsvKeyValueDocument": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvKeyValueDocument],
        @"directoryInfoTypeInfoGlobalRVA": @"0x9B4A258",
        @"directoryInfoTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryInfoTypeInfoGlobal],
        @"directoryInfoTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryInfoTypeInfo],
        @"directoryInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryInfo],
        @"directoryInfoFullNameString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryInfoFullNameString],
        @"directoryGetFilesArray": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.directoryGetFilesArray],
        @"loadMasterFileDocument": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.loadMasterFileDocument],
        @"loadMasterFileDocumentString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.loadMasterFileDocumentString],
        @"loadMasterFileKeyValueDocument": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.loadMasterFileKeyValueDocument],
        @"loadMasterFilePathConstantAGlobalRVA": @"0x9BD5780",
        @"loadMasterFilePathConstantAString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.loadMasterFilePathConstantAString],
        @"loadMasterFilePathConstantBGlobalRVA": @"0x9BC59F8",
        @"loadMasterFilePathConstantBString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.loadMasterFilePathConstantBString],
        @"masterDataEventsTypeInfoGlobalRVA": @"0x9B4E4B0",
        @"masterDataEventsTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataEventsTypeInfoGlobal],
        @"masterDataEventsTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataEventsTypeInfo],
        @"masterDataEvents": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataEvents],
        @"tsvErrorCollectorTypeInfoGlobalRVA": @"0x9B52900",
        @"tsvErrorCollectorTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvErrorCollectorTypeInfoGlobal],
        @"tsvErrorCollectorTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvErrorCollectorTypeInfo],
        @"tsvErrorCollector": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvErrorCollector],
        @"tsvErrorCollectorGetHasErrorRVA": @"0x697C0CC",
        @"tsvErrorCollectorGetHasError": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvErrorCollectorGetHasErrorAddress],
        @"tsvErrorCollectorToStringRVA": @"0x697C288",
        @"tsvErrorCollectorToString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.tsvErrorCollectorToStringAddress],
        @"masterDataLoadExceptionWrapper": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataLoadExceptionWrapper],
        @"masterDataLoadException": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataLoadException],
        @"masterDataLoadExceptionToStringRVA": @"0x676F6E8",
        @"masterDataLoadExceptionToString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterDataLoadExceptionToStringAddress],
        @"masterModelTypeInfoGlobalRVA": @"0x9B4E4B8",
        @"masterModelTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterModelTypeInfoGlobal],
        @"masterModelTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterModelTypeInfo],
        @"masterModelStaticFields": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.masterModelStaticFields],
        @"stageMasterCollection": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageMasterCollection],
        @"getResultRVA": @"0x69056AC",
        @"getResult": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.getResultAddress],
        @"battleRunCoroutineRVA": @"0x6906884",
        @"battleRunCoroutine": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleRunCoroutineAddress],
        @"battleRunCoroutineGetAsyncEnumeratorRVA": @"0x6916644",
        @"battleRunCoroutineGetAsyncEnumerator": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleRunCoroutineGetAsyncEnumeratorAddress],
        @"battleRunCoroutineMoveNextAsyncRVA": @"0x6916760",
        @"battleRunCoroutineMoveNextAsync": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleRunCoroutineMoveNextAsyncAddress],
        @"battleRunCoroutineGetCurrentRVA": @"0x69168F8",
        @"battleRunCoroutineGetCurrent": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleRunCoroutineGetCurrentAddress],
        @"battleRunCoroutineValueTaskGetResultRVA": @"0x6916900",
        @"battleRunCoroutineValueTaskGetResult": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleRunCoroutineValueTaskGetResultAddress],
        @"battleRunCoroutineValueTaskGetStatusRVA": @"0x691695C",
        @"battleRunCoroutineValueTaskGetStatus": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleRunCoroutineValueTaskGetStatusAddress],
        @"battleCreateReplayRVA": @"0x6905580",
        @"battleCreateReplay": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleCreateReplayAddress],
        @"battleCreateForReplayRVA": @"0x6905414",
        @"battleCreateForReplay": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleCreateForReplayAddress],
        @"battleReplayToJsonRVA": @"0x69ADB14",
        @"battleReplayToJson": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleReplayToJsonAddress],
        @"battleReplayFromJsonRVA": @"0x69ADC20",
        @"battleReplayFromJson": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleReplayFromJsonAddress],
        @"managedJsonString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.managedJsonString],
        @"reservationDetail": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.reservationDetail],
        @"aTeam": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.aTeam],
        @"bTeam": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.bTeam],
        @"fieldTerrain": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fieldTerrain],
        @"startSituation": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.startSituation],
        @"specialFinishCondition": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.specialFinishCondition],
        @"backgroundMaster": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.backgroundMaster],
        @"fieldMaster": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.fieldMaster],
        @"stageMaster": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.stageMaster],
        @"selectorTypeInfoGlobalRVA": @"0x9B4F230",
        @"selectorTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorTypeInfoGlobal],
        @"selectorTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorTypeInfo],
        @"systemRandomTypeInfoGlobalRVA": @"0x9B4FFC8",
        @"systemRandomTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.systemRandomTypeInfoGlobal],
        @"systemRandomTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.systemRandomTypeInfo],
        @"funcIntIntIntTypeInfoGlobalRVA": @"0x9B40100",
        @"funcIntIntIntTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.funcIntIntIntTypeInfoGlobal],
        @"funcIntIntIntTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.funcIntIntIntTypeInfo],
        @"funcDoubleTypeInfoGlobalRVA": @"0x9B3C498",
        @"funcDoubleTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.funcDoubleTypeInfoGlobal],
        @"funcDoubleTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.funcDoubleTypeInfo],
        @"operationListRandomFuncTypeInfoGlobalRVA": @"0x9B5A110",
        @"operationListRandomFuncTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.operationListRandomFuncTypeInfoGlobal],
        @"operationListRandomFuncTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.operationListRandomFuncTypeInfo],
        @"soccerBattleTypeInfoGlobalRVA": @"0x9B51418",
        @"soccerBattleTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleTypeInfoGlobal],
        @"soccerBattleTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.soccerBattleTypeInfo],
        @"mainStoryStageContextTypeInfoGlobalRVA": @"0x9B4B710",
        @"mainStoryStageContextTypeInfoGlobal": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.mainStoryStageContextTypeInfoGlobal],
        @"mainStoryStageContextTypeInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.mainStoryStageContextTypeInfo],
        @"mainStoryStageContextCtorRVA": @"0x1FF4C1C",
        @"mainStoryStageContextCtor": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.mainStoryStageContextCtorAddress],
        @"mainStoryCreateFinishReqRVA": @"0x1FF4924",
        @"mainStoryCreateFinishReq": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.mainStoryCreateFinishReqAddress],
        @"selector": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selector],
        @"selectorRandom": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorRandom],
        @"selectorRandomRangeFunc": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorRandomRangeFunc],
        @"selectorRandomDoubleFunc": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorRandomDoubleFunc],
        @"selectorRandomFunc": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.selectorRandomFunc],
        @"battle": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battle],
        @"mainStoryStageContext": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.mainStoryStageContext],
        @"finishReq": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.finishReq],
        @"battleCoroutineEnumerable": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleCoroutineEnumerable],
        @"battleCoroutineEnumerator": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleCoroutineEnumerator],
        @"battleLastPhaseResult": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleLastPhaseResult],
        @"battleReplay": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleReplay],
        @"battleReplayJsonString": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.battleReplayJsonString],
        @"replayBattle": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.replayBattle],
        @"replayBattleCoroutineEnumerable": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.replayBattleCoroutineEnumerable],
        @"replayBattleCoroutineEnumerator": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.replayBattleCoroutineEnumerator],
        @"replayBattleLastPhaseResult": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.replayBattleLastPhaseResult],
        @"moveSelections": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.moveSelections],
        @"phaseResults": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.phaseResults],
        @"replayMoveSelections": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.replayMoveSelections],
        @"replayPhaseResults": [NSString stringWithFormat:@"0x%llx", (unsigned long long)result.replayPhaseResults],
        @"jsonLength": @(result.jsonLength),
        @"battleType": @(result.battleType),
        @"seed": @(result.seed),
        @"stageCode": @(result.stageCode),
        @"stageMasterCollectionOffset": @(result.stageMasterCollectionOffset),
        @"isAlwaysVictory": @(result.isAlwaysVictory),
        @"backgroundCode": @(result.backgroundCode),
        @"fieldCode": @(result.fieldCode),
        @"constructedBattleType": @(result.constructedBattleType),
        @"constructedSeed": @(result.constructedSeed),
        @"constructedBackgroundCode": @(result.constructedBackgroundCode),
        @"selectorRandomSeed": @(result.selectorRandomSeed),
        @"moveSelectionsCount": @(result.moveSelectionsCount),
        @"finishRequestReady": @(result.ok &&
                                  result.battleCoroutineCompleted &&
                                  result.finishReq != 0),
        @"finishRequestSource": @"MainStoryStageContext.CreateFinishBattleReq",
        @"finishRequestPath": @"/v1/Battle/FinishMainStoryBattle",
        @"finishRequestBody": SBUnityBridgeFinishMainStoryBattleRequestBodyFromReq((void *)result.finishReq),
        @"finishRequestBodyRaw": SBUnityBridgeFinishMainStoryBattleRequestRawBodyFromReq((void *)result.finishReq),
        @"manualFinishRequestBody": SBUnityBridgeFinishMainStoryBattleRequestBody(result),
        @"manualFinishRequestBodyRaw": SBUnityBridgeFinishMainStoryBattleRequestRawBody(result),
        @"phaseResultsCount": @(result.phaseResultsCount),
        @"coroutineIterations": @(result.coroutineIterations),
        @"coroutineLastStatus": @(result.coroutineLastStatus),
        @"initialResult": @(result.initialResult),
        @"finalResult": @(result.finalResult),
        @"finalTurn": @(result.finalTurn),
        @"aScore": @(result.aScore),
        @"bScore": @(result.bScore),
        @"aFirstHalfScore": @(result.aFirstHalfScore),
        @"aSecondHalfScore": @(result.aSecondHalfScore),
        @"bFirstHalfScore": @(result.bFirstHalfScore),
        @"bSecondHalfScore": @(result.bSecondHalfScore),
        @"battleReplayJsonLength": @(result.battleReplayJsonLength),
        @"replayCoroutineIterations": @(result.replayCoroutineIterations),
        @"replayCoroutineLastStatus": @(result.replayCoroutineLastStatus),
        @"replayFinalResult": @(result.replayFinalResult),
        @"replayFinalTurn": @(result.replayFinalTurn),
        @"replayMoveSelectionsCount": @(result.replayMoveSelectionsCount),
        @"replayPhaseResultsCount": @(result.replayPhaseResultsCount),
        @"replayAScore": @(result.replayAScore),
        @"replayBScore": @(result.replayBScore),
        @"replayAFirstHalfScore": @(result.replayAFirstHalfScore),
        @"replayASecondHalfScore": @(result.replayASecondHalfScore),
        @"replayBFirstHalfScore": @(result.replayBFirstHalfScore),
        @"replayBSecondHalfScore": @(result.replayBSecondHalfScore),
        @"masterDataProtectionKeyLength": @(result.masterDataProtectionKeyLength),
        @"parameterMasterEncryptedLength": @(result.parameterMasterEncryptedLength),
        @"parameterMasterDecryptedLength": @(result.parameterMasterDecryptedLength),
        @"directoryGetFilesCount": @(result.directoryGetFilesCount),
        @"loadMasterFileDocumentCount": @(result.loadMasterFileDocumentCount),
        @"loadMasterFileDocumentStringLength": @(result.loadMasterFileDocumentStringLength),
        @"masterDataPath": [NSString stringWithUTF8String:result.masterDataPath] ?: @"",
        @"parameterMasterPath": [NSString stringWithUTF8String:result.parameterMasterPath] ?: @"",
        @"parameterMasterPreview": [NSString stringWithUTF8String:result.parameterMasterPreview] ?: @"",
        @"directoryInfoFullName": [NSString stringWithUTF8String:result.directoryInfoFullName] ?: @"",
        @"directoryGetFilesFirst": [NSString stringWithUTF8String:result.directoryGetFilesFirst] ?: @"",
        @"loadMasterFileDocumentPreview": [NSString stringWithUTF8String:result.loadMasterFileDocumentPreview] ?: @"",
        @"loadMasterFilePathConstantA": [NSString stringWithUTF8String:result.loadMasterFilePathConstantA] ?: @"",
        @"loadMasterFilePathConstantB": [NSString stringWithUTF8String:result.loadMasterFilePathConstantB] ?: @"",
        @"battleReplayJsonPreview": [NSString stringWithUTF8String:result.battleReplayJsonPreview] ?: @"",
        @"serverVersionHash": [NSString stringWithUTF8String:result.serverVersionHash] ?: @"",
        @"masterDataLoadExceptionType": [NSString stringWithUTF8String:result.masterDataLoadExceptionType] ?: @"",
        @"masterDataLoadExceptionClass": [NSString stringWithUTF8String:result.masterDataLoadExceptionClass] ?: @"",
        @"masterDataLoadExceptionMessage": [NSString stringWithUTF8String:result.masterDataLoadExceptionMessage] ?: @"",
        @"masterDataLoadExceptionString": [NSString stringWithUTF8String:result.masterDataLoadExceptionString] ?: @"",
        @"tsvErrorCollectorReport": [NSString stringWithUTF8String:result.tsvErrorCollectorReport] ?: @"",
        @"lastStep": [NSString stringWithUTF8String:result.lastStep] ?: @"",
        @"error": [NSString stringWithUTF8String:result.error] ?: @""
    };
}
