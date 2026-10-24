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

- (void)syncWithTransform:(SCNMatrix4)transform {
    // Isolate pure rotation: remove translation component
    transform.m41 = 0;
    transform.m42 = 0;
    transform.m43 = 0;
    _rotatorNode.transform = transform;
}

static SCNNode *createCompassArrow(Vector3D u, CGFloat shaftLen, CGFloat headLen, CGFloat shaftRadius, CGFloat headRadius, NSColor *color, NSString *labelString, NSString *lightingModel) {
    SCNNode *arrowNode = [SCNNode node];

    // 1. Shaft (Cylinder)
    SCNCylinder *shaft = [SCNCylinder cylinderWithRadius:shaftRadius height:shaftLen];
    shaft.radialSegmentCount = 16;
    SCNMaterial *mat = [SCNMaterial material];
    mat.diffuse.contents = color;
    mat.lightingModelName = lightingModel;
    if (![lightingModel isEqualToString:SCNLightingModelConstant]) {
        mat.specular.contents = [NSColor colorWithWhite:0.8 alpha:1.0];
        mat.shininess = 0.3;
    }
    shaft.firstMaterial = mat;

    SCNNode *shaftNode = [SCNNode nodeWithGeometry:shaft];
    shaftNode.position = SCNVector3Make(0, shaftLen * 0.5, 0);

    // 2. Head (Cone)
    SCNCone *head = [SCNCone coneWithTopRadius:0.0 bottomRadius:headRadius height:headLen];
    head.radialSegmentCount = 16;
    head.firstMaterial = mat;

    SCNNode *headNode = [SCNNode nodeWithGeometry:head];
    headNode.position = SCNVector3Make(0, shaftLen + headLen * 0.5, 0);

    // 3. Label (a, b, c)
    SCNText *textGeom = [SCNText textWithString:labelString extrusionDepth:0.02];
    textGeom.font = [NSFont boldSystemFontOfSize:0.13];
    textGeom.flatness = 0.05;

    SCNMaterial *textMat = [SCNMaterial material];
    textMat.diffuse.contents = color;
    textMat.lightingModelName = SCNLightingModelConstant;
    textGeom.firstMaterial = textMat;

    SCNNode *textNode = [SCNNode nodeWithGeometry:textGeom];
    SCNVector3 minV, maxV;
    [textNode getBoundingBoxMin:&minV max:&maxV];
    textNode.pivot = SCNMatrix4MakeTranslation((maxV.x - minV.x) * 0.5, (maxV.y - minV.y) * 0.5, 0);
    textNode.position = SCNVector3Make(0, shaftLen + headLen + 0.07, 0);

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
    centerSphere.segmentCount = 16;
    SCNMaterial *sphereMat = [SCNMaterial material];
    sphereMat.diffuse.contents = (style == CrystalRenderStyleFlat) ? [NSColor colorWithWhite:0.3 alpha:1.0] : [NSColor colorWithWhite:0.65 alpha:1.0];
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
    CGFloat shaftLen = 0.30;
    CGFloat headLen = 0.09;
    CGFloat shaftRadius = 0.016;
    CGFloat headRadius = 0.040;

    // Colors: a=Red, b=Green, c=Blue
    NSColor *colA = [NSColor colorWithSRGBRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    NSColor *colB = [NSColor colorWithSRGBRed:0.20 green:0.78 blue:0.35 alpha:1.0];
    NSColor *colC = [NSColor colorWithSRGBRed:0.0 green:0.48 blue:1.0 alpha:1.0];

    SCNNode *arrowA = createCompassArrow(ua, shaftLen, headLen, shaftRadius, headRadius, colA, @"a", lightingModel);
    SCNNode *arrowB = createCompassArrow(ub, shaftLen, headLen, shaftRadius, headRadius, colB, @"b", lightingModel);
    SCNNode *arrowC = createCompassArrow(uc, shaftLen, headLen, shaftRadius, headRadius, colC, @"c", lightingModel);

    [_rotatorNode addChildNode:arrowA];
    [_rotatorNode addChildNode:arrowB];
    [_rotatorNode addChildNode:arrowC];
}

@end
