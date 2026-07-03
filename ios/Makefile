THEOS ?= $(HOME)/theos
ARCHS = arm64
TARGET = iphone:clang:16.5:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SoccerAppBypass

SoccerAppBypass_FILES = Sources/Tweak.m Sources/BypassShared.c Sources/IL2CPPStringProbe.m Sources/LocalControlServer.m Sources/UnityRuntimeBridge.mm Sources/FinishRequestCapture.m
SoccerAppBypass_CFLAGS = -fobjc-arc -ISources -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -fmodules-cache-path=$(CURDIR)/.theos/module-cache
SoccerAppBypass_OBJCCFLAGS = -std=gnu++17 -fexceptions
SoccerAppBypass_FRAMEWORKS = Foundation UIKit CydiaSubstrate
SoccerAppBypass_LDFLAGS = -Wl,-dead_strip

INSTALL_TARGET_PROCESSES = SoccerApp

include $(THEOS_MAKE_PATH)/tweak.mk

.PHONY: verify-offsets
verify-offsets:
	python3 scripts/verify_finish_offsets.py

.PHONY: selftest-finish-evidence
selftest-finish-evidence:
	python3 scripts/selftest_finish_evidence.py
