//
//  CrystalViewController.h
//  CrystalQuickLook
//

#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>
#import "CrystalModel.h"
#import "CrystalSceneBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface CrystalViewController : NSViewController

@property (nonatomic, strong, readonly) SCNView *scnView;
@property (nonatomic, strong, readonly, nullable) CrystalModel *model;
@property (nonatomic, assign) CrystalRenderStyle currentStyle;

- (BOOL)loadStructureFromURL:(NSURL *)url error:(NSError * _Nullable *)error;
- (BOOL)loadStructureFromString:(NSString *)content filename:(NSString *)filename error:(NSError * _Nullable *)error;

- (void)setRenderStyle:(CrystalRenderStyle)style;
- (void)cycleNextStyle;

- (void)resetCamera;
- (void)lookAlongA;
- (void)lookAlongB;
- (void)lookAlongC;

@end

NS_ASSUME_NONNULL_END
