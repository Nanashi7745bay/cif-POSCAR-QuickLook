//
//  CrystalViewController.m
//  CrystalQuickLook
//

#import "CrystalViewController.h"
#import "CIFParser.h"
#import "POSCARParser.h"

static NSString * const kSavedRenderStyleKey = @"CrystalQuickLookRenderStyle";

@interface KeyHandlingSCNView : SCNView
@property (nonatomic, weak) CrystalViewController *controller;
@end

@implementation KeyHandlingSCNView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    NSString *chars = [[event charactersIgnoringModifiers] lowercaseString];
    if (chars.length == 0) {
        [super keyDown:event];
        return;
    }
    unichar c = [chars characterAtIndex:0];
    if (c == 'r') {
        [_controller resetCamera];
    } else if (c == 'a') {
        [_controller lookAlongA];
    } else if (c == 'b') {
        [_controller lookAlongB];
    } else if (c == 'c') {
        [_controller lookAlongC];
    } else if (c == 't' || c == 's' || c == ' ') {
        [_controller cycleNextStyle];
    } else if (c == '1') {
        [_controller setRenderStyle:CrystalRenderStyleStudio];
    } else if (c == '2') {
        [_controller setRenderStyle:CrystalRenderStyleVESTA];
    } else if (c == '3') {
        [_controller setRenderStyle:CrystalRenderStyleFlat];
    } else {
        [super keyDown:event];
    }
}

@end

@interface CrystalViewController ()

@property (nonatomic, strong) KeyHandlingSCNView *scnView;
@property (nonatomic, strong) NSVisualEffectView *hudView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *infoLabel;
@property (nonatomic, strong) NSSegmentedControl *styleControl;
@property (nonatomic, strong) NSStackView *buttonStack;
@property (nonatomic, strong) CrystalModel *model;
@property (nonatomic, assign) double initialCameraDistance;

@end

@implementation CrystalViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        NSInteger savedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kSavedRenderStyleKey];
        if (savedStyle >= 0 && savedStyle <= 2) {
            _currentStyle = (CrystalRenderStyle)savedStyle;
        } else {
            _currentStyle = CrystalRenderStyleStudio;
        }
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // 1. SceneKit 3D View with Key handling
    _scnView = [[KeyHandlingSCNView alloc] initWithFrame:self.view.bounds];
    _scnView.controller = self;
    _scnView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scnView.allowsCameraControl = YES;
    _scnView.autoenablesDefaultLighting = NO;
    _scnView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    [self.view addSubview:_scnView];

    // 2. Translucent Glass HUD Card (Top Left)
    _hudView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(16, self.view.bounds.size.height - 246, 290, 230)];
    _hudView.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    _hudView.state = NSVisualEffectStateActive;
    _hudView.wantsLayer = YES;
    _hudView.layer.cornerRadius = 10.0;
    _hudView.layer.masksToBounds = YES;
    _hudView.layer.borderWidth = 1.0;
    [self.view addSubview:_hudView];

    // Style Switcher Segmented Control at top of HUD
    _styleControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Studio", @"VESTA", @"Flat (White)"]
                                                      trackingMode:NSSegmentSwitchTrackingSelectOne
                                                            target:self
                                                            action:@selector(styleChanged:)];
    _styleControl.frame = NSMakeRect(14, 196, 262, 24);
    _styleControl.selectedSegment = _currentStyle;
    _styleControl.segmentDistribution = NSSegmentDistributionFillEqually;
    [_hudView addSubview:_styleControl];

    // Title / Formula Label
    _titleLabel = [NSTextField labelWithString:@"Crystal Structure"];
    _titleLabel.frame = NSMakeRect(14, 166, 262, 22);
    _titleLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_hudView addSubview:_titleLabel];

    // Details Label
    _infoLabel = [NSTextField wrappingLabelWithString:@"Loading..."];
    _infoLabel.frame = NSMakeRect(14, 38, 262, 124);
    _infoLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    [_hudView addSubview:_infoLabel];

    // View Orientation Buttons
    _buttonStack = [[NSStackView alloc] initWithFrame:NSMakeRect(14, 10, 262, 22)];
    _buttonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    _buttonStack.spacing = 6;
    _buttonStack.distribution = NSStackViewDistributionFillEqually;

    NSArray *btnTitles = @[@"Reset", @"a-view", @"b-view", @"c-view"];
    NSArray *actions = @[
        NSStringFromSelector(@selector(resetCamera)),
        NSStringFromSelector(@selector(lookAlongA)),
        NSStringFromSelector(@selector(lookAlongB)),
        NSStringFromSelector(@selector(lookAlongC))
    ];

    for (NSUInteger idx = 0; idx < btnTitles.count; idx++) {
        NSButton *btn = [NSButton buttonWithTitle:btnTitles[idx] target:self action:NSSelectorFromString(actions[idx])];
        btn.bezelStyle = NSBezelStyleInline;
        btn.font = [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
        [_buttonStack addArrangedSubview:btn];
    }
    [_hudView addSubview:_buttonStack];

    [self updateHUDTheme];
}

- (void)updateHUDTheme {
    if (_currentStyle == CrystalRenderStyleFlat) {
        // Light themed HUD for White background
        _hudView.material = NSVisualEffectMaterialSheet;
        _hudView.layer.borderColor = [NSColor colorWithWhite:0.0 alpha:0.15].CGColor;
        _titleLabel.textColor = [NSColor colorWithWhite:0.1 alpha:1.0];
        _infoLabel.textColor = [NSColor colorWithWhite:0.25 alpha:1.0];
    } else {
        // Dark themed HUD for Studio / VESTA
        _hudView.material = NSVisualEffectMaterialHUDWindow;
        _hudView.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.15].CGColor;
        _titleLabel.textColor = [NSColor whiteColor];
        _infoLabel.textColor = [NSColor colorWithWhite:0.92 alpha:1.0];
    }
}

