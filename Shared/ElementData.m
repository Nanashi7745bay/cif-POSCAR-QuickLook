//
//  ElementData.m
//  CrystalQuickLook
//

#import "ElementData.h"

@implementation ElementInfo

- (instancetype)initWithSymbol:(NSString *)symbol
                          name:(NSString *)name
                  atomicNumber:(NSInteger)atomicNumber
                         color:(NSColor *)color
                    vestaColor:(nullable NSColor *)vestaColor
                covalentRadius:(double)covalentRadius
                     vdwRadius:(double)vdwRadius {
    self = [super init];
    if (self) {
        _symbol = [symbol copy];
        _name = [name copy];
        _atomicNumber = atomicNumber;
        _color = color;
        _vestaColor = vestaColor ?: color;
        _covalentRadius = covalentRadius;
        _vdwRadius = vdwRadius;
        // Display radius scaled for clear crystal visualization
        double r = (covalentRadius > 0.1) ? (covalentRadius * 0.45) : 0.4;
        if (r < 0.25) r = 0.25;
        if (r > 0.75) r = 0.75;
        _displayRadius = r;
    }
    return self;
}

- (NSColor *)colorForStyle:(ElementStyle)style {
    if (style == ElementStyleVESTA) {
        return _vestaColor;
    }
    return _color;
}

@end

static NSDictionary<NSString *, ElementInfo *> *sElementTable = nil;

@implementation ElementData

