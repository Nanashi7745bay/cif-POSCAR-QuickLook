//
//  CIFParser.m
//  CrystalQuickLook
//

#import "CIFParser.h"

// Structure representing an affine symmetry operation: r' = R * r + t
typedef struct {
    double r[3][3];
    double t[3];
} SymOp;

static double cleanNumericString(NSString *str) {
    if (!str || str.length == 0) return 0.0;
    // Remove (..) uncertainties, e.g. "3.840(5)" -> "3.840"
    NSRange openParen = [str rangeOfString:@"("];
    if (openParen.location != NSNotFound) {
        str = [str substringToIndex:openParen.location];
    }
    return [str doubleValue];
}

static BOOL parseSingleAxisOp(NSString *expr, double rowR[3], double *rowT) {
    rowR[0] = 0.0; rowR[1] = 0.0; rowR[2] = 0.0;
    *rowT = 0.0;

    NSString *s = [[expr lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (s.length == 0) return NO;

    NSInteger i = 0;
    NSInteger len = s.length;

    while (i < len) {
        double sign = 1.0;
        unichar c = [s characterAtIndex:i];
        if (c == '+') {
            sign = 1.0;
            i++;
        } else if (c == '-') {
            sign = -1.0;
            i++;
        }

        if (i >= len) break;
        c = [s characterAtIndex:i];

        if (c == 'x') {
            rowR[0] += sign;
            i++;
        } else if (c == 'y') {
            rowR[1] += sign;
            i++;
        } else if (c == 'z') {
            rowR[2] += sign;
            i++;
        } else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c]) {
            // Parse number or fraction like 1/2, 3/4, 0.5
            NSInteger start = i;
            while (i < len) {
                unichar ch = [s characterAtIndex:i];
                if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch] || ch == '.' || ch == '/') {
                    i++;
                } else {
                    break;
                }
            }
            NSString *numStr = [s substringWithRange:NSMakeRange(start, i - start)];
            double val = 0.0;
            if ([numStr containsString:@"/"]) {
                NSArray *parts = [numStr componentsSeparatedByString:@"/"];
                if (parts.count == 2) {
                    val = [parts[0] doubleValue] / [parts[1] doubleValue];
                }
            } else {
                val = [numStr doubleValue];
            }
            *rowT += sign * val;
        } else {
            i++;
        }
    }
    return YES;
}

static BOOL parseSymOp(NSString *rawString, SymOp *op) {
    // E.g. " -x+1/2, y, -z+1/4 "
    NSString *clean = [rawString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\" "]];
    NSArray *parts = [clean componentsSeparatedByString:@","];
    if (parts.count != 3) return NO;

    if (!parseSingleAxisOp(parts[0], op->r[0], &op->t[0])) return NO;
    if (!parseSingleAxisOp(parts[1], op->r[1], &op->t[1])) return NO;
    if (!parseSingleAxisOp(parts[2], op->r[2], &op->t[2])) return NO;
    return YES;
}

@implementation CIFParser

+ (nullable CrystalModel *)parseFileAtURL:(NSURL *)url error:(NSError * _Nullable *)error {
    NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
    if (!content) {
        // Fallback to ISO-8859-1 / ASCII
        content = [NSString stringWithContentsOfURL:url encoding:NSISOLatin1StringEncoding error:error];
    }
    if (!content) return nil;
    return [self parseString:content error:error];
}

