SDKVERSION = latest
include theos/makefiles/common.mk

TWEAK_NAME = PullFeatureForReeder
PullFeatureForReeder_FILES = Tweak.xm
PullFeatureForReeder_FRAMEWORKS = UIKit QuartzCore AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk
