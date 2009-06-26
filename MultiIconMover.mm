/**
 * Name: MultiIconMover
 * Type: iPhone OS 3.x SpringBoard extension (MobileSubstrate-based)
 * Description: Allows for moving multiple SpringBoard icons at a time.
 * Usage: In edit (jitter) mode, tap the icons to move, switch to target page,
          and press Home button. The icons will be place to the top of the
          page.
 * Author: Lance Fetters (aka. ashikase)
j* Last-modified: 2009-06-27 01:04:42
 */

/**
 * Copyright (C) 2008  Lance Fetters (aka. ashikase)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#include <sys/time.h>

#import "Common.h"

#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SpringBoard.h>


static struct timeval touchesBeganTime = {0, 0};
static NSMutableArray *selectedIcons = nil;
static UIImage *checkMarkImage = nil;

//______________________________________________________________________________
//______________________________________________________________________________

static UIImage * uikitImageNamed(NSString *name)
{
    // NOTE: This code is modified from Jay Freeman (aka. saurik)'s
    //       UIImages applications, which is bundled with WinterBoard

    struct nlist nl[2];
    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *) "_LoadMappedImageRef";
    nlist("/System/Library/Frameworks/UIKit.framework/UIKit", nl);
    CGImageRef (*_LoadMappedImageRef)(CFStringRef) = (CGImageRef (*)(CFStringRef)) nl[0].n_value;

    return [UIImage imageWithCGImage:_LoadMappedImageRef(reinterpret_cast<CFStringRef>(name))];
}

HOOK(SBIconController, setIsEditing$, void, BOOL isEditing)
{
    if (isEditing) {
        // Load and cache the checkmark image
        checkMarkImage = [uikitImageNamed(@"UIRemoveControlMultiCheckedImage.png") retain];
    } else {
        // Checkmark image is not needed outside of editing mode, release
        [checkMarkImage release];
        checkMarkImage = nil;
    }

    CALL_ORIG(SBIconController, setIsEditing$, isEditing);
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBIcon, touchesBegan$withEvent$, void, NSSet *touches, UIEvent *event)
{
    unsigned int &_isJittering = MSHookIvar<unsigned int>(self, "_isJittering");
    if (_isJittering == 0x3) {
        // Record the touch timer to determine whether or not to select an icon
        // FIXME: It might be more efficient to skip checking for _isJittering
        gettimeofday(&touchesBeganTime, NULL);
    }

    CALL_ORIG(SBIcon, touchesBegan$withEvent$, touches, event);
}

HOOK(SBIcon, touchesEnded$withEvent$, void, NSSet *touches, UIEvent *event)
{
    // FIXME: Is there a simpler way to determine if icons are jittering?
    unsigned int &_isJittering = MSHookIvar<unsigned int>(self, "_isJittering");
    if (_isJittering == 0x7 || _isJittering == 0x4) {
        // Is jittering
        struct timeval nowTime, diffTime;
        gettimeofday(&nowTime, NULL);
        timersub(&nowTime, &touchesBeganTime, &diffTime); 
        // NOTE: If tap time is less than 0.3 seconds, mark as selected
        if (diffTime.tv_sec == 0 && diffTime.tv_usec < 300000) {
            NSString *identifier = [self displayIdentifier];
            SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
            SBIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
            if ([selectedIcons containsObject:identifier]) {
                // Remove icon from list of selected icons
                [selectedIcons removeObject:identifier];

                // Remove the "selected" marker
                [[icon viewWithTag:1000] removeFromSuperview];
            } else {
                // Add icon to list of selected icons
                [selectedIcons addObject:identifier];

                // Add a "selected" marker
                UIImageView *marker = [[UIImageView alloc] initWithImage:checkMarkImage];
                [marker setOrigin:CGPointMake(40.0f, 39.0f)];
                [marker setTag:1000];
                [icon addSubview:marker];
                [marker release];
            }
        }
    }

    CALL_ORIG(SBIcon, touchesEnded$withEvent$, touches, event);
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SpringBoard, applicationDidFinishLaunching$, void, id application)
{
    selectedIcons = [[NSMutableArray alloc] initWithCapacity:4];

    CALL_ORIG(SpringBoard, applicationDidFinishLaunching$, application);
}

HOOK(SpringBoard, dealloc, void)
{
    [selectedIcons release];
    CALL_ORIG(SpringBoard, dealloc);
}

HOOK(SpringBoard, menuButtonUp$, void, struct __GSEvent *event)
{
    SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
    SBIconList *list = [iconCont currentIconList];

    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    for (NSString *identifier in selectedIcons) {
        SBIcon *icon = [iconModel iconForDisplayIdentifier:identifier];

        // Remove the "selected" marker
        [[icon viewWithTag:1000] removeFromSuperview];

        // Move the icon
        // NOTE: Use SBIconController so that any excess icons get moved to next
        //       page
        [iconCont removeIcon:icon animate:NO];
        [iconCont insertIcon:icon intoIconList:list X:0 Y:0 moveNow:YES duration:0];
    }

    // Clear the list of selected icons
    [selectedIcons removeAllObjects];

    CALL_ORIG(SpringBoard, menuButtonUp$, event);
}

//______________________________________________________________________________
//______________________________________________________________________________

extern "C" void MultiIconMoverInitialize()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // NOTE: This library should only be loaded for SpringBoard
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    if (![identifier isEqualToString:@"com.apple.springboard"])
        return;

    Class $SBIconController(objc_getClass("SBIconController"));
    _SBIconController$setIsEditing$ =
        MSHookMessage($SBIconController, @selector(setIsEditing:), &$SBIconController$setIsEditing$);

    Class $SBIcon(objc_getClass("SBIcon"));
    _SBIcon$touchesBegan$withEvent$ =
        MSHookMessage($SBIcon, @selector(touchesBegan:withEvent:), &$SBIcon$touchesBegan$withEvent$);
    _SBIcon$touchesEnded$withEvent$ =
        MSHookMessage($SBIcon, @selector(touchesEnded:withEvent:), &$SBIcon$touchesEnded$withEvent$);

    Class $SpringBoard(objc_getClass("SpringBoard"));
    _SpringBoard$applicationDidFinishLaunching$ =
        MSHookMessage($SpringBoard, @selector(applicationDidFinishLaunching:), &$SpringBoard$applicationDidFinishLaunching$);
    _SpringBoard$dealloc =
        MSHookMessage($SpringBoard, @selector(dealloc), &$SpringBoard$dealloc);
    _SpringBoard$menuButtonUp$ =
        MSHookMessage($SpringBoard, @selector(menuButtonUp:), &$SpringBoard$menuButtonUp$);

    [pool release];
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
