#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioUnit/AudioUnit.h>

#import "SoccerAppBypass.h"

#ifndef SB_MACVER
#define SB_MACVER 0
#endif

#ifndef SB_CONTROL_PORT
#define SB_CONTROL_PORT 19876
#endif

#define SB_ENABLE_LOW_LEVEL_BYPASS 0
#ifndef SB_EMBEDDED_SHELL
#define SB_EMBEDDED_SHELL 0
#endif
#define SB_ENABLE_METADATA_DUMP 0
#define SB_ENABLE_FOUNDATION_NETWORK_LOG 0
#define SB_ENABLE_KEYCHAIN_AUTH_DUMP 0
#define SB_ENABLE_OBJC_BYPASS 0
#define SB_ENABLE_ACE_ALERT_BYPASS 0
#define SB_ENABLE_UNITY_ANOSDK_INIT_BYPASS 1
#define SB_ENABLE_MAC_LIFECYCLE_GUARD 1
#define SB_ENABLE_MAC_KEEPALIVE_GUARD 1
#define SB_ENABLE_MAC_SELF_KILL_GUARD 1
#define SB_ENABLE_MAC_DIRECT_SYSCALL_GUARD 1
#define SB_ENABLE_MAC_AUDIO_MUTE 1
#define SB_ENABLE_ANORT_SELF_KILL_TERMINATOR_PATCH 1
#define SB_ENABLE_UNITY_RENDER_CRASH_GUARD 0
#define SB_ENABLE_UNITY_RENDER_ENCODER_GUARD 0
#define SB_ENABLE_UNITY_GFX_COMMAND_NOOP_GUARD 0
#define SB_ENABLE_UNITY_ASSERT_LOG_HOOK 1
#define SB_UNITY_GFX_COMMAND_NOOP_DELAY_SECONDS 20
#define SB_ENABLE_UI_ALERT_BYPASS 0
#define SB_ENABLE_ANOGS_ALERT_ONLY_HOOK 0
#define SB_ENABLE_ANOGS_HOOKS 0
#define SB_ENABLE_ANORT_OBJC_LOAD_BYPASS 0
#define SB_ENABLE_ANORT_VM_HOOK 1
#define SB_ENABLE_ANORT_VTABLE_HOOK 0
#define SB_ENABLE_ANORT_MAC_GATE_PRIME 0
#define SB_ENABLE_ANORT_MAC_GATE_WAIT_HOOK 1
#define SB_ENABLE_ANORT_MAC_GATE_WAIT_RET 0
#define SB_ENABLE_IL2CPP_STRING_PROBE 0
#define SB_ENABLE_LOCAL_CONTROL_SERVER 1
#define SB_ENABLE_EARLY_UNITYFRAMEWORK_DLOPEN 0

#if SB_MACVER || SB_ENABLE_ANOGS_HOOKS
#include "SBHookCompat.h"
#endif
#include <dlfcn.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libkern/OSCacheControl.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <limits.h>
#include <time.h>
#if __has_include(<ptrauth.h>)
#include <ptrauth.h>
#endif

#include "BypassShared.h"
#import "IL2CPPStringProbe.h"
#if SB_ENABLE_LOCAL_CONTROL_SERVER
#import "LocalControlServer.h"
#endif
#if SB_ENABLE_LOW_LEVEL_BYPASS || (SB_MACVER && SB_ENABLE_MAC_SELF_KILL_GUARD)
#include "fishhook.h"
#endif

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

static const uintptr_t SBAnogsRootCheckReportCachedOffset = 0xB0E0;
static const uintptr_t SBAnogsRootCheckCoreOffset = 0xB1C0;
static const uintptr_t SBAnogsJailbreakModuleScanOnceOffset = 0xB845C;
static const uintptr_t SBAnogsMaybeShowJailbreakAlertOffset = 0xB852C;
static const uintptr_t SBAnogsJailbreakRecordStateOffset = 0xB86A0;
static const uintptr_t SBAnogsShowJailbreakAlertOffset = 0xB858C;
static const uintptr_t SBAnogsIsRootCachedOffset = 0xF0B30;
static const uintptr_t SBAnogsJailbreakModuleVtableOffset = 0x153900;
static const uintptr_t SBAnogsJailbreakStateVtableOffset = 0x153940;
static const uintptr_t SBAnortThreadCheckRunOffset = 0x2A72C;
static const uintptr_t SBAnortThreadReportSamplerOffset = 0x2AA54;
static const uintptr_t SBAnortReportFlushOffset = 0x2F6F8;
static const uintptr_t SBAnortVMResultHandlerOffset = 0x2D258;
static const uintptr_t SBAnortVMMonitorRunOffset = 0x2DB4C;
static const uintptr_t SBAnortCheckEngineVtableOffset = 0x668B0;
static const uintptr_t SBAnortGateManagerGetterOffset = 0x46364;
static const uintptr_t SBAnortGateFirstProducerOffset = 0x4648C;
static const uintptr_t SBAnortGateSecondProducerOffset = 0x46648;
static const uintptr_t SBAnortGateFirstWaitOffset = 0x46698;
static const uintptr_t SBAnortGateSecondWaitOffset = 0x466F4;
static const uint32_t SBAnortGateFirstFallbackValue = 0xA176447A;
static const uintptr_t SBAnortObjCLoadOffset = 0x31CCC;
static const uintptr_t SBAnortIndirectSyscallSvcOffset = 0x2A34C;
static const uintptr_t SBAnortKillSelfTerminatorOffset = 0x404A0;
static const uintptr_t SBAnortKillSelfTerminatorAltOffset = 0x42A3C;
static const uintptr_t SBAnogsIndirectSyscallSvcOffsets[] = {
    0x11A24,
    0xA56C4, 0xA56FC, 0xA5754, 0xA57AC, 0xA580C, 0xA5864,
    0xA58BC, 0xA591C, 0xA5974, 0xA59D4, 0xA5A34, 0xA5A94,
    0xA5AF4, 0xA5B4C, 0xA5BA4, 0xA5C04, 0xA5C5C, 0xA5CB4,
    0xA5D0C, 0xA5D6C, 0xA5DCC, 0xA5E2C, 0xA5E8C, 0xA5EE4,
    0xA5F44, 0xA5FA4, 0xA6004, 0xA605C, 0xA60B4, 0xA6114,
    0xA616C, 0xA61C4, 0xA621C,
};
static const uintptr_t SBUnityAnoSdkSdkInitExOffset = 0x1F2E254;
static const uintptr_t SBUnityAnoSdkPInvokeInitExOffset = 0x1F2E28C;
static const uintptr_t SBUnityRenderCallbackListOffset = 0x5E8A08;
static const uintptr_t SBUnityRenderFenceOffset = 0x6C6FE8;
static const uintptr_t SBUnityRenderEncoderBeginOffset = 0xE36744;
static const uintptr_t SBUnityGfxCommandInterpreterOffset = 0xD35750;
static const uintptr_t SBUnityAssertLogOffset = 0xD0A510;

static atomic_bool SBAnogsHooksInstalled = false;
static atomic_bool SBAnogsAlertOnlyHookInstalled = false;
static atomic_bool SBAnogsScanSuppressedLogged = false;
static atomic_bool SBAnogsAlertSuppressedLogged = false;
static atomic_bool SBAnogsStateSuppressedLogged = false;
static atomic_bool SBAnortHookInstalled = false;
static atomic_bool SBAnortTextPatchInstalled = false;
static atomic_bool SBAnortMacGatePrimeScheduled = false;
static atomic_bool SBAnortMacGateWaitHookInstalled = false;
static atomic_bool SBAnortSuppressedLogged = false;
static atomic_bool SBAnortObjCLoadBypassInstalled = false;
static atomic_bool SBSoccerAppBypassInstalled = false;
static atomic_bool SBAceAlertHookInstalled = false;
static atomic_bool SBAceAlertSuppressedLogged = false;
static atomic_bool SBUnityAnoSdkInitBypassInstalled = false;
static atomic_bool SBMacLifecycleGuardInstalled = false;
static atomic_bool SBMacKeepaliveGuardInstalled = false;
static atomic_bool SBMacSelfKillGuardInstalled = false;
static atomic_bool SBMacAudioMuteInstalled = false;
static atomic_uint SBMacAudioMuteRenderCallbacks = 0;
static atomic_uint SBMacAudioMuteRenderBuffers = 0;
static atomic_bool SBMacDirectSyscallGuardAnortInstalled = false;
static atomic_bool SBMacDirectSyscallGuardAnogsInstalled = false;
static atomic_uint SBMacDirectSyscallTraceCount = 0;
static atomic_bool SBAnortSelfKillTerminatorPatchInstalled = false;
static atomic_bool SBUnityRenderCrashGuardInstalled = false;
static atomic_bool SBUnityRenderEncoderGuardInstalled = false;
static atomic_bool SBUnityGfxCommandNoopGuardInstalled = false;
static atomic_bool SBUnityGfxCommandNoopGuardScheduled = false;
static atomic_bool SBUnityAssertLogHookInstalled = false;
static atomic_bool SBUIAlertHooksInstalled = false;
static atomic_bool SBUIAlertSuppressedLogged = false;
static atomic_bool SBDyldImageCallbackRegistered = false;
static atomic_bool SBIndexPathCReady = false;
static atomic_bool SBEarlyUnityFrameworkDlopenAttempted = false;
#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static atomic_bool SBNetworkHooksInstalled = false;
#endif
static char SBIndexPathC[PATH_MAX];
static char SBEarlyUnityFrameworkDlopenPath[PATH_MAX];
static char SBEarlyUnityFrameworkDlopenError[512];
static void *SBEarlyUnityFrameworkDlopenHandle = NULL;
static id SBMacKeepaliveActivity = nil;
static atomic_ulong SBNextSelfKillIdent = 1;

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static const NSUInteger SBMaxLoggedBodyBytes = 8 * 1024 * 1024;
#endif
#if SB_ENABLE_METADATA_DUMP
static const uintptr_t SBUnityMetadataGlobalOffset = 0x9F4E068;
static atomic_bool SBMetadataDumped = false;
static atomic_bool SBMetadataRawDumped = false;
#endif
#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static atomic_ulong SBNextLogIdent = 1;
static char SBTaskIdentKey;
static char SBTaskDataKey;
static char SBTaskSourceKey;
#endif

static int (*orig_access)(const char *path, int mode);
static int (*orig_open)(const char *path, int oflag, ...);
static FILE *(*orig_fopen)(const char *path, const char *mode);
static DIR *(*orig_opendir)(const char *path);
static int (*orig_stat)(const char *path, struct stat *buf);
static int (*orig_lstat)(const char *path, struct stat *buf);
static ssize_t (*orig_readlink)(const char *path, char *buf, size_t bufsiz);
static char *(*orig_realpath)(const char *path, char *resolved_path);
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*orig_ptrace)(int request, pid_t pid, caddr_t addr, int data);
static pid_t (*orig_fork)(void);
static int (*orig_kill)(pid_t pid, int sig);
static int (*orig_killpg)(pid_t pgrp, int sig);
static int (*orig_raise)(int sig);
static int (*orig_pthread_kill)(pthread_t thread, int sig);
static void (*orig_abort)(void);
static void (*orig_exit)(int status);
static void (*orig__exit)(int status);
static int (*orig___kill)(pid_t pid, int sig);
static int (*orig___pthread_kill)(pthread_t thread, int sig);
static void (*orig___exit)(int status);
static void (*orig_abort_with_reason)(uint32_t reason_namespace, uint64_t reason_code, const char *reason_string, uint64_t reason_flags);
static void (*orig_abort_with_payload)(uint32_t reason_namespace, uint64_t reason_code, void *payload, uint32_t payload_size, const char *reason_string, uint64_t reason_flags);
static void (*orig___abort_with_payload)(uint32_t reason_namespace, uint64_t reason_code, void *payload, uint32_t payload_size, const char *reason_string, uint64_t reason_flags);
static void (*orig_terminate_with_reason)(uint32_t reason_namespace, uint64_t reason_code, const char *reason_string, uint64_t reason_flags);
static void (*orig_terminate_with_payload)(uint32_t reason_namespace, uint64_t reason_code, void *payload, uint32_t payload_size, const char *reason_string, uint64_t reason_flags);
static void (*orig___terminate_with_payload)(uint32_t reason_namespace, uint64_t reason_code, void *payload, uint32_t payload_size, const char *reason_string, uint64_t reason_flags);
static kern_return_t (*orig_task_terminate)(task_t target_task);
static long (*orig_syscall)(long number, ...);
static long (*orig___syscall)(long number, ...);
static OSStatus (*orig_AudioUnitSetProperty)(AudioUnit inUnit,
                                             AudioUnitPropertyID inID,
                                             AudioUnitScope inScope,
                                             AudioUnitElement inElement,
                                             const void *inData,
                                             UInt32 inDataSize);
static OSStatus (*orig_AudioUnitSetParameter)(AudioUnit inUnit,
                                              AudioUnitParameterID inID,
                                              AudioUnitScope inScope,
                                              AudioUnitElement inElement,
                                              AudioUnitParameterValue inValue,
                                              UInt32 inBufferOffsetInFrames);
static OSStatus (*orig_AudioUnitRender)(AudioUnit inUnit,
                                        AudioUnitRenderActionFlags *ioActionFlags,
                                        const AudioTimeStamp *inTimeStamp,
                                        UInt32 inOutputBusNumber,
                                        UInt32 inNumberFrames,
                                        AudioBufferList *ioData);
static OSStatus (*orig_AudioOutputUnitStart)(AudioUnit ci);
static OSStatus (*orig_AudioQueueSetParameter)(AudioQueueRef inAQ,
                                               AudioQueueParameterID inParamID,
                                               AudioQueueParameterValue inValue);
static OSStatus (*orig_AudioQueueStart)(AudioQueueRef inAQ,
                                        const AudioTimeStamp *inStartTime);
static char *(*orig_getenv)(const char *name);
static void *(*orig_dlopen)(const char *path, int mode);
static void *(*orig_dlsym)(void *handle, const char *symbol);
static uint32_t (*orig_dyld_image_count)(void);
static const char *(*orig_dyld_get_image_name)(uint32_t image_index);
static OSStatus (*orig_SecTrustEvaluate)(SecTrustRef trust, SecTrustResultType *result);
static bool (*orig_SecTrustEvaluateWithError)(SecTrustRef trust, CFErrorRef *error);
static int (*orig_anogs_root_check_report_cached)(int report);
static int (*orig_anogs_root_check_core)(char *reason, size_t reasonSize);
static int64_t (*orig_anogs_jailbreak_module_scan_once)(void *context);
static int64_t (*orig_anogs_maybe_show_jailbreak_alert)(void *context, const char *reason);
static int64_t (*orig_anogs_jailbreak_record_state)(void *context, const char *reason);
static int64_t (*orig_anogs_show_jailbreak_alert)(void);
static bool (*orig_anogs_is_root_cached)(void *context);
typedef void (*SBAceShowMessageBoxImp)(id self, SEL _cmd, id title, id message, id left, id right);
static SBAceShowMessageBoxImp orig_AceMsgBoxImp_ShowMessageBox;

static NSString *SBTimestamp(void);
static void SBAppendIndexLine(NSString *line);
static void SBRegisterDyldImageCallback(void);

static BOOL SBPathShouldHide(NSString *path) {
    return path.length > 0 && sb_is_sensitive_jb_path(path.fileSystemRepresentation);
}

static BOOL SBURLSchemeShouldHide(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    if (!scheme) {
        return NO;
    }

    static NSSet<NSString *> *schemes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        schemes = [NSSet setWithObjects:@"cydia", @"sileo", @"zbra", @"filza", @"activator",
                   @"undecimus", @"dopamine", @"palera1n", nil];
    });
    return [schemes containsObject:scheme];
}

static NSString *SBLogParentPath(void) {
    static NSString *parent;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *base = paths.firstObject ?: NSTemporaryDirectory();
        parent = [base stringByAppendingPathComponent:@"SoccerAppBypassLogs"];
        [[NSFileManager defaultManager] createDirectoryAtPath:parent
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    });
    return parent;
}

static NSString *SBLogRootPath(void) {
    static NSString *root;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        formatter.dateFormat = @"yyyyMMdd-HHmmss";

        NSString *sessionName = [NSString stringWithFormat:@"%@-pid%d",
                                 [formatter stringFromDate:[NSDate date]], getpid()];
        root = [SBLogParentPath() stringByAppendingPathComponent:sessionName];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *latest = [SBLogParentPath() stringByAppendingPathComponent:@"latest"];
        [fm removeItemAtPath:latest error:nil];
        [fm createSymbolicLinkAtPath:latest withDestinationPath:root error:nil];
    });
    return root;
}

#if SB_MACVER
static NSString *SBMacPluginStatusParentPath(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    NSString *appsPath = bundlePath.length > 0 ? bundlePath.stringByDeletingLastPathComponent : NSTemporaryDirectory();
    NSString *parent = [appsPath stringByAppendingPathComponent:@"srzq_plugin_status"];
    [[NSFileManager defaultManager] createDirectoryAtPath:parent
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return parent;
}
#endif

static void SBWriteMacPluginStatus(NSString *stage) {
#if SB_MACVER
    @try {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
        NSString *statusDir = [SBMacPluginStatusParentPath() stringByAppendingPathComponent:bundleID];
        NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"srzq_plugin_status" stringByAppendingPathComponent:bundleID]];
        NSArray<NSString *> *dirs = @[statusDir, tmpDir];
        NSMutableDictionary *status = [@{
            @"stage": stage ?: @"unknown",
            @"timestamp": SBTimestamp() ?: @"",
            @"pid": @(getpid()),
            @"bundleId": bundleID,
            @"bundlePath": NSBundle.mainBundle.bundlePath ?: @"",
            @"executablePath": NSBundle.mainBundle.executablePath ?: @"",
            @"controlURL": [NSString stringWithFormat:@"http://127.0.0.1:%d", SB_CONTROL_PORT],
            @"logRoot": SBLogRootPath() ?: @"",
            @"macver": @YES
        } mutableCopy];
        NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};
        status[@"appVersion"] = info[@"CFBundleShortVersionString"] ?: @"";
        status[@"appBuild"] = info[@"CFBundleVersion"] ?: @"";

        NSData *data = [NSJSONSerialization dataWithJSONObject:status
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:nil];
        for (NSString *dir in dirs) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
            [data writeToFile:[dir stringByAppendingPathComponent:@"latest_status.json"] atomically:YES];
        }
    } @catch (__unused NSException *exception) {
    }
#else
    (void)stage;
#endif
}


static NSString *SBStateDirectoryPath(void) {
    static NSString *stateDir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *base = paths.firstObject ?: NSTemporaryDirectory();
        stateDir = [base stringByAppendingPathComponent:@"SoccerAppBypassState"];
        [[NSFileManager defaultManager] createDirectoryAtPath:stateDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    });
    return stateDir;
}

static NSString *SBServerVersionHashPath(void) {
    return [SBStateDirectoryPath() stringByAppendingPathComponent:@"server_version_hash.txt"];
}

static void SBPrepareCLogPath(void) {
    NSString *path = [SBLogRootPath() stringByAppendingPathComponent:@"index.tsv"];
    const char *fsPath = path.fileSystemRepresentation;
    if (!fsPath) {
        return;
    }

    strlcpy(SBIndexPathC, fsPath, sizeof(SBIndexPathC));
    atomic_store(&SBIndexPathCReady, true);
}

