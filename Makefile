TWEAK_NAME = MultiIconMover
MultiIconMover_OBJCC_FILES = MultiIconMover.mm
MultiIconMover_CFLAGS = -F$(SYSROOT)/System/Library/PrivateFrameworks -F$(SYSROOT)/System/Library/CoreServices
MultiIconMover_FRAMEWORKS = UIKit

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
