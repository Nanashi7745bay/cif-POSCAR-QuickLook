//
//  CrystalCompassNode.m
//  CrystalQuickLook
//

#import "CrystalCompassNode.h"

@interface CrystalCompassNode ()

@property (nonatomic, strong) SCNNode *rotatorNode;

@end

@implementation CrystalCompassNode

+ (instancetype)compassWithModel:(CrystalModel *)model style:(CrystalRenderStyle)style {
    CrystalCompassNode *node = [[CrystalCompassNode alloc] init];
    [node setupWithModel:model style:style];
    return node;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _rotatorNode = [SCNNode node];
        _rotatorNode.name = @"CompassRotator";
        [self addChildNode:_rotatorNode];
    }
    return self;
}

- (void)updateWithModel:(CrystalModel *)model style:(CrystalRenderStyle)style {
    [_rotatorNode.childNodes makeObjectsPerformSelector:@selector(removeFromParentNode)];
    [self buildCompassWithModel:model style:style];
}

- (void)setupWithModel:(CrystalModel *)model style:(CrystalRenderStyle)style {
    [self buildCompassWithModel:model style:style];
}

- (void)syncRotationWithStructureEulerAngles:(SCNVector3)eulerAngles {
    _rotatorNode.eulerAngles = eulerAngles;
}

// Helper to create an arrow along unit direction vector u
static SCNNode *createArrow(Vector3D u, CGFloat shaftLen, CGFloat headLen, CGFloat shaftRadius, CGFloat headRadius, NSColor *color, NSString *labelString, NSString *lightingModel) {
    SCNNode *arrowNode = [SCNNode node];

    CGFloat totalLen = shaftLen + headLen;

    // 1. Shaft (Cylinder)
    SCNCylinder *shaft = [SCNCylinder cylinderWithRadius:shaftRadius height:shaftLen];
    shaft.radialSegmentCount = 12;
    SCNMaterial *mat = [SCNMaterial material];
    mat.diffuse.contents = color;
    mat.lightingModelName = lightingModel;
    if (![lightingModel isEqualToString:SCNLightingModelConstant]) {
        mat.specular.contents = [NSColor colorWithWhite:0.7 alpha:1.0];
    }
    shaft.firstMaterial = mat;

    SCNNode *shaftNode = [SCNNode nodeWithGeometry:shaft];
    shaftNode.position = SCNVector3Make(0, shaftLen * 0.5, 0);

    // 2. Head (Cone)
    SCNCone *head = [SCNCone coneWithTopRadius:0.0 bottomRadius:headRadius height:headLen];
    head.radialSegmentCount = 12;
    head.firstMaterial = mat;

    SCNNode *headNode = [SCNNode nodeWithGeometry:head];
    headNode.position = SCNVector3Make(0, shaftLen + headLen * 0.5, 0);

    // 3. Label (a, b, c)
    SCNText *textGeom = [SCNText textWithString:labelString extrusionDepth:0.015];
    textGeom.font = [NSFont boldSystemFontOfSize:0.12];
    textGeom.flatness = 0.05;

    SCNMaterial *textMat = [SCNMaterial material];
    textMat.diffuse.contents = color;
    textMat.lightingModelName = SCNLightingModelConstant;
    textGeom.firstMaterial = textMat;

    SCNNode *textNode = [SCNNode nodeWithGeometry:textGeom];
    // Center the text
    SCNVector3 minV, maxV;
    [textNode getBoundingBoxMin:&minV max:&maxV];
    textNode.pivot = SCNMatrix4MakeTranslation((maxV.x - minV.x) * 0.5, (maxV.y - minV.y) * 0.5, 0);
    textNode.position = SCNVector3Make(0, totalLen + 0.08, 0);

    // Billboard constraint so text always faces camera
    SCNBillboardConstraint *billboard = [SCNBillboardConstraint billboardConstraint];
    billboard.freeAxes = SCNBillboardAxisAll;
    textNode.constraints = @[billboard];

    // Sub-assembly along +Y
    SCNNode *yAligned = [SCNNode node];
    [yAligned addChildNode:shaftNode];
    [yAligned addChildNode:headNode];
    [yAligned addChildNode:textNode];

    // Orient from (0, 1, 0) to unit vector u
    CGFloat len = sqrt(u.x*u.x + u.y*u.y + u.z*u.z);
    if (len < 1e-6) return arrowNode;

    CGFloat ux = u.x / len;
    CGFloat uy = u.y / len;
    CGFloat uz = u.z / len;

    // Cross product: (0, 1, 0) x (ux, uy, uz) = (uz, 0, -ux)
    CGFloat rx = uz;
    CGFloat ry = 0.0;
    CGFloat rz = -ux;
    CGFloat rlen = sqrt(rx*rx + ry*ry + rz*rz);

    if (rlen > 1e-6) {
        CGFloat angle = acos(fmax(-1.0, fmin(1.0, uy)));
        yAligned.rotation = SCNVector4Make(rx / rlen, ry / rlen, rz / rlen, angle);
    } else {
        if (uy < 0.0) {
            yAligned.rotation = SCNVector4Make(1, 0, 0, M_PI);
        }
    }

    [arrowNode addChildNode:yAligned];
    return arrowNode;
}