- (void)styleChanged:(NSSegmentedControl *)sender {
    [self setRenderStyle:(CrystalRenderStyle)sender.selectedSegment];
}

- (void)setRenderStyle:(CrystalRenderStyle)style {
    _currentStyle = style;
    _styleControl.selectedSegment = style;
    [[NSUserDefaults standardUserDefaults] setInteger:style forKey:kSavedRenderStyleKey];

    [self updateHUDTheme];

    if (_model) {
        // Save current orientation before rebuilding scene
        SCNNode *oldStructure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
        SCNVector3 currentAngles = oldStructure ? oldStructure.eulerAngles : SCNVector3Make(-M_PI / 6.0, M_PI / 5.0, 0);

        double camDist = _initialCameraDistance;
        SCNScene *scene = [CrystalSceneBuilder buildSceneForModel:_model style:_currentStyle cameraDistance:&camDist];
        _scnView.scene = scene;

        SCNNode *newStructure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
        if (newStructure) {
            newStructure.eulerAngles = currentAngles;
        }
    }
}

- (void)cycleNextStyle {
    CrystalRenderStyle next = (_currentStyle + 1) % 3;
    [self setRenderStyle:next];
}

- (BOOL)loadStructureFromURL:(NSURL *)url error:(NSError * _Nullable *)error {
    NSString *ext = [[url pathExtension] lowercaseString];
    NSString *filename = [url lastPathComponent];

    CrystalModel *parsed = nil;

    if ([ext isEqualToString:@"cif"]) {
        parsed = [CIFParser parseFileAtURL:url error:error];
    } else if ([ext isEqualToString:@"vasp"] || [ext isEqualToString:@"poscar"] ||
               [filename hasPrefix:@"POSCAR"] || [filename hasPrefix:@"CONTCAR"]) {
        parsed = [POSCARParser parseFileAtURL:url error:error];
    } else {
        NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        if (!content) {
            content = [NSString stringWithContentsOfURL:url encoding:NSISOLatin1StringEncoding error:nil];
        }
        if (content) {
            return [self loadStructureFromString:content filename:filename error:error];
        }
    }

    if (parsed) {
        [self displayModel:parsed];
        return YES;
    }
    return NO;
}

- (BOOL)loadStructureFromString:(NSString *)content filename:(NSString *)filename error:(NSError * _Nullable *)error {
    CrystalModel *parsed = nil;
    if ([content containsString:@"_cell_"] || [content containsString:@"loop_"] || [content containsString:@"data_"]) {
        parsed = [CIFParser parseString:content error:error];
    } else {
        parsed = [POSCARParser parseString:content error:error];
        if (!parsed) {
            parsed = [CIFParser parseString:content error:error];
        }
    }

    if (parsed) {
        if (!parsed.title || parsed.title.length == 0) {
            parsed.title = filename;
        }
        [self displayModel:parsed];
        return YES;
    }
    return NO;
}

- (void)displayModel:(CrystalModel *)model {
    _model = model;

    double camDist = 10.0;
    SCNScene *scene = [CrystalSceneBuilder buildSceneForModel:model style:_currentStyle cameraDistance:&camDist];
    _initialCameraDistance = camDist;
    _scnView.scene = scene;

    // Update HUD Text
    _titleLabel.stringValue = [NSString stringWithFormat:@"%@  (%@)", [model formattedFormula], model.sourceFormat];

    NSMutableString *info = [NSMutableString string];
    if (model.spaceGroup.length > 0) {
        [info appendFormat:@"SG: %@\n", model.spaceGroup];
    }
    [info appendFormat:@"a=%.3f b=%.3f c=%.3f Å\n", model.a, model.b, model.c];
    [info appendFormat:@"α=%.1f° β=%.1f° γ=%.1f°\n", model.alpha, model.beta, model.gamma];
    [info appendFormat:@"Vol: %.2f Å³\n", model.volume];

    // Element breakdown
    NSMutableDictionary<NSString *, NSNumber *> *elemCounts = [NSMutableDictionary dictionary];
    NSUInteger totalBase = 0;
    for (CrystalAtom *a in model.atoms) {
        if (!a.isPeriodicReplica) {
            totalBase++;
            elemCounts[a.symbol] = @(elemCounts[a.symbol].integerValue + 1);
        }
    }

    NSMutableArray *elemSummary = [NSMutableArray array];
    for (NSString *sym in [elemCounts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [elemSummary addObject:[NSString stringWithFormat:@"%@:%@", sym, elemCounts[sym]]];
    }
    [info appendFormat:@"Atoms: %lu (%@)\n", (unsigned long)totalBase, [elemSummary componentsJoinedByString:@" "]];
    [info appendFormat:@"Bonds: %lu", (unsigned long)model.bonds.count];

    _infoLabel.stringValue = info;

    [self resetCamera];
}

#pragma mark - View Orientations

- (void)resetCamera {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    if (!structure) return;

    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.4];
    structure.eulerAngles = SCNVector3Make(-M_PI / 6.0, M_PI / 5.0, 0);
    [SCNTransaction commit];
}

- (void)lookAlongA {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    if (!structure) return;

    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.4];
    structure.eulerAngles = SCNVector3Make(0, -M_PI / 2.0, 0);
    [SCNTransaction commit];
}

- (void)lookAlongB {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    if (!structure) return;

    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.4];
    structure.eulerAngles = SCNVector3Make(M_PI / 2.0, 0, 0);
    [SCNTransaction commit];
}

- (void)lookAlongC {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    if (!structure) return;

    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.4];
    structure.eulerAngles = SCNVector3Make(0, 0, 0);
    [SCNTransaction commit];
}

@end