+ (void)initialize {
    if (self != [ElementData class]) return;

    NSMutableDictionary<NSString *, ElementInfo *> *dict = [NSMutableDictionary dictionary];

    #define DEF_ELEM(sym, n, num, r, g, b, vr, vg, vb, cov, vdw) \
        dict[[@sym lowercaseString]] = [[ElementInfo alloc] initWithSymbol:@sym \
                                                                      name:@n \
                                                              atomicNumber:num \
                                                                     color:[NSColor colorWithSRGBRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0] \
                                                                vestaColor:[NSColor colorWithSRGBRed:(vr)/255.0 green:(vg)/255.0 blue:(vb)/255.0 alpha:1.0] \
                                                            covalentRadius:cov \
                                                                 vdwRadius:vdw]

    // Period 1
    DEF_ELEM("H", "Hydrogen", 1, 255, 255, 255, 255, 255, 255, 0.31, 1.20);
    DEF_ELEM("He", "Helium", 2, 217, 255, 255, 217, 255, 255, 0.28, 1.40);

    // Period 2
    DEF_ELEM("Li", "Lithium", 3, 204, 128, 255, 128, 0, 255, 1.28, 1.82);
    DEF_ELEM("Be", "Beryllium", 4, 194, 255, 0, 194, 255, 0, 0.96, 1.53);
    DEF_ELEM("B", "Boron", 5, 255, 181, 181, 255, 181, 181, 0.84, 1.92);
    DEF_ELEM("C", "Carbon", 6, 120, 120, 120, 100, 100, 100, 0.76, 1.70);
    DEF_ELEM("N", "Nitrogen", 7, 48, 80, 248, 0, 0, 255, 0.71, 1.55);
    DEF_ELEM("O", "Oxygen", 8, 255, 13, 13, 255, 0, 0, 0.66, 1.52);
    DEF_ELEM("F", "Fluorine", 9, 144, 224, 80, 144, 224, 80, 0.57, 1.47);
    DEF_ELEM("Ne", "Neon", 10, 179, 227, 245, 179, 227, 245, 0.58, 1.54);

    // Period 3
    DEF_ELEM("Na", "Sodium", 11, 171, 92, 242, 171, 92, 242, 1.66, 2.27);
    DEF_ELEM("Mg", "Magnesium", 12, 138, 255, 0, 138, 255, 0, 1.41, 1.73);
    DEF_ELEM("Al", "Aluminium", 13, 191, 166, 166, 191, 166, 166, 1.21, 1.84);
    // VESTA Si is iconic Sky Blue / Cyan (40, 160, 220)
    DEF_ELEM("Si", "Silicon", 14, 240, 200, 160, 40, 160, 220, 1.11, 2.10);
    DEF_ELEM("P", "Phosphorus", 15, 255, 128, 0, 255, 128, 0, 1.07, 1.80);
    DEF_ELEM("S", "Sulfur", 16, 255, 255, 48, 255, 255, 0, 1.05, 1.80);
    DEF_ELEM("Cl", "Chlorine", 17, 31, 240, 31, 31, 240, 31, 1.02, 1.75);
    DEF_ELEM("Ar", "Argon", 18, 128, 209, 227, 128, 209, 227, 1.06, 1.88);

    // Period 4
    DEF_ELEM("K", "Potassium", 19, 143, 64, 212, 143, 64, 212, 2.03, 2.75);
    DEF_ELEM("Ca", "Calcium", 20, 61, 255, 0, 61, 255, 0, 1.76, 2.31);
    DEF_ELEM("Sc", "Scandium", 21, 230, 230, 230, 230, 230, 230, 1.70, 2.11);
    // VESTA Ti is iconic Cyan-Turquoise (77, 187, 213)
    DEF_ELEM("Ti", "Titanium", 22, 191, 194, 199, 77, 187, 213, 1.60, 2.15);
    DEF_ELEM("V", "Vanadium", 23, 166, 166, 171, 166, 166, 171, 1.53, 2.05);
    DEF_ELEM("Cr", "Chromium", 24, 138, 153, 199, 138, 153, 199, 1.39, 2.06);
    DEF_ELEM("Mn", "Manganese", 25, 156, 122, 199, 156, 122, 199, 1.39, 2.05);
    DEF_ELEM("Fe", "Iron", 26, 224, 102, 51, 224, 102, 51, 1.32, 2.04);
    DEF_ELEM("Co", "Cobalt", 27, 240, 144, 160, 240, 144, 160, 1.26, 2.00);
    DEF_ELEM("Ni", "Nickel", 28, 80, 208, 80, 80, 208, 80, 1.24, 1.97);
    DEF_ELEM("Cu", "Copper", 29, 200, 128, 51, 200, 128, 51, 1.32, 1.96);
    DEF_ELEM("Zn", "Zinc", 30, 125, 128, 176, 125, 128, 176, 1.22, 2.01);
    DEF_ELEM("Ga", "Gallium", 31, 194, 143, 143, 194, 143, 143, 1.22, 1.87);
    DEF_ELEM("Ge", "Germanium", 32, 102, 143, 143, 102, 143, 143, 1.20, 2.11);
    DEF_ELEM("As", "Arsenic", 33, 189, 128, 227, 189, 128, 227, 1.19, 1.85);
    DEF_ELEM("Se", "Selenium", 34, 255, 161, 0, 255, 161, 0, 1.20, 1.90);
    DEF_ELEM("Br", "Bromine", 35, 166, 41, 41, 166, 41, 41, 1.20, 1.85);
    DEF_ELEM("Kr", "Krypton", 36, 92, 184, 209, 92, 184, 209, 1.16, 2.02);

    // Period 5
    DEF_ELEM("Rb", "Rubidium", 37, 112, 46, 176, 112, 46, 176, 2.20, 3.03);
    DEF_ELEM("Sr", "Strontium", 38, 0, 255, 44, 0, 255, 44, 1.95, 2.49);
    DEF_ELEM("Y", "Yttrium", 39, 148, 255, 255, 148, 255, 255, 1.90, 2.32);
    DEF_ELEM("Zr", "Zirconium", 40, 148, 224, 224, 148, 224, 224, 1.75, 2.23);
    DEF_ELEM("Nb", "Niobium", 41, 115, 194, 201, 115, 194, 201, 1.64, 2.18);
    DEF_ELEM("Mo", "Molybdenum", 42, 84, 181, 181, 84, 181, 181, 1.54, 2.17);
    DEF_ELEM("Tc", "Technetium", 43, 59, 158, 158, 59, 158, 158, 1.47, 2.16);
    DEF_ELEM("Ru", "Ruthenium", 44, 36, 143, 143, 36, 143, 143, 1.46, 2.13);
    DEF_ELEM("Rh", "Rhodium", 45, 10, 125, 140, 10, 125, 140, 1.42, 2.10);
    DEF_ELEM("Pd", "Palladium", 46, 0, 105, 133, 0, 105, 133, 1.39, 2.10);
    DEF_ELEM("Ag", "Silver", 47, 192, 192, 192, 192, 192, 192, 1.45, 2.11);
    DEF_ELEM("Cd", "Cadmium", 48, 255, 217, 143, 255, 217, 143, 1.44, 2.18);
    DEF_ELEM("In", "Indium", 49, 166, 117, 115, 166, 117, 115, 1.42, 1.93);
    DEF_ELEM("Sn", "Tin", 50, 102, 128, 128, 102, 128, 128, 1.39, 2.17);
    DEF_ELEM("Sb", "Antimony", 51, 158, 99, 181, 158, 99, 181, 1.39, 2.06);
    DEF_ELEM("Te", "Tellurium", 52, 212, 122, 0, 212, 122, 0, 1.38, 2.06);
    DEF_ELEM("I", "Iodine", 53, 148, 0, 148, 148, 0, 148, 1.39, 1.98);
    DEF_ELEM("Xe", "Xenon", 54, 66, 158, 176, 66, 158, 176, 1.40, 2.16);

    // Period 6
    DEF_ELEM("Cs", "Caesium", 55, 87, 23, 143, 87, 23, 143, 2.44, 3.43);
    DEF_ELEM("Ba", "Barium", 56, 0, 201, 0, 0, 201, 0, 2.15, 2.68);
    DEF_ELEM("La", "Lanthanum", 57, 112, 212, 255, 112, 212, 255, 2.07, 2.43);
    DEF_ELEM("Ce", "Cerium", 58, 255, 255, 199, 255, 255, 199, 2.04, 2.42);
    DEF_ELEM("Pr", "Praseodymium", 59, 217, 255, 199, 217, 255, 199, 2.03, 2.40);
    DEF_ELEM("Nd", "Neodymium", 60, 199, 255, 199, 199, 255, 199, 2.01, 2.39);
    DEF_ELEM("Sm", "Samarium", 62, 143, 255, 199, 143, 255, 199, 1.98, 2.36);
    DEF_ELEM("Eu", "Europium", 63, 97, 255, 199, 97, 255, 199, 1.98, 2.35);
    DEF_ELEM("Gd", "Gadolinium", 64, 69, 255, 199, 69, 255, 199, 1.96, 2.34);
    DEF_ELEM("Tb", "Terbium", 65, 48, 255, 199, 48, 255, 199, 1.94, 2.33);
    DEF_ELEM("Dy", "Dysprosium", 66, 31, 255, 199, 31, 255, 199, 1.92, 2.31);
    DEF_ELEM("Ho", "Holmium", 67, 0, 255, 156, 0, 255, 156, 1.92, 2.30);
    DEF_ELEM("Er", "Erbium", 68, 0, 230, 117, 0, 230, 117, 1.89, 2.29);
    DEF_ELEM("Tm", "Thulium", 69, 0, 212, 82, 0, 212, 82, 1.90, 2.27);
    DEF_ELEM("Yb", "Ytterbium", 70, 0, 191, 56, 0, 191, 56, 1.87, 2.26);
    DEF_ELEM("Lu", "Lutetium", 71, 0, 171, 36, 0, 171, 36, 1.87, 2.24);
    DEF_ELEM("Hf", "Hafnium", 72, 77, 194, 255, 77, 194, 255, 1.75, 2.23);
    DEF_ELEM("Ta", "Tantalum", 73, 77, 166, 255, 77, 166, 255, 1.70, 2.22);
    DEF_ELEM("W", "Tungsten", 74, 33, 148, 214, 33, 148, 214, 1.62, 2.18);
    DEF_ELEM("Re", "Rhenium", 75, 38, 125, 171, 38, 125, 171, 1.51, 2.16);
    DEF_ELEM("Os", "Osmium", 76, 38, 102, 150, 38, 102, 150, 1.44, 2.16);
    DEF_ELEM("Ir", "Iridium", 77, 23, 84, 135, 23, 84, 135, 1.41, 2.13);
    DEF_ELEM("Pt", "Platinum", 78, 208, 208, 224, 208, 208, 224, 1.36, 2.13);
    DEF_ELEM("Au", "Gold", 79, 255, 209, 35, 255, 209, 35, 1.36, 2.14);
    DEF_ELEM("Hg", "Mercury", 80, 184, 184, 208, 184, 184, 208, 1.32, 2.23);
    DEF_ELEM("Tl", "Thallium", 81, 166, 84, 77, 166, 84, 77, 1.45, 1.96);
    DEF_ELEM("Pb", "Lead", 82, 87, 89, 97, 87, 89, 97, 1.46, 2.02);
    DEF_ELEM("Bi", "Bismuth", 83, 158, 79, 181, 158, 79, 181, 1.48, 2.07);

    // Period 7 & Actinides
    DEF_ELEM("Th", "Thorium", 90, 0, 186, 255, 0, 186, 255, 2.06, 2.45);
    DEF_ELEM("U", "Uranium", 92, 0, 143, 255, 0, 143, 255, 1.96, 2.41);

    #undef DEF_ELEM

    sElementTable = [dict copy];
}

