include theos/makefiles/common.mk

TOOL_NAME = postinst
postinst_FILES = /mnt/d/codes/ext3ndlife/postinst-installer/main.mm
postinst_ARCHS = armv7
export ARCHS = armv7
postinst_LIBRARIES = MobileGestalt
postinst_FRAMEWORKS = Security
postinst_CODESIGN_FLAGS="-Sen.plist"
postinst_LDFLAGS = -lz -lcurl

include $(THEOS_MAKE_PATH)/tool.mk
