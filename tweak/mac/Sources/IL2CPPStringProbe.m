#import "IL2CPPStringProbe.h"

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#if __has_include(<ptrauth.h>)
#include <ptrauth.h>
#endif

typedef void (*SBIl2CppMethodPointer)(void);
typedef struct SBIl2CppClass SBIl2CppClass;
typedef struct SBMethodInfo SBMethodInfo;

typedef struct SBVirtualInvokeData {
    SBIl2CppMethodPointer methodPtr;
    const SBMethodInfo *method;
} SBVirtualInvokeData;

typedef struct SBIl2CppType {
    void *data;
    uint32_t bits;
} SBIl2CppType;

typedef void (*SBInvokerMethod)(SBIl2CppMethodPointer methodPointer,
                                const SBMethodInfo *method,
                                void *obj,
                                void **params,
                                void *ret);

struct SBMethodInfo {
    SBIl2CppMethodPointer methodPointer;
    SBIl2CppMethodPointer virtualMethodPointer;
    SBInvokerMethod invokerMethod;
    const char *name;
    SBIl2CppClass *klass;
    const SBIl2CppType *returnType;
    const SBIl2CppType **parameters;
    const void *rgctxDataOrMetadataHandle;
    const void *genericMethodOrContainerHandle;
    uint32_t token;
    uint16_t flags;
    uint16_t iflags;
    uint16_t slot;
    uint8_t parametersCount;
    uint8_t bitflags;
};

typedef struct SBIl2CppClass1 {
    void *image;
    void *gcDesc;
    const char *name;
    const char *namespaze;
    SBIl2CppType byvalArg;
    SBIl2CppType thisArg;
    SBIl2CppClass *elementClass;
    SBIl2CppClass *castClass;
    SBIl2CppClass *declaringType;
    SBIl2CppClass *parent;
    void *genericClass;
    void *typeMetadataHandle;
    void *interopData;
    SBIl2CppClass *klass;
    void *fields;
    void *events;
    void *properties;
    void *methods;
    SBIl2CppClass **nestedTypes;
    SBIl2CppClass **implementedInterfaces;
    void *interfaceOffsets;
} SBIl2CppClass1;

typedef struct SBIl2CppClass2 {
    SBIl2CppClass **typeHierarchy;
    void *unityUserData;
    uint32_t initializationExceptionGCHandle;
    uint32_t cctorStarted;
    uint32_t cctorFinished;
    size_t cctorThread;
    void *genericContainerHandle;
    uint32_t instanceSize;
    uint32_t actualSize;
    uint32_t elementSize;
    int32_t nativeSize;
    uint32_t staticFieldsSize;
    uint32_t threadStaticFieldsSize;
    int32_t threadStaticFieldsOffset;
    uint32_t flags;
    uint32_t token;
    uint16_t methodCount;
    uint16_t propertyCount;
    uint16_t fieldCount;
    uint16_t eventCount;
    uint16_t nestedTypeCount;
    uint16_t vtableCount;
    uint16_t interfacesCount;
    uint16_t interfaceOffsetsCount;
    uint8_t typeHierarchyDepth;
    uint8_t genericRecursionDepth;
    uint8_t rank;
    uint8_t minimumAlignment;
    uint8_t naturalAlignment;
    uint8_t packingSize;
    uint8_t bitflags1;
    uint8_t bitflags2;
} SBIl2CppClass2;

struct SBIl2CppClass {
    SBIl2CppClass1 class1;
    void *staticFields;
    void *rgctxData;
    SBIl2CppClass2 class2;
    SBVirtualInvokeData vtable[255];
};

typedef struct SBIl2CppStringFields {
    int32_t length;
    uint16_t firstChar;
} SBIl2CppStringFields;

typedef struct SBIl2CppString {
    SBIl2CppClass *klass;
    void *monitor;
    SBIl2CppStringFields fields;
} SBIl2CppString;

typedef struct SBByReferenceChar {
    intptr_t value;
} SBByReferenceChar;

