//
//  POSCARParser.m
//  CrystalQuickLook
//

#import "POSCARParser.h"

static NSArray<NSString *> *tokenizeLine(NSString *line) {
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:line];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    while (!scanner.isAtEnd) {
        NSString *token = nil;
        if ([scanner scanUpToCharactersFromSet:ws intoString:&token]) {
            [tokens addObject:token];
        }
        [scanner scanCharactersFromSet:ws intoString:NULL];
    }
    return tokens;
}

@implementation POSCARParser

+ (nullable CrystalModel *)parseFileAtURL:(NSURL *)url error:(NSError * _Nullable *)error {
    NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
    if (!content) {
        content = [NSString stringWithContentsOfURL:url encoding:NSISOLatin1StringEncoding error:error];
    }
    if (!content) return nil;
    return [self parseString:content error:error];
}

+ (nullable CrystalModel *)parseString:(NSString *)poscarString error:(NSError * _Nullable *)error {
    if (!poscarString || poscarString.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"POSCARParser" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Empty POSCAR content"}];
        }
        return nil;
    }

    NSArray<NSString *> *rawLines = [poscarString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    for (NSString *l in rawLines) {
        NSString *trimmed = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) {
            [lines addObject:trimmed];
        }
    }

    if (lines.count < 7) {
        if (error) {
            *error = [NSError errorWithDomain:@"POSCARParser" code:2 userInfo:@{NSLocalizedDescriptionKey: @"POSCAR has fewer than 7 lines"}];
        }
        return nil;
    }

    NSUInteger lineIdx = 0;

    // Line 1: Comment / Title
    NSString *title = lines[lineIdx++];

    // Line 2: Universal scale factor
    NSArray<NSString *> *scaleTokens = tokenizeLine(lines[lineIdx++]);
    if (scaleTokens.count == 0) return nil;
    double scale = [scaleTokens[0] doubleValue];
    if (fabs(scale) < 1e-9) scale = 1.0;

    // Lines 3-5: Lattice vectors
    NSArray<NSString *> *v1Tokens = tokenizeLine(lines[lineIdx++]);
    NSArray<NSString *> *v2Tokens = tokenizeLine(lines[lineIdx++]);
    NSArray<NSString *> *v3Tokens = tokenizeLine(lines[lineIdx++]);

    if (v1Tokens.count < 3 || v2Tokens.count < 3 || v3Tokens.count < 3) {
        if (error) {
            *error = [NSError errorWithDomain:@"POSCARParser" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid lattice vector lines"}];
        }
        return nil;
    }

    Vector3D va = Vector3DMake([v1Tokens[0] doubleValue], [v1Tokens[1] doubleValue], [v1Tokens[2] doubleValue]);
    Vector3D vb = Vector3DMake([v2Tokens[0] doubleValue], [v2Tokens[1] doubleValue], [v2Tokens[2] doubleValue]);
    Vector3D vc = Vector3DMake([v3Tokens[0] doubleValue], [v3Tokens[1] doubleValue], [v3Tokens[2] doubleValue]);

    if (scale > 0.0) {
        va = Vector3DScale(va, scale);
        vb = Vector3DScale(vb, scale);
        vc = Vector3DScale(vc, scale);
    } else {
        // Negative scale means total volume is -scale
        double targetVolume = fabs(scale);
        Vector3D bCrossC = Vector3DMake(
            vb.y * vc.z - vb.z * vc.y,
            vb.z * vc.x - vb.x * vc.z,
            vb.x * vc.y - vb.y * vc.x
        );
        double currentVol = fabs(Vector3DDot(va, bCrossC));
        if (currentVol > 1e-9) {
            double lengthScale = cbrt(targetVolume / currentVol);
            va = Vector3DScale(va, lengthScale);
            vb = Vector3DScale(vb, lengthScale);
            vc = Vector3DScale(vc, lengthScale);
        }
    }

    // Line 6 & 7: Species and counts
    NSArray<NSString *> *line6Tokens = tokenizeLine(lines[lineIdx++]);
    NSMutableArray<NSString *> *elementSymbols = [NSMutableArray array];
    NSMutableArray<NSNumber *> *elementCounts = [NSMutableArray array];

    BOOL isVasp5 = YES;
    // Check if line 6 contains element symbols (letters) or numbers (VASP 4)
    for (NSString *tok in line6Tokens) {
        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[tok characterAtIndex:0]]) {
            isVasp5 = NO;
            break;
        }
    }

    if (isVasp5) {
        [elementSymbols addObjectsFromArray:line6Tokens];
        if (lineIdx >= lines.count) return nil;
        NSArray<NSString *> *line7Tokens = tokenizeLine(lines[lineIdx++]);
        for (NSString *tok in line7Tokens) {
            [elementCounts addObject:@([tok integerValue])];
        }
    } else {
        // VASP 4: Line 6 is counts. Try to extract element names from title comment
        for (NSString *tok in line6Tokens) {
            [elementCounts addObject:@([tok integerValue])];
        }
        NSArray<NSString *> *titleWords = tokenizeLine(title);
        NSUInteger found = 0;
        for (NSString *w in titleWords) {
            NSString *clean = [ElementData cleanElementSymbol:w];
            if (![clean isEqualToString:@"X"]) {
                [elementSymbols addObject:clean];
                found++;
                if (found >= elementCounts.count) break;
            }
        }
        while (elementSymbols.count < elementCounts.count) {
            [elementSymbols addObject:[NSString stringWithFormat:@"El%lu", (unsigned long)(elementSymbols.count + 1)]];
        }
    }

    if (elementSymbols.count != elementCounts.count || elementCounts.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"POSCARParser" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Species/count mismatch"}];
        }
        return nil;
    }

    // Next line might be "Selective dynamics"
    if (lineIdx >= lines.count) return nil;
    NSString *next = lines[lineIdx];
    if ([next hasPrefix:@"S"] || [next hasPrefix:@"s"]) {
        lineIdx++; // skip Selective dynamics
    }

    if (lineIdx >= lines.count) return nil;
    NSString *coordTypeLine = lines[lineIdx++];
    unichar c0 = [[coordTypeLine lowercaseString] characterAtIndex:0];
    BOOL isDirect = (c0 == 'd' || c0 == 'f'); // Direct or Fractional

    CrystalModel *model = [[CrystalModel alloc] init];
    model.sourceFormat = @"POSCAR";
    model.title = title;
    model.vectorA = va;
    model.vectorB = vb;
    model.vectorC = vc;
    [model calculateParametersFromVectors];

    NSMutableArray<CrystalAtom *> *atoms = [NSMutableArray array];
    NSUInteger totalSpecies = elementSymbols.count;

    for (NSUInteger s = 0; s < totalSpecies; s++) {
        NSString *sym = elementSymbols[s];
        NSInteger count = elementCounts[s].integerValue;

        for (NSInteger a = 0; a < count; a++) {
            if (lineIdx >= lines.count) break;
            NSArray<NSString *> *cTokens = tokenizeLine(lines[lineIdx++]);
            if (cTokens.count < 3) continue;

            double x = [cTokens[0] doubleValue];
            double y = [cTokens[1] doubleValue];
            double z = [cTokens[2] doubleValue];

            CrystalAtom *atom = [[CrystalAtom alloc] initWithSymbol:sym
                                                              label:[NSString stringWithFormat:@"%@%ld", sym, (long)(a + 1)]
                                                         fractional:Vector3DMake(0, 0, 0)];

            if (isDirect) {
                atom.fractionalCoord = Vector3DMake(x, y, z);
                atom.cartesianCoord = [model fractionalToCartesian:atom.fractionalCoord];
            } else {
                // Cartesian coordinates
                Vector3D cart = Vector3DMake(x, y, z);
                if (scale > 0.0) {
                    // Cartesian in POSCAR may be affected by scale depending on convention, typically already scaled with lattice
                }
                atom.cartesianCoord = cart;
                atom.fractionalCoord = [model cartesianToFractional:cart];
            }

            [atoms addObject:atom];
        }
    }

    model.atoms = atoms;
    [model populatePeriodicBoundaryAtoms];
    [model detectBonds];

    return model;
}

@end
