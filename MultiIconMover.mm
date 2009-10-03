/**
 * Name: MultiIconMover
 * Type: iPhone OS 3.x SpringBoard extension (MobileSubstrate-based)
 * Description: Allows for moving multiple SpringBoard icons at a time.
 * Usage: In edit (jitter) mode, tap the icons to move, switch to target page,
          and press Home button. The icons will be place to the top of the
          page.
 * Author: Lance Fetters (aka. ashikase)
j* Last-modified: 2009-10-03 17:19:16
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


#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SpringBoard.h>

#define TAG_CHECKMARK 2000


static NSTimeInterval touchesBeganTime = 0;
static NSMutableArray *selectedIcons = nil;
static UIImage *checkMarkImage = nil;

//______________________________________________________________________________
//______________________________________________________________________________

// NOTE: This code is taken from Jay Freeman (aka. saurik)'s UIImages
//       application, which is bundled with WinterBoard.

template <typename Type_>
static void nlset(Type_ &function, struct nlist *nl, size_t index) {
    struct nlist &name(nl[index]);
    uintptr_t value(name.n_value);
    if ((name.n_desc & N_ARM_THUMB_DEF) != 0)
        value |= 0x00000001;
    function = reinterpret_cast<Type_>(value);
}

// NOTE: This code is modified from Jay Freeman (aka. saurik)'s UIImages
//       application, which is bundled with WinterBoard.
static UIImage * uikitImageNamed(NSString *name)
{
    CGImageRef (*_LoadMappedImageRef)(CFStringRef) = NULL;

    struct nlist nl[2];
    memset(nl, 0, sizeof(nl));
    nl[0].n_un.n_name = (char *) "_LoadMappedImageRef";
    nlist("/System/Library/Frameworks/UIKit.framework/UIKit", nl);
    nlset(_LoadMappedImageRef, nl, 0);

    return [UIImage imageWithCGImage:_LoadMappedImageRef(reinterpret_cast<CFStringRef>(name))];
}

HOOK(SBIconController, setIsEditing$, void, BOOL isEditing)
{
    if (isEditing) {
        // Create array to track selected icons
        selectedIcons = [[NSMutableArray alloc] init];

        // Load and cache the checkmark image
        checkMarkImage = [uikitImageNamed(@"UIRemoveControlMultiCheckedImage.png") retain];
    } else {
        // Checkmark image is not needed outside of editing mode, release
        [checkMarkImage release];
        checkMarkImage = nil;

        // ... same goes for selected icons array
        [selectedIcons release];
        selectedIcons = nil;
    }

    CALL_ORIG(SBIconController, setIsEditing$, isEditing);
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SBIcon, touchesBegan$withEvent$, void, NSSet *touches, UIEvent *event)
{
    if ([[objc_getClass("SBIconController") sharedInstance] isEditing])
        // Record the touch start time to determine whether or not to select an icon
        // FIXME: It might be more efficient to skip checking for edit mode
        touchesBeganTime = [[touches anyObject] timestamp];

    CALL_ORIG(SBIcon, touchesBegan$withEvent$, touches, event);
}

HOOK(SBIcon, touchesMoved$withEvent$, void, NSSet *touches, UIEvent *event)
{
    // Touch moved, not a tap; reset the touch time-tracking variable
    touchesBeganTime = 0;
    CALL_ORIG(SBIcon, touchesMoved$withEvent$, touches, event);
}

HOOK(SBIcon, touchesEnded$withEvent$, void, NSSet *touches, UIEvent *event)
{
    if ([[objc_getClass("SBIconController") sharedInstance] isEditing]) {
        // SpringBoard is in edit mode (icons are jittering)
        if ([[touches anyObject] timestamp] - touchesBeganTime < 0.3) {
            NSString *identifier = [self displayIdentifier];
            SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
            SBIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
            if ([selectedIcons containsObject:identifier]) {
                // Remove icon from list of selected icons
                [selectedIcons removeObject:identifier];

                // Remove the "selected" marker
                [[icon viewWithTag:TAG_CHECKMARK] removeFromSuperview];
            } else {
                // Add icon to list of selected icons
                [selectedIcons addObject:identifier];

                // Add a "selected" marker
                UIImageView *marker = [[UIImageView alloc] initWithImage:checkMarkImage];
                marker.frame = CGRectMake(40.0f, 39.0f, checkMarkImage.size.width, checkMarkImage.size.height);
                marker.tag = TAG_CHECKMARK;
                [icon addSubview:marker];
                [marker release];
            }
        }
    }

    CALL_ORIG(SBIcon, touchesEnded$withEvent$, touches, event);
}

//______________________________________________________________________________
//______________________________________________________________________________

HOOK(SpringBoard, menuButtonUp$, void, struct __GSEvent *event)
{
    if ([selectedIcons count] != 0) {
        int x = 0, y = 0;

        SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
        SBIconList *newList = [iconCont currentIconList];

        SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
        for (NSString *identifier in selectedIcons) {
            SBIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
            SBIconList *oldList = [iconModel iconListContainingIcon:icon];

            // Remove the "selected" marker
            [[icon viewWithTag:TAG_CHECKMARK] removeFromSuperview];

            if (oldList == newList)
                // The icon is already on this page, no need to move
                continue;

            if ([newList firstFreeSlotX:&x Y:&y]) {
                // Page has a free slot; move icon to this slot
                [oldList removeIcon:icon compactEmptyLists:NO animate:NO];
                [oldList compactIconsInIconList:YES];
                [newList placeIcon:icon atX:x Y:y animate:YES moveNow:YES];
            }
        }

        // Empty the selected icons array
        [selectedIcons removeAllObjects];

        // Reset the SpringBoard hold-button timer
        [self clearMenuButtonTimer];
    } else {
        CALL_ORIG(SpringBoard, menuButtonUp$, event);
    }
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

    GET_CLASS(SBIconController);
    LOAD_HOOK(SBIconController, setIsEditing:, setIsEditing$);

    GET_CLASS(SBIcon);
    LOAD_HOOK(SBIcon, touchesBegan:withEvent:, touchesBegan$withEvent$);
    LOAD_HOOK(SBIcon, touchesMoved:withEvent:, touchesMoved$withEvent$);
    LOAD_HOOK(SBIcon, touchesEnded:withEvent:, touchesEnded$withEvent$);

    GET_CLASS(SpringBoard);
    LOAD_HOOK(SpringBoard, menuButtonUp:, menuButtonUp$);

    [pool release];
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
