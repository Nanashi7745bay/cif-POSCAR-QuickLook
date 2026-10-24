#import <Foundation/Foundation.h>
#import "CrystalModel.h"
#import "CIFParser.h"
#import "POSCARParser.h"
#import "CrystalSceneBuilder.h"
#import "CrystalCompassNode.h"
#import "CrystalViewController.h"

static void testStyle(NSString *testName, CrystalModel *model, CrystalRenderStyle style, NSString *styleName) {
    double camDist = 0;
    SCNScene *scene = [CrystalSceneBuilder buildSceneForModel:model style:style cameraDistance:&camDist];
    if (!scene || scene.rootNode.childNodes.count == 0) {
        printf("FAILED (%s [%s]: Scene construction failed)\n", [testName UTF8String], [styleName UTF8String]);
        exit(1);
    }

    SCNNode *camNode = [scene.rootNode childNodeWithName:@"MainCameraNode" recursively:YES];
    if (!camNode || !camNode.camera || !camNode.camera.usesOrthographicProjection) {
        printf("FAILED (%s [%s]: MainCameraNode must use orthographic projection)\n", [testName UTF8String], [styleName UTF8String]);
        exit(1);
    }

    SCNNode *structureNode = [scene.rootNode childNodeWithName:@"StructureNode" recursively:YES];
    SCNNode *contentNode = [structureNode childNodeWithName:@"ContentNode" recursively:NO];
    if (!structureNode || !contentNode) {
        printf("FAILED (%s [%s]: StructureNode/ContentNode missing)\n", [testName UTF8String], [styleName UTF8String]);
        exit(1);
    }

    Vector3D center = [model unitCellCenter];
    Vector3D axes[3] = { model.vectorA, model.vectorB, model.vectorC };

    for (NSInteger axisIdx = 0; axisIdx < 3; axisIdx++) {
        SCNMatrix4 mat = [model transformForDepthAxis:axisIdx];
        structureNode.transform = mat;

        // 1. Verify unit cell center stays strictly at world (0, 0, 0)
        SCNVector3 worldCenter = [scene.rootNode convertPosition:SCNVector3Make(center.x, center.y, center.z) fromNode:contentNode];
        if (fabs(worldCenter.x) > 1e-5 || fabs(worldCenter.y) > 1e-5 || fabs(worldCenter.z) > 1e-5) {
            printf("FAILED (%s: Unit cell center off-center in axis %ld view: %.4f, %.4f, %.4f)\n",
                   [testName UTF8String], (long)axisIdx, worldCenter.x, worldCenter.y, worldCenter.z);
            exit(1);
        }

        // 2. Verify axis endpoints line up straight along depth (+Z), i.e., identical screen (X, Y)
        SCNVector3 p0 = [scene.rootNode convertPosition:SCNVector3Make(0, 0, 0) fromNode:contentNode];
        Vector3D ax = axes[axisIdx];
        SCNVector3 p1 = [scene.rootNode convertPosition:SCNVector3Make(ax.x, ax.y, ax.z) fromNode:contentNode];
        if (fabs(p1.x - p0.x) > 1e-5 || fabs(p1.y - p0.y) > 1e-5 || (p1.z - p0.z) <= 0.0) {
            printf("FAILED (%s: Axis %ld not aligned straight along depth: dx=%.6f, dy=%.6f, dz=%.6f)\n",
                   [testName UTF8String], (long)axisIdx, p1.x - p0.x, p1.y - p0.y, p1.z - p0.z);
            exit(1);
        }
    }
}

