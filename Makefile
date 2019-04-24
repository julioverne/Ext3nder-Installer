include theos/makefiles/common.mk

SUBPROJECTS += springboardhook
SUBPROJECTS += ext3nderhook
SUBPROJECTS += installdhook
SUBPROJECTS += libWebServer
SUBPROJECTS += postinst-installer


include $(THEOS_MAKE_PATH)/aggregate.mk

all::
	
