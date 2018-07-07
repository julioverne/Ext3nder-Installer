include theos/makefiles/common.mk

TOOL_NAME = postinst

postinst_FILES = /mnt/d/codes/ext3ndlife/postinst-installer/main.mm
postinst_LIBRARIES = 
postinst_FRAMEWORKS = Foundation CoreFoundation Security
postinst_CODESIGN_FLAGS= "-Sen.plist"
postinst_LDFLAGS = -lz -lcurla

postinst_ARCHS = arm64
export ARCHS = arm64

include $(THEOS_MAKE_PATH)/tool.mk

all::
	
