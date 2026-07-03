#import "SBHookCompat.h"

#if SB_MACVER
#import <Foundation/Foundation.h>

void MSHookFunction(void *symbol, void *replace, void **result) {
    if (result) {
        *result = NULL;
    }
    if (!symbol || !replace) {
        NSLog(@"[SoccerAppBypass][mac] MSHookFunction invalid args symbol=%p replace=%p", symbol, replace);
        return;
    }

    void *origin = NULL;
    int rc = DobbyHook(symbol, replace, &origin);
    if (result) {
        *result = origin;
    }
    if (rc != 0) {
        NSLog(@"[SoccerAppBypass][mac] DobbyHook failed rc=%d symbol=%p replace=%p", rc, symbol, replace);
    }
}

void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result) {
    if (result) {
        *result = NULL;
    }
    if (!cls || !sel || !imp) {
        NSLog(@"[SoccerAppBypass][mac] MSHookMessageEx invalid args class=%p sel=%p imp=%p", cls, sel, imp);
        return;
    }

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        NSLog(@"[SoccerAppBypass][mac] MSHookMessageEx missing method %s %s",
              class_getName(cls), sel_getName(sel));
        return;
    }

    IMP oldImp = method_setImplementation(method, imp);
    if (result) {
        *result = oldImp;
    }
}
#endif