+ (NSString *)cleanElementSymbol:(NSString *)rawLabel {
    if (!rawLabel || rawLabel.length == 0) return @"X";

    NSString *trimmed = [rawLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return @"X";

    NSMutableString *letters = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:c]) {
            [letters appendFormat:@"%C", c];
            if (letters.length >= 2) break;
        } else {
            if (letters.length > 0) break;
        }
    }

    if (letters.length == 0) return @"X";

    NSString *candidate2 = nil;
    if (letters.length >= 2) {
        candidate2 = [NSString stringWithFormat:@"%@%@",
                      [[letters substringToIndex:1] uppercaseString],
                      [[letters substringWithRange:NSMakeRange(1, 1)] lowercaseString]];
        if (sElementTable[[candidate2 lowercaseString]]) {
            return candidate2;
        }
    }

    NSString *candidate1 = [[letters substringToIndex:1] uppercaseString];
    if (sElementTable[[candidate1 lowercaseString]]) {
        return candidate1;
    }

    return candidate2 ?: candidate1;
}

+ (ElementInfo *)infoForSymbol:(NSString *)symbol {
    NSString *clean = [self cleanElementSymbol:symbol];
    ElementInfo *info = sElementTable[[clean lowercaseString]];
    if (!info) {
        NSUInteger hash = [clean hash];
        CGFloat r = ((hash & 0xFF0000) >> 16) / 255.0;
        CGFloat g = ((hash & 0x00FF00) >> 8) / 255.0;
        CGFloat b = (hash & 0x0000FF) / 255.0;
        NSColor *fallbackColor = [NSColor colorWithSRGBRed:r green:g blue:b alpha:1.0];
        info = [[ElementInfo alloc] initWithSymbol:clean
                                              name:clean
                                      atomicNumber:0
                                             color:fallbackColor
                                        vestaColor:fallbackColor
                                    covalentRadius:1.20
                                         vdwRadius:1.70];
    }
    return info;
}

@end