#if SB_ENABLE_EARLY_UNITYFRAMEWORK_DLOPEN
static void SBEarlyDlopenUnityFramework(void) {
    if (atomic_exchange(&SBEarlyUnityFrameworkDlopenAttempted, true)) {
        return;
    }

    int flags = RTLD_NOW | RTLD_GLOBAL;
    NSString *frameworksPath = NSBundle.mainBundle.privateFrameworksPath;
    NSString *absolutePath = [frameworksPath stringByAppendingPathComponent:@"UnityFramework.framework/UnityFramework"];
    const char *absolute = absolutePath.fileSystemRepresentation;
    const char *fallback = "@rpath/UnityFramework.framework/UnityFramework";

    if (absolute && absolute[0]) {
        strlcpy(SBEarlyUnityFrameworkDlopenPath, absolute, sizeof(SBEarlyUnityFrameworkDlopenPath));
        dlerror();
        SBEarlyUnityFrameworkDlopenHandle = dlopen(absolute, flags);
        if (SBEarlyUnityFrameworkDlopenHandle) {
            SBEarlyUnityFrameworkDlopenError[0] = '\0';
            return;
        }

        const char *error = dlerror();
        if (error) {
            strlcpy(SBEarlyUnityFrameworkDlopenError, error, sizeof(SBEarlyUnityFrameworkDlopenError));
        }
    }

    strlcpy(SBEarlyUnityFrameworkDlopenPath, fallback, sizeof(SBEarlyUnityFrameworkDlopenPath));
    dlerror();
    SBEarlyUnityFrameworkDlopenHandle = dlopen(fallback, flags);
    if (!SBEarlyUnityFrameworkDlopenHandle) {
        const char *error = dlerror();
        if (error) {
            strlcpy(SBEarlyUnityFrameworkDlopenError, error, sizeof(SBEarlyUnityFrameworkDlopenError));
        }
    } else {
        SBEarlyUnityFrameworkDlopenError[0] = '\0';
    }
}

static void SBLogEarlyDlopenUnityFrameworkResult(void) {
    if (!atomic_load(&SBEarlyUnityFrameworkDlopenAttempted)) {
        return;
    }

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tearly-unityframework-dlopen\tUnityFramework\t\tpath=%s handle=%p error=%s\t\t\t",
                       SBTimestamp(),
                       SBEarlyUnityFrameworkDlopenPath,
                       SBEarlyUnityFrameworkDlopenHandle,
                       SBEarlyUnityFrameworkDlopenError]);
}
#endif

static void SBAppendAnogsEventC(const char *event, const void *arg0, const void *arg1) {
    if (!event || !atomic_load(&SBIndexPathCReady)) {
        return;
    }

    time_t now = time(NULL);
    struct tm tmNow;
    char timestamp[32] = {0};
    if (gmtime_r(&now, &tmNow)) {
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S +0000", &tmNow);
    }

    char line[256];
    int len = snprintf(line,
                       sizeof(line),
                       "000000\t%s\t%s\tanogs\t\targ0=%p arg1=%p\t\t\t\n",
                       timestamp[0] ? timestamp : "unknown",
                       event,
                       arg0,
                       arg1);
    if (len <= 0) {
        return;
    }

    int fd = open(SBIndexPathC, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }
    write(fd, line, (size_t)MIN(len, (int)sizeof(line) - 1));
    close(fd);
}

static void SBAppendAnortGateEventC(const char *event,
                                    const void *manager,
                                    uint32_t beforeValue,
                                    uint32_t afterValue,
                                    const void *semHandle,
                                    uint32_t semReady,
                                    uint32_t count) {
    if (!event || !atomic_load(&SBIndexPathCReady)) {
        return;
    }

    time_t now = time(NULL);
    struct tm tmNow;
    char timestamp[32] = {0};
    if (gmtime_r(&now, &tmNow)) {
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S +0000", &tmNow);
    }

    char line[384];
    int len = snprintf(line,
                       sizeof(line),
                       "000000\t%s\t%s\tanort\t\tmanager=%p before=0x%08x after=0x%08x sem=%p semReady=%u count=%u\t\t\t\n",
                       timestamp[0] ? timestamp : "unknown",
                       event,
                       manager,
                       beforeValue,
                       afterValue,
                       semHandle,
                       semReady,
                       count);
    if (len <= 0) {
        return;
    }

    int fd = open(SBIndexPathC, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }
    write(fd, line, (size_t)MIN(len, (int)sizeof(line) - 1));
    close(fd);
}

static void SBCopyCStringPreview(char *dst, size_t dstSize, const char *src) {
    if (!dst || dstSize == 0) {
        return;
    }
    dst[0] = '\0';
    if (!src || (uintptr_t)src < 0x10000) {
        return;
    }

    size_t out = 0;
    for (size_t i = 0; i < 240 && out + 1 < dstSize; i++) {
        unsigned char ch = (unsigned char)src[i];
        if (ch == '\0') {
            break;
        }
        dst[out++] = (ch == '\n' || ch == '\r' || ch == '\t') ? ' ' : (char)ch;
    }
    dst[out] = '\0';
}

static void SBAppendUnityAssertEventC(const char *event,
                                      const void *entry,
                                      uint32_t flags,
                                      uint32_t line,
                                      const char *message,
                                      const char *detail,
                                      const char *file,
                                      const char *condition,
                                      uint32_t count) {
    if (!event || !atomic_load(&SBIndexPathCReady)) {
        return;
    }

    char messagePreview[256];
    char detailPreview[256];
    char filePreview[192];
    char conditionPreview[192];
    SBCopyCStringPreview(messagePreview, sizeof(messagePreview), message);
    SBCopyCStringPreview(detailPreview, sizeof(detailPreview), detail);
    SBCopyCStringPreview(filePreview, sizeof(filePreview), file);
    SBCopyCStringPreview(conditionPreview, sizeof(conditionPreview), condition);

    time_t now = time(NULL);
    struct tm tmNow;
    char timestamp[32] = {0};
    if (gmtime_r(&now, &tmNow)) {
        strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S +0000", &tmNow);
    }

    char lineBuffer[1200];
    int len = snprintf(lineBuffer,
                       sizeof(lineBuffer),
                       "000000\t%s\t%s\tUnityFramework\t\tentry=%p flags=0x%08x line=%u count=%u message=\"%s\" detail=\"%s\" file=\"%s\" condition=\"%s\"\t\t\t\n",
                       timestamp[0] ? timestamp : "unknown",
                       event,
                       entry,
                       flags,
                       line,
                       count,
                       messagePreview,
                       detailPreview,
                       filePreview,
                       conditionPreview);
    if (len <= 0) {
        return;
    }

    int fd = open(SBIndexPathC, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        return;
    }
    write(fd, lineBuffer, (size_t)MIN(len, (int)sizeof(lineBuffer) - 1));
    close(fd);
}

static void *SBPlainFunctionPointer(void *function) {
#if __has_feature(ptrauth_calls)
    return ptrauth_strip(function, ptrauth_key_function_pointer);
#else
    return function;
#endif
}

static BOOL SBWritePointerValue(uintptr_t address, void *value) {
    if (!address || !value) {
        return NO;
    }

    uintptr_t pageSize = (uintptr_t)getpagesize();
    uintptr_t pageStart = address & ~(pageSize - 1);
    uintptr_t pageEnd = (address + sizeof(void *) + pageSize - 1) & ~(pageSize - 1);
    vm_size_t protectSize = (vm_size_t)(pageEnd - pageStart);
    kern_return_t kr = vm_protect(mach_task_self(),
                                  (vm_address_t)pageStart,
                                  protectSize,
                                  false,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = vm_protect(mach_task_self(),
                        (vm_address_t)pageStart,
                        protectSize,
                        false,
                        VM_PROT_READ | VM_PROT_WRITE);
        if (kr != KERN_SUCCESS) {
            return NO;
        }
    }

    *(void **)address = value;
    __sync_synchronize();
    vm_protect(mach_task_self(),
               (vm_address_t)pageStart,
               protectSize,
               false,
               VM_PROT_READ | VM_PROT_WRITE);
    return YES;
}

static BOOL SBWriteReturnZeroPatch(uintptr_t address) {
    if (!address) {
        return NO;
    }

    uintptr_t pageSize = (uintptr_t)getpagesize();
    uintptr_t pageStart = address & ~(pageSize - 1);
    uintptr_t pageEnd = (address + sizeof(uint32_t) * 2 + pageSize - 1) & ~(pageSize - 1);
    vm_size_t protectSize = (vm_size_t)(pageEnd - pageStart);
    kern_return_t kr = vm_protect(mach_task_self(),
                                  (vm_address_t)pageStart,
                                  protectSize,
                                  false,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = vm_protect(mach_task_self(),
                        (vm_address_t)pageStart,
                        protectSize,
                        false,
                        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr != KERN_SUCCESS) {
            return NO;
        }
    }

    uint32_t *code = (uint32_t *)address;
    code[0] = 0x52800000; // mov w0, #0
    code[1] = 0xD65F03C0; // ret
    __sync_synchronize();
    sys_icache_invalidate((void *)address, sizeof(uint32_t) * 2);
    vm_protect(mach_task_self(),
               (vm_address_t)pageStart,
               protectSize,
               false,
               VM_PROT_READ | VM_PROT_EXECUTE);
    return YES;
}

static BOOL SBWriteReturnOnePatch(uintptr_t address) {
    if (!address) {
        return NO;
    }

    uintptr_t pageSize = (uintptr_t)getpagesize();
    uintptr_t pageStart = address & ~(pageSize - 1);
    uintptr_t pageEnd = (address + sizeof(uint32_t) * 2 + pageSize - 1) & ~(pageSize - 1);
    vm_size_t protectSize = (vm_size_t)(pageEnd - pageStart);
    kern_return_t kr = vm_protect(mach_task_self(),
                                  (vm_address_t)pageStart,
                                  protectSize,
                                  false,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = vm_protect(mach_task_self(),
                        (vm_address_t)pageStart,
                        protectSize,
                        false,
                        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr != KERN_SUCCESS) {
            return NO;
        }
    }

    uint32_t *code = (uint32_t *)address;
    code[0] = 0x52800020; // mov w0, #1
    code[1] = 0xD65F03C0; // ret
    __sync_synchronize();
    sys_icache_invalidate((void *)address, sizeof(uint32_t) * 2);
    vm_protect(mach_task_self(),
               (vm_address_t)pageStart,
               protectSize,
               false,
               VM_PROT_READ | VM_PROT_EXECUTE);
    return YES;
}

static BOOL SBWriteRetPatch(uintptr_t address) {
    if (!address) {
        return NO;
    }

    uintptr_t pageSize = (uintptr_t)getpagesize();
    uintptr_t pageStart = address & ~(pageSize - 1);
    uintptr_t pageEnd = (address + sizeof(uint32_t) + pageSize - 1) & ~(pageSize - 1);
    vm_size_t protectSize = (vm_size_t)(pageEnd - pageStart);
    kern_return_t kr = vm_protect(mach_task_self(),
                                  (vm_address_t)pageStart,
                                  protectSize,
                                  false,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = vm_protect(mach_task_self(),
                        (vm_address_t)pageStart,
                        protectSize,
                        false,
                        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr != KERN_SUCCESS) {
            return NO;
        }
    }

    *(uint32_t *)address = 0xD65F03C0; // ret
    __sync_synchronize();
    sys_icache_invalidate((void *)address, sizeof(uint32_t));
    vm_protect(mach_task_self(),
               (vm_address_t)pageStart,
               protectSize,
               false,
               VM_PROT_READ | VM_PROT_EXECUTE);
    return YES;
}

static NSObject *SBLogLock(void) {
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    return lock;
}

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static NSString *SBBasename(unsigned long ident, const char *kind) {
    char name[64];
    if (sb_make_log_basename(ident, kind, name, sizeof(name)) != 0) {
        snprintf(name, sizeof(name), "%06lu-%s.bin", ident, kind ?: "log");
    }
    return [NSString stringWithUTF8String:name];
}

static NSString *SBPathForLog(unsigned long ident, const char *kind) {
    return [SBLogRootPath() stringByAppendingPathComponent:SBBasename(ident, kind)];
}

static void SBAppendString(NSMutableData *data, NSString *string) {
    NSData *bytes = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (bytes) {
        [data appendData:bytes];
    }
}

static void SBAppendFormat(NSMutableData *data, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    SBAppendString(data, line);
}

static void SBAppendBody(NSMutableData *out, NSData *body, NSString *label) {
    if (!body) {
        return;
    }

    NSUInteger written = MIN(body.length, SBMaxLoggedBodyBytes);
    SBAppendFormat(out, @"\n%@-Length: %lu\n%@-Logged-Length: %lu\n\n",
                   label, (unsigned long)body.length, label, (unsigned long)written);
    if (written > 0) {
        [out appendData:[body subdataWithRange:NSMakeRange(0, written)]];
    }
    if (written < body.length) {
        SBAppendString(out, @"\n\n[SoccerAppBypass: body truncated]\n");
    }
}

static void SBWriteData(NSString *path, NSData *data) {
    if (!path || !data) {
        return;
    }
    @synchronized (SBLogLock()) {
        [data writeToFile:path atomically:YES];
    }
}
#endif

#if SB_ENABLE_KEYCHAIN_AUTH_DUMP
static void SBDumpKeychainClass(CFTypeRef secClass, NSString *filePrefix) {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)secClass;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    query[(__bridge id)kSecReturnAttributes] = @YES;
    query[(__bridge id)kSecReturnData] = @YES;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    NSMutableDictionary *root = [NSMutableDictionary dictionary];
    root[@"status"] = @(status);
    root[@"items"] = [NSMutableArray array];

    if (status == errSecSuccess && result) {
        NSArray *items = CFBridgingRelease(result);
        if ([items isKindOfClass:NSDictionary.class]) {
            items = @[(NSDictionary *)items];
        }

        if ([items isKindOfClass:NSArray.class]) {
            for (NSDictionary *item in items) {
                if (![item isKindOfClass:NSDictionary.class]) {
                    continue;
                }

                NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                for (id key in @[(__bridge id)kSecAttrAccessGroup,
                                 (__bridge id)kSecAttrAccount,
                                 (__bridge id)kSecAttrService,
                                 (__bridge id)kSecAttrServer,
                                 (__bridge id)kSecAttrLabel,
                                 (__bridge id)kSecAttrDescription,
                                 (__bridge id)kSecAttrGeneric]) {
                    id value = item[key];
                    if (!value || value == (id)kCFNull) {
                        continue;
                    }
                    NSString *name = [NSString stringWithFormat:@"%@", key];
                    if ([value isKindOfClass:NSData.class]) {
                        NSData *data = (NSData *)value;
                        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        entry[name] = text ?: [data base64EncodedStringWithOptions:0];
                    } else {
                        entry[name] = [NSString stringWithFormat:@"%@", value];
                    }
                }

                NSData *secret = item[(__bridge id)kSecValueData];
                if ([secret isKindOfClass:NSData.class]) {
                    NSString *text = [[NSString alloc] initWithData:secret encoding:NSUTF8StringEncoding];
                    if (text) {
                        entry[@"value_utf8"] = text;
                    }
                    entry[@"value_b64"] = [secret base64EncodedStringWithOptions:0];
                    entry[@"value_length"] = @(secret.length);
                }

                [(NSMutableArray *)root[@"items"] addObject:entry];
            }
        }
    } else if (result) {
        CFRelease(result);
    }

    NSData *json = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
    if (json) {
        NSString *path = [SBLogRootPath() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@-keychain.json", filePrefix ?: @"auth"]];
        [json writeToFile:path atomically:YES];
        SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tkeychain-dumped\tSecurity\t\t%@ status=%d\t\t\t",
                           SBTimestamp(), path, (int)status]);
    }
}

static void SBDumpKeychainAuthItems(void) {
    SBDumpKeychainClass(kSecClassGenericPassword, @"generic");
    SBDumpKeychainClass(kSecClassInternetPassword, @"internet");
}
#endif

static void SBAppendIndexLine(NSString *line) {
    NSString *path = [SBLogRootPath() stringByAppendingPathComponent:@"index.tsv"];
    NSData *bytes = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (!bytes) {
        return;
    }

    @synchronized (SBLogLock()) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:path]) {
            [fm createFileAtPath:path
                        contents:[@"id\ttime\tevent\tsource\tmethod\turl\trequest_file\tresponse_file\terror\n"
                                  dataUsingEncoding:NSUTF8StringEncoding]
                      attributes:nil];
        }

        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        [handle seekToEndOfFile];
        [handle writeData:bytes];
        [handle closeFile];
    }
}

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
// Capture only the game API hosts. These logs feed the Python client so Charles
// is not required for auth/session material.
static NSString *SBRequestMethod(NSURLRequest *request) {
    return request.HTTPMethod.length > 0 ? request.HTTPMethod : @"GET";
}

static NSString *SBRequestURL(NSURLRequest *request) {
    return request.URL.absoluteString ?: @"";
}

static BOOL SBShouldLogURL(NSURL *url) {
    NSString *host = url.host.lowercaseString;
    return [host isEqualToString:@"jp-prd-391k-api.inazuma-cross.jp"] ||
           [host isEqualToString:@"jp-prd-link.inazuma-cross.jp"];
}

static void SBCaptureServerVersionHash(NSURLResponse *response, NSData *body) {
    NSURL *url = response.URL;
    if (!url || body.length == 0) {
        return;
    }
    if (![url.host.lowercaseString isEqualToString:@"jp-prd-391k-api.inazuma-cross.jp"] ||
        [url.path rangeOfString:@"/Entrypoint/Current"].location == NSNotFound) {
        return;
    }

    id json = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) {
        return;
    }

    NSDictionary *root = (NSDictionary *)json;
    id current = root[@"Current"];
    if (![current isKindOfClass:NSDictionary.class]) {
        return;
    }

    id hash = ((NSDictionary *)current)[@"ServerVersionHash"];
    if (![hash isKindOfClass:NSString.class] || [(NSString *)hash length] == 0) {
        return;
    }

    NSString *trimmed = [(NSString *)hash stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return;
    }

    [trimmed writeToFile:SBServerVersionHashPath()
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:nil];
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tserver-version-hash\tEntrypoint\t\t%@\t\t\t",
                       SBTimestamp(),
                       trimmed]);
}
#endif

#if SB_ENABLE_METADATA_DUMP
static void SBAppendDiagnostic(NSString *event, NSString *detail) {
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\t%@\tSoccerAppBypass\t\t%@\t\t\t",
                       SBTimestamp(), event ?: @"diagnostic", detail ?: @""]);
}
#endif

