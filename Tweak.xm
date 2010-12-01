/**
 * Name: MultiIconMover
 * Type: iOS OS 3.x/4.x SpringBoard extension (MobileSubstrate-based)
 * Desc: Allows for moving multiple SpringBoard icons at a time.
 * Usage: In edit (jitter) mode, tap the icons to move, switch to target page,
 *        and press Home button. The icons will be moved to the top of the page.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2010-12-02 01:23:54
 */

#import <substrate.h>

#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBIconList.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SpringBoard.h>

@interface UIView (Geometry)
@property(assign) CGPoint origin;
@end

@interface UIImage (UIImagePrivate)
+ (id)kitImageNamed:(id)named;
@end

@interface SBIcon (Firmware32)
+ (CGSize)defaultIconImageSize;
@end
@interface SBIcon (Firmware4)
- (BOOL)isFolderIcon;
- (id)leafIdentifier;
@end

@interface SBIconList (Firmware32)
- (BOOL)firstFreeSlotIndex:(int *)index;
- (id)placeIcon:(id)icon atIndex:(int)index animate:(BOOL)animate moveNow:(BOOL)now;
@end

@interface SBIconController (Firmware4)
- (id)currentRootIconList;
- (id)openFolder;
@end
@interface SBIconController (FolderEnhancer)
- (BOOL)folderEnhancerMoveIconsToCurrentIconList:(NSArray *)icons;
- (BOOL)folderEnhancerDropIcons:(NSArray *)icons;
@end

@interface SBIconModel (Firmware4)
- (id)rootFolder;
- (id)leafIconForIdentifier:(NSString *)identifier;
@end

@interface SBIconListModel : NSObject
- (void)removeIcon:(id)icon;
- (void)compactIcons;
@end

@interface SBIconListView : UIView
- (id)model;
- (BOOL)isFull;
- (unsigned)firstFreeSlotIndex;
- (id)placeIcon:(id)icon atIndex:(unsigned)index moveNow:(BOOL)now pop:(BOOL)pop;
@end

@interface SBFolder : NSObject
- (id)listContainingIcon:(id)icon;
@end

#define TAG_CHECKMARK 2000


static NSTimeInterval touchesBeganTime = 0;
static NSMutableArray *selectedIcons = nil;
static UIImage *checkMarkImage = nil;

static BOOL menuButtonIsDown = NO;

static BOOL isFirmware3x_ = NO;
static BOOL isFirmware32_ = NO;
static BOOL hasFolderEnhancer_ = NO;

//==============================================================================

static void deselectIcons()
{
    // Unmark all selected icons
    SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
    for (NSString *identifier in selectedIcons) {
        // Remove the "selected" marker
        SBIcon *icon = isFirmware3x_ ?
            [iconModel iconForDisplayIdentifier:identifier] :
            [iconModel leafIconForIdentifier:identifier];
        [[icon viewWithTag:TAG_CHECKMARK] removeFromSuperview];
    }

    // Empty the selected icons array
    [selectedIcons removeAllObjects];
}

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
        // Deselect any remaining selected icons
        deselectIcons();

        // Checkmark image is not needed outside of editing mode, release
        [checkMarkImage release];
        checkMarkImage = nil;

        // ... same goes for selected icons array
        [selectedIcons release];
        selectedIcons = nil;
    }

    %orig;
}

%group GFirmware4x_Normal

static inline void removeSelectedIcon(SBIcon *icon)
{
    NSString *identifier = [icon leafIdentifier];
    if ([selectedIcons containsObject:identifier]) {
        // Remove icon from list of selected icons
        [selectedIcons removeObject:identifier];

        // Remove the "selected" marker
        [[icon viewWithTag:TAG_CHECKMARK] removeFromSuperview];
    }
}

- (void)animateIcons:(id)icons intoFolderIcon:(id)folderIcon openFolderOnFinish:(BOOL)finish
{
    %orig;

    // Icon(s) was added to a folder; make sure icon is not in selected array
    for (SBIcon *icon in icons)
        removeSelectedIcon(icon);
}

- (void)_dropIconInDestinationHole:(id)icon
{
    %orig;

    if ([self openFolder] != nil)
        // Icon was added to a folder; make sure icon is not in selected array
        removeSelectedIcon(icon);
}

%end // GFirmware4x_FolderEnhancer

%group GFirmware4x_FolderEnhancer
%end // GFirmware4x_FolderEnhancer

%end

//==============================================================================

