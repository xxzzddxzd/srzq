#import "FinishRequestCapture.h"

#import <Foundation/Foundation.h>
#include "SBHookCompat.h"
#include <mach-o/dyld.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static const uintptr_t SBFinishCaptureCreateFinishMainStoryBattleReqRVA = 0x1FF4924;
static const uintptr_t SBFinishCaptureReqExpectedResultOffset = 0x1C;
static const uintptr_t SBFinishCaptureReqExpectedAScoreOffset = 0x20;
static const uintptr_t SBFinishCaptureReqExpectedBScoreOffset = 0x24;
static const uintptr_t SBFinishCaptureReqMoveSelectionsOffset = 0x28;
static const uintptr_t SBFinishCaptureMoveTeamIdOffset = 0x10;
static const uintptr_t SBFinishCaptureMovePlayerIndexOffset = 0x14;
static const uintptr_t SBFinishCaptureMoveMoveIndexOffset = 0x18;
static const uintptr_t SBFinishCaptureMoveMoveCodeOffset = 0x20;
static const uintptr_t SBFinishCaptureNullableHasValueOffset = 0x0;
static const uintptr_t SBFinishCaptureNullableValueOffset = 0x4;
static const uintptr_t SBFinishCaptureArrayLengthOffset = 0x18;
static const uintptr_t SBFinishCaptureArrayItemsOffset = 0x20;

typedef void *(*SBFinishCaptureCreateFinishReqFn)(void *stageContext, void *battle, const void *methodInfo);

static atomic_bool SBFinishCaptureInstalled = false;
static atomic_bool SBFinishCaptureInstallAttempted = false;
static SBFinishCaptureCreateFinishReqFn SBFinishCaptureOrigCreateFinishReq = NULL;
static uintptr_t SBFinishCaptureUnityBase = 0;
static uintptr_t SBFinishCaptureHookAddress = 0;
static char SBFinishCaptureInstallError[192];

typedef struct SBFinishCaptureNullableInt32 {
    BOOL hasValue;
    int32_t value;
} SBFinishCaptureNullableInt32;

static NSObject *SBFinishCaptureLock(void) {
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    return lock;
}

static NSMutableDictionary *SBFinishCaptureState(void) {
    static NSMutableDictionary *state;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        state = [NSMutableDictionary dictionary];
    });
    return state;
}

static NSString *SBFinishCaptureTimestamp(void) {
    return [[NSDate date] descriptionWithLocale:nil] ?: @"";
}

static BOOL SBFinishCaptureIsUnityFrameworkImage(const char *name) {
    if (!name || !name[0]) {
        return NO;
    }
    return strstr(name, "/UnityFramework.framework/UnityFramework") != NULL ||
           strcmp(name, "UnityFramework") == 0;
}

static uintptr_t SBFinishCaptureFindUnityBase(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBFinishCaptureIsUnityFrameworkImage(name)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

static SBFinishCaptureNullableInt32 SBFinishCaptureReadNullableInt32(void *field) {
    SBFinishCaptureNullableInt32 value = {NO, 0};
    if (!field) {
        return value;
    }

    uint8_t *bytes = (uint8_t *)field;
    value.hasValue = *(bool *)(bytes + SBFinishCaptureNullableHasValueOffset);
    value.value = *(int32_t *)(bytes + SBFinishCaptureNullableValueOffset);
    return value;
}

static id SBFinishCaptureJSONObjectForNullableInt32(SBFinishCaptureNullableInt32 value) {
    return value.hasValue ? @(value.value) : (id)NSNull.null;
}

static NSString *SBFinishCaptureJSONStringForNullableInt32(SBFinishCaptureNullableInt32 value) {
    return value.hasValue ? [NSString stringWithFormat:@"%d", value.value] : @"null";
}

static int32_t SBFinishCaptureArrayCount(void *array, int32_t maxCount) {
    if (!array) {
        return 0;
    }
    uintptr_t length = *(uintptr_t *)((uint8_t *)array + SBFinishCaptureArrayLengthOffset);
    if (length > (uintptr_t)INT32_MAX) {
        length = INT32_MAX;
    }
    int32_t count = (int32_t)length;
    if (maxCount >= 0 && count > maxCount) {
        count = maxCount;
    }
    return count;
}

static int32_t SBFinishCaptureNullMoveSelectionCount(void *array) {
    int32_t count = SBFinishCaptureArrayCount(array, 512);
    if (!array || count <= 0) {
        return 0;
    }

    int32_t nullCount = 0;
    uint8_t *arrayBytes = (uint8_t *)array;
    for (int32_t i = 0; i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + SBFinishCaptureArrayItemsOffset + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            nullCount++;
        }
    }
    return nullCount;
}

