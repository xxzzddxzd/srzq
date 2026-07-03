#import "LocalControlServer.h"

#import <UIKit/UIKit.h>

#include <arpa/inet.h>
#include <errno.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#import "IL2CPPStringProbe.h"
#import "UnityRuntimeBridge.h"
#import "FinishRequestCapture.h"

static const uint16_t SBControlPort = 19876;
static const NSTimeInterval SBControlFallbackStartDelaySeconds = 30.0;
static atomic_bool SBControlServerStarted = false;
static NSString * const SBControlThreadRequestSummaryKey = @"SoccerAppBypass.control.requestSummary";

static void SBControlRecordResponse(int status, NSString *reason, NSDictionary *body);
static void SBControlAppendStatusEvent(NSString *line);
static void SBControlSetServerState(NSString *state, NSString *detail);

static NSString *SBControlTimestamp(void) {
    return [[NSDate date] descriptionWithLocale:nil];
}

static NSString *SBControlParentPath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    NSString *parent = [base stringByAppendingPathComponent:@"SoccerAppBypassLogs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:parent
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return parent;
}

static NSString *SBControlLogRootPath(void) {
    NSString *parent = SBControlParentPath();
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

static NSString *SBControlStateDirectoryPath(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    NSString *stateDir = [base stringByAppendingPathComponent:@"SoccerAppBypassState"];
    [[NSFileManager defaultManager] createDirectoryAtPath:stateDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return stateDir;
}

static NSString *SBControlCachedServerVersionHash(void) {
    NSString *path = [SBControlStateDirectoryPath() stringByAppendingPathComponent:@"server_version_hash.txt"];
    NSString *value = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:nil] ?: @"";
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static void SBControlAppendIndexLine(NSString *event, NSString *detail) {
    NSString *path = [SBControlLogRootPath() stringByAppendingPathComponent:@"index.tsv"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createFileAtPath:path
                    contents:[@"id\ttime\tevent\tsource\tmethod\turl\trequest_file\tresponse_file\terror\n"
                              dataUsingEncoding:NSUTF8StringEncoding]
                  attributes:nil];
    }

    NSString *line = [NSString stringWithFormat:@"000000\t%@\t%@\tLocalControlServer\t\t%@\t\t\t\n",
                      SBControlTimestamp(),
                      event ?: @"control",
                      detail ?: @""];
    NSData *bytes = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:bytes];
    [handle closeFile];
}

static void SBControlUnityBridgeProgress(NSString *event, NSString *detail) {
    SBControlAppendIndexLine(event ?: @"unity-bridge", detail ?: @"");
}

static NSData *SBControlJSONData(NSDictionary *object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object ?: @{}
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    return data ?: [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
}

static void SBControlWriteAll(int fd, const void *bytes, size_t length) {
    const uint8_t *cursor = (const uint8_t *)bytes;
    while (length > 0) {
        ssize_t written = write(fd, cursor, length);
        if (written <= 0) {
            if (errno == EINTR) {
                continue;
            }
            return;
        }
        cursor += written;
        length -= (size_t)written;
    }
}

static void SBControlSendJSON(int fd, int status, NSString *reason, NSDictionary *body) {
    NSData *json = SBControlJSONData(body);
    NSString *head = [NSString stringWithFormat:
                      @"HTTP/1.1 %d %@\r\n"
                      "Content-Type: application/json; charset=utf-8\r\n"
                      "Content-Length: %lu\r\n"
                      "Connection: close\r\n"
                      "Access-Control-Allow-Origin: *\r\n"
                      "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
                      "Access-Control-Allow-Headers: Content-Type\r\n"
                      "\r\n",
                      status,
                      reason ?: @"OK",
                      (unsigned long)json.length];
    NSData *headData = [head dataUsingEncoding:NSUTF8StringEncoding];
    SBControlWriteAll(fd, headData.bytes, headData.length);
    SBControlWriteAll(fd, json.bytes, json.length);
    SBControlRecordResponse(status, reason ?: @"OK", body ?: @{});
}

static UIWindow *SBControlBestWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *keyWindow = app.keyWindow;
    if (keyWindow && !keyWindow.hidden) {
        return keyWindow;
    }

    for (UIWindow *window in app.windows) {
        if (window.isKeyWindow && !window.hidden) {
            return window;
        }
    }
    for (UIWindow *window in app.windows) {
        if (!window.hidden && window.rootViewController) {
            return window;
        }
    }
    return nil;
}

static UIViewController *SBControlTopViewController(void) {
    UIViewController *controller = SBControlBestWindow().rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        controller = ((UINavigationController *)controller).visibleViewController ?: controller;
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        controller = ((UITabBarController *)controller).selectedViewController ?: controller;
    }
    return controller;
}

static void SBControlRunOnMainRunLoop(void (^block)(void)) {
    if (!block) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
        return;
    }
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, block);
    CFRunLoopWakeUp(CFRunLoopGetMain());
}

static UIView *SBControlStatusPanel = nil;
static UILabel *SBControlStatusTitleLabel = nil;
static UILabel *SBControlStatusEndpointLabel = nil;
static UITextView *SBControlStatusTextView = nil;
static BOOL SBControlStatusOverlayClosed = NO;
static NSString *SBControlServerState = @"starting";

@interface SBControlStatusOverlayTarget : NSObject
@property(nonatomic, weak) UIView *panel;
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
- (void)close:(UIButton *)button;
@end

@implementation SBControlStatusOverlayTarget

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = self.panel;
    UIView *container = panel.superview;
    if (!panel || !container) {
        return;
    }

    CGPoint translation = [recognizer translationInView:container];
    CGPoint center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    CGFloat halfWidth = CGRectGetWidth(panel.bounds) / 2.0;
    CGFloat halfHeight = CGRectGetHeight(panel.bounds) / 2.0;
    CGRect bounds = container.bounds;
    center.x = MAX(halfWidth, MIN(CGRectGetWidth(bounds) - halfWidth, center.x));
    center.y = MAX(halfHeight, MIN(CGRectGetHeight(bounds) - halfHeight, center.y));
    panel.center = center;
    [recognizer setTranslation:CGPointZero inView:container];
}

- (void)close:(__unused UIButton *)button {
    SBControlStatusOverlayClosed = YES;
    SBControlStatusPanel.hidden = YES;
}

@end

static SBControlStatusOverlayTarget *SBControlStatusOverlayTargetObject = nil;

static NSMutableArray<NSString *> *SBControlStatusEvents(void) {
    static NSMutableArray<NSString *> *events = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        events = [NSMutableArray array];
    });
    return events;
}

static NSString *SBControlShortTimestamp(void) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"HH:mm:ss";
    return [formatter stringFromDate:[NSDate date]] ?: @"";
}

static NSString *SBControlTruncateLine(NSString *line, NSUInteger limit) {
    if (line.length <= limit) {
        return line ?: @"";
    }
    return [[line substringToIndex:limit] stringByAppendingString:@"..."];
}

