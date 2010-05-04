/**
 * Name: MultiIconMover
 * Type: iPhone OS 3.x SpringBoard extension (MobileSubstrate-based)
 * Description: Allows for moving multiple SpringBoard icons at a time.
 * Usage: In edit (jitter) mode, tap the icons to move, switch to target page,
          and press Home button. The icons will be place to the top of the
          page.
 * Author: Lance Fetters (aka. ashikase)
j* Last-modified: 2010-05-04 16:35:06
 */

/**
 * Copyright (C) 2009-2010  Lance Fetters (aka. ashikase)
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

#import <substrate.h>

#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SpringBoard.h>

@interface UIImage (UIImagePrivate)
+ (id)kitImageNamed:(id)named;
@end

@interface SBIconList (Firmware32)
- (BOOL)firstFreeSlotIndex:(int *)index;
- (id)placeIcon:(id)icon atIndex:(int)index animate:(BOOL)animate moveNow:(BOOL)now;
@end

#define TAG_CHECKMARK 2000


static NSTimeInterval touchesBeganTime = 0;
static NSMutableArray *selectedIcons = nil;
static UIImage *checkMarkImage = nil;

static BOOL isFirmwarePre32_ = NO;

//==============================================================================

%hook SBIconController

- (void)setIsEditing:(BOOL)isEditing
{
    if (isEditing) {
        // Create array to track selected icons
        selectedIcons = [[NSMutableArray alloc] init];

        // Load and cache the checkmark image
        checkMarkImage = [[UIImage kitImageNamed:@"UIRemoveControlMultiCheckedImage.png"] retain];
    } else {
        // Checkmark image is not needed outside of editing mode, release
        [checkMarkImage release];
        checkMarkImage = nil;

        // ... same goes for selected icons array
        [selectedIcons release];
        selectedIcons = nil;
    }

    %orig;
}

%end

//==============================================================================

%hook SBIcon

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([[objc_getClass("SBIconController") sharedInstance] isEditing])
        // Record the touch start time to determine whether or not to select an icon
        // FIXME: It might be more efficient to skip checking for edit mode
        touchesBeganTime = [[touches anyObject] timestamp];

    %orig;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Touch moved, not a tap; reset the touch time-tracking variable
    touchesBeganTime = 0;
    %orig;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([[objc_getClass("SBIconController") sharedInstance] isEditing]) {
        // SpringBoard is in edit mode (icons are jittering)
        if ([[touches anyObject] timestamp] - touchesBeganTime < 0.3) {
            NSString *identifier = [self displayIdentifier];
            if ([selectedIcons containsObject:identifier]) {
                // Remove icon from list of selected icons
                [selectedIcons removeObject:identifier];

                // Remove the "selected" marker
                [[self viewWithTag:TAG_CHECKMARK] removeFromSuperview];
            } else {
                // Add icon to list of selected icons
                [selectedIcons addObject:identifier];

                // Add a "selected" marker
                UIImageView *marker = [[UIImageView alloc] initWithImage:checkMarkImage];
                marker.frame = CGRectMake(40.0f, 39.0f, checkMarkImage.size.width, checkMarkImage.size.height);
                marker.tag = TAG_CHECKMARK;
                [self addSubview:marker];
                [marker release];
            }
        }
    }

    %orig;
}

%end

//==============================================================================

%hook SpringBoard

- (void)menuButtonUp:(GSEventRef)event
{
    if ([selectedIcons count] != 0) {
        int x = 0, y = 0;
        int index = 0;

        SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
        SBIconList *newList = [iconCont currentIconList];

        SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
        for (NSString *identifier in selectedIcons) {
            SBIcon *icon = [iconModel iconForDisplayIdentifier:identifier];
            if (icon == nil)
                // Application has been removed
                continue;

            // Remove the "selected" marker
            [[icon viewWithTag:TAG_CHECKMARK] removeFromSuperview];

            SBIconList *oldList = [iconModel iconListContainingIcon:icon];
            if (oldList == newList)
                // The icon is already on this page, no need to move
                continue;

            if (isFirmwarePre32_) {
                if ([newList firstFreeSlotX:&x Y:&y]) {
                    // Page has a free slot; move icon to this slot
                    [oldList removeIcon:icon compactEmptyLists:NO animate:NO];
                    [oldList compactIconsInIconList:YES];
                    [newList placeIcon:icon atX:x Y:y animate:YES moveNow:YES];
                }
            } else {
                if ([newList firstFreeSlotIndex:&index]) {
                    // Page has a free slot; move icon to this slot
                    [oldList removeIcon:icon compactEmptyLists:NO animate:NO];
                    [oldList compactIconsInIconList:YES];
                    [newList placeIcon:icon atIndex:index animate:YES moveNow:YES];
                }
            }
        }

        // Empty the selected icons array
        [selectedIcons removeAllObjects];

        // Reset the SpringBoard hold-button timer
        [self clearMenuButtonTimer];
    } else {
        %orig;
    }
}

%end

//==============================================================================

__attribute__((constructor)) static void init()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Determine firmware version
    Class $SBIconList = objc_getClass("SBIconList");
    isFirmwarePre32_ = (class_getInstanceMethod($SBIconList, @selector(firstFreeSlotX:Y:)) != NULL);

    %init;

    [pool release];
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
