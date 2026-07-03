#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void SBStartIL2CPPStringProbe(void);
BOOL SBIL2CPPRunReadyProbe(NSDictionary * __autoreleasing _Nullable * _Nullable detailsOut);
NSString * _Nullable SBIL2CPPCreateManagedStringRoundTrip(NSString *value,
                                                          NSDictionary * __autoreleasing _Nullable * _Nullable detailsOut);

NS_ASSUME_NONNULL_END
