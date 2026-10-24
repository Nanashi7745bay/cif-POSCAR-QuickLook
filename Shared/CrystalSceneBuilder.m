//
//  CrystalSceneBuilder.m
//  CrystalQuickLook
//

#import "CrystalSceneBuilder.h"

@implementation CrystalSceneBuilder

+ (SCNNode *)cylinderFromPoint:(SCNVector3)p1
                       toPoint:(SCNVector3)p2
                        radius:(CGFloat)radius
                         color:(NSColor *)color
                 lightingModel:(NSString *)lightingModel {
    CGFloat dx = p2.x - p1.x;
    CGFloat dy = p2.y - p1.y;
    CGFloat dz = p2.z - p1.z;
    CGFloat length = sqrt(dx*dx + dy*dy + dz*dz);

    if (length < 1e-6) return [SCNNode node];

    SCNCylinder *cylinder = [SCNCylinder cylinderWithRadius:radius height:length];
    cylinder.radialSegmentCount = 16;

    SCNMaterial *material = [SCNMaterial material];
    material.diffuse.contents = color;
    material.lightingModelName = lightingModel;

    if (![lightingModel isEqualToString:SCNLightingModelConstant]) {
        material.specular.contents = [NSColor colorWithWhite:0.7 alpha:1.0];
        material.roughness.contents = @0.4;
    }

    cylinder.firstMaterial = material;

    SCNNode *node = [SCNNode nodeWithGeometry:cylinder];
    node.position = SCNVector3Make((p1.x + p2.x)*0.5, (p1.y + p2.y)*0.5, (p1.z + p2.z)*0.5);

    CGFloat vx = dx / length;
    CGFloat vy = dy / length;
    CGFloat vz = dz / length;

    CGFloat rx = vz;
    CGFloat ry = 0.0;
    CGFloat rz = -vx;
    CGFloat rlen = sqrt(rx*rx + ry*ry + rz*rz);

    if (rlen > 1e-6) {
        CGFloat angle = acos(fmax(-1.0, fmin(1.0, vy)));
        node.rotation = SCNVector4Make(rx / rlen, ry / rlen, rz / rlen, angle);
    } else {
        if (vy < 0.0) {
            node.rotation = SCNVector4Make(1, 0, 0, M_PI);
        }
    }

    return node;
}

+ (SCNScene *)buildSceneForModel:(CrystalModel *)model cameraDistance:(double *)outCameraDistance {
    return [self buildSceneForModel:model style:CrystalRenderStyleStudio cameraDistance:outCameraDistance];
}