static NSArray<NSDictionary *> *SBFinishCaptureMoveSelectionsFromArray(void *array) {
    int32_t count = SBFinishCaptureArrayCount(array, 512);
    if (!array || count <= 0) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *moves = [NSMutableArray arrayWithCapacity:(NSUInteger)count];
    uint8_t *arrayBytes = (uint8_t *)array;
    for (int32_t i = 0; i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + SBFinishCaptureArrayItemsOffset + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            continue;
        }

        uint8_t *moveBytes = (uint8_t *)moveSelection;
        int32_t teamId = (int32_t)*(uint8_t *)(moveBytes + SBFinishCaptureMoveTeamIdOffset);
        int32_t playerIndex = *(int32_t *)(moveBytes + SBFinishCaptureMovePlayerIndexOffset);
        SBFinishCaptureNullableInt32 moveIndex = SBFinishCaptureReadNullableInt32(moveBytes + SBFinishCaptureMoveMoveIndexOffset);
        SBFinishCaptureNullableInt32 moveCode = SBFinishCaptureReadNullableInt32(moveBytes + SBFinishCaptureMoveMoveCodeOffset);
        BOOL hasMove = moveIndex.hasValue && moveCode.hasValue;

        [moves addObject:@{
            @"HasMove": @(hasMove),
            @"TeamId": @(teamId),
            @"PlayerIndex": @(playerIndex),
            @"MoveIndex": SBFinishCaptureJSONObjectForNullableInt32(moveIndex),
            @"MoveCode": SBFinishCaptureJSONObjectForNullableInt32(moveCode)
        }];
    }
    return moves;
}

static NSString *SBFinishCaptureRawBodyFromReq(void *req) {
    if (!req) {
        return @"";
    }

    int32_t expectedResult = *(int32_t *)((uint8_t *)req + SBFinishCaptureReqExpectedResultOffset);
    int32_t expectedAScore = *(int32_t *)((uint8_t *)req + SBFinishCaptureReqExpectedAScoreOffset);
    int32_t expectedBScore = *(int32_t *)((uint8_t *)req + SBFinishCaptureReqExpectedBScoreOffset);
    void *movesArray = *(void **)((uint8_t *)req + SBFinishCaptureReqMoveSelectionsOffset);
    int32_t count = SBFinishCaptureArrayCount(movesArray, 512);

    NSMutableString *raw = [NSMutableString stringWithFormat:
        @"{\"$type\":\"FinishMainStoryBattleReq\",\"ExpectedResult\":%d,\"ExpectedAScore\":%d,\"ExpectedBScore\":%d,\"MoveSelections\":[",
        expectedResult,
        expectedAScore,
        expectedBScore];
    BOOL first = YES;
    uint8_t *arrayBytes = (uint8_t *)movesArray;
    for (int32_t i = 0; arrayBytes && i < count; i++) {
        void *moveSelection = *(void **)(arrayBytes + SBFinishCaptureArrayItemsOffset + ((uintptr_t)i * sizeof(void *)));
        if (!moveSelection) {
            continue;
        }

        uint8_t *moveBytes = (uint8_t *)moveSelection;
        int32_t teamId = (int32_t)*(uint8_t *)(moveBytes + SBFinishCaptureMoveTeamIdOffset);
        int32_t playerIndex = *(int32_t *)(moveBytes + SBFinishCaptureMovePlayerIndexOffset);
        SBFinishCaptureNullableInt32 moveIndex = SBFinishCaptureReadNullableInt32(moveBytes + SBFinishCaptureMoveMoveIndexOffset);
        SBFinishCaptureNullableInt32 moveCode = SBFinishCaptureReadNullableInt32(moveBytes + SBFinishCaptureMoveMoveCodeOffset);
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
            SBFinishCaptureJSONStringForNullableInt32(moveIndex),
            SBFinishCaptureJSONStringForNullableInt32(moveCode)];
    }
    [raw appendString:@"]}"];
    return raw;
}