static NSArray<NSString *> *SBControlLANAddresses(void) {
    NSMutableArray<NSString *> *addresses = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) {
        return addresses;
    }

    for (struct ifaddrs *cursor = interfaces; cursor != NULL; cursor = cursor->ifa_next) {
        if (!cursor->ifa_addr || cursor->ifa_addr->sa_family != AF_INET) {
            continue;
        }
        if ((cursor->ifa_flags & IFF_UP) == 0 || (cursor->ifa_flags & IFF_LOOPBACK) != 0) {
            continue;
        }

        char buffer[INET_ADDRSTRLEN] = {0};
        struct sockaddr_in *addr = (struct sockaddr_in *)cursor->ifa_addr;
        if (!inet_ntop(AF_INET, &addr->sin_addr, buffer, sizeof(buffer))) {
            continue;
        }
        if (strncmp(buffer, "169.254.", 8) == 0) {
            continue;
        }

        NSString *name = cursor->ifa_name ? [NSString stringWithUTF8String:cursor->ifa_name] : @"";
        NSString *address = [NSString stringWithFormat:@"%@ %@:%u",
                             name.length > 0 ? name : @"if",
                             [NSString stringWithUTF8String:buffer] ?: @"",
                             SBControlPort];
        if ([name isEqualToString:@"en0"]) {
            [addresses insertObject:address atIndex:0];
        } else {
            [addresses addObject:address];
        }
    }

    freeifaddrs(interfaces);
    return addresses;
}

static NSString *SBControlEndpointSummary(void) {
    NSString *state = nil;
    @synchronized (SBControlStatusEvents()) {
        state = [SBControlServerState copy] ?: @"unknown";
    }

    NSArray<NSString *> *lanAddresses = SBControlLANAddresses();
    NSString *lan = lanAddresses.count > 0 ? [lanAddresses componentsJoinedByString:@", "] : @"unavailable";
    return [NSString stringWithFormat:@"State: %@\nListen: 0.0.0.0:%u\nLAN: %@\nProxy/local: 127.0.0.1:%u",
            state,
            SBControlPort,
            lan,
            SBControlPort];
}

static void SBControlLayoutStatusPanel(UIWindow *window) {
    if (!window || SBControlStatusPanel) {
        return;
    }

    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        insets = window.safeAreaInsets;
    }

    CGFloat availableWidth = MAX(260.0, CGRectGetWidth(window.bounds) - 24.0 - insets.left - insets.right);
    CGFloat availableHeight = MAX(220.0, CGRectGetHeight(window.bounds) - 32.0 - insets.top - insets.bottom);
    CGFloat width = MIN(390.0, availableWidth);
    CGFloat height = MIN(285.0, availableHeight);
    CGRect frame = CGRectMake(12.0 + insets.left, 12.0 + insets.top, width, height);

    UIView *panel = [[UIView alloc] initWithFrame:frame];
    panel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
    panel.userInteractionEnabled = YES;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 8.0, width - 48.0, 20.0)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.text = @"SoccerAppBypass Control";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:14.0];
    [panel addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 36.0, 2.0, 34.0, 32.0);
    close.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [close setTitle:@"x" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
    [panel addSubview:close];

    UILabel *endpoint = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 32.0, width - 20.0, 66.0)];
    endpoint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    endpoint.numberOfLines = 4;
    endpoint.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    endpoint.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    [panel addSubview:endpoint];

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(8.0, 102.0, width - 16.0, height - 110.0)];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.backgroundColor = [UIColor clearColor];
    textView.textColor = [UIColor colorWithWhite:0.90 alpha:1.0];
    textView.font = [UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightRegular];
    textView.editable = NO;
    textView.selectable = YES;
    textView.alwaysBounceVertical = YES;
    textView.textContainerInset = UIEdgeInsetsZero;
    [panel addSubview:textView];

    SBControlStatusOverlayTargetObject = [SBControlStatusOverlayTarget new];
    SBControlStatusOverlayTargetObject.panel = panel;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:SBControlStatusOverlayTargetObject
                                                                          action:@selector(handlePan:)];
    [panel addGestureRecognizer:pan];
    [close addTarget:SBControlStatusOverlayTargetObject
              action:@selector(close:)
    forControlEvents:UIControlEventTouchUpInside];

    SBControlStatusPanel = panel;
    SBControlStatusTitleLabel = title;
    SBControlStatusEndpointLabel = endpoint;
    SBControlStatusTextView = textView;
}

static void SBControlRefreshStatusOverlay(void) {
    SBControlRunOnMainRunLoop(^{
        if (SBControlStatusOverlayClosed) {
            return;
        }

        UIWindow *window = SBControlBestWindow();
        if (!window) {
            return;
        }

        SBControlLayoutStatusPanel(window);
        if (!SBControlStatusPanel) {
            return;
        }
        if (SBControlStatusPanel.superview != window) {
            [SBControlStatusPanel removeFromSuperview];
            [window addSubview:SBControlStatusPanel];
        }
        SBControlStatusPanel.hidden = NO;
        [window bringSubviewToFront:SBControlStatusPanel];

        SBControlStatusEndpointLabel.text = SBControlEndpointSummary();

        NSArray<NSString *> *snapshot = nil;
        @synchronized (SBControlStatusEvents()) {
            snapshot = [SBControlStatusEvents() copy];
        }
        NSString *text = snapshot.count > 0
            ? [snapshot componentsJoinedByString:@"\n"]
            : @"waiting for requests...";
        SBControlStatusTextView.text = text;
        if (SBControlStatusTextView.text.length > 0) {
            NSRange bottom = NSMakeRange(SBControlStatusTextView.text.length - 1, 1);
            [SBControlStatusTextView scrollRangeToVisible:bottom];
        }
    });
}

static void SBControlAppendStatusEvent(NSString *line) {
    NSString *trimmed = SBControlTruncateLine(line ?: @"", 220);
    NSString *entry = [NSString stringWithFormat:@"%@ %@", SBControlShortTimestamp(), trimmed];
    @synchronized (SBControlStatusEvents()) {
        NSMutableArray<NSString *> *events = SBControlStatusEvents();
        [events addObject:entry];
        while (events.count > 28) {
            [events removeObjectAtIndex:0];
        }
    }
    SBControlRefreshStatusOverlay();
}

static void SBControlSetServerState(NSString *state, NSString *detail) {
    @synchronized (SBControlStatusEvents()) {
        SBControlServerState = [state copy] ?: @"unknown";
    }
    NSString *line = detail.length > 0
        ? [NSString stringWithFormat:@"SERVER %@ %@", state ?: @"unknown", detail]
        : [NSString stringWithFormat:@"SERVER %@", state ?: @"unknown"];
    SBControlAppendStatusEvent(line);
}

