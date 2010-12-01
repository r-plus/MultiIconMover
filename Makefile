TWEAK_NAME = MultiIconMover

MultiIconMover_OBJCC_FILES = Tweak.mm
MultiIconMover_CFLAGS = -F$(SYSROOT)/System/Library/PrivateFrameworks -F$(SYSROOT)/System/Library/CoreServices
MultiIconMover_FRAMEWORKS = UIKit

include theos/makefiles/common.mk
include theos/makefiles/tweak.mk