static NSDictionary *SBFinishCaptureBodyFromReq(void *req) {
    if (!req) {
        return @{};
    }

    void *movesArray = *(void **)((uint8_t *)req + SBFinishCaptureReqMoveSelectionsOffset);
    return @{
        @"$type": @"FinishMainStoryBattleReq",
        @"ExpectedResult": @(*(int32_t *)((uint8_t *)req + SBFinishCaptureReqExpectedResultOffset)),
        @"ExpectedAScore": @(*(int32_t *)((uint8_t *)req + SBFinishCaptureReqExpectedAScoreOffset)),
        @"ExpectedBScore": @(*(int32_t *)((uint8_t *)req + SBFinishCaptureReqExpectedBScoreOffset)),
        @"MoveSelections": SBFinishCaptureMoveSelectionsFromArray(movesArray)
    };
}

static void SBFinishCaptureStoreReq(void *stageContext, void *battle, const void *methodInfo, void *req) {
    if (!req) {
        return;
    }

    void *movesArray = *(void **)((uint8_t *)req + SBFinishCaptureReqMoveSelectionsOffset);
    NSDictionary *body = SBFinishCaptureBodyFromReq(req);
    NSString *raw = SBFinishCaptureRawBodyFromReq(req);
    NSArray *serializedMoves = [body[@"MoveSelections"] isKindOfClass:NSArray.class] ? body[@"MoveSelections"] : @[];
    int32_t moveSelectionsCount = SBFinishCaptureArrayCount(movesArray, INT32_MAX);
    int32_t nullMoveSelectionsCount = SBFinishCaptureNullMoveSelectionCount(movesArray);
    NSDictionary *snapshot = @{
        @"captured": @YES,
        @"time": SBFinishCaptureTimestamp(),
        @"path": @"/v1/Battle/FinishMainStoryBattle",
        @"method": @"POST",
        @"requestBody": body,
        @"rawBody": raw ?: @"",
        @"moveSelectionsCount": @(moveSelectionsCount),
        @"serializedMoveSelectionsCount": @((int32_t)serializedMoves.count),
        @"nullMoveSelectionsCount": @(nullMoveSelectionsCount),
        @"moveSelectionsComplete": @(nullMoveSelectionsCount == 0 &&
                                     serializedMoves.count == (NSUInteger)moveSelectionsCount),
        @"request": [NSString stringWithFormat:@"0x%llx", (unsigned long long)(uintptr_t)req],
        @"battle": [NSString stringWithFormat:@"0x%llx", (unsigned long long)(uintptr_t)battle],
        @"stageContext": [NSString stringWithFormat:@"0x%llx", (unsigned long long)(uintptr_t)stageContext],
        @"methodInfo": [NSString stringWithFormat:@"0x%llx", (unsigned long long)(uintptr_t)methodInfo],
        @"createFinishReqRVA": @"0x1FF4924"
    };

    @synchronized (SBFinishCaptureLock()) {
        NSMutableDictionary *state = SBFinishCaptureState();
        [state removeAllObjects];
        [state addEntriesFromDictionary:snapshot];
    }
}

static void *SBFinishCaptureReplacementCreateFinishReq(void *stageContext, void *battle, const void *methodInfo) {
    void *req = NULL;
    if (SBFinishCaptureOrigCreateFinishReq) {
        req = SBFinishCaptureOrigCreateFinishReq(stageContext, battle, methodInfo);
    }
    SBFinishCaptureStoreReq(stageContext, battle, methodInfo, req);
    return req;
}

