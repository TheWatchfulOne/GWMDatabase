//
//  GWMRelationshipItem.m
//  GWMKit
//
//  Created by Gregory Moore on 4/26/18.
//  Copyright © 2018 Gregory Moore. All rights reserved.
//

#import "GWMRelationshipItem.h"
#import "GWMDatabaseResult.h"

NSString * const GWMTableColumnDataItemKey = @"itemKey";
NSString * const GWMTableColumnRelatedDataItemKey = @"relatedItemKey";
NSString * const GWMTableColumnRelationshipKey = @"relationshipKey";

@implementation GWMRelationshipItem

+(NSString*)tableAlias
{
    return @"LK";
}

+(NSDictionary<NSString*,NSString*>*)columnOverrideInfo
{
    NSMutableDictionary *mutableInfo = [NSMutableDictionary dictionaryWithDictionary:[super columnOverrideInfo]];
    [mutableInfo addEntriesFromDictionary:@{GWMTableColumnDataItemKey:GWMTableColumnDataItemKey,
                                            GWMTableColumnRelatedDataItemKey:GWMTableColumnRelatedDataItemKey,
                                            GWMTableColumnRelationshipKey:GWMTableColumnRelationshipKey}];
    return [NSDictionary dictionaryWithDictionary:mutableInfo];
}

#pragma mark Table Column Info

+(NSArray<NSString*>*)excludedColumns
{
    return @[GWMTableColumnName,
             GWMTableColumnDescription];
}

+(NSArray<GWMColumnDefinition*>*)columnDefinitionItems
{
    NSMutableArray<GWMColumnDefinition*> *mutableDefinitions = [NSMutableArray arrayWithArray:[super columnDefinitionItems]];
    NSDictionary *columnNameInfo = [[self class] columnOverrideInfo];
    [mutableDefinitions addObjectsFromArray:@[[GWMColumnDefinition columnDefinitionWithName:columnNameInfo[GWMTableColumnDataItemKey]
                                                                                   affinity:GWMColumnAffinityInteger defaultValue:nil
                                                                                   property:NSStringFromSelector(@selector(dataItemID))
                                                                                    include:GWMColumnIncludeInList
                                                                                    options:GWMColumnOptionNotNull
                                                                                  className:NSStringFromClass([self class])
                                                                                   sequence:3],
                                          [GWMColumnDefinition columnDefinitionWithName:columnNameInfo[GWMTableColumnRelatedDataItemKey]
                                                                               affinity:GWMColumnAffinityInteger defaultValue:nil
                                                                               property:NSStringFromSelector(@selector(relatedDataItemID))
                                                                                include:GWMColumnIncludeInList
                                                                                options:GWMColumnOptionNotNull
                                                                              className:NSStringFromClass([self class])
                                                                               sequence:4],
                                              [GWMColumnDefinition columnDefinitionWithName:columnNameInfo[GWMTableColumnRelationshipKey]
                                                                                   affinity:GWMColumnAffinityInteger defaultValue:nil
                                                                                   property:NSStringFromSelector(@selector(relationshipID))
                                                                                    include:GWMColumnIncludeInList options:GWMColumnOptionNone
                                                                                  className:NSStringFromClass([self class])
                                                                                   sequence:5]]];
    NSArray *definitions = [NSArray arrayWithArray:mutableDefinitions];
    NSIndexSet *definitionsToRemove = [definitions indexesOfObjectsPassingTest:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        
        return [[self excludedColumns] containsObject:definition.name];
    }];
    
    [mutableDefinitions removeObjectsAtIndexes:definitionsToRemove];
    
    return [NSArray arrayWithArray:mutableDefinitions];
}

+(NSDictionary<NSString*,NSString*> *)tableColumnInfo
{
    NSMutableDictionary *mutableInfo = [NSMutableDictionary dictionaryWithDictionary:[super tableColumnInfo]];
    
    mutableInfo[GWMTableColumnDataItemKey] = NSStringFromSelector(@selector(dataItemID));
    mutableInfo[GWMTableColumnRelatedDataItemKey] = NSStringFromSelector(@selector(relatedDataItemID));
    mutableInfo[GWMTableColumnRelationshipKey] = NSStringFromSelector(@selector(relationshipID));
    mutableInfo[GWMTableColumnName] = nil;
    mutableInfo[GWMTableColumnDescription] = nil;
    return [NSDictionary dictionaryWithDictionary:mutableInfo];
}

