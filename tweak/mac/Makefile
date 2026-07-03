THEOS ?= $(HOME)/theos
TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME :=

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := SoccerAppBypass

SoccerAppBypass_FILES := Sources/Tweak.m Sources/SBHookCompat.m Sources/BypassShared.c Sources/fishhook.c Sources/IL2CPPStringProbe.m Sources/LocalControlServer.m Sources/UnityRuntimeBridge.mm Sources/FinishRequestCapture.m
SoccerAppBypass_CFLAGS := -fobjc-arc -ISources -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -fmodules-cache-path=$(CURDIR)/.theos/module-cache -DSB_MACVER=1 -DSB_CONTROL_PORT=19877 -I$(CURDIR)/vendor/dobby
SoccerAppBypass_OBJCCFLAGS := -std=gnu++17 -fexceptions
SoccerAppBypass_FRAMEWORKS := Foundation UIKit Security CoreGraphics AudioToolbox
SoccerAppBypass_LDFLAGS += $(CURDIR)/vendor/dobby/libdobby.a -Wl,-dead_strip

INSTALL_TARGET_PROCESSES := SoccerApp

include $(THEOS_MAKE_PATH)/tweak.mk

.PHONY: embedded-mac-dylib
embedded-mac-dylib:
	$(MAKE) clean
	$(MAKE)
	mkdir -p build/mac
	cp .theos/obj/debug/SoccerAppBypass.dylib build/mac/SoccerAppBypass.dylib
	install_name_tool -id @executable_path/Frameworks/SoccerAppBypass.dylib build/mac/SoccerAppBypass.dylib
	vtool -set-build-version maccatalyst 11.0 14.0 -replace -output build/mac/SoccerAppBypass.dylib build/mac/SoccerAppBypass.dylib
	codesign --force --sign - build/mac/SoccerAppBypass.dylib

.PHONY: verify-offsets
verify-offsets:
	python3 scripts/verify_finish_offsets.py

.PHONY: selftest-finish-evidence
selftest-finish-evidence:
	python3 scripts/selftest_finish_evidence.py
