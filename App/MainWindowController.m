//
//  MainWindowController.m
//  CrystalQuickLook
//

#import "MainWindowController.h"

@interface DragDropView : NSView
@property (nonatomic, copy) void (^fileDroppedHandler)(NSURL *url);
@end

@implementation DragDropView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard.types containsObject:NSPasteboardTypeFileURL]) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard.types containsObject:NSPasteboardTypeFileURL]) {
        NSArray *classes = @[[NSURL class]];
        NSDictionary *options = @{NSPasteboardURLReadingFileURLsOnlyKey: @YES};
        NSArray *urls = [pboard readObjectsForClasses:classes options:options];
        if (urls.count > 0 && _fileDroppedHandler) {
            _fileDroppedHandler(urls.firstObject);
            return YES;
        }
    }
    return NO;
}

@end

@interface MainWindowController ()

@property (nonatomic, strong) CrystalViewController *crystalVC;
@property (nonatomic, strong) DragDropView *dragView;
@property (nonatomic, strong) NSView *dropPromptView;

@end

@implementation MainWindowController

- (instancetype)init {
    NSRect contentRect = NSMakeRect(200, 200, 960, 680);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable |
                              NSWindowStyleMaskFullSizeContentView;

    NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Crystal QuickLook Viewer";
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.minSize = NSMakeSize(500, 400);

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSWindow *window = self.window;

    _dragView = [[DragDropView alloc] initWithFrame:window.contentView.bounds];
    _dragView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [window.contentView addSubview:_dragView];

    __weak typeof(self) weakSelf = self;
    _dragView.fileDroppedHandler = ^(NSURL *url) {
        [weakSelf openFileURL:url];
    };

    _crystalVC = [[CrystalViewController alloc] init];
    _crystalVC.view.frame = _dragView.bounds;
    _crystalVC.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_dragView addSubview:_crystalVC.view];

    // Placeholder view before file is loaded
    _dropPromptView = [[NSView alloc] initWithFrame:_dragView.bounds];
    _dropPromptView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSTextField *label = [NSTextField labelWithString:@"Drag & Drop CIF or POSCAR file here\nor choose File → Open (⌘O)"];
    label.alignment = NSTextAlignmentCenter;
    label.font = [NSFont systemFontOfSize:18 weight:NSFontWeightMedium];
    label.textColor = [NSColor colorWithWhite:0.6 alpha:1.0];
    label.frame = NSMakeRect(0, (window.contentView.bounds.size.height - 60) * 0.5, window.contentView.bounds.size.width, 60);
    label.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
    [_dropPromptView addSubview:label];

    [_dragView addSubview:_dropPromptView];
}

- (void)openFileURL:(NSURL *)url {
    NSError *error = nil;
    BOOL success = [_crystalVC loadStructureFromURL:url error:&error];
    if (success) {
        [_dropPromptView setHidden:YES];
        self.window.title = [NSString stringWithFormat:@"%@ — Crystal QuickLook", [url lastPathComponent]];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Failed to open crystal file";
        alert.informativeText = error.localizedDescription ?: @"The file format was not recognized as CIF or POSCAR.";
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
}

@end