- (void)buildCompassWithModel:(CrystalModel *)model style:(CrystalRenderStyle)style {
    NSString *lightingModel = (style == CrystalRenderStyleFlat) ? SCNLightingModelConstant : SCNLightingModelBlinn;

    // Central small sphere
    SCNSphere *centerSphere = [SCNSphere sphereWithRadius:0.035];
    centerSphere.segmentCount = 12;
    SCNMaterial *sphereMat = [SCNMaterial material];
    sphereMat.diffuse.contents = [NSColor colorWithWhite:0.6 alpha:1.0];
    sphereMat.lightingModelName = lightingModel;
    centerSphere.firstMaterial = sphereMat;

    SCNNode *centerNode = [SCNNode nodeWithGeometry:centerSphere];
    [_rotatorNode addChildNode:centerNode];

    // Unit vectors along a, b, c axes
    Vector3D va = model.vectorA;
    Vector3D vb = model.vectorB;
    Vector3D vc = model.vectorC;

    CGFloat la = sqrt(va.x*va.x + va.y*va.y + va.z*va.z);
    CGFloat lb = sqrt(vb.x*vb.x + vb.y*vb.y + vb.z*vb.z);
    CGFloat lc = sqrt(vc.x*vc.x + vc.y*vc.y + vc.z*vc.z);

    Vector3D ua = (la > 1e-6) ? Vector3DScale(va, 1.0 / la) : Vector3DMake(1, 0, 0);
    Vector3D ub = (lb > 1e-6) ? Vector3DScale(vb, 1.0 / lb) : Vector3DMake(0, 1, 0);
    Vector3D uc = (lc > 1e-6) ? Vector3DScale(vc, 1.0 / lc) : Vector3DMake(0, 0, 1);

    // Dimensions
    CGFloat shaftLen = 0.32;
    CGFloat headLen = 0.10;
    CGFloat shaftRadius = 0.016;
    CGFloat headRadius = 0.042;

    // Colors: a=Red, b=Green, c=Blue
    NSColor *colA = [NSColor colorWithSRGBRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    NSColor *colB = [NSColor colorWithSRGBRed:0.20 green:0.78 blue:0.35 alpha:1.0];
    NSColor *colC = [NSColor colorWithSRGBRed:0.0 green:0.48 blue:1.0 alpha:1.0];

    SCNNode *arrowA = createArrow(ua, shaftLen, headLen, shaftRadius, headRadius, colA, @"a", lightingModel);
    SCNNode *arrowB = createArrow(ub, shaftLen, headLen, shaftRadius, headRadius, colB, @"b", lightingModel);
    SCNNode *arrowC = createArrow(uc, shaftLen, headLen, shaftRadius, headRadius, colC, @"c", lightingModel);

    [_rotatorNode addChildNode:arrowA];
    [_rotatorNode addChildNode:arrowB];
    [_rotatorNode addChildNode:arrowC];
}

@end