static NSString *SBControlResponseSummary(NSDictionary *body) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    id ok = body[@"ok"];
    if ([ok respondsToSelector:@selector(boolValue)]) {
        [parts addObject:[NSString stringWithFormat:@"ok=%d", [ok boolValue]]];
    }

    NSDictionary *simulation = [body[@"simulation"] isKindOfClass:NSDictionary.class] ? body[@"simulation"] : nil;
    if (simulation) {
        id aScore = simulation[@"aScore"];
        id bScore = simulation[@"bScore"];
        if (aScore || bScore) {
            [parts addObject:[NSString stringWithFormat:@"score=%@-%@",
                              aScore ?: @"?",
                              bScore ?: @"?"]];
        }
        id moves = simulation[@"moveSelectionsCount"];
        if (moves) {
            [parts addObject:[NSString stringWithFormat:@"moves=%@", moves]];
        }
        id phases = simulation[@"phaseResultsCount"];
        if (phases) {
            [parts addObject:[NSString stringWithFormat:@"phases=%@", phases]];
        }
    }

    id error = body[@"error"] ?: body[@"Error"] ?: body[@"ErrorCode"] ?: body[@"message"] ?: body[@"Message"];
    if ([error isKindOfClass:NSString.class] && [(NSString *)error length] > 0) {
        [parts addObject:[NSString stringWithFormat:@"error=%@", SBControlTruncateLine(error, 80)]];
    } else if (error) {
        [parts addObject:[NSString stringWithFormat:@"error=%@", error]];
    }

    if (parts.count == 0) {
        return @"";
    }
    return [@" " stringByAppendingString:[parts componentsJoinedByString:@" "]];
}

static void SBControlRecordResponse(int status, NSString *reason, NSDictionary *body) {
    NSString *requestSummary = NSThread.currentThread.threadDictionary[SBControlThreadRequestSummaryKey] ?: @"";
    NSString *responseSummary = SBControlResponseSummary(body ?: @{});
    NSString *line = [NSString stringWithFormat:@"RES %d %@%@%@",
                      status,
                      reason ?: @"OK",
                      responseSummary ?: @"",
                      requestSummary.length > 0 ? [NSString stringWithFormat:@" <- %@", requestSummary] : @""];
    SBControlAppendStatusEvent(line);
}

static void SBControlWriteReadyResult(NSDictionary *result) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:result ?: @{}
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:nil];
    if (!json) {
        return;
    }
    NSString *path = [SBControlLogRootPath() stringByAppendingPathComponent:@"control-ready.json"];
    [json writeToFile:path atomically:YES];
}

