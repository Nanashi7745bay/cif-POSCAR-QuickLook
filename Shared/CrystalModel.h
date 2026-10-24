//
//  CrystalModel.h
//  CrystalQuickLook
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import "ElementData.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    double x, y, z;
} Vector3D;

static inline Vector3D Vector3DMake(double x, double y, double z) {
    Vector3D v; v.x = x; v.y = y; v.z = z; return v;
}

static inline Vector3D Vector3DAdd(Vector3D a, Vector3D b) {
    return Vector3DMake(a.x + b.x, a.y + b.y, a.z + b.z);
}

static inline Vector3D Vector3DSub(Vector3D a, Vector3D b) {
    return Vector3DMake(a.x - b.x, a.y - b.y, a.z - b.z);
}

static inline Vector3D Vector3DScale(Vector3D v, double s) {
    return Vector3DMake(v.x * s, v.y * s, v.z * s);
}

static inline double Vector3DDot(Vector3D a, Vector3D b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

static inline double Vector3DLength(Vector3D v) {
    return sqrt(Vector3DDot(v, v));
}

static inline Vector3D Vector3DCross(Vector3D a, Vector3D b) {
    return Vector3DMake(a.y * b.z - a.z * b.y,
                        a.z * b.x - a.x * b.z,
                        a.x * b.y - a.y * b.x);
}

static inline Vector3D Vector3DNormalize(Vector3D v) {
    double len = Vector3DLength(v);
    if (len < 1e-12) return Vector3DMake(0, 0, 0);
    return Vector3DScale(v, 1.0 / len);
}

@interface CrystalAtom : NSObject <NSCopying>

@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, assign) Vector3D fractionalCoord;
@property (nonatomic, assign) Vector3D cartesianCoord;
@property (nonatomic, assign) double occupancy;
@property (nonatomic, strong) ElementInfo *elementInfo;
@property (nonatomic, assign) BOOL isPeriodicReplica;

- (instancetype)initWithSymbol:(NSString *)symbol
                         label:(NSString *)label
                    fractional:(Vector3D)fractional;

@end

@interface CrystalBond : NSObject

@property (nonatomic, strong) CrystalAtom *atom1;
@property (nonatomic, strong) CrystalAtom *atom2;
@property (nonatomic, assign) double length;

- (instancetype)initWithAtom1:(CrystalAtom *)atom1
                        atom2:(CrystalAtom *)atom2
                       length:(double)length;

@end

@interface CrystalModel : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *spaceGroup;
@property (nonatomic, copy) NSString *sourceFormat; // @"CIF" or @"POSCAR"

// Lattice parameters
@property (nonatomic, assign) double a;     // Length a (Å)
@property (nonatomic, assign) double b;     // Length b (Å)
@property (nonatomic, assign) double c;     // Length c (Å)
@property (nonatomic, assign) double alpha; // Angle alpha (deg)
@property (nonatomic, assign) double beta;  // Angle beta (deg)
@property (nonatomic, assign) double gamma; // Angle gamma (deg)
@property (nonatomic, assign) double volume;// Volume (Å^3)

// Lattice vectors
@property (nonatomic, assign) Vector3D vectorA;
@property (nonatomic, assign) Vector3D vectorB;
@property (nonatomic, assign) Vector3D vectorC;

@property (nonatomic, strong) NSMutableArray<CrystalAtom *> *atoms;
@property (nonatomic, strong) NSMutableArray<CrystalBond *> *bonds;

// Computed properties
- (NSString *)formattedFormula;
- (NSString *)summaryText;
- (Vector3D)unitCellCenter;
- (NSInteger)longestAxisIndex; // 0 for a, 1 for b, 2 for c
- (NSString *)longestAxisName;
- (SCNVector3)eulerAnglesForDepthAxis:(NSInteger)axisIndex;
- (SCNMatrix4)transformForDepthAxis:(NSInteger)axisIndex;
- (SCNMatrix4)classicIsometricTransform;

// Transformations
- (void)calculateVectorsFromParameters;
- (void)calculateParametersFromVectors;
- (Vector3D)fractionalToCartesian:(Vector3D)frac;
- (Vector3D)cartesianToFractional:(Vector3D)cart;
- (void)updateCartesianCoordinates;
- (void)populatePeriodicBoundaryAtoms;
- (void)detectBonds;

@end

NS_ASSUME_NONNULL_END
