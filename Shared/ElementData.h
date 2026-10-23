//
//  ElementData.h
//  CrystalQuickLook
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ElementStyle) {
    ElementStyleStandardCPK = 0,
    ElementStyleVESTA = 1
};

@interface ElementInfo : NSObject

@property (nonatomic, copy, readonly) NSString *symbol;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) NSInteger atomicNumber;
@property (nonatomic, strong, readonly) NSColor *color;        // Standard CPK
@property (nonatomic, strong, readonly) NSColor *vestaColor;   // VESTA compatible
@property (nonatomic, assign, readonly) double covalentRadius;     // in Angstroms
@property (nonatomic, assign, readonly) double vdwRadius;          // in Angstroms
@property (nonatomic, assign, readonly) double displayRadius;      // for 3D visualization

- (instancetype)initWithSymbol:(NSString *)symbol
                          name:(NSString *)name
                  atomicNumber:(NSInteger)atomicNumber
                         color:(NSColor *)color
                    vestaColor:(nullable NSColor *)vestaColor
                covalentRadius:(double)covalentRadius
                     vdwRadius:(double)vdwRadius;

- (NSColor *)colorForStyle:(ElementStyle)style;

@end

@interface ElementData : NSObject

+ (ElementInfo *)infoForSymbol:(NSString *)symbol;
+ (NSString *)cleanElementSymbol:(NSString *)rawLabel;

@end

NS_ASSUME_NONNULL_END