static NSString *SBTimestamp(void) {
    return [[NSDate date] descriptionWithLocale:nil];
}

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static void SBAppendHeaders(NSMutableData *out, NSDictionary *headers) {
    NSArray *keys = [[headers allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (id key in keys) {
        SBAppendFormat(out, @"%@: %@\n", key, headers[key]);
    }
}

static void SBWriteMetaFile(unsigned long ident, NSURLRequest *request, NSString *source) {
    NSMutableData *out = [NSMutableData data];
    NSString *requestFile = SBBasename(ident, "request");
    NSString *responseFile = SBBasename(ident, "response");

    SBAppendFormat(out, @"ID: %06lu\n", ident);
    SBAppendFormat(out, @"Time: %@\n", SBTimestamp());
    SBAppendFormat(out, @"Source: %@\n", source ?: @"unknown");
    SBAppendFormat(out, @"Method: %@\n", SBRequestMethod(request));
    SBAppendFormat(out, @"URL: %@\n", SBRequestURL(request));
    SBAppendFormat(out, @"Request-File: %@\n", requestFile);
    SBAppendFormat(out, @"Response-File: %@\n", responseFile);
    SBWriteData(SBPathForLog(ident, "meta"), out);
}

static void SBWriteRequestFile(unsigned long ident, NSURLRequest *request, NSData *overrideBody, NSString *source) {
    NSMutableData *out = [NSMutableData data];
    SBAppendFormat(out, @"ID: %06lu\n", ident);
    SBAppendFormat(out, @"Source: %@\n", source ?: @"unknown");
    SBAppendFormat(out, @"%@ %@ HTTP/1.1\n", SBRequestMethod(request), SBRequestURL(request));
    SBAppendHeaders(out, request.allHTTPHeaderFields ?: @{});

    NSData *body = overrideBody ?: request.HTTPBody;
    if (body) {
        SBAppendBody(out, body, @"Request-Body");
    } else if (request.HTTPBodyStream) {
        SBAppendString(out, @"\n[SoccerAppBypass: request uses HTTPBodyStream; stream body not consumed]\n");
    } else {
        SBAppendString(out, @"\n");
    }

    SBWriteData(SBPathForLog(ident, "request"), out);
}

static void SBWriteResponseFile(unsigned long ident, NSURLResponse *response, NSData *body, NSError *error, NSString *source) {
    NSMutableData *out = [NSMutableData data];
    SBAppendFormat(out, @"ID: %06lu\n", ident);
    SBAppendFormat(out, @"Source: %@\n", source ?: @"unknown");
    SBAppendFormat(out, @"URL: %@\n", response.URL.absoluteString ?: @"");

    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        SBAppendFormat(out, @"Status: %ld\n", (long)http.statusCode);
        SBAppendHeaders(out, http.allHeaderFields ?: @{});
    }

    if (error) {
        SBAppendFormat(out, @"Error: %@ %ld %@\n", error.domain, (long)error.code, error.localizedDescription ?: @"");
    }
    SBAppendBody(out, body, @"Response-Body");
    SBWriteData(SBPathForLog(ident, "response"), out);
}

static unsigned long SBLogRequest(NSURLRequest *request, NSData *body, NSString *source) {
    if (!SBShouldLogURL(request.URL)) {
        return 0;
    }

    unsigned long ident = atomic_fetch_add(&SBNextLogIdent, 1);
    SBWriteMetaFile(ident, request, source);
    SBWriteRequestFile(ident, request, body, source);
    SBAppendIndexLine([NSString stringWithFormat:@"%06lu\t%@\trequest\t%@\t%@\t%@\t%@\t%@\t",
                       ident, SBTimestamp(), source ?: @"unknown", SBRequestMethod(request),
                       SBRequestURL(request), SBBasename(ident, "request"), SBBasename(ident, "response")]);
    return ident;
}

static void SBLogResponse(unsigned long ident, NSURLResponse *response, NSData *body, NSError *error, NSString *source) {
    if (ident == 0) {
        return;
    }

    SBCaptureServerVersionHash(response, body);
    SBWriteResponseFile(ident, response, body, error, source);
    SBAppendIndexLine([NSString stringWithFormat:@"%06lu\t%@\tresponse\t%@\t\t%@\t%@\t%@\t%@",
                       ident, SBTimestamp(), source ?: @"unknown",
                       response.URL.absoluteString ?: @"", SBBasename(ident, "request"),
                       SBBasename(ident, "response"),
                       error ? error.localizedDescription ?: @"" : @""]);
}

static BOOL SBResponseFileExists(unsigned long ident) {
    if (ident == 0) {
        return NO;
    }
    return [[NSFileManager defaultManager] fileExistsAtPath:SBPathForLog(ident, "response")];
}

static void SBAssociateTask(id task, unsigned long ident, NSString *source) {
    if (!task || ident == 0) {
        return;
    }
    objc_setAssociatedObject(task, &SBTaskIdentKey, @(ident), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (source) {
        objc_setAssociatedObject(task, &SBTaskSourceKey, source, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

static unsigned long SBTaskIdent(id task) {
    NSNumber *number = task ? objc_getAssociatedObject(task, &SBTaskIdentKey) : nil;
    return number ? number.unsignedLongValue : 0;
}

static NSString *SBTaskSource(id task) {
    NSString *source = task ? objc_getAssociatedObject(task, &SBTaskSourceKey) : nil;
    return source ?: @"NSURLSession delegate";
}

static unsigned long SBEnsureTaskIdent(NSURLSessionTask *task, NSString *source) {
    unsigned long ident = SBTaskIdent(task);
    if (ident != 0) {
        return ident;
    }

    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    ident = SBLogRequest(request, nil, source);
    SBAssociateTask(task, ident, source);
    return ident;
}

static NSMutableData *SBTaskMutableData(id task) {
    if (!task) {
        return nil;
    }

    NSMutableData *data = objc_getAssociatedObject(task, &SBTaskDataKey);
    if (!data) {
        data = [NSMutableData data];
        objc_setAssociatedObject(task, &SBTaskDataKey, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return data;
}
#endif

#if SB_ENABLE_METADATA_DUMP
// Metadata dumping is disabled by default. Keep this block for future reference
// if runtime IL2CPP metadata extraction is needed again.
static uintptr_t SBFindImageBase(const char *needle) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, needle)) {
            const struct mach_header *header = _dyld_get_image_header(i);
            return (uintptr_t)header;
        }
    }
    return 0;
}

static BOOL SBReadPointer(uintptr_t address, uintptr_t *out) {
    if (!address || !out) {
        return NO;
    }

    uintptr_t value = 0;
    vm_size_t readSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)address,
                                         sizeof(value),
                                         (vm_address_t)&value,
                                         &readSize);
    if (kr != KERN_SUCCESS || readSize != sizeof(value)) {
        return NO;
    }

    *out = value;
    return YES;
}

static NSData *SBReadProcessMemory(uintptr_t address, size_t size) {
    if (!address || size == 0 || size > 0x40000000u) {
        return nil;
    }

    NSMutableData *out = [NSMutableData dataWithLength:size];
    vm_size_t readSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)address,
                                         (vm_size_t)size,
                                         (vm_address_t)out.mutableBytes,
                                         &readSize);
    if (kr != KERN_SUCCESS || readSize == 0) {
        return nil;
    }

    if ((size_t)readSize < size) {
        out.length = (NSUInteger)readSize;
    }
    return out;
}

static NSString *SBMetadataDirectory(void) {
    NSString *path = [SBLogRootPath() stringByAppendingPathComponent:@"metadata"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return path;
}

static size_t SBOnDiskMetadataSize(void) {
    NSString *bundle = NSBundle.mainBundle.bundlePath;
    NSArray<NSString *> *relativePaths = @[
        @"Data/Managed/Metadata/global-metadata.dat",
        @"Data/Metadata/global-metadata.dat"
    ];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *relative in relativePaths) {
        NSString *path = [bundle stringByAppendingPathComponent:relative];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        NSNumber *size = attrs[NSFileSize];
        if (size.unsignedLongLongValue > 0 && size.unsignedLongLongValue <= 0x40000000ULL) {
            return (size_t)size.unsignedLongLongValue;
        }
    }
    return 0;
}

static NSString *SBHexPrefix(NSData *data, NSUInteger maxBytes) {
    if (!data.length) {
        return @"";
    }

    const unsigned char *bytes = data.bytes;
    NSUInteger count = MIN(data.length, maxBytes);
    NSMutableString *out = [NSMutableString stringWithCapacity:count * 3];
    for (NSUInteger i = 0; i < count; i++) {
        [out appendFormat:@"%02x", bytes[i]];
        if (i + 1 < count) {
            [out appendString:@" "];
        }
    }
    return out;
}

static void SBDumpRawMetadataCandidate(uintptr_t metadataPtr, NSData *header) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&SBMetadataRawDumped, &expected, true)) {
        return;
    }

    size_t fallbackSize = SBOnDiskMetadataSize();
    if (fallbackSize == 0) {
        fallbackSize = 24 * 1024 * 1024;
    }

    NSData *raw = SBReadProcessMemory(metadataPtr, fallbackSize);
    NSString *dir = SBMetadataDirectory();
    NSString *rawPath = [dir stringByAppendingPathComponent:@"loaded-metadata-candidate.raw.dat"];
    NSString *headerPath = [dir stringByAppendingPathComponent:@"loaded-metadata-candidate.header.bin"];
    NSString *infoPath = [dir stringByAppendingPathComponent:@"loaded-metadata-candidate-info.txt"];

    if (header.length > 0) {
        [header writeToFile:headerPath atomically:YES];
    }
    if (raw.length > 0) {
        [raw writeToFile:rawPath atomically:YES];
    }

    NSString *info = [NSString stringWithFormat:
                      @"MetadataPtr: 0x%llx\nRequestedSize: %lu\nReadSize: %lu\nHeaderSize: %lu\nHeaderPrefix: %@\nRawDump: %@\nHeaderDump: %@\n",
                      (unsigned long long)metadataPtr,
                      (unsigned long)fallbackSize,
                      (unsigned long)raw.length,
                      (unsigned long)header.length,
                      SBHexPrefix(header, 64),
                      rawPath,
                      headerPath];
    [info writeToFile:infoPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    SBAppendDiagnostic(@"metadata-raw-dumped",
                       [NSString stringWithFormat:@"ptr=0x%llx requested=%lu read=%lu prefix=%@",
                        (unsigned long long)metadataPtr,
                        (unsigned long)fallbackSize,
                        (unsigned long)raw.length,
                        SBHexPrefix(header, 16)]);
}

static BOOL SBTryDumpLoadedMetadata(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&SBMetadataDumped, &expected, true)) {
        return YES;
    }

    uintptr_t unityBase = SBFindImageBase("UnityFramework");
    if (!unityBase) {
        atomic_store(&SBMetadataDumped, false);
        return NO;
    }

    uintptr_t metadataPtr = 0;
    uintptr_t globalAddress = unityBase + SBUnityMetadataGlobalOffset;
    if (!SBReadPointer(globalAddress, &metadataPtr) || !metadataPtr) {
        atomic_store(&SBMetadataDumped, false);
        return NO;
    }

    NSData *header = SBReadProcessMemory(metadataPtr, 0x1000);
    size_t metadataSize = sb_metadata_size_from_header(header.bytes, header.length);
    if (metadataSize == 0) {
        SBDumpRawMetadataCandidate(metadataPtr, header);
        atomic_store(&SBMetadataDumped, false);
        SBAppendDiagnostic(@"metadata-ptr-not-ready",
                           [NSString stringWithFormat:@"base=0x%llx global=0x%llx ptr=0x%llx",
                            (unsigned long long)unityBase,
                            (unsigned long long)globalAddress,
                            (unsigned long long)metadataPtr]);
        return NO;
    }

    NSData *metadata = SBReadProcessMemory(metadataPtr, metadataSize);
    if (!metadata || metadata.length < metadataSize) {
        atomic_store(&SBMetadataDumped, false);
        SBAppendDiagnostic(@"metadata-read-failed",
                           [NSString stringWithFormat:@"ptr=0x%llx size=%lu read=%lu",
                            (unsigned long long)metadataPtr,
                            (unsigned long)metadataSize,
                            (unsigned long)metadata.length]);
        return NO;
    }

    NSString *dir = SBMetadataDirectory();
    BOOL magicRepaired = sb_metadata_header_needs_magic_repair(metadata.bytes, metadata.length);
    NSMutableData *dumpData = [metadata mutableCopy];
    if (magicRepaired) {
        sb_repair_metadata_magic(dumpData.mutableBytes, dumpData.length);
    }

    NSString *dumpPath = [dir stringByAppendingPathComponent:@"global-metadata.dat"];
    NSString *runtimePath = [dir stringByAppendingPathComponent:@"global-metadata.runtime.dat"];
    NSString *infoPath = [dir stringByAppendingPathComponent:@"metadata-info.txt"];
    [dumpData writeToFile:dumpPath atomically:YES];
    if (magicRepaired) {
        [metadata writeToFile:runtimePath atomically:YES];
    }

    const unsigned int *words = (const unsigned int *)metadata.bytes;
    const unsigned int *dumpWords = (const unsigned int *)dumpData.bytes;
    NSString *info = [NSString stringWithFormat:
                      @"UnityFrameworkBase: 0x%llx\nMetadataGlobal: 0x%llx\nMetadataPtr: 0x%llx\nRuntimeMagic: 0x%08x\nDumpMagic: 0x%08x\nMagicRepaired: %@\nVersion: %u\nSize: %lu\nDump: %@\nRuntimeDump: %@\n",
                      (unsigned long long)unityBase,
                      (unsigned long long)globalAddress,
                      (unsigned long long)metadataPtr,
                      words[0],
                      dumpWords[0],
                      magicRepaired ? @"YES" : @"NO",
                      words[1],
                      (unsigned long)metadataSize,
                      dumpPath,
                      magicRepaired ? runtimePath : @""];
    [info writeToFile:infoPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    SBAppendDiagnostic(@"metadata-dumped",
                       [NSString stringWithFormat:@"ptr=0x%llx size=%lu repaired=%@ file=%@",
                        (unsigned long long)metadataPtr,
                        (unsigned long)metadataSize,
                        magicRepaired ? @"YES" : @"NO",
                        dumpPath.lastPathComponent]);
    return YES;
}

static void SBStartMetadataDumpTimer(void) {
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    for (int i = 1; i <= 45; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * NSEC_PER_SEC), queue, ^{
            if (!atomic_load(&SBMetadataDumped)) {
                SBTryDumpLoadedMetadata();
            }
        });
    }
}
#endif

static void SBClearPTraced(void *oldp, size_t oldlen) {
    if (!oldp || oldlen < sizeof(struct kinfo_proc)) {
        return;
    }

    size_t count = oldlen / sizeof(struct kinfo_proc);
    struct kinfo_proc *infos = (struct kinfo_proc *)oldp;
    for (size_t i = 0; i < count; i++) {
        infos[i].kp_proc.p_flag &= ~P_TRACED;
    }
}

static int replacement_access(const char *path, int mode) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(path, mode);
}

static int replacement_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) {
        va_list args;
        va_start(args, oflag);
        mode = (mode_t)va_arg(args, int);
        va_end(args);
    }

    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return -1;
    }
    if ((oflag & (O_CREAT | O_WRONLY | O_RDWR | O_TRUNC | O_APPEND)) && sb_should_deny_write_probe(path)) {
        errno = EACCES;
        return -1;
    }

    if (oflag & O_CREAT) {
        return orig_open(path, oflag, mode);
    }
    return orig_open(path, oflag);
}

static FILE *replacement_fopen(const char *path, const char *mode) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return NULL;
    }
    if (mode && strpbrk(mode, "wa+") && sb_should_deny_write_probe(path)) {
        errno = EACCES;
        return NULL;
    }
    return orig_fopen(path, mode);
}

static DIR *replacement_opendir(const char *path) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return NULL;
    }
    return orig_opendir(path);
}

static int replacement_stat(const char *path, struct stat *buf) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_stat(path, buf);
}

static int replacement_lstat(const char *path, struct stat *buf) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_lstat(path, buf);
}

static ssize_t replacement_readlink(const char *path, char *buf, size_t bufsiz) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_readlink(path, buf, bufsiz);
}

static char *replacement_realpath(const char *path, char *resolved_path) {
    if (sb_is_sensitive_jb_path(path)) {
        errno = ENOENT;
        return NULL;
    }
    return orig_realpath(path, resolved_path);
}

static int replacement_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int result = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (result == 0 && oldp && oldlenp && namelen >= 4 &&
        name[0] == CTL_KERN && name[1] == KERN_PROC) {
        SBClearPTraced(oldp, *oldlenp);
    }
    return result;
}

static int replacement_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int result = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (result == 0 && oldp && oldlenp && name && strstr(name, "kern.proc")) {
        SBClearPTraced(oldp, *oldlenp);
    }
    return result;
}

static int replacement_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    if (request == PT_DENY_ATTACH) {
        return 0;
    }
    return orig_ptrace ? orig_ptrace(request, pid, addr, data) : 0;
}

static pid_t replacement_fork(void) {
    errno = ENOTSUP;
    return -1;
}

#if SB_MACVER && SB_ENABLE_MAC_SELF_KILL_GUARD
static BOOL SBMacSelfKillSignalIsFatal(int sig) {
    return sig == SIGKILL || sig == SIGTERM || sig == SIGABRT || sig == SIGQUIT;
}

static NSString *SBMacSelfKillSignalName(int sig) {
    switch (sig) {
        case SIGKILL: return @"SIGKILL";
        case SIGTERM: return @"SIGTERM";
        case SIGABRT: return @"SIGABRT";
        case SIGQUIT: return @"SIGQUIT";
        default: return [NSString stringWithFormat:@"%d", sig];
    }
}

static void SBLogMacSelfKillGuard(NSString *action, int sig, NSString *detail) {
    unsigned long ident = atomic_fetch_add(&SBNextSelfKillIdent, 1);
    NSString *fileName = [NSString stringWithFormat:@"self-kill-%06lu.txt", ident];
    NSString *path = [SBLogRootPath() stringByAppendingPathComponent:fileName];
    NSArray<NSString *> *stack = [NSThread callStackSymbols] ?: @[];
    NSString *body = [NSString stringWithFormat:
                      @"time: %@\naction: %@\nsignal: %@ (%d)\npid: %d\nprocess: %@\ndetail: %@\n\n%@\n",
                      SBTimestamp(),
                      action ?: @"unknown",
                      SBMacSelfKillSignalName(sig),
                      sig,
                      getpid(),
                      NSProcessInfo.processInfo.processName ?: @"",
                      detail ?: @"",
                      [stack componentsJoinedByString:@"\n"]];
    [body writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-self-kill-guard\tlibSystem\t\t%@ sig=%@ detail=%@ stack=%@\t\t\t",
                       SBTimestamp(),
                       action ?: @"unknown",
                       SBMacSelfKillSignalName(sig),
                       detail ?: @"",
                       fileName]);
}

static int replacement_kill(pid_t pid, int sig) {
    if (SBMacSelfKillSignalIsFatal(sig) && (pid == getpid() || pid == 0 || pid == -getpgrp())) {
        SBLogMacSelfKillGuard(@"kill", sig, [NSString stringWithFormat:@"pid=%d", pid]);
        return 0;
    }
    return orig_kill ? orig_kill(pid, sig) : 0;
}

static int replacement_killpg(pid_t pgrp, int sig) {
    if (SBMacSelfKillSignalIsFatal(sig) && (pgrp == getpgrp() || pgrp == 0)) {
        SBLogMacSelfKillGuard(@"killpg", sig, [NSString stringWithFormat:@"pgrp=%d", pgrp]);
        return 0;
    }
    return orig_killpg ? orig_killpg(pgrp, sig) : 0;
}

static int replacement_raise(int sig) {
    if (SBMacSelfKillSignalIsFatal(sig)) {
        SBLogMacSelfKillGuard(@"raise", sig, @"self");
        return 0;
    }
    return orig_raise ? orig_raise(sig) : 0;
}

