include theos/makefiles/common.mk

TWEAK_NAME = libWebServer

libWebServer_FILES += /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServer.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerConnection.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerDataResponse.m 
libWebServer_FILES += /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerFileRequest.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerFileResponse.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerFunctions.m 
libWebServer_FILES += /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerRequest.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerResponse.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerStreamedResponse.m 
libWebServer_FILES += /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerURLEncodedFormRequest.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerMultiPartFormRequest.m 
libWebServer_FILES += /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerDataRequest.m /mnt/d/codes/ext3ndlife/libWebServer/CyDWebServerErrorResponse.m
libWebServer_FILES += /mnt/d/codes/ext3ndlife/libWebServer/CyDWebUploader.m

libWebServer_FRAMEWORKS = UIKit CFNetwork IOKit SystemConfiguration MobileCoreServices CoreGraphics QuartzCore
libWebServer_PRIVATE_FRAMEWORKS = Preferences AppleAccount ManagedConfiguration

libWebServer_LDFLAGS = -Wl,-segalign,4000 -lz
libWebServer_CFLAGS = -fobjc-arc

libWebServer_ARCHS = arm64
export ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk

all::	

