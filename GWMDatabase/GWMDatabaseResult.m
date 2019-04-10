//
//  GWMDatabaseResult.m
//  GWMKit
//
//  Created by Gregory Moore on 8/30/15.
//
//

#import "GWMDatabaseResult.h"

@implementation GWMDatabaseResult

-(NSMutableDictionary<NSNumber*,NSString*> *)errors
{
    if (!_errors) {
        _errors = [NSMutableDictionary<NSNumber*,NSString*> new];
    }
    return _errors;
}

@end