+ (nullable CrystalModel *)parseString:(NSString *)cifString error:(NSError * _Nullable *)error {
    if (!cifString || cifString.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"CIFParser" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Empty CIF data"}];
        }
        return nil;
    }

    // Tokenize CIF text
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:cifString];
    scanner.charactersToBeSkipped = nil;

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet *tokenDelims = [NSCharacterSet whitespaceAndNewlineCharacterSet];

    NSInteger length = cifString.length;
    while (!scanner.isAtEnd) {
        // Skip whitespace
        [scanner scanCharactersFromSet:whitespace intoString:NULL];
        if (scanner.isAtEnd) break;

        unichar ch = [cifString characterAtIndex:scanner.scanLocation];

        // Comment
        if (ch == '#') {
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
            continue;
        }

        // Multi-line semicolon block
        if (ch == ';') {
            scanner.scanLocation = scanner.scanLocation + 1;
            NSString *block = nil;
            // Scan until next newline followed by semicolon
            NSRange restRange = NSMakeRange(scanner.scanLocation, length - scanner.scanLocation);
            NSRange endRange = [cifString rangeOfString:@"\n;" options:0 range:restRange];
            if (endRange.location != NSNotFound) {
                block = [cifString substringWithRange:NSMakeRange(scanner.scanLocation, endRange.location - scanner.scanLocation)];
                scanner.scanLocation = endRange.location + 2;
            } else {
                block = [cifString substringFromIndex:scanner.scanLocation];
                scanner.scanLocation = length;
            }
            [tokens addObject:[block stringByTrimmingCharactersInSet:whitespace]];
            continue;
        }

        // Quoted string '...' or "..."
        if (ch == '\'' || ch == '"') {
            unichar quote = ch;
            scanner.scanLocation = scanner.scanLocation + 1;
            NSInteger start = scanner.scanLocation;
            BOOL closed = NO;
            while (scanner.scanLocation < length) {
                if ([cifString characterAtIndex:scanner.scanLocation] == quote) {
                    closed = YES;
                    break;
                }
                scanner.scanLocation = scanner.scanLocation + 1;
            }
            NSString *token = [cifString substringWithRange:NSMakeRange(start, scanner.scanLocation - start)];
            if (closed) scanner.scanLocation = scanner.scanLocation + 1;
            [tokens addObject:token];
            continue;
        }

        // Standard token
        NSInteger start = scanner.scanLocation;
        while (scanner.scanLocation < length) {
            unichar c = [cifString characterAtIndex:scanner.scanLocation];
            if ([tokenDelims characterIsMember:c] || c == '#') {
                break;
            }
            scanner.scanLocation = scanner.scanLocation + 1;
        }
        if (scanner.scanLocation > start) {
            NSString *token = [cifString substringWithRange:NSMakeRange(start, scanner.scanLocation - start)];
            [tokens addObject:token];
        }
    }

    if (tokens.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"CIFParser" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No CIF tokens found"}];
        }
        return nil;
    }

    CrystalModel *model = [[CrystalModel alloc] init];
    model.sourceFormat = @"CIF";

    double cellA = 0, cellB = 0, cellC = 0;
    double alpha = 90, beta = 90, gamma = 90;
    NSString *formula = nil;
    NSString *spaceGroup = nil;
    NSString *title = nil;

    NSMutableArray<NSValue *> *symOps = [NSMutableArray array];
    NSMutableArray<CrystalAtom *> *asymAtoms = [NSMutableArray array];

    NSUInteger i = 0;
    NSUInteger numTokens = tokens.count;

    while (i < numTokens) {
        NSString *token = tokens[i];

        if ([token hasPrefix:@"data_"]) {
            if (!title) {
                title = [token substringFromIndex:5];
            }
            i++;
            continue;
        }

        if ([token isEqualToString:@"_cell_length_a"] && i + 1 < numTokens) {
            cellA = cleanNumericString(tokens[++i]);
        } else if ([token isEqualToString:@"_cell_length_b"] && i + 1 < numTokens) {
            cellB = cleanNumericString(tokens[++i]);
        } else if ([token isEqualToString:@"_cell_length_c"] && i + 1 < numTokens) {
            cellC = cleanNumericString(tokens[++i]);
        } else if ([token isEqualToString:@"_cell_angle_alpha"] && i + 1 < numTokens) {
            alpha = cleanNumericString(tokens[++i]);
        } else if ([token isEqualToString:@"_cell_angle_beta"] && i + 1 < numTokens) {
            beta = cleanNumericString(tokens[++i]);
        } else if ([token isEqualToString:@"_cell_angle_gamma"] && i + 1 < numTokens) {
            gamma = cleanNumericString(tokens[++i]);
        } else if (([token isEqualToString:@"_space_group_name_H-M_alt"] ||
                    [token isEqualToString:@"_symmetry_space_group_name_H-M"] ||
                    [token isEqualToString:@"_space_group.Patterson_name_h-m"]) && i + 1 < numTokens) {
            if (!spaceGroup || spaceGroup.length == 0) {
                spaceGroup = tokens[++i];
            } else {
                i++;
            }
        } else if (([token isEqualToString:@"_chemical_formula_sum"] ||
                    [token isEqualToString:@"_chemical_formula_structural"]) && i + 1 < numTokens) {
            formula = tokens[++i];
        } else if ([token isEqualToString:@"_chemical_name_systematic"] && i + 1 < numTokens) {
            if (!title) title = tokens[++i];
            else i++;
        } else if ([token isEqualToString:@"loop_"]) {
            i++;
            NSMutableArray<NSString *> *headers = [NSMutableArray array];
            while (i < numTokens && [tokens[i] hasPrefix:@"_"]) {
                [headers addObject:tokens[i]];
                i++;
            }

            NSUInteger ncols = headers.count;
            if (ncols == 0) continue;

            // Check if this is atom_site loop
            NSInteger symCol = -1, labelCol = -1, xCol = -1, yCol = -1, zCol = -1, occCol = -1;
            BOOL isAtomLoop = NO;

            for (NSUInteger c = 0; c < ncols; c++) {
                NSString *h = headers[c];
                if ([h isEqualToString:@"_atom_site_type_symbol"]) symCol = c;
                else if ([h isEqualToString:@"_atom_site_label"]) labelCol = c;
                else if ([h isEqualToString:@"_atom_site_fract_x"]) xCol = c;
                else if ([h isEqualToString:@"_atom_site_fract_y"]) yCol = c;
                else if ([h isEqualToString:@"_atom_site_fract_z"]) zCol = c;
                else if ([h isEqualToString:@"_atom_site_occupancy"]) occCol = c;
            }

            if (xCol >= 0 && yCol >= 0 && zCol >= 0 && (symCol >= 0 || labelCol >= 0)) {
                isAtomLoop = YES;
            }

            // Check if this is symmetry loop
            BOOL isSymLoop = NO;
            NSInteger symOpCol = -1;
            for (NSUInteger c = 0; c < ncols; c++) {
                NSString *h = headers[c];
                if ([h isEqualToString:@"_symmetry_equiv_pos_as_xyz"] ||
                    [h isEqualToString:@"_space_group_symop_operation_xyz"]) {
                    isSymLoop = YES;
                    symOpCol = c;
                    break;
                }
            }

            // Read rows
            while (i < numTokens && ![tokens[i] hasPrefix:@"_"] && ![tokens[i] isEqualToString:@"loop_"] && ![tokens[i] hasPrefix:@"data_"]) {
                if (i + ncols > numTokens) break;

                if (isAtomLoop) {
                    NSString *sym = (symCol >= 0) ? tokens[i + symCol] : nil;
                    NSString *label = (labelCol >= 0) ? tokens[i + labelCol] : nil;
                    if (!sym || sym.length == 0 || [sym isEqualToString:@"?"]) {
                        sym = label;
                    }
                    double x = cleanNumericString(tokens[i + xCol]);
                    double y = cleanNumericString(tokens[i + yCol]);
                    double z = cleanNumericString(tokens[i + zCol]);
                    double occ = (occCol >= 0) ? cleanNumericString(tokens[i + occCol]) : 1.0;

                    CrystalAtom *atom = [[CrystalAtom alloc] initWithSymbol:sym
                                                                      label:label
                                                                 fractional:Vector3DMake(x, y, z)];
                    atom.occupancy = (occ > 0.0) ? occ : 1.0;
                    [asymAtoms addObject:atom];
                } else if (isSymLoop) {
                    NSString *opStr = tokens[i + symOpCol];
                    SymOp op;
                    if (parseSymOp(opStr, &op)) {
                        NSValue *val = [NSValue valueWithBytes:&op objCType:@encode(SymOp)];
                        [symOps addObject:(id)val];
                    }
                }

                i += ncols;
            }
        } else {
            i++;
        }
    }

    if (cellA <= 0.0) cellA = 5.0;
    if (cellB <= 0.0) cellB = cellA;
    if (cellC <= 0.0) cellC = cellA;

    model.a = cellA;
    model.b = cellB;
    model.c = cellC;
    model.alpha = alpha;
    model.beta = beta;
    model.gamma = gamma;
    [model calculateVectorsFromParameters];

    model.title = title ?: formula ?: @"Crystal Structure";
    model.spaceGroup = spaceGroup;

    // Expand atoms using symmetry operations if available
    NSMutableArray<CrystalAtom *> *fullAtoms = [NSMutableArray array];
    if (symOps.count > 0 && asymAtoms.count > 0) {
        for (CrystalAtom *asym in asymAtoms) {
            for (NSValue *val in symOps) {
                SymOp op;
                [val getValue:&op];

                double x = asym.fractionalCoord.x;
                double y = asym.fractionalCoord.y;
                double z = asym.fractionalCoord.z;

                double nx = op.r[0][0]*x + op.r[0][1]*y + op.r[0][2]*z + op.t[0];
                double ny = op.r[1][0]*x + op.r[1][1]*y + op.r[1][2]*z + op.t[1];
                double nz = op.r[2][0]*x + op.r[2][1]*y + op.r[2][2]*z + op.t[2];

                // Wrap to [0, 1)
                nx = nx - floor(nx);
                ny = ny - floor(ny);
                nz = nz - floor(nz);

                // Check distance against already generated atoms in fullAtoms
                BOOL duplicate = NO;
                Vector3D cartNew = [model fractionalToCartesian:Vector3DMake(nx, ny, nz)];
                for (CrystalAtom *existing in fullAtoms) {
                    if ([existing.symbol isEqualToString:asym.symbol]) {
                        Vector3D d = Vector3DSub(existing.cartesianCoord, cartNew);
                        if (Vector3DLength(d) < 0.25) { // Duplicate within 0.25 Å
                            duplicate = YES;
                            break;
                        }
                    }
                }

                if (!duplicate) {
                    CrystalAtom *newAtom = [[CrystalAtom alloc] initWithSymbol:asym.symbol
                                                                         label:asym.label
                                                                    fractional:Vector3DMake(nx, ny, nz)];
                    newAtom.cartesianCoord = cartNew;
                    newAtom.occupancy = asym.occupancy;
                    [fullAtoms addObject:newAtom];
                }
            }
        }
    } else {
        [fullAtoms addObjectsFromArray:asymAtoms];
    }

    model.atoms = fullAtoms;
    [model updateCartesianCoordinates];
    [model populatePeriodicBoundaryAtoms];
    [model detectBonds];

    return model;
}

@end
