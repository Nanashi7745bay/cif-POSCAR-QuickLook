//
//  CrystalViewController.h
//  CrystalQuickLook
//

#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>
#import "CrystalModel.h"
#import "CrystalSceneBuilder.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, InitialOrientationMode) {
    InitialOrientationModeLongestAxisDepth = 0, // 長軸奥行き (Default)
    InitialOrientationModeClassicIsometric = 1, // 従来の斜視アングル
    InitialOrientationModeSpecifiedAxis    = 2  // 指定軸 (a, b, c) を奥行きにする
};

typedef NS_ENUM(NSInteger, SpecifiedDepthAxis) {
    SpecifiedDepthAxisA = 0,
    SpecifiedDepthAxisB = 1,
    SpecifiedDepthAxisC = 2
};

extern NSString * const kInitialOrientationModeKey;
extern NSString * const kSpecifiedDepthAxisKey;

@interface CrystalViewController : NSViewController <SCNSceneRendererDelegate>

@property (nonatomic, strong, readonly) SCNView *scnView;
@property (nonatomic, strong, readonly, nullable) CrystalModel *model;
@property (nonatomic, assign) CrystalRenderStyle currentStyle;
@property (nonatomic, assign) InitialOrientationMode orientationMode;
@property (nonatomic, assign) SpecifiedDepthAxis specifiedAxis;

- (BOOL)loadStructureFromURL:(NSURL *)url error:(NSError * _Nullable *)error;
- (BOOL)loadStructureFromString:(NSString *)content filename:(NSString *)filename error:(NSError * _Nullable *)error;

- (void)setRenderStyle:(CrystalRenderStyle)style;
- (void)cycleNextStyle;

- (void)setOrientationMode:(InitialOrientationMode)mode;
- (void)setSpecifiedAxis:(SpecifiedDepthAxis)axis;

- (void)resetCamera;
- (void)lookAlongA;
- (void)lookAlongB;
- (void)lookAlongC;

@end

NS_ASSUME_NONNULL_END
