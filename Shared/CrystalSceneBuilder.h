//
//  CrystalSceneBuilder.h
//  CrystalQuickLook
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import "CrystalModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CrystalRenderStyle) {
    CrystalRenderStyleStudio = 0,   // Studio Dark: Dark background, realistic studio lighting, CPK colors
    CrystalRenderStyleVESTA = 1,    // VESTA Style: Light blue-gray background, specular shine, VESTA colors
    CrystalRenderStyleFlat = 2      // Flat White: No shade, no lighting, pure white background, black cell lines
};

@interface CrystalSceneBuilder : NSObject

+ (SCNScene *)buildSceneForModel:(CrystalModel *)model
                           style:(CrystalRenderStyle)style
                  cameraDistance:(double *)outCameraDistance;

+ (SCNScene *)buildSceneForModel:(CrystalModel *)model cameraDistance:(double *)outCameraDistance;

+ (SCNNode *)cylinderFromPoint:(SCNVector3)p1
                       toPoint:(SCNVector3)p2
                        radius:(CGFloat)radius
                         color:(NSColor *)color
                 lightingModel:(NSString *)lightingModel;

@end

NS_ASSUME_NONNULL_END
