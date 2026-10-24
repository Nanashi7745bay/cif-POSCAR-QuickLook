//
//  CrystalModel.m
//  CrystalQuickLook
//

#import "CrystalModel.h"

@implementation CrystalAtom

- (instancetype)initWithSymbol:(NSString *)symbol
                         label:(NSString *)label
                    fractional:(Vector3D)fractional {
    self = [super init];
    if (self) {
        _symbol = [ElementData cleanElementSymbol:symbol];
        _label = [label copy] ?: _symbol;
        _fractionalCoord = fractional;
        _cartesianCoord = Vector3DMake(0, 0, 0);
        _occupancy = 1.0;
        _elementInfo = [ElementData infoForSymbol:_symbol];
        _isPeriodicReplica = NO;
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    CrystalAtom *copy = [[[self class] allocWithZone:zone] initWithSymbol:_symbol
                                                                    label:_label
                                                               fractional:_fractionalCoord];
    copy.cartesianCoord = _cartesianCoord;
    copy.occupancy = _occupancy;
    copy.elementInfo = _elementInfo;
    copy.isPeriodicReplica = _isPeriodicReplica;
    return copy;
}

@end

@implementation CrystalBond

- (instancetype)initWithAtom1:(CrystalAtom *)atom1
                        atom2:(CrystalAtom *)atom2
                       length:(double)length {
    self = [super init];
    if (self) {
        _atom1 = atom1;
        _atom2 = atom2;
        _length = length;
    }
    return self;
}

@end

@implementation CrystalModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _a = 1.0; _b = 1.0; _c = 1.0;
        _alpha = 90.0; _beta = 90.0; _gamma = 90.0;
        _volume = 1.0;
        _atoms = [NSMutableArray array];
        _bonds = [NSMutableArray array];
        _sourceFormat = @"Unknown";
    }
    return self;
}

- (Vector3D)fractionalToCartesian:(Vector3D)frac {
    Vector3D va = Vector3DScale(_vectorA, frac.x);
    Vector3D vb = Vector3DScale(_vectorB, frac.y);
    Vector3D vc = Vector3DScale(_vectorC, frac.z);
    return Vector3DAdd(Vector3DAdd(va, vb), vc);
}

- (Vector3D)cartesianToFractional:(Vector3D)cart {
    // Solve linear system: cart = M * frac using determinant / inverse
    double ax = _vectorA.x, ay = _vectorA.y, az = _vectorA.z;
    double bx = _vectorB.x, by = _vectorB.y, bz = _vectorB.z;
    double cx = _vectorC.x, cy = _vectorC.y, cz = _vectorC.z;

    double det = ax * (by * cz - bz * cy) -
                 ay * (bx * cz - bz * cx) +
                 az * (bx * cy - by * cx);

    if (fabs(det) < 1e-9) {
        return Vector3DMake(0, 0, 0);
    }

    double invDet = 1.0 / det;

    double u = ((by * cz - bz * cy) * cart.x + (bz * cx - bx * cz) * cart.y + (bx * cy - by * cx) * cart.z) * invDet;
    double v = ((cy * az - cz * ay) * cart.x + (cz * ax - cx * az) * cart.y + (cx * ay - cy * ax) * cart.z) * invDet;
    double w = ((ay * bz - az * by) * cart.x + (az * bx - ax * bz) * cart.y + (ax * by - ay * bx) * cart.z) * invDet;

    return Vector3DMake(u, v, w);
}

- (void)calculateVectorsFromParameters {
    double alphaRad = _alpha * M_PI / 180.0;
    double betaRad  = _beta  * M_PI / 180.0;
    double gammaRad = _gamma * M_PI / 180.0;

    double cosA = cos(alphaRad);
    double cosB = cos(betaRad);
    double cosG = cos(gammaRad);
    double sinG = sin(gammaRad);

    if (fabs(sinG) < 1e-6) sinG = 1e-6;

    double term = 1.0 - cosA*cosA - cosB*cosB - cosG*cosG + 2.0*cosA*cosB*cosG;
    double vFrac = (term > 0.0) ? sqrt(term) : 0.0;

    _vectorA = Vector3DMake(_a, 0.0, 0.0);
    _vectorB = Vector3DMake(_b * cosG, _b * sinG, 0.0);

    double cz = _c * vFrac / sinG;
    double cy = _c * (cosA - cosB * cosG) / sinG;
    double cx = _c * cosB;
    _vectorC = Vector3DMake(cx, cy, cz);

    _volume = _a * _b * _c * vFrac;
}

