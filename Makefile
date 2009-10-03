NAME = MultiIconMover

# These paths must be changed to match the compilation environment
TOOLCHAIN = /opt/iPhone/sdk/3.0/dumped
SYS_PATH = /opt/iPhone/sys
MS_PATH = /files/Platforms/iPhone/Projects/Others/saurik/mobilesubstrate
LDID = /opt/iPhone/ldid

CXX = arm-apple-darwin9-g++
CXXFLAGS = -g0 -O1 -Wall -Werror -include common.h
LD = $(CXX)
LDFLAGS = -march=armv6 \
		  -mcpu=arm1176jzf-s \
		  -bind_at_load \
		  -multiply_defined suppress \
		  -framework CoreFoundation \
		  -framework Foundation \
		  -framework UIKit \
		  -F$(SYS_PATH)/System/Library/PrivateFrameworks \
		  -L$(MS_PATH) -lsubstrate \
		  -lobjc

INCLUDES = -F$(SYS_PATH)/System/Library/PrivateFrameworks \
		   -F$(SYS_PATH)/System/Library/CoreServices \
		   -I$(MS_PATH)

SUBDIRS    = .

DIRLIST    := $(SUBDIRS:%=%)
SRCS       := $(foreach dir,$(DIRLIST), $(wildcard $(dir)/*.mm))
HDRS       := $(foreach dir,$(DIRLIST), $(wildcard $(dir)/*.h))
OBJS       := $(SRCS:.mm=.o)

all: $(NAME).dylib

config:
	ln -snf $(TOOLCHAIN) $(SYS_PATH)

# Replace 'iphone' with the IP or hostname of your device
install: $(NAME).dylib
	ssh root@iphone rm -f /Library/MobileSubstrate/DynamicLibraries/$(NAME).dylib
	scp $(NAME).dylib root@iphone:/Library/MobileSubstrate/DynamicLibraries/
	ssh root@iphone restart

$(NAME).dylib: config $(OBJS) $(HDRS)
	$(LD) -dynamiclib $(LDFLAGS) $(OBJS) -o $@
	$(LDID) -S $@

%.o: %.mm
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJS) $(NAME).dylib

.PHONY: all clean config install
