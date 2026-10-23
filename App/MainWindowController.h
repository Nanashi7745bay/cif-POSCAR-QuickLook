//
//  MainWindowController.h
//  CrystalQuickLook
//

#import <Cocoa/Cocoa.h>
#import "CrystalViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainWindowController : NSWindowController <NSWindowDelegate>

@property (nonatomic, strong, readonly) CrystalViewController *crystalVC;

- (void)openFileURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
