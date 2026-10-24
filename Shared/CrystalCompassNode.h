//
//  CrystalCompassNode.h
//  CrystalQuickLook
//

#import <SceneKit/SceneKit.h>
#import "CrystalModel.h"
#import "CrystalSceneBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface CrystalCompassNode : SCNNode

+ (instancetype)compassWithModel:(CrystalModel *)model style:(CrystalRenderStyle)style;
- (void)updateWithModel:(CrystalModel *)model style:(CrystalRenderStyle)style;
- (void)syncRotationWithStructureEulerAngles:(SCNVector3)eulerAngles;

@end

NS_ASSUME_NONNULL_END