typedef struct SBReadOnlySpanChar {
    SBByReferenceChar pointer;
    int32_t length;
} SBReadOnlySpanChar;

typedef void *(*SBIl2CppDomainGetFn)(void);
typedef void *(*SBIl2CppThreadAttachFn)(void *domain);
typedef SBIl2CppString *(*SBStringCtorUtf16Fn)(const uint16_t *ptr,
                                               int32_t startIndex,
                                               int32_t length,
                                               const SBMethodInfo *method);
typedef bool (*SBStringIsNullOrEmptyFn)(SBIl2CppString *value,
                                        const SBMethodInfo *method);
typedef SBIl2CppString *(*SBStringToStringFn)(SBIl2CppString *self,
                                              const SBMethodInfo *method);
typedef int32_t (*SBStringGetHashCodeFn)(SBIl2CppString *self,
                                         const SBMethodInfo *method);
typedef bool (*SBStringEqualsObjectFn)(SBIl2CppString *self,
                                       void *other,
                                       const SBMethodInfo *method);

static const uintptr_t SBStringCtorUtf16DumpRVA = 0x655B868;
static const uintptr_t SBStringCtorUtf16StartRVA = 0x655B868;
static const uintptr_t SBMethodStringCtorUtf16SlotRVA = 0x9BA22C8;
static const uintptr_t SBStringIsNullOrEmptyRVA = 0x655C334;

enum {
    SBStringVTableEqualsObject = 0,
    SBStringVTableGetHashCode = 2,
    SBStringVTableToString = 3
};

static atomic_bool SBStringProbeStarted = false;
static atomic_bool SBStringProbeFinished = false;
static atomic_int SBStringProbeLastLoggedAttempt = 0;

static NSString *SBProbeTimestamp(void) {
    return [[NSDate date] descriptionWithLocale:nil];
}

static NSString *SBProbeParentPath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    NSString *parent = [base stringByAppendingPathComponent:@"SoccerAppBypassLogs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:parent
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return parent;
}

static NSString *SBProbeLogRootPath(void) {
    NSString *parent = SBProbeParentPath();
    NSString *latest = [parent stringByAppendingPathComponent:@"latest"];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *destination = [fm destinationOfSymbolicLinkAtPath:latest error:nil];
    if (destination.length > 0) {
        if (![destination hasPrefix:@"/"]) {
            destination = [parent stringByAppendingPathComponent:destination];
        }
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:destination isDirectory:&isDir] && isDir) {
            return destination;
        }
    }

    BOOL isDir = NO;
    if ([fm fileExistsAtPath:latest isDirectory:&isDir] && isDir) {
        return latest;
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *session = [NSString stringWithFormat:@"%@-pid%d",
                         [formatter stringFromDate:[NSDate date]], getpid()];
    NSString *root = [parent stringByAppendingPathComponent:session];
    [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:latest error:nil];
    [fm createSymbolicLinkAtPath:latest withDestinationPath:root error:nil];
    return root;
}

static void SBProbeAppendIndexLine(NSString *event, NSString *detail) {
    NSString *path = [SBProbeLogRootPath() stringByAppendingPathComponent:@"index.tsv"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createFileAtPath:path
                    contents:[@"id\ttime\tevent\tsource\tmethod\turl\trequest_file\tresponse_file\terror\n"
                              dataUsingEncoding:NSUTF8StringEncoding]
                  attributes:nil];
    }

    NSString *line = [NSString stringWithFormat:@"000000\t%@\t%@\tIL2CPPStringProbe\t\t%@\t\t\t\n",
                      SBProbeTimestamp(),
                      event ?: @"string-probe",
                      detail ?: @""];
    NSData *bytes = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:bytes];
    [handle closeFile];
}

static NSString *SBProbeCommandPath(void) {
    return [SBProbeParentPath() stringByAppendingPathComponent:@"string-probe-command.json"];
}