static int replacement_pthread_kill(pthread_t thread, int sig) {
    if (SBMacSelfKillSignalIsFatal(sig)) {
        SBLogMacSelfKillGuard(@"pthread_kill", sig,
                              [NSString stringWithFormat:@"thread=%p self=%d",
                               (void *)thread,
                               pthread_equal(thread, pthread_self()) ? 1 : 0]);
        return 0;
    }
    return orig_pthread_kill ? orig_pthread_kill(thread, sig) : 0;
}

static void replacement_abort(void) {
    SBLogMacSelfKillGuard(@"abort", SIGABRT, @"suppressed");
}

static void replacement_exit(int status) {
    SBLogMacSelfKillGuard(@"exit", 0, [NSString stringWithFormat:@"status=%d", status]);
}

static void replacement__exit(int status) {
    SBLogMacSelfKillGuard(@"_exit", 0, [NSString stringWithFormat:@"status=%d", status]);
}

static int replacement___kill(pid_t pid, int sig) {
    if (SBMacSelfKillSignalIsFatal(sig) && (pid == getpid() || pid == 0 || pid == -getpgrp())) {
        SBLogMacSelfKillGuard(@"__kill", sig, [NSString stringWithFormat:@"pid=%d", pid]);
        return 0;
    }
    return orig___kill ? orig___kill(pid, sig) : 0;
}

static int replacement___pthread_kill(pthread_t thread, int sig) {
    if (SBMacSelfKillSignalIsFatal(sig)) {
        SBLogMacSelfKillGuard(@"__pthread_kill", sig,
                              [NSString stringWithFormat:@"thread=%p self=%d",
                               (void *)thread,
                               pthread_equal(thread, pthread_self()) ? 1 : 0]);
        return 0;
    }
    return orig___pthread_kill ? orig___pthread_kill(thread, sig) : 0;
}

static void replacement___exit(int status) {
    SBLogMacSelfKillGuard(@"__exit", 0, [NSString stringWithFormat:@"status=%d", status]);
}

static void replacement_abort_with_reason(uint32_t reason_namespace,
                                          uint64_t reason_code,
                                          const char *reason_string,
                                          uint64_t reason_flags) {
    SBLogMacSelfKillGuard(@"abort_with_reason", SIGABRT,
                          [NSString stringWithFormat:@"namespace=%u code=%llu flags=%llu reason=%s",
                           reason_namespace,
                           (unsigned long long)reason_code,
                           (unsigned long long)reason_flags,
                           reason_string ?: ""]);
}

static void replacement_abort_with_payload(uint32_t reason_namespace,
                                           uint64_t reason_code,
                                           void *payload,
                                           uint32_t payload_size,
                                           const char *reason_string,
                                           uint64_t reason_flags) {
    SBLogMacSelfKillGuard(@"abort_with_payload", SIGABRT,
                          [NSString stringWithFormat:@"namespace=%u code=%llu payload=%p size=%u flags=%llu reason=%s",
                           reason_namespace,
                           (unsigned long long)reason_code,
                           payload,
                           payload_size,
                           (unsigned long long)reason_flags,
                           reason_string ?: ""]);
}

static void replacement___abort_with_payload(uint32_t reason_namespace,
                                             uint64_t reason_code,
                                             void *payload,
                                             uint32_t payload_size,
                                             const char *reason_string,
                                             uint64_t reason_flags) {
    SBLogMacSelfKillGuard(@"__abort_with_payload", SIGABRT,
                          [NSString stringWithFormat:@"namespace=%u code=%llu payload=%p size=%u flags=%llu reason=%s",
                           reason_namespace,
                           (unsigned long long)reason_code,
                           payload,
                           payload_size,
                           (unsigned long long)reason_flags,
                           reason_string ?: ""]);
}

static void replacement_terminate_with_reason(uint32_t reason_namespace,
                                              uint64_t reason_code,
                                              const char *reason_string,
                                              uint64_t reason_flags) {
    SBLogMacSelfKillGuard(@"terminate_with_reason", SIGKILL,
                          [NSString stringWithFormat:@"namespace=%u code=%llu flags=%llu reason=%s",
                           reason_namespace,
                           (unsigned long long)reason_code,
                           (unsigned long long)reason_flags,
                           reason_string ?: ""]);
}

static void replacement_terminate_with_payload(uint32_t reason_namespace,
                                               uint64_t reason_code,
                                               void *payload,
                                               uint32_t payload_size,
                                               const char *reason_string,
                                               uint64_t reason_flags) {
    SBLogMacSelfKillGuard(@"terminate_with_payload", SIGKILL,
                          [NSString stringWithFormat:@"namespace=%u code=%llu payload=%p size=%u flags=%llu reason=%s",
                           reason_namespace,
                           (unsigned long long)reason_code,
                           payload,
                           payload_size,
                           (unsigned long long)reason_flags,
                           reason_string ?: ""]);
}

static void replacement___terminate_with_payload(uint32_t reason_namespace,
                                                 uint64_t reason_code,
                                                 void *payload,
                                                 uint32_t payload_size,
                                                 const char *reason_string,
                                                 uint64_t reason_flags) {
    SBLogMacSelfKillGuard(@"__terminate_with_payload", SIGKILL,
                          [NSString stringWithFormat:@"namespace=%u code=%llu payload=%p size=%u flags=%llu reason=%s",
                           reason_namespace,
                           (unsigned long long)reason_code,
                           payload,
                           payload_size,
                           (unsigned long long)reason_flags,
                           reason_string ?: ""]);
}

static kern_return_t replacement_task_terminate(task_t target_task) {
    if (target_task == mach_task_self()) {
        SBLogMacSelfKillGuard(@"task_terminate", SIGKILL, @"mach_task_self");
        return KERN_SUCCESS;
    }
    return orig_task_terminate ? orig_task_terminate(target_task) : KERN_SUCCESS;
}

static long SBForwardSyscall(long (*fn)(long number, ...), long number,
                             long a0, long a1, long a2, long a3,
                             long a4, long a5, long a6, long a7) {
    return fn ? fn(number, a0, a1, a2, a3, a4, a5, a6, a7) : -1;
}

static long replacement_syscall(long number, ...) {
    va_list ap;
    va_start(ap, number);
    long a0 = va_arg(ap, long);
    long a1 = va_arg(ap, long);
    long a2 = va_arg(ap, long);
    long a3 = va_arg(ap, long);
    long a4 = va_arg(ap, long);
    long a5 = va_arg(ap, long);
    long a6 = va_arg(ap, long);
    long a7 = va_arg(ap, long);
    va_end(ap);

    if (number == SYS_kill) {
        pid_t pid = (pid_t)a0;
        int sig = (int)a1;
        if (SBMacSelfKillSignalIsFatal(sig) && (pid == getpid() || pid == 0 || pid == -getpgrp())) {
            SBLogMacSelfKillGuard(@"syscall(SYS_kill)", sig, [NSString stringWithFormat:@"pid=%d", pid]);
            return 0;
        }
    }

    return SBForwardSyscall(orig_syscall, number, a0, a1, a2, a3, a4, a5, a6, a7);
}

static long replacement___syscall(long number, ...) {
    va_list ap;
    va_start(ap, number);
    long a0 = va_arg(ap, long);
    long a1 = va_arg(ap, long);
    long a2 = va_arg(ap, long);
    long a3 = va_arg(ap, long);
    long a4 = va_arg(ap, long);
    long a5 = va_arg(ap, long);
    long a6 = va_arg(ap, long);
    long a7 = va_arg(ap, long);
    va_end(ap);

    if (number == SYS_kill) {
        pid_t pid = (pid_t)a0;
        int sig = (int)a1;
        if (SBMacSelfKillSignalIsFatal(sig) && (pid == getpid() || pid == 0 || pid == -getpgrp())) {
            SBLogMacSelfKillGuard(@"__syscall(SYS_kill)", sig, [NSString stringWithFormat:@"pid=%d", pid]);
            return 0;
        }
    }

    return SBForwardSyscall(orig___syscall, number, a0, a1, a2, a3, a4, a5, a6, a7);
}
#endif

#if SB_MACVER && SB_ENABLE_MAC_DIRECT_SYSCALL_GUARD && SB_ENABLE_MAC_SELF_KILL_GUARD
static void SBTraceMacDirectSyscall(long number, long a0, long a1, long a2) {
    uint32_t count = atomic_fetch_add(&SBMacDirectSyscallTraceCount, 1) + 1;
    BOOL interesting = number == SYS_kill ||
                       number == SYS_exit ||
                       number == SYS_ptrace ||
#ifdef SYS___pthread_kill
                       number == SYS___pthread_kill ||
#endif
                       false;
    if (!interesting && count > 24) {
        return;
    }

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-direct-syscall-trace\tinline-svc\t\tnumber=%ld a0=%ld a1=%ld a2=%ld count=%u\t\t\t",
                       SBTimestamp(),
                       number,
                       a0,
                       a1,
                       a2,
                       count]);
}

static long replacement_mac_indirect_syscall_svc(long number,
                                                 long a0,
                                                 long a1,
                                                 long a2,
                                                 long a3,
                                                 long a4,
                                                 long a5,
                                                 long a6) {
    SBTraceMacDirectSyscall(number, a0, a1, a2);

    if (number == SYS_kill) {
        pid_t pid = (pid_t)a0;
        int sig = (int)a1;
        if (SBMacSelfKillSignalIsFatal(sig) && (pid == getpid() || pid == 0 || pid == -getpgrp())) {
            SBLogMacSelfKillGuard(@"direct-syscall(SYS_kill)",
                                  sig,
                                  [NSString stringWithFormat:@"pid=%d a2=%ld", pid, a2]);
            return 0;
        }
    }

    if (number == SYS_exit) {
        SBLogMacSelfKillGuard(@"direct-syscall(SYS_exit)",
                              0,
                              [NSString stringWithFormat:@"status=%ld", a0]);
        return 0;
    }

#ifdef SYS___pthread_kill
    if (number == SYS___pthread_kill) {
        int sig = (int)a1;
        if (SBMacSelfKillSignalIsFatal(sig)) {
            SBLogMacSelfKillGuard(@"direct-syscall(SYS___pthread_kill)",
                                  sig,
                                  [NSString stringWithFormat:@"thread=%ld", a0]);
            return 0;
        }
    }
#endif

    if (number == SYS_ptrace && (int)a0 == PT_DENY_ATTACH) {
        SBLogMacSelfKillGuard(@"direct-syscall(SYS_ptrace)",
                              0,
                              @"PT_DENY_ATTACH suppressed");
        return 0;
    }

    return syscall(number, a0, a1, a2, a3, a4, a5, a6);
}
#endif

static char *replacement_getenv(const char *name) {
    if (name && (strstr(name, "DYLD_") || strstr(name, "SUBSTRATE") || strstr(name, "FRIDA"))) {
        return NULL;
    }
    return orig_getenv(name);
}

static void *replacement_dlopen(const char *path, int mode) {
    if (sb_is_sensitive_jb_path(path) || sb_is_injection_image_name(path)) {
        errno = ENOENT;
        return NULL;
    }
    return orig_dlopen(path, mode);
}

static void *replacement_dlsym(void *handle, const char *symbol) {
    if (symbol && (strstr(symbol, "MSHook") || strstr(symbol, "Substrate") ||
                   strstr(symbol, "frida") || strstr(symbol, "ellekit"))) {
        return NULL;
    }
    return orig_dlsym(handle, symbol);
}

static uint32_t SBHiddenImageCount(void) {
    if (!orig_dyld_image_count || !orig_dyld_get_image_name) {
        return 0;
    }

    uint32_t count = orig_dyld_image_count();
    static uint32_t cachedCount;
    static uint32_t cachedHidden;
    if (cachedCount == count) {
        return cachedHidden;
    }

    uint32_t hidden = 0;
    for (uint32_t i = 0; i < count; i++) {
        if (sb_is_injection_image_name(orig_dyld_get_image_name(i))) {
            hidden++;
        }
    }
    cachedCount = count;
    cachedHidden = hidden;
    return hidden;
}

static uint32_t replacement_dyld_image_count(void) {
    uint32_t count = orig_dyld_image_count();
    uint32_t hidden = SBHiddenImageCount();
    return count > hidden ? count - hidden : count;
}

static const char *replacement_dyld_get_image_name(uint32_t image_index) {
    const char *name = orig_dyld_get_image_name(image_index);
    if (sb_is_injection_image_name(name)) {
        return "/System/Library/Frameworks/Foundation.framework/Foundation";
    }
    return name;
}

static OSStatus replacement_SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
    if (result) {
        *result = kSecTrustResultProceed;
    }
    return errSecSuccess;
}

static bool replacement_SecTrustEvaluateWithError(SecTrustRef trust, CFErrorRef *error) {
    if (error) {
        *error = NULL;
    }
    return true;
}

static int replacement_anogs_root_check_report_cached(int report) {
    return 0;
}

static int replacement_anogs_root_check_core(char *reason, size_t reasonSize) {
    if (reason && reasonSize > 0) {
        reason[0] = '\0';
    }
    return 0;
}

static int64_t replacement_anogs_jailbreak_module_scan_once(void *context) {
    if (!atomic_exchange(&SBAnogsScanSuppressedLogged, true)) {
        SBAppendAnogsEventC("suppressed-anogs-jb-scan", context, NULL);
    }
    return 0;
}

static int64_t replacement_anogs_maybe_show_jailbreak_alert(void *context, const char *reason) {
    if (!atomic_exchange(&SBAnogsAlertSuppressedLogged, true)) {
        SBAppendAnogsEventC("suppressed-anogs-alert-decision", context, reason);
    }
    return 0;
}

static int64_t replacement_anogs_jailbreak_record_state(void *context, const char *reason) {
    if (!atomic_exchange(&SBAnogsStateSuppressedLogged, true)) {
        SBAppendAnogsEventC("suppressed-anogs-jb-state", context, reason);
    }
    return 0;
}

static int64_t replacement_anogs_show_jailbreak_alert(void) {
    if (!atomic_exchange(&SBAnogsAlertSuppressedLogged, true)) {
        SBAppendAnogsEventC("suppressed-anogs-alert", NULL, NULL);
    }
    return 0;
}

static bool replacement_anogs_is_root_cached(void *context) {
    return false;
}

static int64_t replacement_anort_check_engine_run(void *context) {
    if (!atomic_exchange(&SBAnortSuppressedLogged, true)) {
        SBAppendAnogsEventC("suppressed-anort-check-engine", context, NULL);
    }
    return 0;
}

#if SB_MACVER && (SB_ENABLE_ANORT_MAC_GATE_PRIME || SB_ENABLE_ANORT_MAC_GATE_WAIT_HOOK)
typedef void *(*SBAnortGateManagerGetter)(void);
typedef void (*SBAnortGateProducer)(void *);
#endif

#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_WAIT_HOOK
typedef void (*SBAnortGateWaitFunction)(void *);

static uintptr_t SBAnortMacGateRuntimeBase = 0;
static SBAnortGateWaitFunction orig_anort_gate_first_wait = NULL;
static SBAnortGateWaitFunction orig_anort_gate_second_wait = NULL;
static atomic_uint SBAnortGateFirstWaitCallCount = 0;
static atomic_uint SBAnortGateSecondWaitCallCount = 0;

static uint32_t SBAnortGateReadValue(void *manager, uintptr_t offset) {
    if (!manager) {
        return 0;
    }
    return *(volatile uint32_t *)((uint8_t *)manager + offset);
}

static void *SBAnortGateReadSemaphoreHandle(void *manager, uintptr_t semObjectOffset) {
    if (!manager) {
        return NULL;
    }
    return *(void **)((uint8_t *)manager + semObjectOffset + 0x40);
}

static uint32_t SBAnortGateReadSemaphoreReady(void *manager, uintptr_t semObjectOffset) {
    if (!manager) {
        return 0;
    }
    return *(volatile uint32_t *)((uint8_t *)manager + semObjectOffset + 0x48);
}

static void replacement_anort_gate_first_wait(void *manager) {
    uint32_t callCount = atomic_fetch_add(&SBAnortGateFirstWaitCallCount, 1) + 1;
    uint32_t beforeValue = SBAnortGateReadValue(manager, 0);

    if (manager && SBAnortMacGateRuntimeBase) {
        SBAnortGateProducer firstProducer =
            (SBAnortGateProducer)(void *)(SBAnortMacGateRuntimeBase + SBAnortGateFirstProducerOffset);
        if (firstProducer && beforeValue == 0) {
            firstProducer(manager);
        }
    }

    uint32_t afterValue = SBAnortGateReadValue(manager, 0);
    if (manager && afterValue == 0) {
        *(volatile uint32_t *)manager = SBAnortGateFirstFallbackValue;
        afterValue = SBAnortGateReadValue(manager, 0);
    }
    if (callCount <= 12) {
        SBAppendAnortGateEventC("anort-gate-first-wait",
                                manager,
                                beforeValue,
                                afterValue,
                                SBAnortGateReadSemaphoreHandle(manager, 0x8),
                                SBAnortGateReadSemaphoreReady(manager, 0x8),
                                callCount);
    }

    if (orig_anort_gate_first_wait) {
        orig_anort_gate_first_wait(manager);
    }
}

static void replacement_anort_gate_second_wait(void *manager) {
    uint32_t callCount = atomic_fetch_add(&SBAnortGateSecondWaitCallCount, 1) + 1;
    uint32_t beforeValue = SBAnortGateReadValue(manager, 4);

    if (manager && SBAnortMacGateRuntimeBase) {
        SBAnortGateProducer secondProducer =
            (SBAnortGateProducer)(void *)(SBAnortMacGateRuntimeBase + SBAnortGateSecondProducerOffset);
        if (secondProducer && beforeValue == 0) {
            secondProducer(manager);
        }
    }

    uint32_t afterValue = SBAnortGateReadValue(manager, 4);
    if (callCount <= 12) {
        SBAppendAnortGateEventC("anort-gate-second-wait",
                                manager,
                                beforeValue,
                                afterValue,
                                SBAnortGateReadSemaphoreHandle(manager, 0x58),
                                SBAnortGateReadSemaphoreReady(manager, 0x58),
                                callCount);
    }

    if (orig_anort_gate_second_wait) {
        orig_anort_gate_second_wait(manager);
    }
}
#endif

#if SB_MACVER && SB_ENABLE_UNITY_ASSERT_LOG_HOOK
typedef void (*SBUnityAssertLogFunction)(void *entry);

static SBUnityAssertLogFunction orig_unity_assert_log = NULL;
static atomic_uint SBUnityAssertLogCallCount = 0;

static void replacement_unity_assert_log(void *entry) {
    uint32_t callCount = atomic_fetch_add(&SBUnityAssertLogCallCount, 1) + 1;
    if (entry && callCount <= 32) {
        const char *message = *(const char **)entry;
        const char *detail = *(const char **)((uint8_t *)entry + 0x10);
        const char *file = *(const char **)((uint8_t *)entry + 0x18);
        const char *condition = *(const char **)((uint8_t *)entry + 0x20);
        uint32_t line = *(volatile uint32_t *)((uint8_t *)entry + 0x28);
        uint32_t flags = *(volatile uint32_t *)((uint8_t *)entry + 0x30);
        SBAppendUnityAssertEventC("unity-assert-entry",
                                  entry,
                                  flags,
                                  line,
                                  message,
                                  detail,
                                  file,
                                  condition,
                                  callCount);
    }

    if (orig_unity_assert_log) {
        orig_unity_assert_log(entry);
    }
}
#endif

