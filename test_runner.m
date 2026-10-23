#import <Foundation/Foundation.h>
#import "CrystalModel.h"
#import "CIFParser.h"
#import "POSCARParser.h"
#import "CrystalSceneBuilder.h"

static void testStyle(NSString *testName, CrystalModel *model, CrystalRenderStyle style, NSString *styleName) {
    double camDist = 0;
    SCNScene *scene = [CrystalSceneBuilder buildSceneForModel:model style:style cameraDistance:&camDist];
    if (!scene || scene.rootNode.childNodes.count == 0) {
        printf("FAILED (%s [%s]: Scene construction failed)\n", [testName UTF8String], [styleName UTF8String]);
        exit(1);
    }
}

static void runAllStylesTest(NSString *name, NSURL *url, BOOL isCIF, double expectedA, NSUInteger minAtoms) {
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

    // Verify all 3 styles
    testStyle(name, model, CrystalRenderStyleStudio, @"Studio Dark");
    testStyle(name, model, CrystalRenderStyleVESTA,  @"VESTA Compatible");
    testStyle(name, model, CrystalRenderStyleFlat,   @"Flat White (No Shade)");

    printf("PASSED (Formula=%s, a=%.3f, atoms=%lu, bonds=%lu) [Studio/VESTA/Flat OK]\n",
           [[model formattedFormula] UTF8String], model.a, (unsigned long)model.atoms.count, (unsigned long)model.bonds.count);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        printf("====================================================================\n");
        printf("  Running CrystalQuickLook v1.1 Multi-Style & Parser Tests\n");
        printf("====================================================================\n");

        runAllStylesTest(@"Silicon Diamond (CIF)", [NSURL fileURLWithPath:@"Samples/Si_diamond.cif"], YES, 5.431, 8);
        runAllStylesTest(@"Perovskite SrTiO3 (CIF)", [NSURL fileURLWithPath:@"Samples/SrTiO3_perovskite.cif"], YES, 3.905, 5);
        runAllStylesTest(@"Halite NaCl (CIF)", [NSURL fileURLWithPath:@"Samples/NaCl.cif"], YES, 5.640, 8);
        runAllStylesTest(@"Silicon (POSCAR)", [NSURL fileURLWithPath:@"Samples/POSCAR_Si"], NO, 5.431, 8);
        runAllStylesTest(@"Rutile TiO2 (POSCAR)", [NSURL fileURLWithPath:@"Samples/POSCAR_TiO2"], NO, 4.594, 6);

        printf("\n✨ All 5 test structures PASSED in all 3 styles (Studio, VESTA, Flat White)! ✨\n");
    }
    return 0;
}