#pragma mark Save Record Changes

-(void)saveTo:(GWMReadWriteDestination)destination completion:(GWMSaveDataItemCompletionBlock _Nullable)completion
{
    switch (destination) {
        case GWMReadWriteLocal:
        {
            // determine if record exists
            NSString *table = self.databaseController.classToTableMapping[NSStringFromClass([self class])];
            if (!table) {
                NSError *error = [NSError errorWithDomain:GWMErrorDomainDataModel code:0 userInfo:@{}];
                if(completion)
                    completion(kGWMNewRecordValue,error);
                return;
            }
            NSDictionary *overrideInfo = [[self class] columnOverrideInfo];
            NSDictionary<NSString*,id> *values = @{overrideInfo[GWMTableColumnDataItemKey]:@(self.dataItemID),
                                     overrideInfo[GWMTableColumnRelatedDataItemKey]:@(self.relatedDataItemID),
                                     overrideInfo[GWMTableColumnRelationshipKey]:@(self.relationshipID)};
            NSArray *excluded = [[self class] excludedColumns];
            NSMutableDictionary *mutableValues = [NSMutableDictionary new];
            [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop){
                if (![excluded containsObject:key])
                    mutableValues[key] = obj;
            }];
            NSDictionary *finalValues = [NSDictionary dictionaryWithDictionary:mutableValues];
            NSDictionary *criteria = @{overrideInfo[GWMTableColumnDataItemKey]:@(self.dataItemID),
                                       overrideInfo[GWMTableColumnRelatedDataItemKey]:@(self.relatedDataItemID)};
            NSString *columns = [[[self class] tableColumns] componentsJoinedByString:@", "];
            NSString *tableString = [NSString stringWithFormat:@"%@ %@",table,[[self class] tableAlias]];
            NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@", columns,tableString];
            GWMDatabaseResult *result = [self.databaseController resultWithStatement:statement criteria:@[criteria] exclude:nil sortBy:nil ascending:YES limit:0 completion:nil];
            
            if (result.data.count > 0) {
                @try {
                    [self.databaseController updateTable:table withValues:finalValues criteria:criteria onConflict:GWMDBOnConflictAbort completion:^(GWMDataItem *itm, NSError *err){
                        if(completion)
                            completion(itm.itemID,err);
                    }];
                } @catch (NSException *exception) {
                    NSLog(@"%@", exception);
                }
            } else {
                @try {
                    [self.databaseController insertIntoTable:table values:finalValues completion:^(GWMDataItem *itm, NSError *err){
                        if(completion)
                            completion(itm.itemID,err);
                    }];
                } @catch (NSException *exception) {
                    NSLog(@"%@", exception);
                }
            }
            break;
        }
        case GWMReadWriteCloud:
        {
            break;
        }
        default:
            break;
    }
    
}

-(void)deleteFrom:(GWMReadWriteDestination)destination completion:(GWMSaveDataItemCompletionBlock)completion
{
    switch (destination) {
        case GWMReadWriteLocal:
        {
            // determine if record exists
            NSString *table = self.databaseController.classToTableMapping[NSStringFromClass([self class])];
            if (!table) {
                NSError *error = [NSError errorWithDomain:GWMErrorDomainDataModel code:0 userInfo:@{}];
                if(completion)
                    completion(kGWMNewRecordValue, error);
                return;
            }
            NSDictionary *criteria = @{GWMTableColumnDataItemKey:@(self.dataItemID),
                                       GWMTableColumnRelatedDataItemKey:@(self.relatedDataItemID)};
            NSString *columns = [[[self class] tableColumns] componentsJoinedByString:@", "];
            NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@", columns,table];
            GWMDatabaseResult *result = [self.databaseController resultWithStatement:statement criteria:@[criteria] exclude:nil sortBy:nil ascending:YES limit:0 completion:nil];
//            [self.databaseController deleteFromTable:table criteria:@[criteria] completion:^{
//                NSLog(@"*** Record was deleted?" ***);
//            }];
            
            if (result.data.count > 0){
                @try {
                    [self.databaseController deleteFromTable:table criteria:@[criteria] completion:nil];
                } @catch (NSException *exception) {
                    NSLog(@"%@", exception);
                }
            }
            break;
        }
        case GWMReadWriteCloud:
        {
            break;
        }
        default:
            break;
    }
    if(completion)
        completion(self.itemID, nil);
}


@end