static NSString *SBStringFromObject(id object) {
    if (!object) {
        return @"";
    }
    if ([object isKindOfClass:NSString.class]) {
        return (NSString *)object;
    }
    if ([object respondsToSelector:@selector(description)]) {
        NSString *description = [object description];
        return description ?: @"";
    }
    return @"";
}

static BOOL SBTextContains(NSString *haystack, NSString *needle) {
    return haystack.length > 0 &&
           needle.length > 0 &&
           [haystack rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL SBAceMessageBoxLooksLikeJailbreakBlock(id title, id message, id left, id right) {
    NSString *titleText = SBStringFromObject(title);
    NSString *messageText = SBStringFromObject(message);
    NSString *leftText = SBStringFromObject(left);
    NSString *rightText = SBStringFromObject(right);
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@",
                          titleText, messageText, leftText, rightText];

    if (SBTextContains(combined, @"jailbroken") ||
        SBTextContains(combined, @"security risk") ||
        SBTextContains(combined, @"root_alert")) {
        return YES;
    }

    BOOL warningTitle = SBTextContains(titleText, @"Warning");
    BOOL exitButton = SBTextContains(leftText, @"Exit") || SBTextContains(rightText, @"Exit");
    return warningTitle && exitButton && SBTextContains(messageText, @"jailbreak");
}

static void replacement_AceMsgBoxImp_ShowMessageBox(id self, SEL _cmd, id title, id message, id left, id right) {
    if (SBAceMessageBoxLooksLikeJailbreakBlock(title, message, left, right)) {
        if (!atomic_exchange(&SBAceAlertSuppressedLogged, true)) {
            SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tsuppressed-ace-alert\tAceMsgBoxImp\t\t%@\t\t\t",
                               SBTimestamp(), SBStringFromObject(message)]);
        }
        return;
    }

    if (orig_AceMsgBoxImp_ShowMessageBox) {
        orig_AceMsgBoxImp_ShowMessageBox(self, _cmd, title, message, left, right);
    }
}

static void SBInstallAceAlertHook(void) {
    Class cls = objc_getClass("AceMsgBoxImp");
    if (!cls) {
        return;
    }

    SEL selector = @selector(ShowMessageBoxWithTitle:Message:LeftBtn:RightBtn:);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || atomic_exchange(&SBAceAlertHookInstalled, true)) {
        return;
    }

    orig_AceMsgBoxImp_ShowMessageBox = (SBAceShowMessageBoxImp)method_setImplementation(method, (IMP)replacement_AceMsgBoxImp_ShowMessageBox);
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tace-alert-hook\tAceMsgBoxImp\t\t%s\t\t\t",
                       SBTimestamp(), sel_getName(selector)]);
}

static void SBStartAceAlertHookRetryTimer(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
        for (int i = 1; i <= 60; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * 50 * NSEC_PER_MSEC), queue, ^{
                SBInstallAceAlertHook();
            });
        }
        for (int i = 1; i <= 45; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * NSEC_PER_SEC), queue, ^{
                SBInstallAceAlertHook();
            });
        }
    });
}

static BOOL SBIsUnityFrameworkImageName(const char *name) {
    return name && strstr(name, "/UnityFramework.framework/UnityFramework");
}

#if SB_MACVER && SB_ENABLE_UNITY_ASSERT_LOG_HOOK
static void SBInstallUnityAssertLogHookAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBUnityAssertLogHookInstalled, true)) {
        return;
    }

    MSHookFunction((void *)(base + SBUnityAssertLogOffset),
                   (void *)replacement_unity_assert_log,
                   (void **)&orig_unity_assert_log);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tunity-assert-log-hook\tUnityFramework\t\t%s+0x%llx offset=0x%llx orig=%p\t\t\t",
                       SBTimestamp(),
                       imageName ?: "UnityFramework",
                       (unsigned long long)base,
                       (unsigned long long)SBUnityAssertLogOffset,
                       orig_unity_assert_log]);
    SBWriteMacPluginStatus(orig_unity_assert_log ? @"unity-assert-log-hook" : @"unity-assert-log-hook-failed");
}

static BOOL SBInstallUnityAssertLogHookIfLoaded(void) {
    if (atomic_load(&SBUnityAssertLogHookInstalled)) {
        return YES;
    }

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsUnityFrameworkImageName(name)) {
            SBInstallUnityAssertLogHookAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return YES;
        }
    }
    return NO;
}

static void SBInstallUnityAssertLogHook(void) {
    SBRegisterDyldImageCallback();
    SBInstallUnityAssertLogHookIfLoaded();
}
#endif

#if SB_ENABLE_UNITY_ANOSDK_INIT_BYPASS
static void SBInstallUnityAnoSdkInitBypassAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBUnityAnoSdkInitBypassInstalled, true)) {
        return;
    }

    BOOL sdkInitPatched = SBWriteReturnZeroPatch(base + SBUnityAnoSdkSdkInitExOffset);
    BOOL pinvokeInitPatched = SBWriteReturnZeroPatch(base + SBUnityAnoSdkPInvokeInitExOffset);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tunity-anosdk-init-bypass\tUnityFramework\t\t%s+0x%llx sdk=0x%llx pinvoke=0x%llx patched=%d/%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "UnityFramework",
                       (unsigned long long)base,
                       (unsigned long long)SBUnityAnoSdkSdkInitExOffset,
                       (unsigned long long)SBUnityAnoSdkPInvokeInitExOffset,
                       sdkInitPatched,
                       pinvokeInitPatched]);
#if SB_MACVER
    SBWriteMacPluginStatus((sdkInitPatched && pinvokeInitPatched) ? @"unity-anosdk-init-bypass" : @"unity-anosdk-init-bypass-failed");
#endif
}

static BOOL SBInstallUnityAnoSdkInitBypassIfLoaded(void) {
    if (atomic_load(&SBUnityAnoSdkInitBypassInstalled)) {
        return YES;
    }

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsUnityFrameworkImageName(name)) {
            SBInstallUnityAnoSdkInitBypassAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return YES;
        }
    }
    return NO;
}

static void SBStartUnityAnoSdkInitBypassRetryTimer(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        for (int i = 1; i <= 80; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * 25 * NSEC_PER_MSEC), queue, ^{
                SBInstallUnityAnoSdkInitBypassIfLoaded();
            });
        }
        for (int i = 1; i <= 20; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * NSEC_PER_SEC), queue, ^{
                SBInstallUnityAnoSdkInitBypassIfLoaded();
            });
        }
    });
}

static void SBInstallUnityAnoSdkInitBypass(void) {
    SBRegisterDyldImageCallback();
    SBInstallUnityAnoSdkInitBypassIfLoaded();
    SBStartUnityAnoSdkInitBypassRetryTimer();
}
#endif

#if SB_ENABLE_UNITY_RENDER_CRASH_GUARD
static void SBInstallUnityRenderCrashGuardAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBUnityRenderCrashGuardInstalled, true)) {
        return;
    }

    BOOL callbackListPatched = SBWriteRetPatch(base + SBUnityRenderCallbackListOffset);
    BOOL renderFencePatched = SBWriteRetPatch(base + SBUnityRenderFenceOffset);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tunity-render-crash-guard\tUnityFramework\t\t%s+0x%llx callback=0x%llx fence=0x%llx patched=%d/%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "UnityFramework",
                       (unsigned long long)base,
                       (unsigned long long)SBUnityRenderCallbackListOffset,
                       (unsigned long long)SBUnityRenderFenceOffset,
                       callbackListPatched,
                       renderFencePatched]);
#if SB_MACVER
    SBWriteMacPluginStatus((callbackListPatched && renderFencePatched) ? @"unity-render-crash-guard" : @"unity-render-crash-guard-failed");
#endif
}

static BOOL SBInstallUnityRenderCrashGuardIfLoaded(void) {
    if (atomic_load(&SBUnityRenderCrashGuardInstalled)) {
        return YES;
    }

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsUnityFrameworkImageName(name)) {
            SBInstallUnityRenderCrashGuardAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return YES;
        }
    }
    return NO;
}

static void SBStartUnityRenderCrashGuardRetryTimer(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        for (int i = 1; i <= 80; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * 25 * NSEC_PER_MSEC), queue, ^{
                SBInstallUnityRenderCrashGuardIfLoaded();
            });
        }
        for (int i = 1; i <= 20; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * NSEC_PER_SEC), queue, ^{
                SBInstallUnityRenderCrashGuardIfLoaded();
            });
        }
    });
}

static void SBInstallUnityRenderCrashGuard(void) {
    SBRegisterDyldImageCallback();
    SBInstallUnityRenderCrashGuardIfLoaded();
    SBStartUnityRenderCrashGuardRetryTimer();
}
#endif

#if SB_ENABLE_UNITY_RENDER_ENCODER_GUARD
static void SBInstallUnityRenderEncoderGuardAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBUnityRenderEncoderGuardInstalled, true)) {
        return;
    }

    BOOL encoderPatched = SBWriteRetPatch(base + SBUnityRenderEncoderBeginOffset);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tunity-render-encoder-guard\tUnityFramework\t\t%s+0x%llx encoder=0x%llx patched=%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "UnityFramework",
                       (unsigned long long)base,
                       (unsigned long long)SBUnityRenderEncoderBeginOffset,
                       encoderPatched]);
#if SB_MACVER
    SBWriteMacPluginStatus(encoderPatched ? @"unity-render-encoder-guard" : @"unity-render-encoder-guard-failed");
#endif
}

static BOOL SBInstallUnityRenderEncoderGuardIfLoaded(void) {
    if (atomic_load(&SBUnityRenderEncoderGuardInstalled)) {
        return YES;
    }

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsUnityFrameworkImageName(name)) {
            SBInstallUnityRenderEncoderGuardAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return YES;
        }
    }
    return NO;
}

static void SBStartUnityRenderEncoderGuardRetryTimer(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        for (int i = 1; i <= 80; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * 25 * NSEC_PER_MSEC), queue, ^{
                SBInstallUnityRenderEncoderGuardIfLoaded();
            });
        }
        for (int i = 1; i <= 20; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * NSEC_PER_SEC), queue, ^{
                SBInstallUnityRenderEncoderGuardIfLoaded();
            });
        }
    });
}

static void SBInstallUnityRenderEncoderGuard(void) {
    SBRegisterDyldImageCallback();
    SBInstallUnityRenderEncoderGuardIfLoaded();
    SBStartUnityRenderEncoderGuardRetryTimer();
}
#endif

#if SB_ENABLE_UNITY_GFX_COMMAND_NOOP_GUARD
static void SBInstallUnityGfxCommandNoopGuardNow(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBUnityGfxCommandNoopGuardInstalled, true)) {
        return;
    }

    BOOL interpreterPatched = SBWriteReturnOnePatch(base + SBUnityGfxCommandInterpreterOffset);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tunity-gfx-command-noop-guard\tUnityFramework\t\t%s+0x%llx interpreter=0x%llx patched=%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "UnityFramework",
                       (unsigned long long)base,
                       (unsigned long long)SBUnityGfxCommandInterpreterOffset,
                       interpreterPatched]);
#if SB_MACVER
    SBWriteMacPluginStatus(interpreterPatched ? @"unity-gfx-command-noop-guard" : @"unity-gfx-command-noop-guard-failed");
#endif
}

static void SBInstallUnityGfxCommandNoopGuardAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_load(&SBUnityGfxCommandNoopGuardInstalled)) {
        return;
    }

#if SB_UNITY_GFX_COMMAND_NOOP_DELAY_SECONDS > 0
    if (atomic_exchange(&SBUnityGfxCommandNoopGuardScheduled, true)) {
        return;
    }

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tunity-gfx-command-noop-scheduled\tUnityFramework\t\t%s+0x%llx interpreter=0x%llx delay=%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "UnityFramework",
                       (unsigned long long)base,
                       (unsigned long long)SBUnityGfxCommandInterpreterOffset,
                       SB_UNITY_GFX_COMMAND_NOOP_DELAY_SECONDS]);
#if SB_MACVER
    SBWriteMacPluginStatus(@"unity-gfx-command-noop-scheduled");
#endif

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)SB_UNITY_GFX_COMMAND_NOOP_DELAY_SECONDS * NSEC_PER_SEC),
                   dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^{
                       SBInstallUnityGfxCommandNoopGuardNow(base, imageName);
                   });
#else
    SBInstallUnityGfxCommandNoopGuardNow(base, imageName);
#endif
}

static BOOL SBInstallUnityGfxCommandNoopGuardIfLoaded(void) {
    if (atomic_load(&SBUnityGfxCommandNoopGuardInstalled)) {
        return YES;
    }

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsUnityFrameworkImageName(name)) {
            SBInstallUnityGfxCommandNoopGuardAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return YES;
        }
    }
    return NO;
}

static void SBStartUnityGfxCommandNoopGuardRetryTimer(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        for (int i = 1; i <= 80; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * 25 * NSEC_PER_MSEC), queue, ^{
                SBInstallUnityGfxCommandNoopGuardIfLoaded();
            });
        }
        for (int i = 1; i <= 20; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)i * NSEC_PER_SEC), queue, ^{
                SBInstallUnityGfxCommandNoopGuardIfLoaded();
            });
        }
    });
}

static void SBInstallUnityGfxCommandNoopGuard(void) {
    SBRegisterDyldImageCallback();
    SBInstallUnityGfxCommandNoopGuardIfLoaded();
    SBStartUnityGfxCommandNoopGuardRetryTimer();
}
#endif

static BOOL SBIsAnogsImageName(const char *name) {
    return name && strstr(name, "/anogs.framework/anogs");
}

static BOOL SBIsAnortImageName(const char *name) {
    return name && strstr(name, "/anort.framework/anort");
}

static const char *SBImageNameForHeader(const struct mach_header *header) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        if (_dyld_get_image_header(i) == header) {
            return _dyld_get_image_name(i);
        }
    }
    return NULL;
}

#if SB_ENABLE_ANOGS_HOOKS
static void SBInstallAnogsHooksAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBAnogsHooksInstalled, true)) {
        return;
    }

    MSHookFunction((void *)(base + SBAnogsRootCheckReportCachedOffset),
                   (void *)replacement_anogs_root_check_report_cached,
                   (void **)&orig_anogs_root_check_report_cached);
    MSHookFunction((void *)(base + SBAnogsRootCheckCoreOffset),
                   (void *)replacement_anogs_root_check_core,
                   (void **)&orig_anogs_root_check_core);
    MSHookFunction((void *)(base + SBAnogsJailbreakModuleScanOnceOffset),
                   (void *)replacement_anogs_jailbreak_module_scan_once,
                   (void **)&orig_anogs_jailbreak_module_scan_once);
    MSHookFunction((void *)(base + SBAnogsMaybeShowJailbreakAlertOffset),
                   (void *)replacement_anogs_maybe_show_jailbreak_alert,
                   (void **)&orig_anogs_maybe_show_jailbreak_alert);
    MSHookFunction((void *)(base + SBAnogsJailbreakRecordStateOffset),
                   (void *)replacement_anogs_jailbreak_record_state,
                   (void **)&orig_anogs_jailbreak_record_state);
    MSHookFunction((void *)(base + SBAnogsShowJailbreakAlertOffset),
                   (void *)replacement_anogs_show_jailbreak_alert,
                   (void **)&orig_anogs_show_jailbreak_alert);
    MSHookFunction((void *)(base + SBAnogsIsRootCachedOffset),
                   (void *)replacement_anogs_is_root_cached,
                   (void **)&orig_anogs_is_root_cached);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanogs-hooks\tanogs\t\t%s+0x%llx\t\t\t",
                       SBTimestamp(), imageName ?: "anogs", (unsigned long long)base]);
}
#endif

static void SBInstallAnogsAlertOnlyHookAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBAnogsAlertOnlyHookInstalled, true)) {
        return;
    }

    uintptr_t moduleVtable = base + SBAnogsJailbreakModuleVtableOffset;
    uintptr_t stateVtable = base + SBAnogsJailbreakStateVtableOffset;
    BOOL scanPatched = SBWritePointerValue(moduleVtable + 0x10,
                                           SBPlainFunctionPointer((void *)replacement_anogs_jailbreak_module_scan_once));
    BOOL recordPatched = SBWritePointerValue(moduleVtable + 0x20,
                                             SBPlainFunctionPointer((void *)replacement_anogs_jailbreak_record_state));
    BOOL alertPatched = SBWritePointerValue(moduleVtable + 0x28,
                                            SBPlainFunctionPointer((void *)replacement_anogs_maybe_show_jailbreak_alert));
    BOOL stateThunkPatched = SBWritePointerValue(stateVtable + 0x10,
                                                 SBPlainFunctionPointer((void *)replacement_anogs_jailbreak_record_state));

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanogs-vtable-hook\tanogs\t\t%s+0x%llx off=0x%llx vt=0x%llx/0x%llx patched=%d/%d/%d/%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "anogs",
                       (unsigned long long)base,
                       (unsigned long long)SBAnogsJailbreakModuleVtableOffset,
                       (unsigned long long)moduleVtable,
                       (unsigned long long)stateVtable,
                       scanPatched,
                       recordPatched,
                       alertPatched,
                       stateThunkPatched]);
}

static void SBInstallAnortHookAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBAnortHookInstalled, true)) {
        return;
    }

    uintptr_t checkEngineVtable = base + SBAnortCheckEngineVtableOffset;
    BOOL runPatched = SBWritePointerValue(checkEngineVtable + 0x10,
                                          SBPlainFunctionPointer((void *)replacement_anort_check_engine_run));

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanort-vtable-hook\tanort\t\t%s+0x%llx off=0x%llx vt=0x%llx patched=%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "anort",
                       (unsigned long long)base,
                       (unsigned long long)SBAnortCheckEngineVtableOffset,
                       (unsigned long long)checkEngineVtable,
                       runPatched]);
}

static void SBInstallAnortTextPatchesAtBase(uintptr_t base) {
    if (!base || atomic_exchange(&SBAnortTextPatchInstalled, true)) {
        return;
    }

    BOOL threadReportSamplerPatched = SBWriteReturnZeroPatch(base + SBAnortThreadReportSamplerOffset);
    BOOL reportFlushPatched = SBWriteReturnZeroPatch(base + SBAnortReportFlushOffset);
    BOOL vmResultHandlerPatched = SBWriteReturnZeroPatch(base + SBAnortVMResultHandlerOffset);
    BOOL vmMonitorRunPatched = SBWriteReturnZeroPatch(base + SBAnortVMMonitorRunOffset);
    BOOL firstWaitPatched = NO;
    BOOL secondWaitPatched = NO;
#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_WAIT_RET
    firstWaitPatched = SBWriteRetPatch(base + SBAnortGateFirstWaitOffset);
    secondWaitPatched = SBWriteRetPatch(base + SBAnortGateSecondWaitOffset);
#endif
    SBAppendAnogsEventC("anort-text-patch",
                        (void *)base,
                        (void *)(uintptr_t)((threadReportSamplerPatched ? 1u : 0u) |
                                            (reportFlushPatched ? 2u : 0u) |
                                            (vmResultHandlerPatched ? 4u : 0u) |
                                            (vmMonitorRunPatched ? 8u : 0u) |
                                            (firstWaitPatched ? 16u : 0u) |
                                            (secondWaitPatched ? 32u : 0u)));
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanort-detection-text-patch\tanort\t\tbase=0x%llx threadRun=0x%llx/kept reportSampler=0x%llx/%d reportFlush=0x%llx/%d vmResult=0x%llx/%d vmMonitor=0x%llx/%d\t\t\t",
                       SBTimestamp(),
                       (unsigned long long)base,
                       (unsigned long long)SBAnortThreadCheckRunOffset,
                       (unsigned long long)SBAnortThreadReportSamplerOffset,
                       threadReportSamplerPatched,
                       (unsigned long long)SBAnortReportFlushOffset,
                       reportFlushPatched,
                       (unsigned long long)SBAnortVMResultHandlerOffset,
                       vmResultHandlerPatched,
                       (unsigned long long)SBAnortVMMonitorRunOffset,
                       vmMonitorRunPatched]);
    SBWriteMacPluginStatus((threadReportSamplerPatched && reportFlushPatched && vmMonitorRunPatched) ? @"anort-detection-text-patch" : @"anort-detection-text-patch-failed");
}