static NSDictionary *SBProbeReadCommand(void) {
    NSData *data = [NSData dataWithContentsOfFile:SBProbeCommandPath()];
    if (!data.length) {
        return @{};
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : @{};
}

static NSString *SBProbeStringOption(NSDictionary *command, NSString *key, NSString *fallback) {
    id value = command[key];
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    return fallback;
}

static int32_t SBProbeIntOption(NSDictionary *command, NSString *key, int32_t fallback) {
    id value = command[key];
    if ([value respondsToSelector:@selector(intValue)]) {
        return [value intValue];
    }
    return fallback;
}

static uintptr_t SBProbeFindImageBase(const char *needle) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, needle)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

static void *SBProbeFunctionAtRVA(uintptr_t imageBase, uintptr_t rva) {
    if (!imageBase || !rva) {
        return NULL;
    }

    void *ptr = (void *)(imageBase + rva);
#if __has_feature(ptrauth_calls)
    ptr = ptrauth_sign_unauthenticated(ptr, ptrauth_key_function_pointer, 0);
#endif
    return ptr;
}

static void *SBProbeSignCallablePointer(void *ptr) {
    if (!ptr) {
        return NULL;
    }
#if __has_feature(ptrauth_calls)
    ptr = ptrauth_strip(ptr, ptrauth_key_function_pointer);
    ptr = ptrauth_sign_unauthenticated(ptr, ptrauth_key_function_pointer, 0);
#endif
    return ptr;
}

static NSString *SBProbePointerString(const void *ptr) {
    return [NSString stringWithFormat:@"0x%llx", (unsigned long long)(uintptr_t)ptr];
}

static const SBMethodInfo *SBProbeMethodInfoFromSlot(uintptr_t imageBase, uintptr_t slotRVA) {
    if (!imageBase || !slotRVA) {
        return NULL;
    }

    void **slot = (void **)(imageBase + slotRVA);
    return slot ? (const SBMethodInfo *)(*slot) : NULL;
}

static NSString *SBProbeMethodInfoName(const SBMethodInfo *method) {
    if (!method || !method->name) {
        return @"";
    }
    return [NSString stringWithUTF8String:method->name] ?: @"";
}

static NSString *SBProbeClassName(SBIl2CppClass *klass) {
    if (!klass || !klass->class1.name) {
        return @"";
    }

    NSString *name = [NSString stringWithUTF8String:klass->class1.name] ?: @"";
    if (klass->class1.namespaze && klass->class1.namespaze[0]) {
        NSString *namespaze = [NSString stringWithUTF8String:klass->class1.namespaze] ?: @"";
        return [NSString stringWithFormat:@"%@.%@", namespaze, name];
    }
    return name;
}

static void *SBProbeResolveSymbol(const char *symbol) {
    void *value = dlsym(RTLD_DEFAULT, symbol);
    if (value) {
        return value;
    }

    void *handle = dlopen(NULL, RTLD_NOW);
    return handle ? dlsym(handle, symbol) : NULL;
}

static NSString *SBProbeNSStringFromIl2CppString(SBIl2CppString *string) {
    if (!string || string->fields.length < 0 || string->fields.length > 1024 * 1024) {
        return nil;
    }

    const unichar *chars = (const unichar *)&string->fields.firstChar;
    return [[NSString alloc] initWithCharacters:chars length:(NSUInteger)string->fields.length];
}

static SBIl2CppString *SBProbeCreateIL2CPPString(SBStringCtorUtf16Fn ctor,
                                                 const SBMethodInfo *method,
                                                 NSString *value,
                                                 NSMutableData **storage) {
    if (!ctor || !storage) {
        return NULL;
    }

    NSUInteger length = value.length;
    if (length > INT32_MAX) {
        return NULL;
    }

    NSMutableData *buffer = [NSMutableData dataWithLength:(length + 1) * sizeof(uint16_t)];
    if (length > 0) {
        [value getCharacters:(unichar *)buffer.mutableBytes range:NSMakeRange(0, length)];
    }

    *storage = buffer;
    return ctor((const uint16_t *)buffer.bytes, 0, (int32_t)length, method);
}

