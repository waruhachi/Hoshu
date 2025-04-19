ARCHS = arm64
TARGET = iphone:16.5:14.0
INSTALL_TARGET_PROCESSES = Hoshu
IPHONEOS_DEPLOYMENT_TARGET = 15.0

include $(THEOS)/makefiles/common.mk

XCODE_SCHEME = Hoshu
XCODEPROJ_NAME = Hoshu

$(XCODEPROJ_NAME)_XCODEFLAGS = MARKETING_VERSION=$(THEOS_PACKAGE_BASE_VERSION) IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" CODE_SIGN_IDENTITY="" AD_HOC_CODE_SIGNING_ALLOWED=YES
$(XCODEPROJ_NAME)_XCODE_SCHEME = $(XCODE_SCHEME)
$(XCODEPROJ_NAME)_CODESIGN_FLAGS = -Sentitlements.plist
$(XCODEPROJ_NAME)_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/xcodeproj.mk