static void SBControlScheduleReadyAction(NSString *requestId, NSString *remoteAddress) {
    SBControlRunOnMainRunLoop(^{
        SBUnityBridgeReadyResult bridgeResult = SBUnityBridgeRunReadyProbe();
        NSDictionary *managedDetails = SBUnityBridgeReadyResultDictionary(bridgeResult);
        BOOL managedOK = bridgeResult.ok;
        NSString *displayText = @"ready";

        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        result[@"requestId"] = requestId ?: @"";
        result[@"remote"] = remoteAddress ?: @"";
        result[@"time"] = SBControlTimestamp();
        result[@"managedOK"] = @(managedOK);
        result[@"managedText"] = displayText;
        result[@"details"] = managedDetails ?: @{};

        UIViewController *top = SBControlTopViewController();
        result[@"alertPresented"] = @(top != nil);
        SBControlWriteReadyResult(result);

        SBControlAppendIndexLine(@"control-ready-action",
                                 [NSString stringWithFormat:@"id=%@ remote=%@ managedOK=%d text=%@ top=%@",
                                  requestId ?: @"",
                                  remoteAddress ?: @"",
                                  managedOK,
                                  displayText,
                                  top ? NSStringFromClass(top.class) : @""]);

        if (!top) {
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:displayText
                                                                       message:managedOK ? @"managed System.String.IsNullOrEmpty ok" : @"managed probe fallback"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

static NSString *SBControlRequestPath(const char *target) {
    if (!target) {
        return @"";
    }
    NSString *raw = [NSString stringWithUTF8String:target] ?: @"";
    NSRange query = [raw rangeOfString:@"?"];
    return query.location == NSNotFound ? raw : [raw substringToIndex:query.location];
}

static NSInteger SBControlHeaderBodyOffset(NSData *data) {
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    if (length < 4) {
        return -1;
    }
    for (NSUInteger i = 3; i < length; i++) {
        if (bytes[i - 3] == '\r' &&
            bytes[i - 2] == '\n' &&
            bytes[i - 1] == '\r' &&
            bytes[i] == '\n') {
            return (NSInteger)i + 1;
        }
    }
    return -1;
}

static NSInteger SBControlContentLengthFromHeader(NSString *header) {
    for (NSString *line in [header componentsSeparatedByString:@"\r\n"]) {
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) {
            continue;
        }
        NSString *name = [[line substringToIndex:colon.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([name caseInsensitiveCompare:@"Content-Length"] != NSOrderedSame) {
            continue;
        }
        NSString *value = [[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        return value.integerValue;
    }
    return 0;
}

static NSData *SBControlReadHTTPRequest(int clientFd) {
    static const NSUInteger MaxRequestBytes = 256 * 1024;
    NSMutableData *data = [NSMutableData dataWithCapacity:8192];
    NSInteger bodyOffset = -1;
    NSInteger contentLength = -1;

    while (data.length < MaxRequestBytes) {
        uint8_t buffer[8192];
        ssize_t length = read(clientFd, buffer, sizeof(buffer));
        if (length <= 0) {
            if (length < 0 && errno == EINTR) {
                continue;
            }
            break;
        }
        [data appendBytes:buffer length:(NSUInteger)length];

        if (bodyOffset < 0) {
            bodyOffset = SBControlHeaderBodyOffset(data);
            if (bodyOffset >= 0) {
                NSString *header = [[NSString alloc] initWithBytes:data.bytes
                                                            length:(NSUInteger)bodyOffset
                                                          encoding:NSUTF8StringEncoding] ?: @"";
                contentLength = SBControlContentLengthFromHeader(header);
            }
        }

        if (bodyOffset >= 0) {
            if (contentLength <= 0) {
                break;
            }
            if (data.length >= (NSUInteger)bodyOffset + (NSUInteger)contentLength) {
                break;
            }
        }
    }

    return data;
}

static NSData *SBControlBodyFromRequest(NSData *requestData) {
    NSInteger bodyOffset = SBControlHeaderBodyOffset(requestData);
    if (bodyOffset < 0 || (NSUInteger)bodyOffset >= requestData.length) {
        return [NSData data];
    }
    return [requestData subdataWithRange:NSMakeRange((NSUInteger)bodyOffset,
                                                     requestData.length - (NSUInteger)bodyOffset)];
}

static NSString *SBControlDetailJsonFromObject(id object, NSUInteger depth);

static NSString *SBControlTrimmedString(id value) {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static id SBControlValueForAnyKey(NSDictionary *dict, NSArray<NSString *> *keys) {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    for (NSString *key in keys) {
        id value = dict[key];
        if (value && value != NSNull.null) {
            return value;
        }
    }
    return nil;
}

static NSData *SBControlUTF8Data(NSString *string) {
    return [string dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
}

static id SBControlJSONObjectFromString(NSString *string) {
    NSString *trimmed = SBControlTrimmedString(string);
    if (trimmed.length == 0) {
        return nil;
    }
    unichar first = [trimmed characterAtIndex:0];
    if (first != '{' && first != '[' && first != '"') {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:SBControlUTF8Data(trimmed)
                                           options:0
                                             error:nil];
}

static NSString *SBControlJSONStringFromObject(id object) {
    if (!object || ![NSJSONSerialization isValidJSONObject:object]) {
        return @"";
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    if (!data) {
        return @"";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

static BOOL SBControlLooksLikeBattleDetailDictionary(NSDictionary *dict) {
    if (![dict isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    if (dict[@"$type"] || dict[@"BattleType"] || dict[@"battleType"]) {
        return YES;
    }
    if ((dict[@"ATeam"] || dict[@"aTeam"]) && (dict[@"BTeam"] || dict[@"bTeam"])) {
        return YES;
    }
    return dict[@"Seed"] || dict[@"seed"];
}

static NSString *SBControlDetailJsonFromEntityOperations(id object, NSUInteger depth) {
    if (depth > 10 || !object || object == NSNull.null) {
        return @"";
    }

    if ([object isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)object) {
            NSString *detailJson = SBControlDetailJsonFromObject(item, depth + 1);
            if (detailJson.length > 0) {
                return detailJson;
            }
        }
        return @"";
    }

    if (![object isKindOfClass:NSDictionary.class]) {
        return SBControlDetailJsonFromObject(object, depth + 1);
    }

    NSDictionary *dict = (NSDictionary *)object;
    NSArray<NSString *> *preferredKeys = @[
        @"BattleReservation",
        @"battleReservation",
        @"Soccer.Shared.BattleReservation",
        @"IBattleReservation",
        @"Reservation",
        @"reservation"
    ];
    for (NSString *key in preferredKeys) {
        NSString *detailJson = SBControlDetailJsonFromObject(dict[key], depth + 1);
        if (detailJson.length > 0) {
            return detailJson;
        }
    }

    for (id key in dict) {
        if (![key isKindOfClass:NSString.class]) {
            continue;
        }
        NSString *name = (NSString *)key;
        NSRange battleReservation = [name rangeOfString:@"BattleReservation"
                                                options:NSCaseInsensitiveSearch];
        NSRange reservation = [name rangeOfString:@"Reservation"
                                          options:NSCaseInsensitiveSearch];
        if (battleReservation.location == NSNotFound && reservation.location == NSNotFound) {
            continue;
        }
        NSString *detailJson = SBControlDetailJsonFromObject(dict[key], depth + 1);
        if (detailJson.length > 0) {
            return detailJson;
        }
    }

    for (id value in dict.allValues) {
        NSString *detailJson = SBControlDetailJsonFromObject(value, depth + 1);
        if (detailJson.length > 0) {
            return detailJson;
        }
    }
    return @"";
}

static NSString *SBControlDetailJsonFromObject(id object, NSUInteger depth) {
    if (depth > 10 || !object || object == NSNull.null) {
        return @"";
    }

    if ([object isKindOfClass:NSString.class]) {
        NSString *trimmed = SBControlTrimmedString(object);
        id parsed = SBControlJSONObjectFromString(trimmed);
        if (parsed) {
            NSString *detailJson = SBControlDetailJsonFromObject(parsed, depth + 1);
            if (detailJson.length > 0) {
                return detailJson;
            }
        }
        return depth == 0 ? trimmed : @"";
    }

    if ([object isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)object) {
            NSString *detailJson = SBControlDetailJsonFromObject(item, depth + 1);
            if (detailJson.length > 0) {
                return detailJson;
            }
        }
        return @"";
    }

    if (![object isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *dict = (NSDictionary *)object;
    id detailJsonValue = SBControlValueForAnyKey(dict, @[@"detailJson", @"DetailJson"]);
    NSString *detailJson = SBControlDetailJsonFromObject(detailJsonValue, depth + 1);
    if (detailJson.length > 0) {
        return detailJson;
    }

    id entityOperations = SBControlValueForAnyKey(dict, @[
        @"entityOperations",
        @"EntityOperations",
        @"EntityOperation",
        @"entityOperation"
    ]);
    detailJson = SBControlDetailJsonFromEntityOperations(entityOperations, depth + 1);
    if (detailJson.length > 0) {
        return detailJson;
    }

    id current = SBControlValueForAnyKey(dict, @[@"current", @"Current"]);
    detailJson = SBControlDetailJsonFromObject(current, depth + 1);
    if (detailJson.length > 0) {
        return detailJson;
    }

    id reservation = SBControlValueForAnyKey(dict, @[
        @"battleReservation",
        @"BattleReservation",
        @"reservation",
        @"Reservation"
    ]);
    detailJson = SBControlDetailJsonFromObject(reservation, depth + 1);
    if (detailJson.length > 0) {
        return detailJson;
    }

    id response = SBControlValueForAnyKey(dict, @[
        @"entityOperationResponse",
        @"EntityOperationResponse",
        @"response",
        @"Response",
        @"res",
        @"Res",
        @"data",
        @"Data"
    ]);
    detailJson = SBControlDetailJsonFromObject(response, depth + 1);
    if (detailJson.length > 0) {
        return detailJson;
    }

    if (SBControlLooksLikeBattleDetailDictionary(dict)) {
        return SBControlJSONStringFromObject(dict);
    }
    return @"";
}

static NSString *SBControlDetailJsonFromBody(NSData *bodyData) {
    if (bodyData.length == 0) {
        return @"";
    }

    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:&jsonError];
    NSString *detailJson = SBControlDetailJsonFromObject(json, 0);
    if (detailJson.length > 0) {
        return detailJson;
    }
    if (json && !jsonError) {
        return @"";
    }

    NSString *raw = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding] ?: @"";
    return [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSInteger SBControlBattleStageFromBody(NSData *bodyData) {
    NSInteger stage = 1;
    if (bodyData.length > 0) {
        id json = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:nil];
        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *dict = (NSDictionary *)json;
            id value = dict[@"stage"] ?: dict[@"Stage"] ?: dict[@"maxStage"] ?: dict[@"MaxStage"];
            if ([value respondsToSelector:@selector(integerValue)]) {
                stage = [value integerValue];
            }
        }
    }
    BOOL singleGetterStage = stage >= 21 && stage <= 25;
    BOOL stageMasterProbeStage = stage >= 26 && stage <= 30;
    if (stage < 1) {
        stage = 1;
    }
    if (!singleGetterStage && !stageMasterProbeStage && stage > 6) {
        stage = 6;
    }
    return stage;
}

static NSString *SBControlServerVersionHashFromBody(NSData *bodyData) {
    if (bodyData.length == 0) {
        return @"";
    }

    id json = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *dict = (NSDictionary *)json;
    id value = dict[@"serverVersionHash"] ?: dict[@"ServerVersionHash"];
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *SBControlMasterDataPathFromBody(NSData *bodyData) {
    if (bodyData.length == 0) {
        return @"";
    }

    id json = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *dict = (NSDictionary *)json;
    id value = dict[@"masterDataPath"] ?: dict[@"MasterDataPath"];
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *SBControlBattleDetailSummary(NSString *detailJson) {
    id parsed = SBControlJSONObjectFromString(detailJson);
    if (![parsed isKindOfClass:NSDictionary.class]) {
        return @"";
    }

    NSDictionary *detail = (NSDictionary *)parsed;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    id stageCode = detail[@"StageCode"] ?: detail[@"stageCode"] ?: detail[@"Code"] ?: detail[@"code"];
    id seed = detail[@"Seed"] ?: detail[@"seed"];
    id battleType = detail[@"BattleType"] ?: detail[@"battleType"];
    if (stageCode) {
        [parts addObject:[NSString stringWithFormat:@"stage=%@", stageCode]];
    }
    if (seed) {
        [parts addObject:[NSString stringWithFormat:@"seed=%@", seed]];
    }
    if (battleType) {
        [parts addObject:[NSString stringWithFormat:@"type=%@", battleType]];
    }
    return [parts componentsJoinedByString:@" "];
}

static NSString *SBControlRequestSummary(NSString *method,
                                         NSString *path,
                                         NSString *remoteAddress,
                                         NSData *bodyData) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    [parts addObject:[NSString stringWithFormat:@"%@ %@", method ?: @"", path ?: @""]];
    if (remoteAddress.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"from=%@", remoteAddress]];
    }
    [parts addObject:[NSString stringWithFormat:@"body=%lu", (unsigned long)bodyData.length]];

    if ([path hasPrefix:@"/battle-"]) {
        if ([path isEqualToString:@"/battle-stage-probe"]) {
            [parts addObject:[NSString stringWithFormat:@"probeStage=%ld",
                              (long)SBControlBattleStageFromBody(bodyData)]];
        }
        NSString *detailJson = SBControlDetailJsonFromBody(bodyData);
        NSString *detailSummary = SBControlBattleDetailSummary(detailJson);
        if (detailSummary.length > 0) {
            [parts addObject:detailSummary];
        }
    }

    return [parts componentsJoinedByString:@" "];
}

static NSDictionary *SBControlRunBattleDetailProbe(NSString *detailJson, NSString *remoteAddress) {
    __block NSDictionary *result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    SBControlRunOnMainRunLoop(^{
        SBUnityBridgeBattleDetailResult bridgeResult = SBUnityBridgeRunBattleDetailProbe(detailJson ?: @"");
        NSDictionary *details = SBUnityBridgeBattleDetailResultDictionary(bridgeResult);
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        payload[@"time"] = SBControlTimestamp();
        payload[@"remote"] = remoteAddress ?: @"";
        payload[@"ok"] = @(bridgeResult.ok);
        payload[@"details"] = details ?: @{};

        NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:nil];
        if (json) {
            NSString *path = [SBControlLogRootPath() stringByAppendingPathComponent:@"control-battle-detail-probe.json"];
            [json writeToFile:path atomically:YES];
        }

        SBControlAppendIndexLine(@"control-battle-detail-probe",
                                 [NSString stringWithFormat:@"remote=%@ ok=%d stage=%d seed=%d",
                                  remoteAddress ?: @"",
                                  bridgeResult.ok,
                                  bridgeResult.stageCode,
                                  bridgeResult.seed]);
        result = payload;
        dispatch_semaphore_signal(semaphore);
    });

    long waitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    if (waitResult != 0) {
        return @{
            @"ok": @NO,
            @"error": @"battle detail probe timed out on main thread"
        };
    }
    return result ?: @{@"ok": @NO, @"error": @"battle detail probe produced no result"};
}

static NSDictionary *SBControlRunUnitySceneProbe(NSString *remoteAddress) {
    __block NSDictionary *result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    SBControlRunOnMainRunLoop(^{
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        @try {
            SBUnityBridgeSceneProbeResult bridgeResult = SBUnityBridgeRunSceneProbe();
            NSDictionary *details = SBUnityBridgeSceneProbeResultDictionary(bridgeResult);
            payload[@"time"] = SBControlTimestamp();
            payload[@"remote"] = remoteAddress ?: @"";
            payload[@"ok"] = @(bridgeResult.ok);
            payload[@"details"] = details ?: @{};

            SBControlAppendIndexLine(@"control-unity-scene-probe",
                                     [NSString stringWithFormat:@"remote=%@ ok=%d starters=%d battleVMs=%d starter=0x%llx battleVM=0x%llx model=0x%llx",
                                      remoteAddress ?: @"",
                                      bridgeResult.ok,
                                      bridgeResult.battleStarterCount,
                                      bridgeResult.soccerBattleVMCount,
                                      (unsigned long long)bridgeResult.battleStarter,
                                      (unsigned long long)bridgeResult.soccerBattleVMFromStarter,
                                      (unsigned long long)bridgeResult.soccerBattleModel]);
        } @catch (NSException *exception) {
            payload[@"time"] = SBControlTimestamp();
            payload[@"remote"] = remoteAddress ?: @"";
            payload[@"ok"] = @NO;
            payload[@"exceptionName"] = exception.name ?: @"";
            payload[@"exceptionReason"] = exception.reason ?: @"";
            payload[@"error"] = @"Unity scene probe raised an Objective-C exception";
            SBControlAppendIndexLine(@"control-unity-scene-exception",
                                     [NSString stringWithFormat:@"remote=%@ name=%@ reason=%@",
                                      remoteAddress ?: @"",
                                      exception.name ?: @"",
                                      exception.reason ?: @""]);
        }

        NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:nil];
        if (json) {
            NSString *path = [SBControlLogRootPath() stringByAppendingPathComponent:@"control-unity-scene-probe.json"];
            [json writeToFile:path atomically:YES];
        }

        result = payload;
        dispatch_semaphore_signal(semaphore);
    });

    long waitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    if (waitResult != 0) {
        return @{
            @"ok": @NO,
            @"error": @"unity scene probe timed out on main thread"
        };
    }
    return result ?: @{@"ok": @NO, @"error": @"unity scene probe produced no result"};
}

static NSDictionary *SBControlRunFinishCaptureInstall(NSString *remoteAddress) {
    __block NSDictionary *result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    SBControlRunOnMainRunLoop(^{
        NSString *logRoot = SBControlLogRootPath();
        NSDictionary *snapshot = SBFinishRequestCaptureInstall();
        NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:snapshot ?: @{}];
        payload[@"time"] = SBControlTimestamp();
        payload[@"remote"] = remoteAddress ?: @"";
        payload[@"action"] = @"install";
        payload[@"logRoot"] = logRoot ?: @"";
        payload[@"logSession"] = logRoot.lastPathComponent ?: @"";

        NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:nil];
        if (json) {
            NSString *path = [logRoot stringByAppendingPathComponent:@"control-finish-capture-install.json"];
            [json writeToFile:path atomically:YES];
        }

        SBControlAppendIndexLine(@"control-finish-capture-install",
                                 [NSString stringWithFormat:@"remote=%@ installed=%d captured=%d",
                                  remoteAddress ?: @"",
                                  [payload[@"installed"] boolValue],
                                  [payload[@"captured"] boolValue]]);
        result = payload;
        dispatch_semaphore_signal(semaphore);
    });

    long waitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    if (waitResult != 0) {
        return @{
            @"ok": @NO,
            @"error": @"finish capture install timed out on main thread"
        };
    }
    return result ?: @{@"ok": @NO, @"error": @"finish capture install produced no result"};
}

static NSDictionary *SBControlRunFinishCaptureSnapshot(NSString *remoteAddress, BOOL clear) {
    NSString *logRoot = SBControlLogRootPath();
    NSDictionary *snapshot = clear ? SBFinishRequestCaptureClear() : SBFinishRequestCaptureSnapshot();
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:snapshot ?: @{}];
    payload[@"time"] = SBControlTimestamp();
    payload[@"remote"] = remoteAddress ?: @"";
    payload[@"action"] = clear ? @"clear" : @"last";
    payload[@"logRoot"] = logRoot ?: @"";
    payload[@"logSession"] = logRoot.lastPathComponent ?: @"";

    NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:nil];
    if (json) {
        NSString *name = clear ? @"control-finish-capture-clear.json" : @"control-finish-capture-last.json";
        NSString *path = [logRoot stringByAppendingPathComponent:name];
        [json writeToFile:path atomically:YES];
    }

    SBControlAppendIndexLine(clear ? @"control-finish-capture-clear" : @"control-finish-capture-last",
                             [NSString stringWithFormat:@"remote=%@ installed=%d captured=%d",
                              remoteAddress ?: @"",
                              [payload[@"installed"] boolValue],
                              [payload[@"captured"] boolValue]]);
    return payload;
}

static NSDictionary *SBControlRunBattleStageProbe(NSString *detailJson,
                                                  NSInteger stage,
                                                  NSString *serverVersionHash,
                                                  NSString *masterDataPath,
                                                  NSString *remoteAddress) {
    __block NSDictionary *result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    SBControlRunOnMainRunLoop(^{
        SBControlAppendIndexLine(@"control-battle-stage-enter",
                                 [NSString stringWithFormat:@"remote=%@ stage=%ld serverVersionHash=%@ masterDataPath=%@",
                                  remoteAddress ?: @"",
                                  (long)stage,
                                  serverVersionHash ?: @"",
                                  masterDataPath ?: @""]);
        NSMutableDictionary *payload = [NSMutableDictionary dictionary];
        @try {
            SBUnityBridgeBattleConstructResult bridgeResult =
                SBUnityBridgeRunBattleConstructProbe(detailJson ?: @"",
                                                     (int32_t)stage,
                                                     serverVersionHash ?: @"",
                                                     masterDataPath ?: @"");
            NSDictionary *details = SBUnityBridgeBattleConstructResultDictionary(bridgeResult);
            payload[@"time"] = SBControlTimestamp();
            payload[@"remote"] = remoteAddress ?: @"";
            payload[@"stage"] = @(stage);
            payload[@"serverVersionHash"] = serverVersionHash ?: @"";
            payload[@"masterDataPath"] = masterDataPath ?: @"";
            payload[@"ok"] = @(bridgeResult.ok);
            payload[@"details"] = details ?: @{};

            SBControlAppendIndexLine(@"control-battle-stage-probe",
                                     [NSString stringWithFormat:@"remote=%@ stage=%ld ok=%d completed=%d getter=%d stageCode=%d seed=%d",
                                      remoteAddress ?: @"",
                                      (long)stage,
                                      bridgeResult.ok,
                                      bridgeResult.completedStage,
                                      bridgeResult.completedGetter,
                                      bridgeResult.stageCode,
                                      bridgeResult.seed]);
        } @catch (NSException *exception) {
            payload[@"time"] = SBControlTimestamp();
            payload[@"remote"] = remoteAddress ?: @"";
            payload[@"stage"] = @(stage);
            payload[@"serverVersionHash"] = serverVersionHash ?: @"";
            payload[@"masterDataPath"] = masterDataPath ?: @"";
            payload[@"ok"] = @NO;
            payload[@"exceptionName"] = exception.name ?: @"";
            payload[@"exceptionReason"] = exception.reason ?: @"";
            payload[@"error"] = @"Unity bridge raised an Objective-C exception";
            SBControlAppendIndexLine(@"control-battle-stage-exception",
                                     [NSString stringWithFormat:@"remote=%@ stage=%ld name=%@ reason=%@",
                                      remoteAddress ?: @"",
                                      (long)stage,
                                      exception.name ?: @"",
                                      exception.reason ?: @""]);
        }

        NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                         error:nil];
        if (json) {
            NSString *path = [SBControlLogRootPath() stringByAppendingPathComponent:@"control-battle-stage-probe.json"];
            [json writeToFile:path atomically:YES];
        }

        result = payload;
        dispatch_semaphore_signal(semaphore);
    });

    long waitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC));
    if (waitResult != 0) {
        return @{
            @"ok": @NO,
            @"stage": @(stage),
            @"error": @"battle stage probe timed out on main thread"
        };
    }
    return result ?: @{@"ok": @NO, @"stage": @(stage), @"error": @"battle stage probe produced no result"};
}

static NSDictionary *SBControlRunBattleFinishBody(NSString *detailJson,
                                                  NSString *serverVersionHash,
                                                  NSString *masterDataPath,
                                                  NSString *remoteAddress) {
    NSDictionary *probe = SBControlRunBattleStageProbe(detailJson,
                                                       29,
                                                       serverVersionHash ?: @"",
                                                       masterDataPath ?: @"",
                                                       remoteAddress ?: @"");
    NSDictionary *details = [probe[@"details"] isKindOfClass:NSDictionary.class] ? probe[@"details"] : @{};
    NSDictionary *requestBody = [details[@"finishRequestBody"] isKindOfClass:NSDictionary.class]
        ? details[@"finishRequestBody"]
        : @{};
    NSString *rawBody = [details[@"finishRequestBodyRaw"] isKindOfClass:NSString.class]
        ? details[@"finishRequestBodyRaw"]
        : @"";
    BOOL ready = [details[@"finishRequestReady"] boolValue] &&
                 requestBody.count > 0 &&
                 rawBody.length > 0;

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"time"] = SBControlTimestamp();
    payload[@"remote"] = remoteAddress ?: @"";
    payload[@"ok"] = @([probe[@"ok"] boolValue] && ready);
    payload[@"path"] = @"/v1/Battle/FinishMainStoryBattle";
    payload[@"method"] = @"POST";
    payload[@"requestBody"] = requestBody;
    payload[@"rawBody"] = rawBody;
    payload[@"simulation"] = @{
        @"ok": probe[@"ok"] ?: @NO,
        @"stage": probe[@"stage"] ?: @29,
        @"battleCoroutineCompleted": details[@"battleCoroutineCompleted"] ?: @NO,
        @"finalResult": details[@"finalResult"] ?: @0,
        @"finalTurn": details[@"finalTurn"] ?: @0,
        @"aScore": details[@"aScore"] ?: @0,
        @"bScore": details[@"bScore"] ?: @0,
        @"moveSelectionsCount": details[@"moveSelectionsCount"] ?: @0,
        @"phaseResultsCount": details[@"phaseResultsCount"] ?: @0,
        @"error": details[@"error"] ?: @""
    };
    if (![payload[@"ok"] boolValue]) {
        payload[@"error"] = rawBody.length == 0
            ? @"Unity battle simulation completed without a FinishMainStoryBattle body"
            : (probe[@"error"] ?: details[@"error"] ?: @"battle finish body probe failed");
        payload[@"details"] = details;
    }

    NSData *json = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:nil];
    if (json) {
        NSString *path = [SBControlLogRootPath() stringByAppendingPathComponent:@"control-battle-finish-body.json"];
        [json writeToFile:path atomically:YES];
    }
    SBControlAppendIndexLine(@"control-battle-finish-body",
                             [NSString stringWithFormat:@"remote=%@ ok=%d score=%@-%@ moves=%@",
                              remoteAddress ?: @"",
                              [payload[@"ok"] boolValue],
                              payload[@"simulation"][@"aScore"],
                              payload[@"simulation"][@"bScore"],
                              payload[@"simulation"][@"moveSelectionsCount"]]);
    return payload;
}