static SBReadOnlySpanChar SBProbeSpanFromNSString(NSString *value, NSMutableData **storage) {
    SBReadOnlySpanChar span = {0};
    NSUInteger length = value.length;
    if (length > INT32_MAX || !storage) {
        return span;
    }

    NSMutableData *buffer = [NSMutableData dataWithLength:length * sizeof(unichar)];
    if (length > 0) {
        [value getCharacters:(unichar *)buffer.mutableBytes range:NSMakeRange(0, length)];
    }
    *storage = buffer;
    span.pointer.value = (intptr_t)buffer.mutableBytes;
    span.length = (int32_t)length;
    return span;
}

static BOOL SBProbeWriteJSON(NSDictionary *result) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:result
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:nil];
    if (!json) {
        return NO;
    }

    NSString *path = [SBProbeLogRootPath() stringByAppendingPathComponent:@"string-probe.json"];
    return [json writeToFile:path atomically:YES];
}

BOOL SBIL2CPPRunReadyProbe(NSDictionary *__autoreleasing _Nullable *_Nullable detailsOut) {
    @autoreleasepool {
        uintptr_t unityBase = SBProbeFindImageBase("/UnityFramework.framework/UnityFramework");
        if (!unityBase) {
            unityBase = SBProbeFindImageBase("UnityFramework");
        }

        SBStringIsNullOrEmptyFn isNullOrEmpty =
            (SBStringIsNullOrEmptyFn)SBProbeFunctionAtRVA(unityBase, SBStringIsNullOrEmptyRVA);

        BOOL ok = NO;
        BOOL result = NO;
        if (isNullOrEmpty) {
            result = isNullOrEmpty(NULL, NULL);
            ok = result;
        }

        NSMutableDictionary *details = [NSMutableDictionary dictionary];
        details[@"unityBase"] = [NSString stringWithFormat:@"0x%llx", (unsigned long long)unityBase];
        details[@"method"] = @"System.String.IsNullOrEmpty";
        details[@"methodRVA"] = @"0x655C334";
        details[@"function"] = SBProbePointerString((void *)isNullOrEmpty);
        details[@"argument"] = @"null";
        details[@"result"] = @(result);
        details[@"ok"] = @(ok);
        if (detailsOut) {
            *detailsOut = details;
        }
        return ok;
    }
}

NSString *SBIL2CPPCreateManagedStringRoundTrip(NSString *value,
                                               NSDictionary *__autoreleasing _Nullable *_Nullable detailsOut) {
    @autoreleasepool {
        NSString *source = value ?: @"";
        uintptr_t unityBase = SBProbeFindImageBase("/UnityFramework.framework/UnityFramework");
        if (!unityBase) {
            unityBase = SBProbeFindImageBase("UnityFramework");
        }

        SBStringCtorUtf16Fn ctorUtf16 =
            (SBStringCtorUtf16Fn)SBProbeFunctionAtRVA(unityBase, SBStringCtorUtf16StartRVA);
        const SBMethodInfo *ctorUtf16Method =
            SBProbeMethodInfoFromSlot(unityBase, SBMethodStringCtorUtf16SlotRVA);

        NSMutableDictionary *details = [NSMutableDictionary dictionary];
        details[@"unityBase"] = [NSString stringWithFormat:@"0x%llx", (unsigned long long)unityBase];
        details[@"ctorStartRVA"] = @"0x655B868";
        details[@"ctorDumpRVA"] = @"0x655B868";
        details[@"methodSlotRVA"] = @"0x9BA22C8";
        details[@"ctor"] = SBProbePointerString((void *)ctorUtf16);
        details[@"methodInfo"] = SBProbePointerString(ctorUtf16Method);
        details[@"methodName"] = @"";

        NSString *roundTrip = nil;
        SBIl2CppString *managed = NULL;
        if (ctorUtf16 && ctorUtf16Method) {
            NSMutableData *storage = nil;
            managed = SBProbeCreateIL2CPPString(ctorUtf16, ctorUtf16Method, source, &storage);
            roundTrip = SBProbeNSStringFromIl2CppString(managed);
        }

        details[@"managedString"] = SBProbePointerString(managed);
        details[@"roundTrip"] = roundTrip ?: @"";
        details[@"ok"] = @([roundTrip isEqualToString:source]);
        if (detailsOut) {
            *detailsOut = details;
        }
        return roundTrip;
    }
}

