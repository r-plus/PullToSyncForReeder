include theos/makefiles/common.mk

TWEAK_NAME = PullToSyncForReeder
PullToSyncForReeder_FILES = Tweak.xm
PullToSyncForReeder_FRAMEWORKS = UIKit QuartzCore AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk
