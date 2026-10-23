//
//  AppDelegate.h
//  CrystalQuickLook
//

#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) MainWindowController *mainWindowController;

@end

NS_ASSUME_NONNULL_END
