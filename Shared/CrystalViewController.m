//
//  CrystalViewController.m
//  CrystalQuickLook
//

#import "CrystalViewController.h"
#import "CrystalCompassNode.h"
#import "CIFParser.h"
#import "POSCARParser.h"

NSString * const kInitialOrientationModeKey = @"CrystalInitialOrientationMode";
NSString * const kSpecifiedDepthAxisKey = @"CrystalSpecifiedDepthAxis";
static NSString * const kSavedRenderStyleKey = @"CrystalQuickLookRenderStyle";

// Transparent overlay view that forwards all mouse events to views underneath
@interface TransparentCompassView : SCNView
@end

@implementation TransparentCompassView
- (NSView *)hitTest:(NSPoint)point {
    return nil; // Pass-through all clicks/drags to main view
}
@end

@interface CrystalViewController ()
- (void)rotateByDeltaX:(CGFloat)dx deltaY:(CGFloat)dy;
- (void)panByDeltaX:(CGFloat)dx deltaY:(CGFloat)dy;
- (void)zoomByFactor:(CGFloat)factor;
@end

@interface KeyHandlingSCNView : SCNView
@property (nonatomic, weak) CrystalViewController *controller;
@property (nonatomic, assign) NSPoint lastDragLocation;
@end

@implementation KeyHandlingSCNView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    _lastDragLocation = [self convertPoint:event.locationInWindow fromView:nil];
    [self.window makeFirstResponder:self];
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint cur = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat dx = cur.x - _lastDragLocation.x;
    CGFloat dy = cur.y - _lastDragLocation.y;
    _lastDragLocation = cur;

    if ((event.modifierFlags & NSEventModifierFlagShift) || (event.modifierFlags & NSEventModifierFlagOption)) {
        [_controller panByDeltaX:dx deltaY:dy];
    } else {
        [_controller rotateByDeltaX:dx deltaY:dy];
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    _lastDragLocation = [self convertPoint:event.locationInWindow fromView:nil];
}

- (void)rightMouseDragged:(NSEvent *)event {
    NSPoint cur = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat dx = cur.x - _lastDragLocation.x;
    CGFloat dy = cur.y - _lastDragLocation.y;
    _lastDragLocation = cur;
    [_controller panByDeltaX:dx deltaY:dy];
}

- (void)otherMouseDown:(NSEvent *)event {
    _lastDragLocation = [self convertPoint:event.locationInWindow fromView:nil];
}

- (void)otherMouseDragged:(NSEvent *)event {
    NSPoint cur = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat dx = cur.x - _lastDragLocation.x;
    CGFloat dy = cur.y - _lastDragLocation.y;
    _lastDragLocation = cur;
    [_controller panByDeltaX:dx deltaY:dy];
}

- (void)scrollWheel:(NSEvent *)event {
    CGFloat dy = event.scrollingDeltaY;
    if (fabs(dy) < 1e-4) return;
    CGFloat sensitivity = event.hasPreciseScrollingDeltas ? 0.008 : 0.06;
    CGFloat factor = 1.0 - dy * sensitivity;
    factor = fmax(0.80, fmin(1.25, factor));
    [_controller zoomByFactor:factor];
}

