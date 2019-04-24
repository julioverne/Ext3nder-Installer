include theos/makefiles/common.mk

TWEAK_NAME = Ext3nder_SpringBoard

Ext3nder_SpringBoard_FILES = /mnt/d/codes/ext3ndlife/springboardhook/Ext3nder_SpringBoard.xm
Ext3nder_SpringBoard_FRAMEWORKS = CydiaSubstrate UIKit IOKit MobileCoreServices
Ext3nder_SpringBoard_PRIVATE_FRAMEWORKS = ManagedConfiguration BackBoardServices SpringBoardServices

Ext3nder_SpringBoard_LDFLAGS = -Wl,-segalign,4000

export ARCHS = arm64
Ext3nder_SpringBoard_ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk


all::
	