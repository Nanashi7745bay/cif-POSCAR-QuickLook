//
//  PreviewViewController.m
//  CrystalQuickLookPreview
//

#import "PreviewViewController.h"
#import "CrystalViewController.h"

@interface PreviewViewController ()

@property (nonatomic, strong) CrystalViewController *crystalVC;
@property (nonatomic, copy, nullable) NSString *currentTitle;

@end

@implementation PreviewViewController

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    _crystalVC = [[CrystalViewController alloc] init];
    [self addChildViewController:_crystalVC];
    _crystalVC.view.frame = self.view.bounds;
    _crystalVC.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:_crystalVC.view];
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
    NSError *error = nil;
    BOOL success = [_crystalVC loadStructureFromURL:url error:&error];
    if (success) {
        _currentTitle = _crystalVC.model.title ?: [url lastPathComponent];
        if (handler) handler(nil);
    } else {
        if (handler) handler(error ?: [NSError errorWithDomain:@"CrystalQuickLook" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse crystal structure"}]);
    }
}

- (nullable NSString *)previewItemTitle {
    return _currentTitle ?: @"Crystal Structure";
}

@end