static void SBControlHandleClient(int clientFd, NSString *remoteAddress) {
    NSData *requestData = SBControlReadHTTPRequest(clientFd);
    if (requestData.length == 0) {
        close(clientFd);
        return;
    }

    NSInteger bodyOffset = SBControlHeaderBodyOffset(requestData);
    NSUInteger headerLength = bodyOffset > 0 ? (NSUInteger)bodyOffset : requestData.length;
    NSString *header = [[NSString alloc] initWithBytes:requestData.bytes
                                                length:headerLength
                                              encoding:NSUTF8StringEncoding] ?: @"";

    char method[16] = {0};
    char target[512] = {0};
    if (sscanf(header.UTF8String ?: "", "%15s %511s", method, target) != 2) {
        SBControlSendJSON(clientFd, 400, @"Bad Request", @{@"ok": @NO, @"error": @"bad request"});
        close(clientFd);
        return;
    }

    NSString *path = SBControlRequestPath(target);
    NSString *methodString = [NSString stringWithUTF8String:method] ?: @"";
    SBControlAppendIndexLine(@"control-request",
                             [NSString stringWithFormat:@"%@ %@ from %@",
                              methodString,
                              path,
                              remoteAddress ?: @""]);
    NSData *bodyForSummary = SBControlBodyFromRequest(requestData);
    NSString *requestSummary = SBControlRequestSummary(methodString, path, remoteAddress ?: @"", bodyForSummary);
    NSThread.currentThread.threadDictionary[SBControlThreadRequestSummaryKey] = requestSummary ?: @"";
    SBControlAppendStatusEvent([NSString stringWithFormat:@"REQ %@", requestSummary ?: @""]);

    if (strcmp(method, "OPTIONS") == 0) {
        SBControlSendJSON(clientFd, 200, @"OK", @{@"ok": @YES});
    } else if ([path isEqualToString:@"/health"]) {
        SBControlSendJSON(clientFd, 200, @"OK", @{
            @"ok": @YES,
            @"service": @"SoccerAppBypass",
            @"port": @(SBControlPort)
        });
    } else if ((strcmp(method, "GET") == 0 || strcmp(method, "POST") == 0) && [path isEqualToString:@"/ready"]) {
        NSString *requestId = NSUUID.UUID.UUIDString;
        SBControlScheduleReadyAction(requestId, remoteAddress ?: @"");
        SBControlSendJSON(clientFd, 200, @"OK", @{
            @"ok": @YES,
            @"queued": @YES,
            @"requestId": requestId,
            @"action": @"ready"
        });
    } else if ((strcmp(method, "GET") == 0 || strcmp(method, "POST") == 0) && [path isEqualToString:@"/unity-scene-probe"]) {
        NSDictionary *probe = SBControlRunUnitySceneProbe(remoteAddress ?: @"");
        BOOL ok = [probe[@"ok"] boolValue];
        SBControlSendJSON(clientFd, ok ? 200 : 500, ok ? @"OK" : @"Probe Failed", probe);
    } else if ((strcmp(method, "GET") == 0 || strcmp(method, "POST") == 0) && [path isEqualToString:@"/finish-capture/install"]) {
        NSDictionary *capture = SBControlRunFinishCaptureInstall(remoteAddress ?: @"");
        BOOL ok = [capture[@"installed"] boolValue];
        SBControlSendJSON(clientFd, ok ? 200 : 500, ok ? @"OK" : @"Install Failed", capture);
    } else if ((strcmp(method, "GET") == 0 || strcmp(method, "POST") == 0) && [path isEqualToString:@"/finish-capture/last"]) {
        NSDictionary *capture = SBControlRunFinishCaptureSnapshot(remoteAddress ?: @"", NO);
        SBControlSendJSON(clientFd, 200, @"OK", capture);
    } else if ((strcmp(method, "GET") == 0 || strcmp(method, "POST") == 0) && [path isEqualToString:@"/finish-capture/clear"]) {
        NSDictionary *capture = SBControlRunFinishCaptureSnapshot(remoteAddress ?: @"", YES);
        SBControlSendJSON(clientFd, 200, @"OK", capture);
    } else if (strcmp(method, "POST") == 0 && [path isEqualToString:@"/battle-detail-probe"]) {
        NSData *bodyData = SBControlBodyFromRequest(requestData);
        NSString *detailJson = SBControlDetailJsonFromBody(bodyData);
        if (detailJson.length == 0) {
            SBControlSendJSON(clientFd, 400, @"Bad Request", @{
                @"ok": @NO,
                @"error": @"POST body must be DetailJson or {\"detailJson\":\"...\"}"
            });
        } else {
            NSDictionary *probe = SBControlRunBattleDetailProbe(detailJson, remoteAddress ?: @"");
            BOOL ok = [probe[@"ok"] boolValue];
            SBControlSendJSON(clientFd, ok ? 200 : 500, ok ? @"OK" : @"Probe Failed", probe);
        }
    } else if (strcmp(method, "POST") == 0 && [path isEqualToString:@"/battle-stage-probe"]) {
        NSData *bodyData = SBControlBodyFromRequest(requestData);
        NSString *detailJson = SBControlDetailJsonFromBody(bodyData);
        NSInteger stage = SBControlBattleStageFromBody(bodyData);
        NSString *serverVersionHash = SBControlServerVersionHashFromBody(bodyData);
        NSString *masterDataPath = SBControlMasterDataPathFromBody(bodyData);
        if (serverVersionHash.length == 0 && masterDataPath.length == 0) {
            serverVersionHash = SBControlCachedServerVersionHash();
        }
        if (detailJson.length == 0) {
            SBControlSendJSON(clientFd, 400, @"Bad Request", @{
                @"ok": @NO,
                @"error": @"POST body must be DetailJson or {\"detailJson\":\"...\",\"stage\":1,\"serverVersionHash\":\"...\",\"masterDataPath\":\"...\"}; getter stages: 21..25, raw/direct/load StageMaster stages: 26..28, battle coroutine stage: 29, battle replay round-trip stage: 30"
            });
        } else {
            NSDictionary *probe = SBControlRunBattleStageProbe(detailJson,
                                                               stage,
                                                               serverVersionHash ?: @"",
                                                               masterDataPath ?: @"",
                                                               remoteAddress ?: @"");
            BOOL ok = [probe[@"ok"] boolValue];
            SBControlSendJSON(clientFd, ok ? 200 : 500, ok ? @"OK" : @"Probe Failed", probe);
        }
    } else if (strcmp(method, "POST") == 0 && [path isEqualToString:@"/battle-finish-body"]) {
        NSData *bodyData = SBControlBodyFromRequest(requestData);
        NSString *detailJson = SBControlDetailJsonFromBody(bodyData);
        NSString *serverVersionHash = SBControlServerVersionHashFromBody(bodyData);
        NSString *masterDataPath = SBControlMasterDataPathFromBody(bodyData);
        if (serverVersionHash.length == 0 && masterDataPath.length == 0) {
            serverVersionHash = SBControlCachedServerVersionHash();
        }
        if (detailJson.length == 0) {
            SBControlSendJSON(clientFd, 400, @"Bad Request", @{
                @"ok": @NO,
                @"error": @"POST body must contain DetailJson or EntityOperations -> BattleReservation -> DetailJson"
            });
        } else {
            NSDictionary *finish = SBControlRunBattleFinishBody(detailJson,
                                                                serverVersionHash ?: @"",
                                                                masterDataPath ?: @"",
                                                                remoteAddress ?: @"");
            BOOL ok = [finish[@"ok"] boolValue];
            SBControlSendJSON(clientFd, ok ? 200 : 500, ok ? @"OK" : @"Probe Failed", finish);
        }
    } else {
        SBControlSendJSON(clientFd, 404, @"Not Found", @{
            @"ok": @NO,
            @"error": @"supported endpoints: GET /health, GET/POST /ready, GET/POST /unity-scene-probe, GET/POST /finish-capture/install, GET/POST /finish-capture/last, GET/POST /finish-capture/clear, POST /battle-detail-probe, POST /battle-stage-probe, POST /battle-finish-body"
        });
    }

    [NSThread.currentThread.threadDictionary removeObjectForKey:SBControlThreadRequestSummaryKey];
    close(clientFd);
}

