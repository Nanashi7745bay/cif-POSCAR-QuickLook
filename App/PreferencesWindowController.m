//
//  PreferencesWindowController.m
//  CrystalQuickLook
//

#import "PreferencesWindowController.h"

@interface PreferencesWindowController ()

@property (nonatomic, strong) NSButton *radioLongest;
@property (nonatomic, strong) NSButton *radioClassic;
@property (nonatomic, strong) NSButton *radioSpecified;
@property (nonatomic, strong) NSPopUpButton *axisPopup;

@end

@implementation PreferencesWindowController

+ (instancetype)sharedController {
    static PreferencesWindowController *sController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sController = [[PreferencesWindowController alloc] init];
    });
    return sController;
}

- (instancetype)init {
    NSRect rect = NSMakeRect(0, 0, 480, 290);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"CrystalQuickLook Settings";
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSView *content = self.window.contentView;

    // Header Title
    NSTextField *header = [NSTextField labelWithString:@"Initial Orientation (初期表示の視点設定)"];
    header.frame = NSMakeRect(24, 245, 432, 22);
    header.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    [content addSubview:header];

    // Description
    NSTextField *desc = [NSTextField wrappingLabelWithString:@"ファイルを開いた時、または「Reset」ボタンを押した時の基準となるカメラの向きを設定します。"];
    desc.frame = NSMakeRect(24, 205, 432, 34);
    desc.font = [NSFont systemFontOfSize:11];
    desc.textColor = [NSColor secondaryLabelColor];
    [content addSubview:desc];

    // 1. Radio: Longest Axis as Depth (Default)
    _radioLongest = [NSButton radioButtonWithTitle:@"長軸を奥行き方向にする (Longest Axis as Depth)  [デフォルト]"
                                            target:self
                                            action:@selector(orientationChanged:)];
    _radioLongest.frame = NSMakeRect(28, 170, 420, 20);
    _radioLongest.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [content addSubview:_radioLongest];

    NSTextField *descLongest = [NSTextField labelWithString:@"a, b, c 軸のうち最も長い格子軸が画面の奥に向くように表示します。"];
    descLongest.frame = NSMakeRect(48, 150, 400, 16);
    descLongest.font = [NSFont systemFontOfSize:11];
    descLongest.textColor = [NSColor tertiaryLabelColor];
    [content addSubview:descLongest];

    // 2. Radio: Classic Isometric
    _radioClassic = [NSButton radioButtonWithTitle:@"標準アングル (Default / Classic Angle)"
                                            target:self
                                            action:@selector(orientationChanged:)];
    _radioClassic.frame = NSMakeRect(28, 118, 420, 20);
    _radioClassic.font = [NSFont systemFontOfSize:13];
    [content addSubview:_radioClassic];

    NSTextField *descClassic = [NSTextField labelWithString:@"従来の立体的な斜視アングルで表示します。"];
    descClassic.frame = NSMakeRect(48, 98, 400, 16);
    descClassic.font = [NSFont systemFontOfSize:11];
    descClassic.textColor = [NSColor tertiaryLabelColor];
    [content addSubview:descClassic];

    // 3. Radio: Specified Axis
    _radioSpecified = [NSButton radioButtonWithTitle:@"指定した軸を奥行き方向にする (Specified Axis):"
                                              target:self
                                              action:@selector(orientationChanged:)];
    _radioSpecified.frame = NSMakeRect(28, 66, 320, 20);
    _radioSpecified.font = [NSFont systemFontOfSize:13];
    [content addSubview:_radioSpecified];

    _axisPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(350, 63, 100, 25) pullsDown:NO];
    [_axisPopup addItemsWithTitles:@[@"a 軸", @"b 軸", @"c 軸"]];
    _axisPopup.target = self;
    _axisPopup.action = @selector(axisPopupChanged:);
    [content addSubview:_axisPopup];

    // Close button
    NSButton *closeBtn = [NSButton buttonWithTitle:@"Done" target:self action:@selector(closeWindow:)];
    closeBtn.frame = NSMakeRect(370, 16, 84, 30);
    closeBtn.bezelStyle = NSBezelStyleRounded;
    closeBtn.keyEquivalent = @"\r"; // Enter key
    [content addSubview:closeBtn];

    [self loadSettings];
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger mode = [defaults integerForKey:kInitialOrientationModeKey];
    NSInteger axis = [defaults integerForKey:kSpecifiedDepthAxisKey];

    _radioLongest.state = (mode == InitialOrientationModeLongestAxisDepth) ? NSControlStateValueOn : NSControlStateValueOff;
    _radioClassic.state = (mode == InitialOrientationModeClassicIsometric) ? NSControlStateValueOn : NSControlStateValueOff;
    _radioSpecified.state = (mode == InitialOrientationModeSpecifiedAxis) ? NSControlStateValueOn : NSControlStateValueOff;

    if (axis >= 0 && axis <= 2) {
        [_axisPopup selectItemAtIndex:axis];
    } else {
        [_axisPopup selectItemAtIndex:2]; // c-axis
    }
    _axisPopup.enabled = (_radioSpecified.state == NSControlStateValueOn);
}

- (void)orientationChanged:(NSButton *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    InitialOrientationMode mode = InitialOrientationModeLongestAxisDepth;

    if (sender == _radioClassic) {
        mode = InitialOrientationModeClassicIsometric;
        _radioLongest.state = NSControlStateValueOff;
        _radioSpecified.state = NSControlStateValueOff;
    } else if (sender == _radioSpecified) {
        mode = InitialOrientationModeSpecifiedAxis;
        _radioLongest.state = NSControlStateValueOff;
        _radioClassic.state = NSControlStateValueOff;
    } else {
        mode = InitialOrientationModeLongestAxisDepth;
        _radioClassic.state = NSControlStateValueOff;
        _radioSpecified.state = NSControlStateValueOff;
    }

    _axisPopup.enabled = (mode == InitialOrientationModeSpecifiedAxis);

    [defaults setInteger:mode forKey:kInitialOrientationModeKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CrystalOrientationSettingsDidChange" object:nil];
}

- (void)axisPopupChanged:(NSPopUpButton *)sender {
    NSInteger axis = sender.indexOfSelectedItem;
    [[NSUserDefaults standardUserDefaults] setInteger:axis forKey:kSpecifiedDepthAxisKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CrystalOrientationSettingsDidChange" object:nil];
}

- (void)closeWindow:(id)sender {
    [self.window close];
}

@end
