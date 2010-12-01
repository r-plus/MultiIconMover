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


#include <substrate.h>

#define TP() NSLog(@"=== @%s:%u[%s]\n",  __FILE__, __LINE__, __FUNCTION__);

typedef struct __GSEvent *GSEventRef;

//==============================================================================

@interface UIView (Geometry)
@property(assign) CGPoint origin;
@end

@interface UIImage (UIImagePrivate)
+ (id)kitImageNamed:(id)named;
@end

//==============================================================================

@interface SBFolder : NSObject
- (id)listContainingIcon:(id)icon;
@end

@interface SBIcon : UIView @end
@interface SBIcon (Firmware3x)
- (id)displayIdentifier;
@end
@interface SBIcon (Firmware32)
+ (CGSize)defaultIconImageSize;
@end
@interface SBIcon (Firmware4x)
- (BOOL)isFolderIcon;
- (id)leafIdentifier;
@end

@interface SBIconController : NSObject
@property(assign) BOOL isEditing;
+ (id)sharedInstance;
- (void)animateToNewState:(float)newState domino:(BOOL)domino;
@end
@interface SBIconController (Firmware3x)
- (id)currentIconList;
@end
@interface SBIconController (Firmware4x)
- (id)currentRootIconList;
- (id)openFolder;
@end
@interface SBIconController (FolderEnhancer)
- (BOOL)folderEnhancerMoveIconsToCurrentIconList:(NSArray *)icons;
- (BOOL)folderEnhancerDropIcons:(NSArray *)icons;
@end

@interface SBIconList : UIView @end
@interface SBIconList (Firmware3x)
- (void)compactIconsInIconList:(BOOL)iconList;
- (BOOL)firstFreeSlotX:(int *)x Y:(int *)y;
- (id)placeIcon:(id)icon atX:(int)x Y:(int)y animate:(BOOL)animate moveNow:(BOOL)now;
- (void)removeIcon:(id)icon compactEmptyLists:(BOOL)lists animate:(BOOL)animate;
@end
@interface SBIconList (Firmware32)
- (BOOL)firstFreeSlotIndex:(int *)index;
- (id)placeIcon:(id)icon atIndex:(int)index animate:(BOOL)animate moveNow:(BOOL)now;
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

@interface SBIconModel : NSObject
+ (id)sharedInstance;
@end
@interface SBIconModel (Firmware3x)
- (id)iconForDisplayIdentifier:(NSString *)identifier;
- (id)iconListContainingIcon:(id)icon;
@end
@interface SBIconModel (Firmware4x)
- (id)rootFolder;
- (id)leafIconForIdentifier:(NSString *)identifier;
@end

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