NSDictionary *SBFinishRequestCaptureInstall(void) {
    if (atomic_load(&SBFinishCaptureInstalled)) {
        return SBFinishRequestCaptureSnapshot();
    }

    atomic_store(&SBFinishCaptureInstallAttempted, true);
    uintptr_t unityBase = SBFinishCaptureFindUnityBase();
    SBFinishCaptureUnityBase = unityBase;
    if (!unityBase) {
        strlcpy(SBFinishCaptureInstallError, "UnityFramework image not found", sizeof(SBFinishCaptureInstallError));
        return SBFinishRequestCaptureSnapshot();
    }

    uintptr_t target = unityBase + SBFinishCaptureCreateFinishMainStoryBattleReqRVA;
    SBFinishCaptureHookAddress = target;
    MSHookFunction((void *)target,
                   (void *)SBFinishCaptureReplacementCreateFinishReq,
                   (void **)&SBFinishCaptureOrigCreateFinishReq);
    if (!SBFinishCaptureOrigCreateFinishReq) {
        strlcpy(SBFinishCaptureInstallError, "MSHookFunction did not return original function", sizeof(SBFinishCaptureInstallError));
        return SBFinishRequestCaptureSnapshot();
    }

    SBFinishCaptureInstallError[0] = '\0';
    atomic_store(&SBFinishCaptureInstalled, true);
    return SBFinishRequestCaptureSnapshot();
}

NSDictionary *SBFinishRequestCaptureSnapshot(void) {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    snapshot[@"ok"] = @(atomic_load(&SBFinishCaptureInstalled));
    snapshot[@"installed"] = @(atomic_load(&SBFinishCaptureInstalled));
    snapshot[@"installAttempted"] = @(atomic_load(&SBFinishCaptureInstallAttempted));
    snapshot[@"unityBase"] = [NSString stringWithFormat:@"0x%llx", (unsigned long long)SBFinishCaptureUnityBase];
    snapshot[@"hookAddress"] = [NSString stringWithFormat:@"0x%llx", (unsigned long long)SBFinishCaptureHookAddress];
    snapshot[@"createFinishReqRVA"] = @"0x1FF4924";
    snapshot[@"error"] = [NSString stringWithUTF8String:SBFinishCaptureInstallError] ?: @"";

    @synchronized (SBFinishCaptureLock()) {
        NSDictionary *state = [SBFinishCaptureState() copy];
        snapshot[@"captured"] = @([state[@"captured"] boolValue]);
        if (state.count > 0) {
            snapshot[@"last"] = state;
            snapshot[@"requestBody"] = state[@"requestBody"] ?: @{};
            snapshot[@"rawBody"] = state[@"rawBody"] ?: @"";
            snapshot[@"path"] = state[@"path"] ?: @"/v1/Battle/FinishMainStoryBattle";
            snapshot[@"method"] = state[@"method"] ?: @"POST";
            snapshot[@"moveSelectionsCount"] = state[@"moveSelectionsCount"] ?: @0;
            snapshot[@"serializedMoveSelectionsCount"] = state[@"serializedMoveSelectionsCount"] ?: @0;
            snapshot[@"nullMoveSelectionsCount"] = state[@"nullMoveSelectionsCount"] ?: @0;
            snapshot[@"moveSelectionsComplete"] = state[@"moveSelectionsComplete"] ?: @NO;
        } else {
            snapshot[@"last"] = @{};
            snapshot[@"requestBody"] = @{};
            snapshot[@"rawBody"] = @"";
            snapshot[@"path"] = @"/v1/Battle/FinishMainStoryBattle";
            snapshot[@"method"] = @"POST";
            snapshot[@"moveSelectionsCount"] = @0;
            snapshot[@"serializedMoveSelectionsCount"] = @0;
            snapshot[@"nullMoveSelectionsCount"] = @0;
            snapshot[@"moveSelectionsComplete"] = @NO;
        }
    }
    return snapshot;
}

NSDictionary *SBFinishRequestCaptureClear(void) {
    @synchronized (SBFinishCaptureLock()) {
        [SBFinishCaptureState() removeAllObjects];
    }
    NSMutableDictionary *snapshot = [SBFinishRequestCaptureSnapshot() mutableCopy];
    snapshot[@"cleared"] = @YES;
    return snapshot;
}