#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_WAIT_HOOK
static void SBInstallAnortMacGateWaitHookAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBAnortMacGateWaitHookInstalled, true)) {
        return;
    }

    SBAnortMacGateRuntimeBase = base;
    MSHookFunction((void *)(base + SBAnortGateFirstWaitOffset),
                   (void *)replacement_anort_gate_first_wait,
                   (void **)&orig_anort_gate_first_wait);
    MSHookFunction((void *)(base + SBAnortGateSecondWaitOffset),
                   (void *)replacement_anort_gate_second_wait,
                   (void **)&orig_anort_gate_second_wait);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanort-mac-gate-wait-hook\tanort\t\t%s+0x%llx first=0x%llx second=0x%llx orig=%p/%p\t\t\t",
                       SBTimestamp(),
                       imageName ?: "anort",
                       (unsigned long long)base,
                       (unsigned long long)SBAnortGateFirstWaitOffset,
                       (unsigned long long)SBAnortGateSecondWaitOffset,
                       orig_anort_gate_first_wait,
                       orig_anort_gate_second_wait]);
    SBWriteMacPluginStatus((orig_anort_gate_first_wait && orig_anort_gate_second_wait) ? @"anort-mac-gate-wait-hook" : @"anort-mac-gate-wait-hook-failed");
}
#endif

#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_PRIME
static void SBPrimeAnortMacGateAtBase(uintptr_t base, const char *imageName) {
    if (!base || atomic_exchange(&SBAnortMacGatePrimeScheduled, true)) {
        return;
    }

    NSString *image = imageName ? [NSString stringWithUTF8String:imageName] : @"anort";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        SBAnortGateManagerGetter managerGetter =
            (SBAnortGateManagerGetter)(void *)(base + SBAnortGateManagerGetterOffset);
        SBAnortGateProducer firstProducer =
            (SBAnortGateProducer)(void *)(base + SBAnortGateFirstProducerOffset);
        SBAnortGateProducer secondProducer =
            (SBAnortGateProducer)(void *)(base + SBAnortGateSecondProducerOffset);

        void *manager = NULL;
        uint32_t firstValue = 0;
        uint32_t secondValue = 0;
        BOOL ok = NO;

        if (managerGetter && firstProducer && secondProducer) {
            manager = managerGetter();
            if (manager) {
                firstProducer(manager);
                secondProducer(manager);
                firstValue = *(uint32_t *)manager;
                secondValue = *(((uint32_t *)manager) + 1);
                ok = YES;
            }
        }

        SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanort-mac-gate-prime\tanort\t\t%@+0x%llx manager=%p values=0x%08x/0x%08x ok=%d\t\t\t",
                           SBTimestamp(),
                           image ?: @"anort",
                           (unsigned long long)base,
                           manager,
                           firstValue,
                           secondValue,
                           ok]);
        SBWriteMacPluginStatus(ok ? @"anort-mac-gate-prime" : @"anort-mac-gate-prime-failed");
    });
}
#endif

#if SB_MACVER && SB_ENABLE_MAC_DIRECT_SYSCALL_GUARD && SB_ENABLE_MAC_SELF_KILL_GUARD
static void SBInstallMacDirectSyscallGuardAtBase(uintptr_t base, const char *imageName) {
    if (!base || !imageName) {
        return;
    }

    if (SBIsAnortImageName(imageName)) {
        if (atomic_exchange(&SBMacDirectSyscallGuardAnortInstalled, true)) {
            return;
        }

        MSHookFunction((void *)(base + SBAnortIndirectSyscallSvcOffset),
                       (void *)replacement_mac_indirect_syscall_svc,
                       NULL);
        SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-direct-syscall-guard\tanort\t\t%s+0x%llx svc=0x%llx count=1\t\t\t",
                           SBTimestamp(),
                           imageName,
                           (unsigned long long)base,
                           (unsigned long long)SBAnortIndirectSyscallSvcOffset]);
        SBWriteMacPluginStatus(@"mac-direct-syscall-guard-anort");
        return;
    }

    if (SBIsAnogsImageName(imageName)) {
        if (atomic_exchange(&SBMacDirectSyscallGuardAnogsInstalled, true)) {
            return;
        }

        size_t count = sizeof(SBAnogsIndirectSyscallSvcOffsets) / sizeof(SBAnogsIndirectSyscallSvcOffsets[0]);
        for (size_t i = 0; i < count; i++) {
            MSHookFunction((void *)(base + SBAnogsIndirectSyscallSvcOffsets[i]),
                           (void *)replacement_mac_indirect_syscall_svc,
                           NULL);
        }
        SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-direct-syscall-guard\tanogs\t\t%s+0x%llx svcCount=%zu\t\t\t",
                           SBTimestamp(),
                           imageName,
                           (unsigned long long)base,
                           count]);
        SBWriteMacPluginStatus(@"mac-direct-syscall-guard-anogs");
    }
}

static void SBInstallMacDirectSyscallGuard(void) {
    SBRegisterDyldImageCallback();

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsAnortImageName(name) || SBIsAnogsImageName(name)) {
            SBInstallMacDirectSyscallGuardAtBase((uintptr_t)_dyld_get_image_header(i), name);
        }
    }
}
#endif

#if SB_MACVER && SB_ENABLE_ANORT_SELF_KILL_TERMINATOR_PATCH
static void SBInstallAnortSelfKillTerminatorPatchAtBase(uintptr_t base, const char *imageName) {
    if (!base || !SBIsAnortImageName(imageName) ||
        atomic_exchange(&SBAnortSelfKillTerminatorPatchInstalled, true)) {
        return;
    }

    BOOL primaryPatched = SBWriteReturnZeroPatch(base + SBAnortKillSelfTerminatorOffset);
    BOOL altPatched = SBWriteReturnZeroPatch(base + SBAnortKillSelfTerminatorAltOffset);
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanort-self-kill-terminator-patch\tanort\t\t%s+0x%llx primary=0x%llx alt=0x%llx patched=%d/%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "anort",
                       (unsigned long long)base,
                       (unsigned long long)SBAnortKillSelfTerminatorOffset,
                       (unsigned long long)SBAnortKillSelfTerminatorAltOffset,
                       primaryPatched,
                       altPatched]);
    SBWriteMacPluginStatus((primaryPatched && altPatched) ? @"anort-self-kill-terminator-patch" : @"anort-self-kill-terminator-patch-failed");
}

static void SBInstallAnortSelfKillTerminatorPatch(void) {
    SBRegisterDyldImageCallback();

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsAnortImageName(name)) {
            SBInstallAnortSelfKillTerminatorPatchAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return;
        }
    }
}
#endif

#if SB_MACVER && SB_ENABLE_ANORT_OBJC_LOAD_BYPASS
static void SBInstallAnortObjCLoadBypassAtBase(uintptr_t base, const char *imageName) {
    if (!base || !SBIsAnortImageName(imageName) ||
        atomic_exchange(&SBAnortObjCLoadBypassInstalled, true)) {
        return;
    }

    BOOL loadPatched = SBWriteReturnZeroPatch(base + SBAnortObjCLoadOffset);
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tanort-objc-load-bypass\tanort\t\t%s+0x%llx load=0x%llx patched=%d\t\t\t",
                       SBTimestamp(),
                       imageName ?: "anort",
                       (unsigned long long)base,
                       (unsigned long long)SBAnortObjCLoadOffset,
                       loadPatched]);
    SBWriteMacPluginStatus(loadPatched ? @"anort-objc-load-bypass" : @"anort-objc-load-bypass-failed");
}

static void SBInstallAnortObjCLoadBypass(void) {
    SBRegisterDyldImageCallback();

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsAnortImageName(name)) {
            SBInstallAnortObjCLoadBypassAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return;
        }
    }
}
#endif

static void SBInstallHooksForImage(uintptr_t base, const char *name) {
#if SB_MACVER && SB_ENABLE_ANORT_OBJC_LOAD_BYPASS
    if (SBIsAnortImageName(name)) {
        SBInstallAnortObjCLoadBypassAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_ANORT_SELF_KILL_TERMINATOR_PATCH
    if (SBIsAnortImageName(name)) {
        SBInstallAnortSelfKillTerminatorPatchAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_MAC_DIRECT_SYSCALL_GUARD && SB_ENABLE_MAC_SELF_KILL_GUARD
    if (SBIsAnortImageName(name) || SBIsAnogsImageName(name)) {
        SBInstallMacDirectSyscallGuardAtBase(base, name);
    }
#endif
#if SB_ENABLE_ANOGS_HOOKS
    if (SBIsAnogsImageName(name)) {
        SBInstallAnogsHooksAtBase(base, name);
    }
#endif
#if SB_ENABLE_ANOGS_ALERT_ONLY_HOOK
    if (SBIsAnogsImageName(name)) {
        SBInstallAnogsAlertOnlyHookAtBase(base, name);
    }
#endif
#if SB_ENABLE_ACE_ALERT_BYPASS
    if (SBIsAnogsImageName(name)) {
        SBInstallAceAlertHook();
    }
#endif
#if SB_ENABLE_ANORT_VTABLE_HOOK
    if (SBIsAnortImageName(name)) {
        SBInstallAnortHookAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_PRIME
    if (SBIsAnortImageName(name)) {
        SBPrimeAnortMacGateAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_WAIT_HOOK
    if (SBIsAnortImageName(name)) {
        SBInstallAnortMacGateWaitHookAtBase(base, name);
    }
#endif
}

static void SBHandleAddedImage(const struct mach_header *header, intptr_t slide) {
    (void)slide;
    const char *name = SBImageNameForHeader(header);
    if (!SBIsAnogsImageName(name) && !SBIsAnortImageName(name) && !SBIsUnityFrameworkImageName(name)) {
        return;
    }

    uintptr_t base = (uintptr_t)header;
#if SB_ENABLE_UNITY_ANOSDK_INIT_BYPASS
    if (SBIsUnityFrameworkImageName(name)) {
        SBInstallUnityAnoSdkInitBypassAtBase(base, name);
    }
#endif
#if SB_ENABLE_UNITY_RENDER_CRASH_GUARD
    if (SBIsUnityFrameworkImageName(name)) {
        SBInstallUnityRenderCrashGuardAtBase(base, name);
    }
#endif
#if SB_ENABLE_UNITY_RENDER_ENCODER_GUARD
    if (SBIsUnityFrameworkImageName(name)) {
        SBInstallUnityRenderEncoderGuardAtBase(base, name);
    }
#endif
#if SB_ENABLE_UNITY_GFX_COMMAND_NOOP_GUARD
    if (SBIsUnityFrameworkImageName(name)) {
        SBInstallUnityGfxCommandNoopGuardAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_UNITY_ASSERT_LOG_HOOK
    if (SBIsUnityFrameworkImageName(name)) {
        SBInstallUnityAssertLogHookAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_ANORT_OBJC_LOAD_BYPASS
    if (SBIsAnortImageName(name)) {
        SBInstallAnortObjCLoadBypassAtBase(base, name);
    }
#endif
#if SB_ENABLE_ANORT_VM_HOOK
    if (SBIsAnortImageName(name)) {
        SBInstallAnortTextPatchesAtBase(base);
    }
#endif
#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_WAIT_HOOK
    if (SBIsAnortImageName(name)) {
        SBInstallAnortMacGateWaitHookAtBase(base, name);
    }
#endif
#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_PRIME
    if (SBIsAnortImageName(name)) {
        SBPrimeAnortMacGateAtBase(base, name);
    }
#endif

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                   ^{
                       SBInstallHooksForImage(base, name);
                   });
}

static void SBRegisterDyldImageCallback(void) {
    if (!atomic_exchange(&SBDyldImageCallbackRegistered, true)) {
        _dyld_register_func_for_add_image(SBHandleAddedImage);
    }
}

#if SB_ENABLE_ANOGS_HOOKS
static void SBInstallAnogsHooks(void) {
    SBRegisterDyldImageCallback();

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsAnogsImageName(name)) {
            SBInstallAnogsHooksAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return;
        }
    }
}
#endif

static void SBInstallAnogsAlertOnlyHook(void) {
    SBRegisterDyldImageCallback();

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsAnogsImageName(name)) {
            SBInstallAnogsAlertOnlyHookAtBase((uintptr_t)_dyld_get_image_header(i), name);
            return;
        }
    }
}

static void SBInstallAnortHooks(void) {
    SBRegisterDyldImageCallback();

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (SBIsAnortImageName(name)) {
            uintptr_t base = (uintptr_t)_dyld_get_image_header(i);
            SBInstallAnortTextPatchesAtBase(base);
#if SB_ENABLE_ANORT_VTABLE_HOOK
            SBInstallAnortHookAtBase(base, name);
#endif
#if SB_MACVER && SB_ENABLE_ANORT_MAC_GATE_PRIME
            SBPrimeAnortMacGateAtBase(base, name);
#endif
            return;
        }
    }
}

static void SBInstallAceAlertHooks(void) {
    SBInstallAceAlertHook();
    SBStartAceAlertHookRetryTimer();
}

typedef BOOL (*SBFileExistsImp)(id self, SEL _cmd, NSString *path);
typedef BOOL (*SBFileExistsDirImp)(id self, SEL _cmd, NSString *path, BOOL *isDirectory);
typedef NSDictionary *(*SBAttributesImp)(id self, SEL _cmd, NSString *path, NSError **error);
typedef BOOL (*SBCanOpenURLImp)(id self, SEL _cmd, NSURL *url);
typedef void (*SBPresentImp)(id self, SEL _cmd, UIViewController *controller, BOOL animated, void (^completion)(void));
typedef void (*SBAlertViewShowImp)(id self, SEL _cmd);
#if SB_ENABLE_FOUNDATION_NETWORK_LOG
typedef NSURLSession *(*SBSessionWithConfigurationDelegateImp)(id self, SEL _cmd, NSURLSessionConfiguration *configuration, id delegate, NSOperationQueue *queue);
#endif

static SBFileExistsImp orig_fileExistsAtPath;
static SBFileExistsDirImp orig_fileExistsAtPathIsDirectory;
static SBFileExistsImp orig_isReadableFileAtPath;
static SBFileExistsImp orig_isExecutableFileAtPath;
static SBAttributesImp orig_attributesOfItemAtPath;
static SBCanOpenURLImp orig_canOpenURL;
static SBPresentImp orig_presentViewController;
static SBAlertViewShowImp orig_alertViewShow;
#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static SBSessionWithConfigurationDelegateImp orig_sessionWithConfigurationDelegate;
#endif

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static NSString *SBDelegateImpKey(Class cls, SEL selector) {
    return [NSString stringWithFormat:@"%s|%s", class_getName(cls), sel_getName(selector)];
}

static NSMutableDictionary<NSString *, NSValue *> *SBDelegateOriginals(void) {
    static NSMutableDictionary<NSString *, NSValue *> *originals;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        originals = [NSMutableDictionary dictionary];
    });
    return originals;
}

static NSMutableSet<NSString *> *SBHookedDelegateClasses(void) {
    static NSMutableSet<NSString *> *classes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classes = [NSMutableSet set];
    });
    return classes;
}

static void SBStoreDelegateOriginal(Class cls, SEL selector, IMP imp) {
    if (!cls || !selector) {
        return;
    }
    SBDelegateOriginals()[SBDelegateImpKey(cls, selector)] = [NSValue valueWithPointer:imp];
}

static IMP SBGetDelegateOriginal(id self, SEL selector) {
    Class cls = object_getClass(self);
    NSMutableDictionary<NSString *, NSValue *> *originals = SBDelegateOriginals();
    while (cls) {
        NSValue *value = originals[SBDelegateImpKey(cls, selector)];
        if (value) {
            return value.pointerValue;
        }
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

static void SBInstallDelegateMethod(Class cls, SEL selector, IMP replacement, const char *types) {
    Method inheritedOrOwn = class_getInstanceMethod(cls, selector);
    IMP original = inheritedOrOwn ? method_getImplementation(inheritedOrOwn) : NULL;

    if (!class_addMethod(cls, selector, replacement, types)) {
        Method method = class_getInstanceMethod(cls, selector);
        if (method) {
            original = method_setImplementation(method, replacement);
        }
    }
    SBStoreDelegateOriginal(cls, selector, original);
}

static void replacement_URLSessionDataTaskDidReceiveResponse(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response, void (^completionHandler)(NSURLSessionResponseDisposition disposition)) {
    unsigned long ident = SBEnsureTaskIdent(dataTask, @"NSURLSession delegate didReceiveResponse");
    if (ident != 0 && response && !SBResponseFileExists(ident)) {
        SBWriteResponseFile(ident, response, nil, nil, @"NSURLSession delegate didReceiveResponse");
    }

    IMP original = SBGetDelegateOriginal(self, _cmd);
    if (original) {
        ((void (*)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSURLResponse *, void (^)(NSURLSessionResponseDisposition)))original)(self, _cmd, session, dataTask, response, completionHandler);
    } else if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

static void replacement_URLSessionDataTaskDidReceiveData(id self, SEL _cmd, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {
    unsigned long ident = SBTaskIdent(dataTask);
    if (ident == 0) {
        ident = SBEnsureTaskIdent(dataTask, @"NSURLSession delegate didReceiveData");
    }
    if (ident != 0 && data.length > 0) {
        NSMutableData *body = SBTaskMutableData(dataTask);
        if (body.length < SBMaxLoggedBodyBytes) {
            NSUInteger remaining = SBMaxLoggedBodyBytes - body.length;
            [body appendData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, remaining))]];
        }
    }

    IMP original = SBGetDelegateOriginal(self, _cmd);
    if (original) {
        ((void (*)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSData *))original)(self, _cmd, session, dataTask, data);
    }
}

static void replacement_URLSessionTaskDidCompleteWithError(id self, SEL _cmd, NSURLSession *session, NSURLSessionTask *task, NSError *error) {
    unsigned long ident = SBEnsureTaskIdent(task, @"NSURLSession delegate didComplete");
    NSData *body = objc_getAssociatedObject(task, &SBTaskDataKey);
    if (ident != 0 && (body.length > 0 || error || !SBResponseFileExists(ident))) {
        SBLogResponse(ident, task.response, body, error, SBTaskSource(task));
    }

    IMP original = SBGetDelegateOriginal(self, _cmd);
    if (original) {
        ((void (*)(id, SEL, NSURLSession *, NSURLSessionTask *, NSError *))original)(self, _cmd, session, task, error);
    }
}

