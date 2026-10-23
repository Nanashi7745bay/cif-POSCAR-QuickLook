//
//  POSCARParser.h
//  CrystalQuickLook
//

#import <Foundation/Foundation.h>
#import "CrystalModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface POSCARParser : NSObject

+ (nullable CrystalModel *)parseFileAtURL:(NSURL *)url error:(NSError * _Nullable *)error;
+ (nullable CrystalModel *)parseString:(NSString *)poscarString error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