- (void)calculateParametersFromVectors {
    _a = Vector3DLength(_vectorA);
    _b = Vector3DLength(_vectorB);
    _c = Vector3DLength(_vectorC);

    if (_a > 1e-6 && _b > 1e-6) {
        double dotAB = Vector3DDot(_vectorA, _vectorB) / (_a * _b);
        dotAB = fmax(-1.0, fmin(1.0, dotAB));
        _gamma = acos(dotAB) * 180.0 / M_PI;
    } else {
        _gamma = 90.0;
    }

    if (_a > 1e-6 && _c > 1e-6) {
        double dotAC = Vector3DDot(_vectorA, _vectorC) / (_a * _c);
        dotAC = fmax(-1.0, fmin(1.0, dotAC));
        _beta = acos(dotAC) * 180.0 / M_PI;
    } else {
        _beta = 90.0;
    }

    if (_b > 1e-6 && _c > 1e-6) {
        double dotBC = Vector3DDot(_vectorB, _vectorC) / (_b * _c);
        dotBC = fmax(-1.0, fmin(1.0, dotBC));
        _alpha = acos(dotBC) * 180.0 / M_PI;
    } else {
        _alpha = 90.0;
    }

    // Scalar triple product: a . (b x c)
    Vector3D bCrossC = Vector3DMake(
        _vectorB.y * _vectorC.z - _vectorB.z * _vectorC.y,
        _vectorB.z * _vectorC.x - _vectorB.x * _vectorC.z,
        _vectorB.x * _vectorC.y - _vectorB.y * _vectorC.x
    );
    _volume = fabs(Vector3DDot(_vectorA, bCrossC));
}

- (void)updateCartesianCoordinates {
    for (CrystalAtom *atom in _atoms) {
        atom.cartesianCoord = [self fractionalToCartesian:atom.fractionalCoord];
    }
}

- (Vector3D)unitCellCenter {
    Vector3D sum = Vector3DAdd(Vector3DAdd(_vectorA, _vectorB), _vectorC);
    return Vector3DScale(sum, 0.5);
}

- (void)populatePeriodicBoundaryAtoms {
    // Collect original base atoms
    NSArray<CrystalAtom *> *baseAtoms = [NSArray arrayWithArray:_atoms];
    const double eps = 0.025; // Tolerance for boundary replication

    for (CrystalAtom *atom in baseAtoms) {
        Vector3D f = atom.fractionalCoord;

        // Bring within [0, 1) approximately
        double u = f.x - floor(f.x);
        double v = f.y - floor(f.y);
        double w = f.z - floor(f.z);

        // Check if on boundaries
        int uSteps[2] = {0, 0};
        int vSteps[2] = {0, 0};
        int wSteps[2] = {0, 0};

        uSteps[0] = 0; if (u < eps) uSteps[1] = 1;
        vSteps[0] = 0; if (v < eps) vSteps[1] = 1;
        wSteps[0] = 0; if (w < eps) wSteps[1] = 1;

        for (int i = 0; i <= (u < eps ? 1 : 0); i++) {
            for (int j = 0; j <= (v < eps ? 1 : 0); j++) {
                for (int k = 0; k <= (w < eps ? 1 : 0); k++) {
                    int du = uSteps[i];
                    int dv = vSteps[j];
                    int dw = wSteps[k];

                    if (du == 0 && dv == 0 && dw == 0) continue;

                    Vector3D repFrac = Vector3DMake(u + du, v + dv, w + dw);
                    CrystalAtom *replica = [atom copy];
                    replica.fractionalCoord = repFrac;
                    replica.cartesianCoord = [self fractionalToCartesian:repFrac];
                    replica.isPeriodicReplica = YES;
                    [_atoms addObject:replica];
                }
            }
        }
    }
}