static void replacement_URLSessionDownloadTaskDidFinishDownloading(id self, SEL _cmd, NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location) {
    unsigned long ident = SBEnsureTaskIdent(downloadTask, @"NSURLSession delegate download");
    NSData *body = ident != 0 && location ? [NSData dataWithContentsOfURL:location options:0 error:nil] : nil;
    if (ident != 0) {
        SBLogResponse(ident, downloadTask.response, body, nil, @"NSURLSession delegate download");
    }

    IMP original = SBGetDelegateOriginal(self, _cmd);
    if (original) {
        ((void (*)(id, SEL, NSURLSession *, NSURLSessionDownloadTask *, NSURL *))original)(self, _cmd, session, downloadTask, location);
    }
}

static void SBHookSessionDelegate(id delegate) {
    if (!delegate) {
        return;
    }

    Class cls = object_getClass(delegate);
    NSString *className = @(class_getName(cls));
    @synchronized (SBHookedDelegateClasses()) {
        if ([SBHookedDelegateClasses() containsObject:className]) {
            return;
        }
        [SBHookedDelegateClasses() addObject:className];

        SBInstallDelegateMethod(cls,
                                @selector(URLSession:dataTask:didReceiveResponse:completionHandler:),
                                (IMP)replacement_URLSessionDataTaskDidReceiveResponse,
                                "v@:@@@?");
        SBInstallDelegateMethod(cls,
                                @selector(URLSession:dataTask:didReceiveData:),
                                (IMP)replacement_URLSessionDataTaskDidReceiveData,
                                "v@:@@@");
        SBInstallDelegateMethod(cls,
                                @selector(URLSession:task:didCompleteWithError:),
                                (IMP)replacement_URLSessionTaskDidCompleteWithError,
                                "v@:@@@");
        SBInstallDelegateMethod(cls,
                                @selector(URLSession:downloadTask:didFinishDownloadingToURL:),
                                (IMP)replacement_URLSessionDownloadTaskDidFinishDownloading,
                                "v@:@@@");
    }
}

static NSURLSession *replacement_sessionWithConfigurationDelegate(id self, SEL _cmd, NSURLSessionConfiguration *configuration, id delegate, NSOperationQueue *queue) {
    SBHookSessionDelegate(delegate);
    return orig_sessionWithConfigurationDelegate(self, _cmd, configuration, delegate, queue);
}
#endif

static BOOL replacement_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (SBPathShouldHide(path)) {
        return NO;
    }
    return orig_fileExistsAtPath(self, _cmd, path);
}

static BOOL replacement_fileExistsAtPathIsDirectory(id self, SEL _cmd, NSString *path, BOOL *isDirectory) {
    if (SBPathShouldHide(path)) {
        if (isDirectory) {
            *isDirectory = NO;
        }
        return NO;
    }
    return orig_fileExistsAtPathIsDirectory(self, _cmd, path, isDirectory);
}

static BOOL replacement_isReadableFileAtPath(id self, SEL _cmd, NSString *path) {
    if (SBPathShouldHide(path)) {
        return NO;
    }
    return orig_isReadableFileAtPath(self, _cmd, path);
}

static BOOL replacement_isExecutableFileAtPath(id self, SEL _cmd, NSString *path) {
    if (SBPathShouldHide(path)) {
        return NO;
    }
    return orig_isExecutableFileAtPath(self, _cmd, path);
}

static NSDictionary *replacement_attributesOfItemAtPath(id self, SEL _cmd, NSString *path, NSError **error) {
    if (SBPathShouldHide(path)) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        }
        return nil;
    }
    return orig_attributesOfItemAtPath(self, _cmd, path, error);
}

static BOOL replacement_canOpenURL(id self, SEL _cmd, NSURL *url) {
    if (SBURLSchemeShouldHide(url)) {
        return NO;
    }
    return orig_canOpenURL(self, _cmd, url);
}

static BOOL SBAlertLooksLikeJailbreakBlock(UIViewController *controller) {
    if (![controller isKindOfClass:UIAlertController.class]) {
        return NO;
    }

    UIAlertController *alert = (UIAlertController *)controller;
    NSMutableString *actions = [NSMutableString string];
    for (UIAlertAction *action in alert.actions) {
        if (action.title.length > 0) {
            [actions appendFormat:@"%@ ", action.title];
        }
    }
    return SBAceMessageBoxLooksLikeJailbreakBlock(alert.title, alert.message, actions, nil);
}

static void replacement_presentViewController(id self, SEL _cmd, UIViewController *controller, BOOL animated, void (^completion)(void)) {
    if (SBAlertLooksLikeJailbreakBlock(controller)) {
        if (!atomic_exchange(&SBUIAlertSuppressedLogged, true)) {
            SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tsuppressed-uialertcontroller\tUIViewController\t\t%@\t\t\t",
                               SBTimestamp(), ((UIAlertController *)controller).message ?: @""]);
        }
        if (completion) {
            completion();
        }
        return;
    }
    orig_presentViewController(self, _cmd, controller, animated, completion);
}

static NSString *SBObjectValueForSelector(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector]) {
        return @"";
    }
    id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
    return SBStringFromObject(value);
}

static NSString *SBAlertViewButtonText(id alertView) {
    if (!alertView || ![alertView respondsToSelector:@selector(numberOfButtons)] ||
        ![alertView respondsToSelector:@selector(buttonTitleAtIndex:)]) {
        return @"";
    }

    NSInteger count = ((NSInteger (*)(id, SEL))objc_msgSend)(alertView, @selector(numberOfButtons));
    NSMutableString *buttons = [NSMutableString string];
    for (NSInteger i = 0; i < count; i++) {
        id title = ((id (*)(id, SEL, NSInteger))objc_msgSend)(alertView, @selector(buttonTitleAtIndex:), i);
        NSString *text = SBStringFromObject(title);
        if (text.length > 0) {
            [buttons appendFormat:@"%@ ", text];
        }
    }
    return buttons;
}

static BOOL SBAlertViewLooksLikeJailbreakBlock(id alertView) {
    NSString *title = SBObjectValueForSelector(alertView, @selector(title));
    NSString *message = SBObjectValueForSelector(alertView, @selector(message));
    NSString *buttons = SBAlertViewButtonText(alertView);
    return SBAceMessageBoxLooksLikeJailbreakBlock(title, message, buttons, nil);
}

static void replacement_alertViewShow(id self, SEL _cmd) {
    if (SBAlertViewLooksLikeJailbreakBlock(self)) {
        if (!atomic_exchange(&SBUIAlertSuppressedLogged, true)) {
            SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tsuppressed-uialertview\tUIAlertView\t\t%@\t\t\t",
                               SBTimestamp(), SBObjectValueForSelector(self, @selector(message))]);
        }
        return;
    }

    if (orig_alertViewShow) {
        orig_alertViewShow(self, _cmd);
    }
}

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
typedef void (^SBDataCompletion)(NSData *data, NSURLResponse *response, NSError *error);
typedef void (^SBDownloadCompletion)(NSURL *location, NSURLResponse *response, NSError *error);

typedef NSURLSessionDataTask *(*SBDataTaskRequestImp)(id self, SEL _cmd, NSURLRequest *request, SBDataCompletion completion);
typedef NSURLSessionDataTask *(*SBDataTaskURLImp)(id self, SEL _cmd, NSURL *url, SBDataCompletion completion);
typedef NSURLSessionUploadTask *(*SBUploadTaskDataImp)(id self, SEL _cmd, NSURLRequest *request, NSData *bodyData, SBDataCompletion completion);
typedef NSURLSessionDownloadTask *(*SBDownloadTaskRequestImp)(id self, SEL _cmd, NSURLRequest *request, SBDownloadCompletion completion);
typedef void (*SBResumeImp)(id self, SEL _cmd);
typedef NSData *(*SBSendSyncImp)(id self, SEL _cmd, NSURLRequest *request, NSURLResponse **response, NSError **error);
typedef void (*SBSendAsyncImp)(id self, SEL _cmd, NSURLRequest *request, NSOperationQueue *queue, SBDataCompletion completion);

static SBDataTaskRequestImp orig_dataTaskWithRequestCompletion;
static SBDataTaskURLImp orig_dataTaskWithURLCompletion;
static SBUploadTaskDataImp orig_uploadTaskWithRequestFromDataCompletion;
static SBDownloadTaskRequestImp orig_downloadTaskWithRequestCompletion;
static SBResumeImp orig_taskResume;
static SBSendSyncImp orig_sendSynchronousRequest;
static SBSendAsyncImp orig_sendAsynchronousRequest;

static NSURLSessionDataTask *replacement_dataTaskWithRequestCompletion(id self, SEL _cmd, NSURLRequest *request, SBDataCompletion completion) {
    NSString *source = @"NSURLSession dataTaskWithRequest";
    unsigned long ident = SBLogRequest(request, nil, source);
    SBDataCompletion wrapped = completion ? [^(NSData *data, NSURLResponse *response, NSError *error) {
        SBLogResponse(ident, response, data, error, source);
        completion(data, response, error);
    } copy] : nil;
    NSURLSessionDataTask *task = orig_dataTaskWithRequestCompletion(self, _cmd, request, wrapped);
    SBAssociateTask(task, ident, source);
    return task;
}

static NSURLSessionDataTask *replacement_dataTaskWithURLCompletion(id self, SEL _cmd, NSURL *url, SBDataCompletion completion) {
    NSURLRequest *request = url ? [NSURLRequest requestWithURL:url] : nil;
    NSString *source = @"NSURLSession dataTaskWithURL";
    unsigned long ident = SBLogRequest(request, nil, source);
    SBDataCompletion wrapped = completion ? [^(NSData *data, NSURLResponse *response, NSError *error) {
        SBLogResponse(ident, response, data, error, source);
        completion(data, response, error);
    } copy] : nil;
    NSURLSessionDataTask *task = orig_dataTaskWithURLCompletion(self, _cmd, url, wrapped);
    SBAssociateTask(task, ident, source);
    return task;
}

static NSURLSessionUploadTask *replacement_uploadTaskWithRequestFromDataCompletion(id self, SEL _cmd, NSURLRequest *request, NSData *bodyData, SBDataCompletion completion) {
    NSString *source = @"NSURLSession uploadTaskWithRequest";
    unsigned long ident = SBLogRequest(request, bodyData, source);
    SBDataCompletion wrapped = completion ? [^(NSData *data, NSURLResponse *response, NSError *error) {
        SBLogResponse(ident, response, data, error, source);
        completion(data, response, error);
    } copy] : nil;
    NSURLSessionUploadTask *task = orig_uploadTaskWithRequestFromDataCompletion(self, _cmd, request, bodyData, wrapped);
    SBAssociateTask(task, ident, source);
    return task;
}

static NSURLSessionDownloadTask *replacement_downloadTaskWithRequestCompletion(id self, SEL _cmd, NSURLRequest *request, SBDownloadCompletion completion) {
    NSString *source = @"NSURLSession downloadTaskWithRequest";
    unsigned long ident = SBLogRequest(request, nil, source);
    SBDownloadCompletion wrapped = completion ? [^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSData *body = ident != 0 && location ? [NSData dataWithContentsOfURL:location options:0 error:nil] : nil;
        SBLogResponse(ident, response, body, error, source);
        completion(location, response, error);
    } copy] : nil;
    NSURLSessionDownloadTask *task = orig_downloadTaskWithRequestCompletion(self, _cmd, request, wrapped);
    SBAssociateTask(task, ident, source);
    return task;
}

static void replacement_taskResume(id self, SEL _cmd) {
    if ([self respondsToSelector:@selector(currentRequest)]) {
        NSURLRequest *request = ((NSURLRequest *(*)(id, SEL))objc_msgSend)(self, @selector(currentRequest));
        unsigned long ident = SBTaskIdent(self);
        if (ident == 0 && request.URL) {
            unsigned long ident = SBLogRequest(request, nil, @"NSURLSessionTask resume");
            SBAssociateTask(self, ident, @"NSURLSessionTask resume");
        } else if (ident != 0 && request.HTTPBody.length > 0) {
            SBWriteRequestFile(ident, request, nil, @"NSURLSessionTask resume");
        }
    }
    orig_taskResume(self, _cmd);
}

static NSData *replacement_sendSynchronousRequest(id self, SEL _cmd, NSURLRequest *request, NSURLResponse **response, NSError **error) {
    unsigned long ident = SBLogRequest(request, nil, @"NSURLConnection sendSynchronousRequest");
    NSData *data = orig_sendSynchronousRequest(self, _cmd, request, response, error);
    SBLogResponse(ident, response ? *response : nil, data, error ? *error : nil, @"NSURLConnection sendSynchronousRequest");
    return data;
}

static void replacement_sendAsynchronousRequest(id self, SEL _cmd, NSURLRequest *request, NSOperationQueue *queue, SBDataCompletion completion) {
    unsigned long ident = SBLogRequest(request, nil, @"NSURLConnection sendAsynchronousRequest");
    SBDataCompletion wrapped = completion ? [^(NSData *data, NSURLResponse *response, NSError *error) {
        SBLogResponse(ident, response, data, error, @"NSURLConnection sendAsynchronousRequest");
        completion(data, response, error);
    } copy] : nil;
    orig_sendAsynchronousRequest(self, _cmd, request, queue, wrapped);
}
#endif

static void SBReplaceInstanceMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (method) {
        IMP previous = method_setImplementation(method, replacement);
        if (original) {
            *original = previous;
        }
    }
}

#if SB_MACVER && SB_ENABLE_MAC_LIFECYCLE_GUARD
static void SBLogMacLifecycleGuard(SEL selector, uintptr_t a0, uintptr_t a1, uintptr_t a2) {
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-lifecycle-guard\t%@\t\t%s a0=0x%llx a1=0x%llx a2=0x%llx\t\t\t",
                       SBTimestamp(),
                       NSStringFromClass(UIApplication.class),
                       selector ? sel_getName(selector) : "(null)",
                       (unsigned long long)a0,
                       (unsigned long long)a1,
                       (unsigned long long)a2]);
}

static void replacement_UIApplicationLifecycle0(id self, SEL _cmd) {
    (void)self;
    SBLogMacLifecycleGuard(_cmd, 0, 0, 0);
}

static void replacement_UIApplicationLifecycle1(id self, SEL _cmd, uintptr_t a0) {
    (void)self;
    SBLogMacLifecycleGuard(_cmd, a0, 0, 0);
}

static void replacement_UIApplicationLifecycle2(id self, SEL _cmd, uintptr_t a0, uintptr_t a1) {
    (void)self;
    SBLogMacLifecycleGuard(_cmd, a0, a1, 0);
}

static void replacement_UIApplicationLifecycle3(id self, SEL _cmd, uintptr_t a0, uintptr_t a1, uintptr_t a2) {
    (void)self;
    SBLogMacLifecycleGuard(_cmd, a0, a1, a2);
}

static BOOL replacement_UIApplicationWorkspaceShouldExit(id self, SEL _cmd, uintptr_t a0, uintptr_t a1) {
    (void)self;
    SBLogMacLifecycleGuard(_cmd, a0, a1, 0);
    return NO;
}

static BOOL SBInstallLifecycleSelector(Class cls, NSString *selectorName, IMP replacement) {
    if (!cls || selectorName.length == 0 || !replacement) {
        return NO;
    }

    SEL selector = NSSelectorFromString(selectorName);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return NO;
    }

    method_setImplementation(method, replacement);
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-lifecycle-hook\t%@\t\t%@\t\t\t",
                       SBTimestamp(),
                       NSStringFromClass(cls),
                       selectorName]);
    return YES;
}

static void SBInstallMacLifecycleGuard(void) {
    if (atomic_exchange(&SBMacLifecycleGuardInstalled, true)) {
        return;
    }

    Class app = UIApplication.class;
    unsigned installed = 0;
    installed += SBInstallLifecycleSelector(app, @"terminateWithSuccess", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_terminateWithStatus:", (IMP)replacement_UIApplicationLifecycle1) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_terminateWithStatus:forReason:", (IMP)replacement_UIApplicationLifecycle2) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_terminateWithStatus:withError:", (IMP)replacement_UIApplicationLifecycle2) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_terminateWithStatus:forReason:andReport:", (IMP)replacement_UIApplicationLifecycle3) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_performApplicationExit", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"suspend", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_suspend", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"workspaceShouldExit:withTransitionContext:", (IMP)replacement_UIApplicationWorkspaceShouldExit) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"applicationWillTerminate", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"applicationWillSuspend", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"applicationSuspend", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"suspendReturningToLastApp:", (IMP)replacement_UIApplicationLifecycle1) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"_handleTaskCompletionAndTerminate:", (IMP)replacement_UIApplicationLifecycle1) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"applicationWillSuspendForEventsOnly", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"applicationWillSuspendUnderLock", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;
    installed += SBInstallLifecycleSelector(app, @"applicationDidBeginSuspendAnimation", (IMP)replacement_UIApplicationLifecycle0) ? 1 : 0;

    Class nsApplication = NSClassFromString(@"NSApplication");
    installed += SBInstallLifecycleSelector(nsApplication, @"terminate:", (IMP)replacement_UIApplicationLifecycle1) ? 1 : 0;

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-lifecycle-guard-installed\tUIKit/AppKit\t\tselectors=%u\t\t\t",
                       SBTimestamp(),
                       installed]);
    SBWriteMacPluginStatus(@"mac-lifecycle-guard-installed");
}
#endif

#if SB_MACVER && SB_ENABLE_MAC_KEEPALIVE_GUARD
static void replacement_NSProcessInfoEnableAutomaticTermination(id self, SEL _cmd, NSString *reason) {
    (void)self;
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-keepalive-guard\tNSProcessInfo\t\t%s reason=%@\t\t\t",
                       SBTimestamp(),
                       sel_getName(_cmd),
                       reason ?: @""]);
}

static void replacement_NSProcessInfoEnableSuddenTermination(id self, SEL _cmd) {
    (void)self;
    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-keepalive-guard\tNSProcessInfo\t\t%s\t\t\t",
                       SBTimestamp(),
                       sel_getName(_cmd)]);
}

static void SBInstallMacKeepaliveGuard(void) {
    if (atomic_exchange(&SBMacKeepaliveGuardInstalled, true)) {
        return;
    }

    Class processInfoClass = NSProcessInfo.class;
    SBReplaceInstanceMethod(processInfoClass,
                            @selector(enableAutomaticTermination:),
                            (IMP)replacement_NSProcessInfoEnableAutomaticTermination,
                            NULL);
    SBReplaceInstanceMethod(processInfoClass,
                            @selector(enableSuddenTermination),
                            (IMP)replacement_NSProcessInfoEnableSuddenTermination,
                            NULL);

    NSProcessInfo *processInfo = NSProcessInfo.processInfo;
    NSString *reason = @"SoccerAppBypass mac keepalive";
    if ([processInfo respondsToSelector:@selector(disableAutomaticTermination:)]) {
        ((void (*)(id, SEL, NSString *))objc_msgSend)(processInfo,
                                                      @selector(disableAutomaticTermination:),
                                                      reason);
    }
    if ([processInfo respondsToSelector:@selector(disableSuddenTermination)]) {
        ((void (*)(id, SEL))objc_msgSend)(processInfo,
                                          @selector(disableSuddenTermination));
    }
    if ([processInfo respondsToSelector:@selector(beginActivityWithOptions:reason:)]) {
        NSActivityOptions options = NSActivityUserInitiatedAllowingIdleSystemSleep | NSActivityLatencyCritical;
        SBMacKeepaliveActivity = ((id (*)(id, SEL, NSActivityOptions, NSString *))objc_msgSend)(
            processInfo,
            @selector(beginActivityWithOptions:reason:),
            options,
            reason);
    }

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-keepalive-installed\tNSProcessInfo\t\tactivity=%p\t\t\t",
                       SBTimestamp(),
                       (__bridge void *)SBMacKeepaliveActivity]);
    SBWriteMacPluginStatus(@"mac-keepalive-installed");
}
#endif

