include theos/makefiles/common.mk

TWEAK_NAME = Extendlife_installd

Extendlife_installd_FILES = /mnt/d/codes/ext3ndlife/installdhook/Extendlife_installd.xm
Extendlife_installd_FRAMEWORKS = CydiaSubstrate
Extendlife_installd_LDFLAGS = -Wl,-segalign,4000

Extendlife_installd_ARCHS = arm64
export ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk

all::
	