static BOOL SBTryRunIL2CPPStringProbe(int attempt, BOOL finalAttempt) {
    @autoreleasepool {
        if (atomic_load(&SBStringProbeFinished)) {
            return YES;
        }

        uintptr_t unityBase = SBProbeFindImageBase("/UnityFramework.framework/UnityFramework");
        if (!unityBase) {
            unityBase = SBProbeFindImageBase("UnityFramework");
        }
        if (!unityBase) {
            if (finalAttempt) {
                SBProbeAppendIndexLine(@"string-probe-failed", @"UnityFramework image not loaded");
            }
            return NO;
        }

        SBIl2CppDomainGetFn domainGet = (SBIl2CppDomainGetFn)SBProbeResolveSymbol("il2cpp_domain_get");
        SBIl2CppThreadAttachFn threadAttach = (SBIl2CppThreadAttachFn)SBProbeResolveSymbol("il2cpp_thread_attach");

        if (domainGet && threadAttach) {
            void *domain = domainGet();
            if (domain) {
                threadAttach(domain);
            }
        }

        SBStringCtorUtf16Fn ctorUtf16 =
            (SBStringCtorUtf16Fn)SBProbeFunctionAtRVA(unityBase, SBStringCtorUtf16StartRVA);
        const SBMethodInfo *ctorUtf16Method =
            SBProbeMethodInfoFromSlot(unityBase, SBMethodStringCtorUtf16SlotRVA);

        if (!ctorUtf16 || !ctorUtf16Method) {
            if (finalAttempt) {
                SBProbeAppendIndexLine(@"string-probe-failed",
                                       [NSString stringWithFormat:@"missing call targets base=0x%llx ctor=%d method=%@",
                                        (unsigned long long)unityBase,
                                        ctorUtf16 != NULL,
                                        SBProbePointerString(ctorUtf16Method)]);
            }
            return NO;
        }

        NSDictionary *command = SBProbeReadCommand();
        NSString *leftText = SBProbeStringOption(command, @"left", @"soccer");
        NSString *rightText = SBProbeStringOption(command, @"right", @"-probe");
        NSString *needleText = SBProbeStringOption(command, @"needle", @"pro");
        int32_t substringStart = SBProbeIntOption(command, @"substringStart", 0);
        int32_t substringLength = SBProbeIntOption(command, @"substringLength", 6);

        NSString *joinedSource = [leftText stringByAppendingString:rightText ?: @""];
        NSUInteger safeStart = substringStart < 0 ? 0 : (NSUInteger)substringStart;
        if (safeStart > joinedSource.length) {
            safeStart = joinedSource.length;
        }
        NSUInteger safeLength = substringLength < 0 ? 0 : (NSUInteger)substringLength;
        if (safeStart + safeLength > joinedSource.length) {
            safeLength = joinedSource.length - safeStart;
        }
        NSString *sliceSource = [joinedSource substringWithRange:NSMakeRange(safeStart, safeLength)];

        SBProbeAppendIndexLine(@"string-probe-call-start",
                               [NSString stringWithFormat:@"ctorStart=0x%llx ctorDump=0x%llx methodSlot=0x%llx method=%@ name=%@",
                                (unsigned long long)SBStringCtorUtf16StartRVA,
                                (unsigned long long)SBStringCtorUtf16DumpRVA,
                                (unsigned long long)SBMethodStringCtorUtf16SlotRVA,
                                SBProbePointerString(ctorUtf16Method),
                                SBProbeMethodInfoName(ctorUtf16Method)]);

        NSMutableData *leftStorage = nil;
        NSMutableData *rightStorage = nil;
        NSMutableData *joinedStorage = nil;
        SBIl2CppString *leftString = SBProbeCreateIL2CPPString(ctorUtf16,
                                                               ctorUtf16Method,
                                                               leftText,
                                                               &leftStorage);
        SBIl2CppString *rightString = SBProbeCreateIL2CPPString(ctorUtf16,
                                                                ctorUtf16Method,
                                                                rightText,
                                                                &rightStorage);
        SBIl2CppString *joinedString = SBProbeCreateIL2CPPString(ctorUtf16,
                                                                 ctorUtf16Method,
                                                                 joinedSource,
                                                                 &joinedStorage);

        NSString *leftRoundTrip = SBProbeNSStringFromIl2CppString(leftString) ?: @"";
        NSString *rightRoundTrip = SBProbeNSStringFromIl2CppString(rightString) ?: @"";
        NSString *joinedRoundTrip = SBProbeNSStringFromIl2CppString(joinedString) ?: @"";

        SBVirtualInvokeData toStringInvoke = {0};
        SBVirtualInvokeData hashInvoke = {0};
        SBVirtualInvokeData equalsObjectInvoke = {0};
        bool hasStringClass = joinedString && joinedString->klass;
        if (hasStringClass) {
            toStringInvoke = joinedString->klass->vtable[SBStringVTableToString];
            hashInvoke = joinedString->klass->vtable[SBStringVTableGetHashCode];
            equalsObjectInvoke = joinedString->klass->vtable[SBStringVTableEqualsObject];
        }

        SBStringToStringFn toStringFn =
            (SBStringToStringFn)SBProbeSignCallablePointer((void *)toStringInvoke.methodPtr);
        SBStringGetHashCodeFn hashFn =
            (SBStringGetHashCodeFn)SBProbeSignCallablePointer((void *)hashInvoke.methodPtr);
        SBStringEqualsObjectFn equalsObjectFn =
            (SBStringEqualsObjectFn)SBProbeSignCallablePointer((void *)equalsObjectInvoke.methodPtr);

        SBIl2CppString *toStringResult = toStringFn ? toStringFn(joinedString, toStringInvoke.method) : NULL;
        int32_t joinedHash = hashFn ? hashFn(joinedString, hashInvoke.method) : 0;
        bool equalsSelf = equalsObjectFn ? equalsObjectFn(joinedString, joinedString, equalsObjectInvoke.method) : false;
        bool equalsLeft = equalsObjectFn ? equalsObjectFn(joinedString, leftString, equalsObjectInvoke.method) : false;
        NSString *toStringRoundTrip = SBProbeNSStringFromIl2CppString(toStringResult) ?: @"";

        BOOL constructedOK = leftString && rightString && joinedString &&
            [leftRoundTrip isEqualToString:leftText ?: @""] &&
            [rightRoundTrip isEqualToString:rightText ?: @""] &&
            [joinedRoundTrip isEqualToString:joinedSource ?: @""];
        BOOL memberCallOK = toStringResult &&
            [toStringRoundTrip isEqualToString:joinedSource ?: @""] &&
            equalsSelf &&
            !equalsLeft;

        NSDictionary *result = @{
            @"attempt": @(attempt),
            @"unityBase": [NSString stringWithFormat:@"0x%llx", (unsigned long long)unityBase],
            @"runtimeApi": @{
                @"il2cpp_domain_get": @(domainGet != NULL),
                @"il2cpp_thread_attach": @(threadAttach != NULL)
            },
            @"targets": @{
                @"String.Ctor(char*,int,int)": @{
                    @"dumpRVA": @"0x655B868",
                    @"functionStartRVA": @"0x655B868",
                    @"methodSlotRVA": @"0x9BA22C8",
                    @"methodInfo": SBProbePointerString(ctorUtf16Method),
                    @"methodPointer": SBProbePointerString((void *)ctorUtf16Method->methodPointer),
                    @"invoker": SBProbePointerString((void *)ctorUtf16Method->invokerMethod),
                    @"name": SBProbeMethodInfoName(ctorUtf16Method)
                }
            },
            @"input": @{
                @"left": leftText,
                @"right": rightText,
                @"needle": needleText,
                @"substringStart": @(substringStart),
                @"substringLength": @(substringLength)
            },
            @"output": @{
                @"constructed": @{
                    @"left": leftRoundTrip,
                    @"right": rightRoundTrip,
                    @"joined": joinedRoundTrip,
                    @"leftPtr": SBProbePointerString(leftString),
                    @"rightPtr": SBProbePointerString(rightString),
                    @"joinedPtr": SBProbePointerString(joinedString),
                    @"constructedOK": @(constructedOK)
                },
                @"memberCalls": @{
                    @"class": hasStringClass ? SBProbeClassName(joinedString->klass) : @"",
                    @"vtableCount": hasStringClass ? @(joinedString->klass->class2.vtableCount) : @(0),
                    @"toStringPtr": SBProbePointerString((void *)toStringInvoke.methodPtr),
                    @"toStringMethod": SBProbePointerString(toStringInvoke.method),
                    @"toString": toStringRoundTrip,
                    @"toStringReturnsSelf": @(toStringResult == joinedString),
                    @"getHashCodePtr": SBProbePointerString((void *)hashInvoke.methodPtr),
                    @"hash": @(joinedHash),
                    @"equalsObjectPtr": SBProbePointerString((void *)equalsObjectInvoke.methodPtr),
                    @"equalsSelf": @(equalsSelf),
                    @"equalsLeft": @(equalsLeft),
                    @"memberCallOK": @(memberCallOK)
                },
                @"expectedByObjC": @{
                    @"concat": joinedSource,
                    @"substring": sliceSource,
                    @"containsNeedle": @([joinedSource containsString:needleText ?: @""])
                }
            }
        };

        SBProbeWriteJSON(result);
        if (constructedOK && memberCallOK) {
            SBProbeAppendIndexLine(@"string-probe-ok",
                                   [NSString stringWithFormat:@"constructed=%@ toString=%@ hash=%d equalsSelf=%d equalsLeft=%d",
                                    joinedRoundTrip,
                                    toStringRoundTrip,
                                    joinedHash,
                                    equalsSelf,
                                    equalsLeft]);
            atomic_store(&SBStringProbeFinished, true);
            return YES;
        }

        if (finalAttempt) {
            SBProbeAppendIndexLine(@"string-probe-failed",
                                   [NSString stringWithFormat:@"constructedOK=%d memberCallOK=%d left=%@ right=%@ joined=%@ toString=%@",
                                    constructedOK,
                                    memberCallOK,
                                    leftRoundTrip,
                                    rightRoundTrip,
                                    joinedRoundTrip,
                                    toStringRoundTrip]);
        }
        return NO;
    }
}

void SBStartIL2CPPStringProbe(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&SBStringProbeStarted, &expected, true)) {
        return;
    }

    SBProbeAppendIndexLine(@"string-probe-start", @"scheduled IL2CPP System.String probe");

    for (int attempt = 1; attempt <= 120; attempt++) {
        int64_t delay = (int64_t)(attempt + 8) * NSEC_PER_SEC;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
            if (atomic_load(&SBStringProbeFinished)) {
                return;
            }

            BOOL finalAttempt = attempt == 120;
            if (!SBTryRunIL2CPPStringProbe(attempt, finalAttempt) &&
                (attempt == 1 || attempt % 10 == 0) &&
                atomic_exchange(&SBStringProbeLastLoggedAttempt, attempt) != attempt) {
                SBProbeAppendIndexLine(@"string-probe-wait",
                                       [NSString stringWithFormat:@"attempt=%d waiting for Unity/IL2CPP", attempt]);
            }
        });
    }
}