%hook SBIcon

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
    if ([iconCont isEditing] && !menuButtonIsDown)
        if (isFirmware3x_ || (![self isFolderIcon] && (hasFolderEnhancer_ || [iconCont openFolder] == nil)))
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
    %orig;

    if ([[objc_getClass("SBIconController") sharedInstance] isEditing]) {
        // SpringBoard is in edit mode (icons are jittering)
        if ([[touches anyObject] timestamp] - touchesBeganTime < 0.3) {
            NSString *identifier = isFirmware3x_ ? [self displayIdentifier] : [self leafIdentifier];
            if ([selectedIcons containsObject:identifier]) {
                // Remove icon from list of selected icons
                [selectedIcons removeObject:identifier];

                // Remove the "selected" marker
                [[self viewWithTag:TAG_CHECKMARK] removeFromSuperview];
            } else {
                // Add icon to list of selected icons
                [selectedIcons addObject:identifier];

                // Determine origin for "selected" marker based on icon image size
                // NOTE: Default icon image sizes: iPhone/iPod: 59x62, iPad: 74x76 
                CGPoint point;
                Class $SBIcon = objc_getClass("SBIcon");
                if ([$SBIcon respondsToSelector:@selector(defaultIconImageSize)]) {
                    // Determine position for marker (relative to lower right corner of icon)
                    CGSize size = [$SBIcon defaultIconImageSize];
                    point = CGPointMake((size.width - checkMarkImage.size.width) + 10.0f, size.height - 23.0f);
                } else {
                    // Fall back to hard-coded values (for firmware < 3.2, iPhone/iPod only)
                    point = CGPointMake(40.0f, 39.0f);
                }

                // Add a "selected" marker
                UIImageView *marker = [[UIImageView alloc] initWithImage:checkMarkImage];
                marker.tag = TAG_CHECKMARK;
                marker.origin = point;
                [self addSubview:marker];
                [marker release];
            }
        }

        // Reset the touch time-tracking variable
        // NOTE: This is needed as time may not be reset later (if icon is
        //       touched while menu button is down).
        touchesBeganTime = 0;
    }
}

%end

//==============================================================================

%hook SpringBoard

- (void)menuButtonDown:(GSEventRef)event
{
    if ([selectedIcons count] != 0)
        // NOTE: This is used to prevent selection of icons while menu button is down
        menuButtonIsDown = YES;
    else
        %orig;
}

- (void)menuButtonUp:(GSEventRef)event
{
    SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
    if ([selectedIcons count] != 0) {
        if (isFirmware3x_ || hasFolderEnhancer_ || [iconCont openFolder] == nil) {
            SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
            if (isFirmware3x_) {
                // Get target list
                SBIconList *newList = [iconCont currentIconList];

                // Move each icon
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

                    if (isFirmware32_) {
                        // Firmware 3.2
                        int index = 0;
                        if ([newList firstFreeSlotIndex:&index]) {
                            // Page has a free slot; move icon to this slot
                            [oldList removeIcon:icon compactEmptyLists:NO animate:NO];
                            [oldList compactIconsInIconList:YES];
                            [newList placeIcon:icon atIndex:index animate:YES moveNow:YES];
                        }
                    } else {
                        // Firmware < 3.2
                        int x = 0, y = 0;
                        if ([newList firstFreeSlotX:&x Y:&y]) {
                            // Page has a free slot; move icon to this slot
                            [oldList removeIcon:icon compactEmptyLists:NO animate:NO];
                            [oldList compactIconsInIconList:YES];
                            [newList placeIcon:icon atX:x Y:y animate:YES moveNow:YES];
                        }
                    }
                }
            } else {
                // Get icons for selected identifiers
                NSMutableArray *icons = [NSMutableArray array];
                for (NSString *identifier in selectedIcons) {
                    // NOTE: Selected app/clip may have been removed; must check for nil
                    SBIcon *icon = [iconModel leafIconForIdentifier:identifier];
                    if (icon != nil) {
                        // Remove the "selected" marker
                        [[icon viewWithTag:TAG_CHECKMARK] removeFromSuperview];

                        // Add to icon array
                        [icons addObject:icon];
                    }
                }

                // Move icons
                if (hasFolderEnhancer_) {
                    [iconCont folderEnhancerMoveIconsToCurrentIconList:icons];
                } else {
                    // Get target list
                    SBIconListView *newListView = [iconCont currentRootIconList];
                    SBIconListModel *newListModel = [newListView model];

                    SBFolder *rootFolder = [iconModel rootFolder];
                    for (SBIcon *icon in icons) {
                        SBIconListModel *oldListModel = [rootFolder listContainingIcon:icon];
                        if (oldListModel == newListModel)
                            // The icon is already on this page, no need to move
                            continue;

                        if (![newListView isFull]) {
                            // Page has a free slot; move icon to this slot
                            [oldListModel removeIcon:icon];
                            [oldListModel compactIcons];

                            unsigned int index = [newListView firstFreeSlotIndex];
                            [newListView placeIcon:icon atIndex:index moveNow:YES pop:YES];
                        }
                    }
                }

                // Relayout icon pages
                [iconCont animateToNewState:0 domino:NO];
            }

            // Empty the selected icons array
            [selectedIcons removeAllObjects];
        } else {
            // Folder is open; deselect all icons and call original functionality
            deselectIcons();
            %orig;
        }

        // Reset the local menu button state variable
        menuButtonIsDown = NO;
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
    isFirmware3x_ = ($SBIconList != nil);
    if (isFirmware3x_) {
        isFirmware32_ = (class_getInstanceMethod($SBIconList, @selector(firstFreeSlotX:Y:)) == NULL);
    } else {
        // Detect if FolderEnhancer is installed
        // NOTE: Must ensure that FolderEnhancer is loaded first
        dlopen("/Library/MobileSubstrate/DynamicLibraries/FolderEnhancer.dylib", RTLD_LAZY);
        Class $SBIconController = objc_getClass("SBIconController");
        hasFolderEnhancer_ =
            (class_getInstanceMethod($SBIconController, @selector(folderEnhancerMoveIconsToCurrentIconList:)) != NULL)
            && (class_getInstanceMethod($SBIconController, @selector(folderEnhancerDropIcons:)) != NULL);

        if (hasFolderEnhancer_)
            %init(GFirmware4x_FolderEnhancer);
        else
            %init(GFirmware4x_Normal);
    }

    %init;

    [pool release];
}

/* vim: set syntax=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