- (void)magnifyWithEvent:(NSEvent *)event {
    CGFloat factor = 1.0 - event.magnification;
    factor = fmax(0.80, fmin(1.25, factor));
    [_controller zoomByFactor:factor];
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
@property (nonatomic, strong) TransparentCompassView *compassView;
@property (nonatomic, strong) NSVisualEffectView *hudView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *infoLabel;
@property (nonatomic, strong) NSSegmentedControl *styleControl;
@property (nonatomic, strong) NSStackView *buttonStack;
@property (nonatomic, strong) CrystalModel *model;
@property (nonatomic, strong) CrystalCompassNode *compassNode;
@property (nonatomic, assign) double initialCameraDistance;
@property (nonatomic, assign) double initialOrthoScale;

@end

@implementation CrystalViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        // Render Style
        NSInteger savedStyle = [defaults integerForKey:kSavedRenderStyleKey];
        if (savedStyle >= 0 && savedStyle <= 2) {
            _currentStyle = (CrystalRenderStyle)savedStyle;
        } else {
            _currentStyle = CrystalRenderStyleStudio;
        }

        // Orientation Mode (Default is LongestAxisDepth = 0)
        if ([defaults objectForKey:kInitialOrientationModeKey] == nil) {
            _orientationMode = InitialOrientationModeLongestAxisDepth;
        } else {
            _orientationMode = (InitialOrientationMode)[defaults integerForKey:kInitialOrientationModeKey];
        }

        // Specified Depth Axis (Default is C = 2)
        if ([defaults objectForKey:kSpecifiedDepthAxisKey] == nil) {
            _specifiedAxis = SpecifiedDepthAxisC;
        } else {
            _specifiedAxis = (SpecifiedDepthAxis)[defaults integerForKey:kSpecifiedDepthAxisKey];
        }
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // 1. Main SceneKit 3D View with custom trackball rotation, pan, zoom & keyboard shortcuts
    _scnView = [[KeyHandlingSCNView alloc] initWithFrame:self.view.bounds];
    _scnView.controller = self;
    _scnView.delegate = self;
    _scnView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scnView.allowsCameraControl = NO;
    _scnView.autoenablesDefaultLighting = NO;
    _scnView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    [self.view addSubview:_scnView];

    // 2. Independent Compass Overlay View (Fixed at Bottom-Left: 16, 16, 115x115)
    _compassView = [[TransparentCompassView alloc] initWithFrame:NSMakeRect(16, 16, 115, 115)];
    _compassView.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    _compassView.backgroundColor = [NSColor clearColor];
    _compassView.autoenablesDefaultLighting = NO;
    _compassView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    [self.view addSubview:_compassView];
    [self setupCompassScene];

    // 3. Translucent Glass HUD Card (Top Left)
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

- (void)setupCompassScene {
    SCNScene *cScene = [SCNScene scene];

    // Orthographic Camera (No perspective distortion, constant size)
    SCNCamera *camera = [SCNCamera camera];
    camera.usesOrthographicProjection = YES;
    camera.orthographicScale = 1.05;
    camera.zNear = 0.1;
    camera.zFar = 20.0;

    SCNNode *cCamNode = [SCNNode node];
    cCamNode.camera = camera;
    cCamNode.position = SCNVector3Make(0, 0, 5);
    [cScene.rootNode addChildNode:cCamNode];

    // Key light for compass
    SCNLight *light = [SCNLight light];
    light.type = SCNLightTypeDirectional;
    light.color = [NSColor colorWithWhite:0.95 alpha:1.0];
    SCNNode *lNode = [SCNNode node];
    lNode.light = light;
    lNode.eulerAngles = SCNVector3Make(-M_PI / 4.0, M_PI / 4.0, 0);
    [cScene.rootNode addChildNode:lNode];

    // Ambient light
    SCNLight *amb = [SCNLight light];
    amb.type = SCNLightTypeAmbient;
    amb.color = [NSColor colorWithWhite:0.4 alpha:1.0];
    SCNNode *ambNode = [SCNNode node];
    ambNode.light = amb;
    [cScene.rootNode addChildNode:ambNode];

    _compassView.scene = cScene;
    _compassView.pointOfView = cCamNode;
}

- (void)updateHUDTheme {
    if (_currentStyle == CrystalRenderStyleFlat) {
        _hudView.material = NSVisualEffectMaterialSheet;
        _hudView.layer.borderColor = [NSColor colorWithWhite:0.0 alpha:0.15].CGColor;
        _titleLabel.textColor = [NSColor colorWithWhite:0.1 alpha:1.0];
        _infoLabel.textColor = [NSColor colorWithWhite:0.25 alpha:1.0];
    } else {
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
        SCNNode *oldStructure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
        SCNNode *oldCam = [_scnView.scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
        SCNMatrix4 currentTransform = oldStructure ? oldStructure.transform : [self initialTransform];
        SCNVector3 camPos = oldCam ? oldCam.position : SCNVector3Make(0, 0, _initialCameraDistance);
        double orthoScale = (oldCam && oldCam.camera) ? oldCam.camera.orthographicScale : _initialOrthoScale;

        double camDist = _initialCameraDistance;
        SCNScene *scene = [CrystalSceneBuilder buildSceneForModel:_model style:_currentStyle cameraDistance:&camDist];
        _scnView.scene = scene;

        SCNNode *newCam = [scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
        if (newCam) {
            newCam.position = camPos;
            newCam.camera.orthographicScale = orthoScale;
            _scnView.pointOfView = newCam;
        }

        SCNNode *newStructure = [scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
        if (newStructure) {
            newStructure.transform = currentTransform;
        }

        // Update compass model and style while preserving orientation
        [self updateCompassWithModel:_model];
        [_compassNode syncWithTransform:currentTransform];
        [_compassView setNeedsDisplay:YES];
        [_scnView setNeedsDisplay:YES];
    }
}

- (void)cycleNextStyle {
    CrystalRenderStyle next = (_currentStyle + 1) % 3;
    [self setRenderStyle:next];
}

- (void)setOrientationMode:(InitialOrientationMode)mode {
    _orientationMode = mode;
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kInitialOrientationModeKey];
    [self updateInfoText];
    [self resetCamera];
}

- (void)setSpecifiedAxis:(SpecifiedDepthAxis)axis {
    _specifiedAxis = axis;
    [[NSUserDefaults standardUserDefaults] setInteger:axis forKey:kSpecifiedDepthAxisKey];
    [self updateInfoText];
    if (_orientationMode == InitialOrientationModeSpecifiedAxis) {
        [self resetCamera];
    }
}

- (SCNMatrix4)initialTransform {
    if (!_model) {
        return SCNMatrix4Identity;
    }

    switch (_orientationMode) {
        case InitialOrientationModeLongestAxisDepth: {
            NSInteger longest = [_model longestAxisIndex];
            return [_model transformForDepthAxis:longest];
        }
        case InitialOrientationModeSpecifiedAxis: {
            return [_model transformForDepthAxis:(NSInteger)_specifiedAxis];
        }
        case InitialOrientationModeClassicIsometric:
        default: {
            return [_model classicIsometricTransform];
        }
    }
}

- (void)updateCompassWithModel:(CrystalModel *)model {
    if (!_compassView.scene) return;

    if (_compassNode) {
        [_compassNode removeFromParentNode];
    }
    _compassNode = [CrystalCompassNode compassWithModel:model style:_currentStyle];
    _compassNode.position = SCNVector3Make(0, 0, 0); // Always at origin in compass scene
    [_compassView.scene.rootNode addChildNode:_compassNode];
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

    SCNNode *camNode = [scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
    _initialOrthoScale = (camNode && camNode.camera) ? camNode.camera.orthographicScale : 5.0;

    _scnView.scene = scene;
    if (camNode) {
        _scnView.pointOfView = camNode;
    }

    // Update compass in independent overlay view
    [self updateCompassWithModel:model];

    // Update HUD
    _titleLabel.stringValue = [NSString stringWithFormat:@"%@  (%@)", [model formattedFormula], model.sourceFormat];
    [self updateInfoText];

    // Set initial orientation immediately without animation on first load
    SCNNode *structure = [scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    SCNMatrix4 initMat = [self initialTransform];
    if (structure) {
        structure.transform = initMat;
    }
    [_compassNode syncWithTransform:initMat];
    [_compassView setNeedsDisplay:YES];
    [_scnView setNeedsDisplay:YES];
}

- (void)updateInfoText {
    if (!_model) return;

    NSMutableString *info = [NSMutableString string];
    if (_model.spaceGroup.length > 0) {
        [info appendFormat:@"SG: %@\n", _model.spaceGroup];
    }
    [info appendFormat:@"a=%.3f b=%.3f c=%.3f Å\n", _model.a, _model.b, _model.c];
    [info appendFormat:@"α=%.1f° β=%.1f° γ=%.1f°\n", _model.alpha, _model.beta, _model.gamma];
    [info appendFormat:@"Vol: %.2f Å³\n", _model.volume];

    NSString *depthStr = @"";
    if (_orientationMode == InitialOrientationModeLongestAxisDepth) {
        depthStr = [NSString stringWithFormat:@"Depth: Longest (%@-axis)", [_model longestAxisName]];
    } else if (_orientationMode == InitialOrientationModeSpecifiedAxis) {
        NSString *axName = (_specifiedAxis == SpecifiedDepthAxisA) ? @"a" : (_specifiedAxis == SpecifiedDepthAxisB ? @"b" : @"c");
        depthStr = [NSString stringWithFormat:@"Depth: Specified (%@-axis)", axName];
    } else {
        depthStr = @"Depth: Classic Angle";
    }
    [info appendFormat:@"%@\n", depthStr];

    NSMutableDictionary<NSString *, NSNumber *> *elemCounts = [NSMutableDictionary dictionary];
    NSUInteger totalBase = 0;
    for (CrystalAtom *a in _model.atoms) {
        if (!a.isPeriodicReplica) {
            totalBase++;
            elemCounts[a.symbol] = @(elemCounts[a.symbol].integerValue + 1);
        }
    }

    NSMutableArray *elemSummary = [NSMutableArray array];
    for (NSString *sym in [elemCounts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [elemSummary addObject:[NSString stringWithFormat:@"%@:%@", sym, elemCounts[sym]]];
    }
    [info appendFormat:@"Atoms: %lu (%@)", (unsigned long)totalBase, [elemSummary componentsJoinedByString:@" "]];

    _infoLabel.stringValue = info;
}

#pragma mark - Interactive Mouse Rotation, Pan, Zoom

- (void)rotateByDeltaX:(CGFloat)dx deltaY:(CGFloat)dy {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    if (!structure) return;

    CGFloat sensitivity = 0.0085;
    SCNMatrix4 rotY = SCNMatrix4MakeRotation(dx * sensitivity, 0, 1, 0);
    SCNMatrix4 rotX = SCNMatrix4MakeRotation(-dy * sensitivity, 1, 0, 0);
    SCNMatrix4 screenRot = SCNMatrix4Mult(rotY, rotX);

    // Apply screen-space rotation around the centered unit cell origin (0,0,0)
    SCNMatrix4 newTransform = SCNMatrix4Mult(structure.transform, screenRot);
    structure.transform = newTransform;

    // Immediately sync compass rotation (translation is ignored)
    [_compassNode syncWithTransform:newTransform];
    [_compassView setNeedsDisplay:YES];
    [_scnView setNeedsDisplay:YES];
}

- (void)panByDeltaX:(CGFloat)dx deltaY:(CGFloat)dy {
    SCNNode *camNode = [_scnView.scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
    if (!camNode || !camNode.camera) return;

    CGFloat viewHeight = fmax(self.view.bounds.size.height, 100.0);
    CGFloat unitsPerPixel = (camNode.camera.orthographicScale * 2.0) / viewHeight;

    SCNVector3 pos = camNode.position;
    pos.x -= dx * unitsPerPixel;
    pos.y -= dy * unitsPerPixel;
    camNode.position = pos;

    // Note: Compass stays fixed and does NOT move on pan!
    [_scnView setNeedsDisplay:YES];
}

- (void)zoomByFactor:(CGFloat)factor {
    SCNNode *camNode = [_scnView.scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
    if (!camNode || !camNode.camera) return;

    double newScale = camNode.camera.orthographicScale * factor;
    double minScale = 0.5;
    double maxScale = fmax(_initialOrthoScale * 6.0, 30.0);
    camNode.camera.orthographicScale = fmax(minScale, fmin(maxScale, newScale));
    [_scnView setNeedsDisplay:YES];
}

#pragma mark - SCNSceneRendererDelegate (Sync Pure Rotation to Compass during Animations)

- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    if (structure && _compassNode) {
        SCNMatrix4 liveTransform = structure.presentationNode ? structure.presentationNode.transform : structure.transform;
        [_compassNode syncWithTransform:liveTransform];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_compassView setNeedsDisplay:YES];
        });
    }
}

#pragma mark - View Orientations (Centered + Orthographic Straight-Line Alignment)

- (void)applyTargetTransform:(SCNMatrix4)targetTransform resetZoom:(BOOL)resetZoom {
    SCNNode *structure = [_scnView.scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    SCNNode *camNode = [_scnView.scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
    if (!structure) return;

    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.35];
    structure.transform = targetTransform;
    if (camNode) {
        // Re-center the unit cell in the viewport
        camNode.position = SCNVector3Make(0, 0, _initialCameraDistance);
        if (resetZoom && camNode.camera) {
            camNode.camera.orthographicScale = _initialOrthoScale;
        }
    }
    [_compassNode syncWithTransform:targetTransform];
    [SCNTransaction commit];

    [_scnView setNeedsDisplay:YES];
    [_compassView setNeedsDisplay:YES];
}

- (void)resetCamera {
    if (!_model) return;
    [self applyTargetTransform:[self initialTransform] resetZoom:YES];
}

- (void)lookAlongA {
    if (!_model) return;
    [self applyTargetTransform:[_model transformForDepthAxis:0] resetZoom:NO];
}

- (void)lookAlongB {
    if (!_model) return;
    [self applyTargetTransform:[_model transformForDepthAxis:1] resetZoom:NO];
}

- (void)lookAlongC {
    if (!_model) return;
    [self applyTargetTransform:[_model transformForDepthAxis:2] resetZoom:NO];
}

@end