static void SBControlAcceptLoop(int serverFd) {
    dispatch_queue_t clientQueue = dispatch_queue_create("local.srzq.SoccerAppBypass.control.clients",
                                                         DISPATCH_QUEUE_CONCURRENT);
    while (true) {
        struct sockaddr_in remote;
        socklen_t remoteLen = sizeof(remote);
        int clientFd = accept(serverFd, (struct sockaddr *)&remote, &remoteLen);
        if (clientFd < 0) {
            if (errno == EINTR) {
                continue;
            }
            SBControlAppendIndexLine(@"control-accept-error",
                                     [NSString stringWithFormat:@"errno=%d", errno]);
            continue;
        }

        char remoteBuffer[INET_ADDRSTRLEN] = {0};
        inet_ntop(AF_INET, &remote.sin_addr, remoteBuffer, sizeof(remoteBuffer));
        NSString *remoteAddress = [NSString stringWithFormat:@"%s:%u",
                                   remoteBuffer[0] ? remoteBuffer : "unknown",
                                   ntohs(remote.sin_port)];
        dispatch_async(clientQueue, ^{
            SBControlHandleClient(clientFd, remoteAddress);
        });
    }
}

static void SBControlStartServerNow(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&SBControlServerStarted, &expected, true)) {
        return;
    }
    SBControlSetServerState(@"starting", [NSString stringWithFormat:@"port=%u", SBControlPort]);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) {
            SBControlSetServerState(@"failed", [NSString stringWithFormat:@"socket errno=%d", errno]);
            SBControlAppendIndexLine(@"control-listen-failed",
                                     [NSString stringWithFormat:@"socket errno=%d", errno]);
            return;
        }

        int yes = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
