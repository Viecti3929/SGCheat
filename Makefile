TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Standoff 2

ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SGCheat
SGCheat_FILES = SGEntry.xm SGMenu.mm SGAimbot.mm SGEsp.mm SGMath.mm
SGCheat_CFLAGS = -fobjc-arc -I.
SGCheat_LDFLAGS = -lz -framework Metal -framework MetalKit -framework UIKit -framework CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
    @echo "SGCheat built. .deb at: $(THEOS_OBJ_DIR)"