static void runTests(NSString *name, NSURL *url, BOOL isCIF, double expectedA, NSUInteger minAtoms, NSInteger expectedLongestAxis) {
    printf("[TEST] %-25s: ", [name UTF8String]);
    NSError *error = nil;
    CrystalModel *model = isCIF ? [CIFParser parseFileAtURL:url error:&error] : [POSCARParser parseFileAtURL:url error:&error];

    if (!model) {
        printf("FAILED (Parser error: %s)\n", [[error localizedDescription] UTF8String]);
        exit(1);
    }

    if (fabs(model.a - expectedA) > 0.05) {
        printf("FAILED (Lattice a mismatch: expected %.3f, got %.3f)\n", expectedA, model.a);
        exit(1);
    }

    if (model.atoms.count < minAtoms) {
        printf("FAILED (Atom count too low: expected >= %lu, got %lu)\n", (unsigned long)minAtoms, (unsigned long)model.atoms.count);
        exit(1);
    }

    // Verify 3 styles + orthographic projection + centered a/b/c straight alignment
    testStyle(name, model, CrystalRenderStyleStudio, @"Studio Dark");
    testStyle(name, model, CrystalRenderStyleVESTA,  @"VESTA Compatible");
    testStyle(name, model, CrystalRenderStyleFlat,   @"Flat White (No Shade)");

    // Verify Compass Node creation & pure rotation sync
    CrystalCompassNode *compass = [CrystalCompassNode compassWithModel:model style:CrystalRenderStyleStudio];
    if (!compass || compass.childNodes.count == 0) {
        printf("FAILED (Compass node creation failed)\n");
        exit(1);
    }
    SCNMatrix4 testRot = [model transformForDepthAxis:0];
    testRot.m41 = 42.0; testRot.m42 = -19.0; testRot.m43 = 7.0;
    [compass syncWithTransform:testRot];
    SCNNode *rotator = [compass childNodeWithName:@"CompassRotator" recursively:NO];
    if (!rotator || fabs(rotator.transform.m41) > 1e-6 || fabs(rotator.transform.m42) > 1e-6 || fabs(rotator.transform.m43) > 1e-6 ||
        fabs(rotator.transform.m11 - testRot.m11) > 1e-6) {
        printf("FAILED (Compass rotation sync or translation stripping failed)\n");
        exit(1);
    }

    // Verify longest axis index
    NSInteger longest = [model longestAxisIndex];
    if (expectedLongestAxis >= 0 && longest != expectedLongestAxis) {
        printf("FAILED (Longest axis mismatch: expected %ld, got %ld)\n", (long)expectedLongestAxis, (long)longest);
        exit(1);
    }

    printf("PASSED (Formula=%s, longest=%s-axis, Ortho+Centered+Compass OK)\n",
           [[model formattedFormula] UTF8String], [[model longestAxisName] UTF8String]);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        printf("====================================================================\n");
        printf("  Running CrystalQuickLook v1.2 Orientation & Multi-Style Tests\n");
        printf("====================================================================\n");

        // Cubic Silicon: a = b = c = 5.431 -> index 0 (a-axis)
        runTests(@"Silicon Diamond (CIF)", [NSURL fileURLWithPath:@"Samples/Si_diamond.cif"], YES, 5.431, 8, 0);
        // Cubic SrTiO3: a = b = c = 3.905 -> index 0
        runTests(@"Perovskite SrTiO3 (CIF)", [NSURL fileURLWithPath:@"Samples/SrTiO3_perovskite.cif"], YES, 3.905, 5, 0);
        // Cubic NaCl: a = b = c = 5.640 -> index 0
        runTests(@"Halite NaCl (CIF)", [NSURL fileURLWithPath:@"Samples/NaCl.cif"], YES, 5.640, 8, 0);
        // POSCAR Silicon: 5.431 -> index 0
        runTests(@"Silicon (POSCAR)", [NSURL fileURLWithPath:@"Samples/POSCAR_Si"], NO, 5.431, 8, 0);
        // Rutile TiO2: a = b = 4.594, c = 2.959 -> index 0 (a-axis is longest)
        runTests(@"Rutile TiO2 (POSCAR)", [NSURL fileURLWithPath:@"Samples/POSCAR_TiO2"], NO, 4.594, 6, 0);

        printf("\n✨ All v1.2 tests PASSED! (Orientation Compass + Longest Axis Depth + 3 Styles) ✨\n");
    }
    return 0;
}