- (void)detectBonds {
    [_bonds removeAllObjects];
    NSUInteger count = _atoms.count;
    if (count > 500) {
        // Limit bond detection for very large structures to preserve smooth performance
        return;
    }

    for (NSUInteger i = 0; i < count; i++) {
        CrystalAtom *a1 = _atoms[i];
        double r1 = a1.elementInfo.covalentRadius;

        for (NSUInteger j = i + 1; j < count; j++) {
            CrystalAtom *a2 = _atoms[j];
            double r2 = a2.elementInfo.covalentRadius;

            Vector3D diff = Vector3DSub(a1.cartesianCoord, a2.cartesianCoord);
            double dist = Vector3DLength(diff);

            // Bond distance condition: 0.4 Å <= d <= 1.25 * (r1 + r2)
            double maxDist = 1.25 * (r1 + r2);
            if (dist >= 0.4 && dist <= maxDist) {
                CrystalBond *bond = [[CrystalBond alloc] initWithAtom1:a1 atom2:a2 length:dist];
                [_bonds addObject:bond];
            }
        }
    }
}

static NSInteger gcd(NSInteger a, NSInteger b) {
    while (b != 0) {
        NSInteger t = b;
        b = a % b;
        a = t;
    }
    return a;
}

- (NSString *)formattedFormula {
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (CrystalAtom *atom in _atoms) {
        if (atom.isPeriodicReplica) continue; // Only count unique base atoms
        NSString *sym = atom.symbol ?: @"X";
        counts[sym] = @(counts[sym].integerValue + 1);
    }

    if (counts.count == 0) return _title ?: @"Unknown";

    // Compute GCD across all counts
    NSInteger g = 0;
    for (NSNumber *cnt in counts.allValues) {
        if (g == 0) g = cnt.integerValue;
        else g = gcd(g, cnt.integerValue);
    }
    if (g <= 0) g = 1;

    // Sort elements (Hill system or alphabetical)
    NSArray<NSString *> *sortedKeys = [counts.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *s1, NSString *s2) {
        if ([s1 isEqualToString:@"C"]) return NSOrderedAscending;
        if ([s2 isEqualToString:@"C"]) return NSOrderedDescending;
        if ([s1 isEqualToString:@"H"]) return NSOrderedAscending;
        if ([s2 isEqualToString:@"H"]) return NSOrderedDescending;
        return [s1 compare:s2];
    }];

    NSMutableString *formula = [NSMutableString string];
    for (NSString *sym in sortedKeys) {
        NSInteger reduced = counts[sym].integerValue / g;
        [formula appendString:sym];
        if (reduced > 1) {
            [formula appendFormat:@"%ld", (long)reduced];
        }
    }
    return formula;
}

- (NSString *)summaryText {
    NSMutableString *str = [NSMutableString string];
    if (_title.length > 0) {
        [str appendFormat:@"%@\n", _title];
    }
    [str appendFormat:@"Formula: %@\n", [self formattedFormula]];
    if (_spaceGroup.length > 0) {
        [str appendFormat:@"Space Group: %@\n", _spaceGroup];
    }
    [str appendFormat:@"Lattice: a=%.3f b=%.3f c=%.3f Å\n", _a, _b, _c];
    [str appendFormat:@"Angles:  α=%.2f° β=%.2f° γ=%.2f°\n", _alpha, _beta, _gamma];
    [str appendFormat:@"Volume:  %.2f Å³\n", _volume];

    NSUInteger baseCount = 0;
    for (CrystalAtom *a in _atoms) {
        if (!a.isPeriodicReplica) baseCount++;
    }
    [str appendFormat:@"Atoms:   %lu (unit cell: %lu)", (unsigned long)baseCount, (unsigned long)_atoms.count];
    return str;
}

- (NSInteger)longestAxisIndex {
    if (_a >= _b && _a >= _c) return 0;
    if (_b >= _a && _b >= _c) return 1;
    return 2;
}

- (NSString *)longestAxisName {
    NSInteger idx = [self longestAxisIndex];
    if (idx == 0) return @"a";
    if (idx == 1) return @"b";
    return @"c";
}

- (SCNVector3)eulerAnglesForDepthAxis:(NSInteger)axisIndex {
    switch (axisIndex) {
        case 0: // a-axis into depth
            return SCNVector3Make(-M_PI / 10.0, -M_PI / 2.0 + M_PI / 9.0, 0);
        case 1: // b-axis into depth
            return SCNVector3Make(M_PI / 2.0 - M_PI / 9.0, 0, M_PI / 10.0);
        case 2: // c-axis into depth
        default:
            return SCNVector3Make(-M_PI / 9.0, M_PI / 8.0, 0);
    }
}

@end
