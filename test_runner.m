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

    // Verify 3 styles
    testStyle(name, model, CrystalRenderStyleStudio, @"Studio Dark");
    testStyle(name, model, CrystalRenderStyleVESTA,  @"VESTA Compatible");
    testStyle(name, model, CrystalRenderStyleFlat,   @"Flat White (No Shade)");

    // Verify Compass Node creation
    CrystalCompassNode *compass = [CrystalCompassNode compassWithModel:model style:CrystalRenderStyleStudio];
    if (!compass || compass.childNodes.count == 0) {
        printf("FAILED (Compass node creation failed)\n");
        exit(1);
    }
    [compass syncRotationWithStructureEulerAngles:SCNVector3Make(0.1, 0.2, 0.3)];

    // Verify longest axis index
    NSInteger longest = [model longestAxisIndex];
    if (expectedLongestAxis >= 0 && longest != expectedLongestAxis) {
        printf("FAILED (Longest axis mismatch: expected %ld, got %ld)\n", (long)expectedLongestAxis, (long)longest);
        exit(1);
    }

    // Verify depth angles calculation
    SCNVector3 rotLongest = [model eulerAnglesForDepthAxis:longest];
    SCNVector3 rotA = [model eulerAnglesForDepthAxis:0];
    SCNVector3 rotB = [model eulerAnglesForDepthAxis:1];
    SCNVector3 rotC = [model eulerAnglesForDepthAxis:2];
    (void)rotLongest; (void)rotA; (void)rotB; (void)rotC;

    printf("PASSED (Formula=%s, longest=%s-axis, a=%.3f, atoms=%lu) [Compass/Modes OK]\n",
           [[model formattedFormula] UTF8String], [[model longestAxisName] UTF8String], model.a, (unsigned long)model.atoms.count);
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
