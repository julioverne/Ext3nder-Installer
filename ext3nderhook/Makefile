include theos/makefiles/common.mk

TWEAK_NAME = Extendlife

Extendlife_FILES = /mnt/d/codes/ext3ndlife/ext3nderhook/Version.m /mnt/d/codes/ext3ndlife/ext3nderhook/Extendlife.xm /mnt/d/codes/ext3ndlife/ext3nderhook/SettingsExtendlife.xm /mnt/d/codes/ext3ndlife/ext3nderhook/DocumentsExtendlife.xm
Extendlife_FILES += /mnt/d/codes/ext3ndlife/ext3nderhook/NSData+GZIP.m

Extendlife_FILES += /mnt/d/codes/ext3ndlife/ext3nderhook/CyDownUploadController.xm

Extendlife_FRAMEWORKS = UIKit CFNetwork IOKit SystemConfiguration MobileCoreServices CoreGraphics QuartzCore CydiaSubstrate
Extendlife_PRIVATE_FRAMEWORKS = Preferences AppleAccount ManagedConfiguration
Extendlife_LIBRARIES = MobileGestalt

Extendlife_LDFLAGS = -Wl,-segalign,4000 -lz -Wl,-reexport-lSystem -Wl,-reexport-lSecurity -shared -current_version 1.0.0 -compatibility_version 1.0.0

Extendlife_ARCHS = arm64
export ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@echo "DONE"
	

