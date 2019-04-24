include theos/makefiles/common.mk

TOOL_NAME = postinst

postinst_FILES = /mnt/d/codes/ext3ndlife/postinst/main.mm
postinst_LIBRARIES = MobileGestalt
postinst_FRAMEWORKS = Security
postinst_CODESIGN_FLAGS="-Sen.plist"

postinst_LDFLAGS = -Wl,-segalign,4000

postinst_ARCHS = arm64
export ARCHS = arm64

include $(THEOS_MAKE_PATH)/tool.mk