#ifdef SO_NOSIGPIPE
        setsockopt(serverFd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
#endif

        struct sockaddr_in address;
        memset(&address, 0, sizeof(address));
        address.sin_len = sizeof(address);
        address.sin_family = AF_INET;
        address.sin_port = htons(SBControlPort);
        address.sin_addr.s_addr = htonl(INADDR_ANY);

        if (bind(serverFd, (struct sockaddr *)&address, sizeof(address)) != 0) {
            int savedErrno = errno;
            close(serverFd);
            SBControlSetServerState(@"failed",
                                    [NSString stringWithFormat:@"bind 0.0.0.0:%u errno=%d",
                                     SBControlPort,
                                     savedErrno]);
            SBControlAppendIndexLine(@"control-listen-failed",
                                     [NSString stringWithFormat:@"bind 0.0.0.0:%u errno=%d",
                                      SBControlPort,
                                      savedErrno]);
            return;
        }

        if (listen(serverFd, 8) != 0) {
            int savedErrno = errno;
            close(serverFd);
            SBControlSetServerState(@"failed", [NSString stringWithFormat:@"listen errno=%d", savedErrno]);
            SBControlAppendIndexLine(@"control-listen-failed",
                                     [NSString stringWithFormat:@"listen errno=%d", savedErrno]);
            return;
        }

        SBControlSetServerState(@"listening", [NSString stringWithFormat:@"0.0.0.0:%u", SBControlPort]);
        SBControlAppendIndexLine(@"control-listening",
                                 [NSString stringWithFormat:@"0.0.0.0:%u endpoints=/health,/ready,/unity-scene-probe,/finish-capture/install,/finish-capture/last,/finish-capture/clear,/battle-detail-probe,/battle-stage-probe,/battle-finish-body", SBControlPort]);
        SBControlAcceptLoop(serverFd);
        close(serverFd);
    });
}

void SBStartLocalControlServer(void) {
    SBUnityBridgeSetProgressHandler(SBControlUnityBridgeProgress);
    SBControlSetServerState(@"waiting", @"UIApplicationDidBecomeActive");

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(__unused NSNotification *note) {
        SBControlStartServerNow();
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(SBControlFallbackStartDelaySeconds * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        SBControlStartServerNow();
    });
}