+ (SCNScene *)buildSceneForModel:(CrystalModel *)model
                           style:(CrystalRenderStyle)style
                  cameraDistance:(double *)outCameraDistance {
    SCNScene *scene = [SCNScene scene];

    // Background color based on style
    NSColor *bgColor = nil;
    NSColor *cellEdgeColor = nil;
    NSColor *bondColor = nil;
    NSString *lightingModel = SCNLightingModelBlinn;
    ElementStyle elemStyle = ElementStyleStandardCPK;
    BOOL isFlat = (style == CrystalRenderStyleFlat);

    switch (style) {
        case CrystalRenderStyleVESTA:
            // VESTA characteristic soft cyan-tinted light gray
            bgColor = [NSColor colorWithSRGBRed:0.93 green:0.95 blue:0.97 alpha:1.0];
            cellEdgeColor = [NSColor colorWithWhite:0.2 alpha:0.75];
            bondColor = [NSColor colorWithWhite:0.75 alpha:1.0];
            lightingModel = SCNLightingModelPhong;
            elemStyle = ElementStyleVESTA;
            break;

        case CrystalRenderStyleFlat:
            // Pure white background, No shade, No lighting
            bgColor = [NSColor whiteColor];
            cellEdgeColor = [NSColor colorWithWhite:0.0 alpha:0.9];
            bondColor = [NSColor colorWithWhite:0.55 alpha:1.0];
            lightingModel = SCNLightingModelConstant; // Flat! No shading, no lights
            elemStyle = ElementStyleVESTA;
            break;

        case CrystalRenderStyleStudio:
        default:
            // Deep dark slate background
            bgColor = [NSColor colorWithSRGBRed:0.09 green:0.11 blue:0.14 alpha:1.0];
            cellEdgeColor = [NSColor colorWithWhite:0.85 alpha:0.45];
            bondColor = [NSColor colorWithWhite:0.65 alpha:0.9];
            lightingModel = SCNLightingModelBlinn;
            elemStyle = ElementStyleStandardCPK;
            break;
    }

    scene.background.contents = bgColor;

    SCNNode *rootNode = scene.rootNode;

    // Structure node (at origin so rotations pivot strictly around the unit cell center)
    SCNNode *structureNode = [SCNNode node];
    structureNode.name = @"StructureNode";
    structureNode.position = SCNVector3Make(0, 0, 0);
    [rootNode addChildNode:structureNode];

    // Child content node offset by -center so the unit cell center lies at StructureNode's origin (0,0,0)
    Vector3D center = [model unitCellCenter];
    SCNNode *contentNode = [SCNNode node];
    contentNode.name = @"ContentNode";
    contentNode.position = SCNVector3Make(-center.x, -center.y, -center.z);
    [structureNode addChildNode:contentNode];

    // 1. Build Unit Cell Wireframe & Axes
    Vector3D o = Vector3DMake(0, 0, 0);
    Vector3D a = model.vectorA;
    Vector3D b = model.vectorB;
    Vector3D c = model.vectorC;

    Vector3D ab  = Vector3DAdd(a, b);
    Vector3D ac  = Vector3DAdd(a, c);
    Vector3D bc  = Vector3DAdd(b, c);
    Vector3D abc = Vector3DAdd(ab, c);

    #define P3(v) SCNVector3Make((CGFloat)(v.x), (CGFloat)(v.y), (CGFloat)(v.z))

    // Cell Axes: a=Red, b=Green, c=Blue
    CGFloat axisRadius = isFlat ? 0.035 : 0.045;
    [contentNode addChildNode:[self cylinderFromPoint:P3(o) toPoint:P3(a) radius:axisRadius
                                                color:[NSColor colorWithSRGBRed:1.0 green:0.23 blue:0.19 alpha:1.0]
                                        lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(o) toPoint:P3(b) radius:axisRadius
                                                color:[NSColor colorWithSRGBRed:0.20 green:0.78 blue:0.35 alpha:1.0]
                                        lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(o) toPoint:P3(c) radius:axisRadius
                                                color:[NSColor colorWithSRGBRed:0.0 green:0.48 blue:1.0 alpha:1.0]
                                        lightingModel:lightingModel]];

    // Remaining 9 cell edges
    CGFloat edgeRadius = isFlat ? 0.020 : 0.022;
    [contentNode addChildNode:[self cylinderFromPoint:P3(a) toPoint:P3(ab) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(a) toPoint:P3(ac) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];

    [contentNode addChildNode:[self cylinderFromPoint:P3(b) toPoint:P3(ab) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(b) toPoint:P3(bc) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];

    [contentNode addChildNode:[self cylinderFromPoint:P3(c) toPoint:P3(ac) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(c) toPoint:P3(bc) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];

    [contentNode addChildNode:[self cylinderFromPoint:P3(ab) toPoint:P3(abc) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(ac) toPoint:P3(abc) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];
    [contentNode addChildNode:[self cylinderFromPoint:P3(bc) toPoint:P3(abc) radius:edgeRadius color:cellEdgeColor lightingModel:lightingModel]];

    // 2. Build Atoms
    NSMutableDictionary<NSString *, SCNMaterial *> *materialCache = [NSMutableDictionary dictionary];

    for (CrystalAtom *atom in model.atoms) {
        NSString *sym = atom.symbol ?: @"X";
        SCNMaterial *mat = materialCache[sym];
        if (!mat) {
            mat = [SCNMaterial material];
            NSColor *elemColor = [atom.elementInfo colorForStyle:elemStyle];
            mat.diffuse.contents = elemColor;
            mat.lightingModelName = lightingModel;

            if (style == CrystalRenderStyleFlat) {
                // Completely flat: no specular
                mat.specular.contents = [NSColor blackColor];
            } else if (style == CrystalRenderStyleVESTA) {
                // VESTA: sharp bright white specular highlight (plastic-like)
                mat.specular.contents = [NSColor colorWithWhite:1.0 alpha:1.0];
                mat.shininess = 0.35;
                mat.roughness.contents = @0.2;
            } else {
                // Studio: soft specular
                mat.specular.contents = [NSColor colorWithWhite:0.8 alpha:1.0];
                mat.roughness.contents = @0.35;
                mat.metalness.contents = @0.05;
            }
            materialCache[sym] = mat;
        }

        SCNSphere *sphere = [SCNSphere sphereWithRadius:atom.elementInfo.displayRadius];
        sphere.segmentCount = isFlat ? 28 : 24;
        sphere.firstMaterial = mat;

        SCNNode *atomNode = [SCNNode nodeWithGeometry:sphere];
        atomNode.position = P3(atom.cartesianCoord);
        if (atom.isPeriodicReplica) {
            atomNode.opacity = (style == CrystalRenderStyleFlat) ? 0.95 : 0.88;
        }
        [contentNode addChildNode:atomNode];
    }

    // 3. Build Bonds
    CGFloat bRadius = isFlat ? 0.065 : 0.075;
    for (CrystalBond *bond in model.bonds) {
        SCNVector3 p1 = P3(bond.atom1.cartesianCoord);
        SCNVector3 p2 = P3(bond.atom2.cartesianCoord);
        [contentNode addChildNode:[self cylinderFromPoint:p1 toPoint:p2 radius:bRadius color:bondColor lightingModel:lightingModel]];
    }

    #undef P3

    // 4. Lighting Setup (Only if NOT Flat)
    if (!isFlat) {
        if (style == CrystalRenderStyleVESTA) {
            // VESTA style lighting: Strong front-top-right light + soft fill + bright ambient
            SCNLight *vestaMainLight = [SCNLight light];
            vestaMainLight.type = SCNLightTypeDirectional;
            vestaMainLight.color = [NSColor colorWithWhite:0.95 alpha:1.0];
            vestaMainLight.castsShadow = YES;
            vestaMainLight.shadowSampleCount = 4;
            vestaMainLight.shadowRadius = 2.5;

            SCNNode *mainLightNode = [SCNNode node];
            mainLightNode.light = vestaMainLight;
            mainLightNode.eulerAngles = SCNVector3Make(-M_PI / 3.5, M_PI / 4.0, 0);
            [rootNode addChildNode:mainLightNode];

            SCNLight *vestaFillLight = [SCNLight light];
            vestaFillLight.type = SCNLightTypeDirectional;
            vestaFillLight.color = [NSColor colorWithWhite:0.45 alpha:1.0];

            SCNNode *fillLightNode = [SCNNode node];
            fillLightNode.light = vestaFillLight;
            fillLightNode.eulerAngles = SCNVector3Make(M_PI / 4.0, -2.5 * M_PI / 4.0, 0);
            [rootNode addChildNode:fillLightNode];

            SCNLight *ambient = [SCNLight light];
            ambient.type = SCNLightTypeAmbient;
            ambient.color = [NSColor colorWithWhite:0.40 alpha:1.0];
            SCNNode *ambNode = [SCNNode node];
            ambNode.light = ambient;
            [rootNode addChildNode:ambNode];
        } else {
            // Studio Dark Lighting
            SCNLight *keyLight = [SCNLight light];
            keyLight.type = SCNLightTypeDirectional;
            keyLight.color = [NSColor colorWithWhite:0.9 alpha:1.0];
            keyLight.castsShadow = YES;
            keyLight.shadowSampleCount = 4;
            keyLight.shadowRadius = 3.0;

            SCNNode *keyLightNode = [SCNNode node];
            keyLightNode.light = keyLight;
            keyLightNode.eulerAngles = SCNVector3Make(-M_PI / 4.0, M_PI / 4.0, 0);
            [rootNode addChildNode:keyLightNode];

            SCNLight *fillLight = [SCNLight light];
            fillLight.type = SCNLightTypeDirectional;
            fillLight.color = [NSColor colorWithWhite:0.4 alpha:1.0];
            SCNNode *fillLightNode = [SCNNode node];
            fillLightNode.light = fillLight;
            fillLightNode.eulerAngles = SCNVector3Make(M_PI / 4.0, -3.0 * M_PI / 4.0, 0);
            [rootNode addChildNode:fillLightNode];

            SCNLight *ambientLight = [SCNLight light];
            ambientLight.type = SCNLightTypeAmbient;
            ambientLight.color = [NSColor colorWithWhite:0.28 alpha:1.0];
            SCNNode *ambientLightNode = [SCNNode node];
            ambientLightNode.light = ambientLight;
            [rootNode addChildNode:ambientLightNode];
        }
    }

    // 5. Camera Setup (Orthographic projection so parallel lattice axes & atomic columns align straight)
    double maxDim = fmax(model.a, fmax(model.b, model.c));
    if (maxDim < 2.0) maxDim = 5.0;
    double camDist = maxDim * 4.0;
    double orthoScale = fmax(maxDim * 0.95, 2.5);

    SCNCamera *camera = [SCNCamera camera];
    camera.usesOrthographicProjection = YES;
    camera.orthographicScale = orthoScale;
    camera.zNear = 0.1;
    camera.zFar = camDist * 10.0;

    SCNNode *cameraNode = [SCNNode node];
    cameraNode.name = @"MainCameraNode";
    cameraNode.camera = camera;
    cameraNode.position = SCNVector3Make(0, 0, camDist);
    [rootNode addChildNode:cameraNode];

    if (outCameraDistance) {
        *outCameraDistance = camDist;
    }

    return scene;
}

@end
