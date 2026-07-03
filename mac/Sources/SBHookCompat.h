#pragma once

#import <objc/runtime.h>

#ifndef SB_MACVER
#define SB_MACVER 0
#endif

#if SB_MACVER
#import "dobby.h"
#ifdef __cplusplus
extern "C" {
#endif
void MSHookFunction(void *symbol, void *replace, void **result);
void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result);
#ifdef __cplusplus
}
#endif
#else
#include <substrate.h>
#endif