static void SBInstallUIAlertHooks(void) {
    if (atomic_exchange(&SBUIAlertHooksInstalled, true)) {
        return;
    }

    SBReplaceInstanceMethod(UIViewController.class,
                            @selector(presentViewController:animated:completion:),
                            (IMP)replacement_presentViewController,
                            (IMP *)&orig_presentViewController);

    Class alertView = objc_getClass("UIAlertView");
    SBReplaceInstanceMethod(alertView,
                            @selector(show),
                            (IMP)replacement_alertViewShow,
                            (IMP *)&orig_alertViewShow);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tui-alert-hooks\tUIKit\t\tpresent/show\t\t\t",
                       SBTimestamp()]);
}

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
static void SBReplaceClassMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getClassMethod(cls, selector);
    if (method && original) {
        *original = method_setImplementation(method, replacement);
    }
}

static void SBInstallNetworkHooks(void) {
    if (atomic_exchange(&SBNetworkHooksInstalled, true)) {
        return;
    }

    Class session = NSURLSession.class;
    SBReplaceClassMethod(session, @selector(sessionWithConfiguration:delegate:delegateQueue:), (IMP)replacement_sessionWithConfigurationDelegate, (IMP *)&orig_sessionWithConfigurationDelegate);
    SBReplaceInstanceMethod(session, @selector(dataTaskWithRequest:completionHandler:), (IMP)replacement_dataTaskWithRequestCompletion, (IMP *)&orig_dataTaskWithRequestCompletion);
    SBReplaceInstanceMethod(session, @selector(dataTaskWithURL:completionHandler:), (IMP)replacement_dataTaskWithURLCompletion, (IMP *)&orig_dataTaskWithURLCompletion);
    SBReplaceInstanceMethod(session, @selector(uploadTaskWithRequest:fromData:completionHandler:), (IMP)replacement_uploadTaskWithRequestFromDataCompletion, (IMP *)&orig_uploadTaskWithRequestFromDataCompletion);
    SBReplaceInstanceMethod(session, @selector(downloadTaskWithRequest:completionHandler:), (IMP)replacement_downloadTaskWithRequestCompletion, (IMP *)&orig_downloadTaskWithRequestCompletion);
    SBReplaceInstanceMethod(NSURLSessionTask.class, @selector(resume), (IMP)replacement_taskResume, (IMP *)&orig_taskResume);

    Class connection = NSURLConnection.class;
    SBReplaceClassMethod(connection, @selector(sendSynchronousRequest:returningResponse:error:), (IMP)replacement_sendSynchronousRequest, (IMP *)&orig_sendSynchronousRequest);
    SBReplaceClassMethod(connection, @selector(sendAsynchronousRequest:queue:completionHandler:), (IMP)replacement_sendAsynchronousRequest, (IMP *)&orig_sendAsynchronousRequest);

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tnetwork-hooks\tFoundation\t\tNSURLSession/NSURLConnection\t\t\t",
                       SBTimestamp()]);
}
#endif

static void SBInstallObjCHooks(void) {
    Class fileManager = NSFileManager.class;
    SBReplaceInstanceMethod(fileManager, @selector(fileExistsAtPath:), (IMP)replacement_fileExistsAtPath, (IMP *)&orig_fileExistsAtPath);
    SBReplaceInstanceMethod(fileManager, @selector(fileExistsAtPath:isDirectory:), (IMP)replacement_fileExistsAtPathIsDirectory, (IMP *)&orig_fileExistsAtPathIsDirectory);
    SBReplaceInstanceMethod(fileManager, @selector(isReadableFileAtPath:), (IMP)replacement_isReadableFileAtPath, (IMP *)&orig_isReadableFileAtPath);
    SBReplaceInstanceMethod(fileManager, @selector(isExecutableFileAtPath:), (IMP)replacement_isExecutableFileAtPath, (IMP *)&orig_isExecutableFileAtPath);
    SBReplaceInstanceMethod(fileManager, @selector(attributesOfItemAtPath:error:), (IMP)replacement_attributesOfItemAtPath, (IMP *)&orig_attributesOfItemAtPath);

    SBReplaceInstanceMethod(UIApplication.class, @selector(canOpenURL:), (IMP)replacement_canOpenURL, (IMP *)&orig_canOpenURL);
    SBReplaceInstanceMethod(UIViewController.class, @selector(presentViewController:animated:completion:), (IMP)replacement_presentViewController, (IMP *)&orig_presentViewController);

#if SB_ENABLE_FOUNDATION_NETWORK_LOG
    SBInstallNetworkHooks();
#endif
}

#if SB_ENABLE_LOW_LEVEL_BYPASS
static void SBInstallFishhooks(void) {
    struct rebinding rebindings[] = {
        {"access", replacement_access, (void **)&orig_access},
        {"open", replacement_open, (void **)&orig_open},
        {"fopen", replacement_fopen, (void **)&orig_fopen},
        {"opendir", replacement_opendir, (void **)&orig_opendir},
        {"stat", replacement_stat, (void **)&orig_stat},
        {"lstat", replacement_lstat, (void **)&orig_lstat},
        {"readlink", replacement_readlink, (void **)&orig_readlink},
        {"realpath", replacement_realpath, (void **)&orig_realpath},
        {"sysctl", replacement_sysctl, (void **)&orig_sysctl},
        {"sysctlbyname", replacement_sysctlbyname, (void **)&orig_sysctlbyname},
        {"ptrace", replacement_ptrace, (void **)&orig_ptrace},
        {"fork", replacement_fork, (void **)&orig_fork},
        {"getenv", replacement_getenv, (void **)&orig_getenv},
        {"dlopen", replacement_dlopen, (void **)&orig_dlopen},
        {"dlsym", replacement_dlsym, (void **)&orig_dlsym},
        {"_dyld_image_count", replacement_dyld_image_count, (void **)&orig_dyld_image_count},
        {"_dyld_get_image_name", replacement_dyld_get_image_name, (void **)&orig_dyld_get_image_name},
        {"SecTrustEvaluate", replacement_SecTrustEvaluate, (void **)&orig_SecTrustEvaluate},
        {"SecTrustEvaluateWithError", replacement_SecTrustEvaluateWithError, (void **)&orig_SecTrustEvaluateWithError},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));
}
#endif

#if SB_MACVER && SB_ENABLE_MAC_SELF_KILL_GUARD
static void SBInstallMacSelfKillGuard(void) {
    if (atomic_exchange(&SBMacSelfKillGuardInstalled, true)) {
        return;
    }

    struct rebinding rebindings[] = {
        {"kill", replacement_kill, (void **)&orig_kill},
        {"killpg", replacement_killpg, (void **)&orig_killpg},
        {"raise", replacement_raise, (void **)&orig_raise},
        {"pthread_kill", replacement_pthread_kill, (void **)&orig_pthread_kill},
        {"abort", replacement_abort, (void **)&orig_abort},
        {"exit", replacement_exit, (void **)&orig_exit},
        {"_exit", replacement__exit, (void **)&orig__exit},
        {"__kill", replacement___kill, (void **)&orig___kill},
        {"__pthread_kill", replacement___pthread_kill, (void **)&orig___pthread_kill},
        {"__exit", replacement___exit, (void **)&orig___exit},
        {"abort_with_reason", replacement_abort_with_reason, (void **)&orig_abort_with_reason},
        {"abort_with_payload", replacement_abort_with_payload, (void **)&orig_abort_with_payload},
        {"__abort_with_payload", replacement___abort_with_payload, (void **)&orig___abort_with_payload},
        {"terminate_with_reason", replacement_terminate_with_reason, (void **)&orig_terminate_with_reason},
        {"terminate_with_payload", replacement_terminate_with_payload, (void **)&orig_terminate_with_payload},
        {"__terminate_with_payload", replacement___terminate_with_payload, (void **)&orig___terminate_with_payload},
        {"task_terminate", replacement_task_terminate, (void **)&orig_task_terminate},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-self-kill-installed\tlibSystem\t\tkill/killpg/raise/pthread_kill/abort/exit/_exit + kernel terminate wrappers\t\t\t",
                       SBTimestamp()]);
    SBWriteMacPluginStatus(@"mac-self-kill-installed");
}
#endif

#if SB_MACVER && SB_ENABLE_MAC_AUDIO_MUTE
typedef struct {
    AURenderCallback callback;
    void *refcon;
} SBMutedAURenderContext;

static void SBAudioMuteBufferList(AudioBufferList *ioData) {
    if (!ioData) {
        return;
    }
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer *buffer = &ioData->mBuffers[i];
        if (buffer->mData && buffer->mDataByteSize > 0) {
            memset(buffer->mData, 0, buffer->mDataByteSize);
        }
    }
    atomic_fetch_add(&SBMacAudioMuteRenderBuffers, 1);
}

static BOOL SBAudioUnitParameterIsVolume(AudioUnitParameterID parameterID) {
    return parameterID == kHALOutputParam_Volume ||
           parameterID == kMultiChannelMixerParam_Volume ||
           parameterID == kMatrixMixerParam_Volume;
}

static OSStatus replacement_AudioUnitRender(AudioUnit inUnit,
                                            AudioUnitRenderActionFlags *ioActionFlags,
                                            const AudioTimeStamp *inTimeStamp,
                                            UInt32 inOutputBusNumber,
                                            UInt32 inNumberFrames,
                                            AudioBufferList *ioData) {
    OSStatus status = orig_AudioUnitRender ?
        orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData) :
        noErr;
    SBAudioMuteBufferList(ioData);
    return status;
}

static OSStatus SBAudioMuteRenderCallback(void *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData) {
    SBMutedAURenderContext *context = (SBMutedAURenderContext *)inRefCon;
    OSStatus status = noErr;
    if (context && context->callback) {
        status = context->callback(context->refcon,
                                   ioActionFlags,
                                   inTimeStamp,
                                   inBusNumber,
                                   inNumberFrames,
                                   ioData);
    }
    SBAudioMuteBufferList(ioData);
    return status;
}

static OSStatus replacement_AudioUnitSetProperty(AudioUnit inUnit,
                                                 AudioUnitPropertyID inID,
                                                 AudioUnitScope inScope,
                                                 AudioUnitElement inElement,
                                                 const void *inData,
                                                 UInt32 inDataSize) {
    if (inID == kAudioUnitProperty_SetRenderCallback &&
        inData &&
        inDataSize >= sizeof(AURenderCallbackStruct)) {
        const AURenderCallbackStruct *original = (const AURenderCallbackStruct *)inData;
        if (original->inputProc) {
            SBMutedAURenderContext *context = calloc(1, sizeof(SBMutedAURenderContext));
            if (context) {
                context->callback = original->inputProc;
                context->refcon = original->inputProcRefCon;

                AURenderCallbackStruct muted = *original;
                muted.inputProc = SBAudioMuteRenderCallback;
                muted.inputProcRefCon = context;
                atomic_fetch_add(&SBMacAudioMuteRenderCallbacks, 1);
                return orig_AudioUnitSetProperty ?
                    orig_AudioUnitSetProperty(inUnit, inID, inScope, inElement, &muted, sizeof(muted)) :
                    noErr;
            }
        }
    }

    return orig_AudioUnitSetProperty ?
        orig_AudioUnitSetProperty(inUnit, inID, inScope, inElement, inData, inDataSize) :
        noErr;
}

static OSStatus replacement_AudioUnitSetParameter(AudioUnit inUnit,
                                                  AudioUnitParameterID inID,
                                                  AudioUnitScope inScope,
                                                  AudioUnitElement inElement,
                                                  AudioUnitParameterValue inValue,
                                                  UInt32 inBufferOffsetInFrames) {
    if (SBAudioUnitParameterIsVolume(inID)) {
        inValue = 0.0f;
    }
    return orig_AudioUnitSetParameter ?
        orig_AudioUnitSetParameter(inUnit, inID, inScope, inElement, inValue, inBufferOffsetInFrames) :
        noErr;
}

static OSStatus replacement_AudioOutputUnitStart(AudioUnit ci) {
    if (orig_AudioUnitSetParameter) {
        orig_AudioUnitSetParameter(ci, kHALOutputParam_Volume, kAudioUnitScope_Global, 0, 0.0f, 0);
        orig_AudioUnitSetParameter(ci, kMultiChannelMixerParam_Volume, kAudioUnitScope_Global, 0, 0.0f, 0);
        orig_AudioUnitSetParameter(ci, kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0, 0.0f, 0);
    }
    return orig_AudioOutputUnitStart ? orig_AudioOutputUnitStart(ci) : noErr;
}

static OSStatus replacement_AudioQueueSetParameter(AudioQueueRef inAQ,
                                                   AudioQueueParameterID inParamID,
                                                   AudioQueueParameterValue inValue) {
    if (inParamID == kAudioQueueParam_Volume) {
        inValue = 0.0f;
    }
    return orig_AudioQueueSetParameter ?
        orig_AudioQueueSetParameter(inAQ, inParamID, inValue) :
        noErr;
}

static OSStatus replacement_AudioQueueStart(AudioQueueRef inAQ,
                                            const AudioTimeStamp *inStartTime) {
    if (orig_AudioQueueSetParameter) {
        orig_AudioQueueSetParameter(inAQ, kAudioQueueParam_Volume, 0.0f);
    }
    return orig_AudioQueueStart ? orig_AudioQueueStart(inAQ, inStartTime) : noErr;
}

static void SBInstallMacAudioMute(void) {
    if (atomic_exchange(&SBMacAudioMuteInstalled, true)) {
        return;
    }

    struct rebinding rebindings[] = {
        {"AudioUnitSetProperty", replacement_AudioUnitSetProperty, (void **)&orig_AudioUnitSetProperty},
        {"AudioUnitSetParameter", replacement_AudioUnitSetParameter, (void **)&orig_AudioUnitSetParameter},
        {"AudioUnitRender", replacement_AudioUnitRender, (void **)&orig_AudioUnitRender},
        {"AudioOutputUnitStart", replacement_AudioOutputUnitStart, (void **)&orig_AudioOutputUnitStart},
        {"AudioQueueSetParameter", replacement_AudioQueueSetParameter, (void **)&orig_AudioQueueSetParameter},
        {"AudioQueueStart", replacement_AudioQueueStart, (void **)&orig_AudioQueueStart},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));

    SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tmac-audio-mute-installed\tAudioToolbox\t\tAudioUnit/AudioQueue output forced silent\t\t\t",
                       SBTimestamp()]);
    SBWriteMacPluginStatus(@"mac-audio-mute-installed");
}
#endif

static BOOL SBSoccerAppBypassShouldInstall(NSString *bundleID) {
    return [bundleID isEqualToString:@"jp.co.level5.inazumacross"] ||
           [bundleID isEqualToString:@"local.srzq.SoccerUnityShell"];
}

void SoccerAppBypassInstall(void) {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (!SBSoccerAppBypassShouldInstall(bundleID)) {
            return;
        }

        bool expected = false;
        if (!atomic_compare_exchange_strong(&SBSoccerAppBypassInstalled, &expected, true)) {
            return;
        }

#if SB_ENABLE_EARLY_UNITYFRAMEWORK_DLOPEN
        SBEarlyDlopenUnityFramework();
#endif
        SBPrepareCLogPath();
#if SB_MACVER
        SBWriteMacPluginStatus(@"installing");
#endif
#if SB_MACVER && SB_ENABLE_MAC_LIFECYCLE_GUARD
        SBInstallMacLifecycleGuard();
#endif
#if SB_MACVER && SB_ENABLE_MAC_KEEPALIVE_GUARD
        SBInstallMacKeepaliveGuard();
#endif
#if SB_MACVER && SB_ENABLE_MAC_SELF_KILL_GUARD
        SBInstallMacSelfKillGuard();
#endif
#if SB_MACVER && SB_ENABLE_MAC_AUDIO_MUTE
        SBInstallMacAudioMute();
#endif
#if SB_MACVER && SB_ENABLE_ANORT_OBJC_LOAD_BYPASS
        SBInstallAnortObjCLoadBypass();
#endif
#if SB_MACVER && SB_ENABLE_ANORT_SELF_KILL_TERMINATOR_PATCH
        SBInstallAnortSelfKillTerminatorPatch();
#endif
#if SB_MACVER && SB_ENABLE_MAC_DIRECT_SYSCALL_GUARD && SB_ENABLE_MAC_SELF_KILL_GUARD
        SBInstallMacDirectSyscallGuard();
#endif
#if SB_ENABLE_EARLY_UNITYFRAMEWORK_DLOPEN
        SBLogEarlyDlopenUnityFrameworkResult();
#endif
#if SB_ENABLE_ANOGS_HOOKS
        SBInstallAnogsHooks();
#endif
#if SB_ENABLE_ANOGS_ALERT_ONLY_HOOK
        SBInstallAnogsAlertOnlyHook();
#endif
#if SB_ENABLE_ANORT_VM_HOOK
        SBInstallAnortHooks();
#endif
#if SB_ENABLE_UNITY_ANOSDK_INIT_BYPASS
        SBInstallUnityAnoSdkInitBypass();
#endif
#if SB_ENABLE_UNITY_RENDER_CRASH_GUARD
        SBInstallUnityRenderCrashGuard();
#endif
#if SB_ENABLE_UNITY_RENDER_ENCODER_GUARD
        SBInstallUnityRenderEncoderGuard();
#endif
#if SB_ENABLE_UNITY_GFX_COMMAND_NOOP_GUARD
        SBInstallUnityGfxCommandNoopGuard();
#endif
#if SB_MACVER && SB_ENABLE_UNITY_ASSERT_LOG_HOOK
        SBInstallUnityAssertLogHook();
#endif
#if SB_ENABLE_ACE_ALERT_BYPASS
        SBInstallAceAlertHooks();
#endif
#if SB_ENABLE_UI_ALERT_BYPASS
        SBInstallUIAlertHooks();
#endif
#if SB_ENABLE_LOW_LEVEL_BYPASS
        SBInstallFishhooks();
#endif
#if SB_ENABLE_FOUNDATION_NETWORK_LOG
        SBInstallNetworkHooks();
#endif
#if SB_ENABLE_OBJC_BYPASS
        SBInstallObjCHooks();
#endif
#if SB_ENABLE_KEYCHAIN_AUTH_DUMP
        SBDumpKeychainAuthItems();
#endif
#if SB_ENABLE_METADATA_DUMP
        SBStartMetadataDumpTimer();
#endif
#if SB_ENABLE_IL2CPP_STRING_PROBE
        SBStartIL2CPPStringProbe();
#endif
#if SB_ENABLE_LOCAL_CONTROL_SERVER
        SBStartLocalControlServer();
#endif
        SBAppendIndexLine([NSString stringWithFormat:@"000000\t%@\tinit\tSoccerAppBypass\t\t%@\t\t\t",
                           SBTimestamp(), SBLogRootPath()]);
#if SB_MACVER
        SBWriteMacPluginStatus(@"installed");
#endif
    }
}

#if !SB_EMBEDDED_SHELL
__attribute__((constructor))
static void SoccerAppBypassInit(void) {
    SoccerAppBypassInstall();
}
#endif
