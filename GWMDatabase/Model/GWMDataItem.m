//
//  GWMDataItem.m
//  GWMKit
//
//  Created by Gregory Moore on 2/2/16.
//
//

#import "GWMDataItem.h"
#import "GWMDatabaseResult.h"
#import "GWMDatabaseController.h"

const NSInteger kGWMNewRecordValue = -1;
const NSInteger kGWMColumnSequenceItemClass = -2;
const NSInteger kGWMColumnSequenceItemId = -1;
const NSInteger kGWMColumnSequenceInserted = 1001;
const NSInteger kGWMColumnSequenceUpdated = 1002;

GWMColumnAffinity const GWMColumnAffinityText = @"TEXT";
GWMColumnAffinity const GWMColumnAffinityInteger = @"INTEGER";
GWMColumnAffinity const GWMColumnAffinityBoolean = @"BOOLEAN";
GWMColumnAffinity const GWMColumnAffinityReal = @"REAL";
GWMColumnAffinity const GWMColumnAffinityBlob = @"BLOB";
GWMColumnAffinity const GWMColumnAffinityNull = @"NULL";
GWMColumnAffinity const GWMColumnAffinityDateTime = @"DATE_TIME";
GWMColumnAffinity const GWMColumnAffinityHistoricDateTime = @"HISTORIC_DATE_TIME";

GWMColumnName const GWMTableColumnClass = @"class";
GWMColumnName const GWMTableColumnPkey = @"pKey";
GWMColumnName const GWMTableColumnName = @"name";
GWMColumnName const GWMTableColumnDescription = @"description";
GWMColumnName const GWMTableColumnInsertDate = @"insertDate";
GWMColumnName const GWMTableColumnUpdateDate = @"updateDate";

#pragma mark Error Domain
NSErrorDomain const GWMErrorDomainDataModel = @"GWMErrorDomainDataModel";

@implementation GWMDataItem

#pragma mark - GWMSearchableDataObject

//-(GWMDatabaseController *)databaseController
//{
//
//}
//
//-(NSString *)searchableStringWithObject:(GWMDataItem *)object
//{
//    return self.name;
//}
//
//-(NSString *)scopeStringKey
//{
//    return GWMTRV_ZeroLengthString;
//}
//
//-(BOOL)isInScope:(NSString *)scope
//{
//    return NO;
//}

#pragma mark - GWMCollationDataObject methods

//-(NSString *)alphabeticalCollationValue
//{
//    return [self collationTitle];
//}
//
//-(NSString *)collationTitle
//{
//    if ([self.name length] >= 4) {
//
//        NSString *string = [self.name substringToIndex:4];
//
//        if ([string isEqualToString:@"The "]) {
//
//            // Trim 'The ' from the beginning of the title
//            NSString *collationTitle = [self.name substringFromIndex:4];
//            return collationTitle;
//
//        } else {
//
//            return self.name;
//        }
//
//    } else {
//
//        return self.name;
//    }
//}
//
//-(NSString *)numericalCollationValue
//{
//    return [NSString stringWithFormat:@"%ld", (long)self.itemID];
//}
//
//-(NSComparisonResult)numericalCompare:(GWMDataItem *)item
//{
//    if (self.itemID < item.itemID){
//        return NSOrderedAscending;
//    } else if (self.itemID == item.itemID){
//        return NSOrderedSame;
//    } else {
//        return NSOrderedDescending;
//    }
//}

#pragma mark - Testing Equality

-(BOOL)isEqual:(GWMDataItem *)object
{
    if (![object isKindOfClass:[GWMDataItem class]] && ![object respondsToSelector:@selector(itemID)])
        return NO;
    
    return (self.itemID == object.itemID && [NSStringFromClass([object class]) isEqualToString:NSStringFromClass([self class])]);
}


#pragma mark - Life Cycle

+(instancetype)dataItemWithItemID:(NSInteger)itemID
{
    return [[self alloc] initWithItemID:itemID];
}

-(instancetype)init
{
    if (self = [super init]) {
        self.itemID = -1;
    }
    return self;
}

-(instancetype)initWithItemID:(NSInteger)itemID
{
    if (self = [super init]) {
        self.itemID = itemID;
    }
    return self;
}

+(instancetype)dataItemWithName:(NSString *)name
{
    return [[self alloc] initWithName:name];
}

-(instancetype)initWithName:(NSString *)name
{
    if (self = [super init]) {
        self.name = name;
    }
    return self;
}

#pragma mark - GWMDataItem methods

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
            NSDictionary<NSString*,NSString*> *columnToPropertyInfo = [[self class] tableColumnInfo];
            NSMutableDictionary *mutableValues = [NSMutableDictionary new];
            [columnToPropertyInfo enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull col, NSString *_Nonnull prop, BOOL *_Nonnull stop){
                if ([col isEqualToString:GWMTableColumnPkey] || [prop isEqualToString:GWMTableColumnClass])
                    return ;
                
                if ([self respondsToSelector:NSSelectorFromString(prop)]) {
                    id valueToInsert = [self valueForKey:prop];
                    if (valueToInsert != nil) {
                        mutableValues[col] = valueToInsert;
                    }
                }
                
            }];
            NSDictionary *values = [NSDictionary dictionaryWithDictionary:mutableValues];
            __block GWMColumnName primaryKeyColumn = nil;
            [[[self class] columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *col, NSUInteger idx, BOOL *stop){
                if (col.options &GWMColumnOptionPrimaryKey) {
                    primaryKeyColumn = col.name;
                    *stop = YES;
                }
            }];
            if (!primaryKeyColumn) {
                NSError *error = [NSError errorWithDomain:GWMErrorDomainDataModel code:0 userInfo:@{}];
                if(completion)
                    completion(kGWMNewRecordValue,error);
                return;
            }
            NSDictionary *criteria = @{primaryKeyColumn:@(self.itemID)};
            NSString *columns = [[[self class] tableColumns] componentsJoinedByString:@", "];
            NSString *tableAlias = [[self class] tableAlias];
            NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@ AS %@", columns,table, tableAlias];
            GWMDatabaseResult *result = [self.databaseController resultWithStatement:statement criteria:@[criteria] exclude:nil sortBy:nil ascending:YES limit:0 completion:nil];
            
            if (result.data.count > 0) {
                @try {
                    [self.databaseController updateTable:table withValues:values criteria:criteria onConflict:GWMDBOnConflictAbort completion:^(GWMDataItem *_Nullable itm, NSError *_Nullable err){
                        if(completion)
                            completion(itm.itemID,err);
                    }];
                } @catch (NSException *exception) {
                    NSLog(@"%@", exception);
                }
            } else {
                @try {
                    [self.databaseController insertIntoTable:table values:values completion:^(GWMDataItem *_Nullable itm, NSError *_Nullable err){
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
                    completion(kGWMNewRecordValue,error);
                return;
            }
            __block GWMColumnName primaryKeyColumn = nil;
            [[[self class] columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *col, NSUInteger idx, BOOL *stop){
                if (col.options &GWMColumnOptionPrimaryKey) {
                    primaryKeyColumn = col.name;
                    *stop = YES;
                }
            }];
            if (!primaryKeyColumn) {
                NSError *error = [NSError errorWithDomain:GWMErrorDomainDataModel code:0 userInfo:@{}];
                if(completion)
                    completion(kGWMNewRecordValue,error);
                return;
            }
            NSDictionary *criteria = @{primaryKeyColumn:@(self.itemID)};
            NSString *columns = [[[self class] tableColumns] componentsJoinedByString:@", "];
            NSString *tableAlias = [[self class] tableAlias];
            NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@ %@", columns,table, tableAlias];
            GWMDatabaseResult *result = [self.databaseController resultWithStatement:statement criteria:@[criteria] exclude:nil sortBy:nil ascending:YES limit:0 completion:nil];
            
            if (result.data.count > 0){
                @try {
                    [self.databaseController deleteFromTable:table criteria:@[criteria] completion:^(NSError *_Nullable err){
                        if(completion)
                            completion(kGWMNewRecordValue,err);
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

#pragma mark Table Column Info

+(NSArray<GWMColumnName>*)excludedColumns
{
    return nil;
}

+(NSDictionary<GWMColumnName,GWMColumnName>*)columnOverrideInfo
{
    return @{GWMTableColumnPkey:GWMTableColumnPkey,
             GWMTableColumnName:GWMTableColumnName,
             GWMTableColumnDescription:GWMTableColumnDescription,
             GWMTableColumnInsertDate:GWMTableColumnInsertDate,
             GWMTableColumnUpdateDate:GWMTableColumnUpdateDate};
}

+(NSArray<GWMColumnDefinition*>*)columnDefinitionItems
{
    GWMColumnInclusion includeInAll = GWMColumnIncludeInList | GWMColumnIncludeInDetail;
    return @[[GWMColumnDefinition columnDefinitionWithName:[NSString stringWithFormat:@"'%@'", NSStringFromClass([self class])]
                                                    affinity:nil
                                                defaultValue:nil
                                                    property:GWMTableColumnClass
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:kGWMColumnSequenceItemClass],
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnPkey
                                                    affinity:GWMColumnAffinityInteger
                                                defaultValue:nil
                                                    property:NSStringFromSelector(@selector(itemID))
                                                     include:includeInAll
                                                     options:GWMColumnOptionPrimaryKey | GWMColumnOptionAutoIncrement
                                                   className:NSStringFromClass([self class])
                                                  sequence:kGWMColumnSequenceItemId],
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnName
                                                    affinity:GWMColumnAffinityText
                                                defaultValue:nil
                                                    property:NSStringFromSelector(@selector(name))
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:1],
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnDescription
                                                    affinity:GWMColumnAffinityText
                                                defaultValue:nil
                                                    property:NSStringFromSelector(@selector(description))
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:2],
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnInsertDate
                                                    affinity:GWMColumnAffinityDateTime
                                                defaultValue:@"(datetime('now'))" property:NSStringFromSelector(@selector(inserted))
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:kGWMColumnSequenceInserted],
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnUpdateDate
                                                    affinity:GWMColumnAffinityDateTime
                                                defaultValue:nil
                                                    property:NSStringFromSelector(@selector(updated))
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:kGWMColumnSequenceUpdated]];
}

+(NSArray<GWMTableConstraintDefinition*>*)constraintDefinitionItems
{
    return @[[GWMTableConstraintDefinition tableConstraintWithName:@"un_DataItem_name" style:GWMConstraintUnique columns:@[GWMTableColumnName] referenceTable:nil referenceColumn:nil onConflict:GWMDBOnConflictRollback]];
}

+(NSArray<GWMIndexDefinition*>*)indexDefinitionItems
{
    return nil;
}

+(NSArray<GWMTriggerDefinition*>*)triggerDefinitionItems
{
    return nil;
}

+(NSDictionary<GWMColumnName,NSString*> *)tableColumnInfo
{
    NSMutableDictionary<GWMColumnName,NSString*> *mutableColumnInfo = [NSMutableDictionary new];
    
    [[self columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *col, NSUInteger idx, BOOL *stop){
        mutableColumnInfo[col.name] = col.property;
    }];
    
    return [NSDictionary dictionaryWithDictionary:mutableColumnInfo];
}

+(NSArray<GWMColumnName> *)tableColumns
{
    NSMutableArray<NSString*> *mutableColumnDefs = [NSMutableArray<NSString*> new];
    [[self columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        [mutableColumnDefs addObject:definition.selectString];
    }];
    return [NSArray<NSString*> arrayWithArray:mutableColumnDefs];
}

+(NSArray<GWMColumnName> *)listTableColumns
{
    NSMutableArray<NSString*> *mutableColumnDefs = [NSMutableArray<NSString*> new];
    [[self columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        if (definition.include &GWMColumnIncludeInList)
            [mutableColumnDefs addObject:definition.selectString];
    }];
    return [NSArray<NSString*> arrayWithArray:mutableColumnDefs];
}

+(NSArray<GWMColumnName> *)detailTableColumns
{
    NSMutableArray<NSString*> *mutableColumnDefs = [NSMutableArray<NSString*> new];
    [[self columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        if (definition.include &GWMColumnIncludeInDetail)
            [mutableColumnDefs addObject:definition.selectString];
    }];
    return [NSArray<NSString*> arrayWithArray:mutableColumnDefs];
}

-(NSString *)rowIdentifier
{
    return [NSString stringWithFormat:@"%li", (long)self.itemID];
}

-(void)setNeedsDataRefresh
{
    
}

-(BOOL)isSelectableInTableRow
{
    return NO;
}

-(NSString *)searchPlaceholderString
{
    return @"Search By Title Or Subtitle";
}

-(NSInteger)countOfRelatedItemsForKey:(NSString *)key
{
    id rawItems = [self valueForKey:key];
    
    if ([rawItems isKindOfClass:[NSArray class]]) {
        NSArray *itemsArray = (NSArray *)rawItems;
        return itemsArray.count;
    } else if ([rawItems isKindOfClass:[NSDictionary class]]){
        NSDictionary *itemsInfo = (NSDictionary *)rawItems;
        return itemsInfo.count;
    } else if ([rawItems isKindOfClass:[NSSet class]]) {
        NSSet *itemsSet = (NSSet *)rawItems;
        return itemsSet.count;
    }
    return 0;
}

-(BOOL)isNew
{
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    if ([self.addedInAppVersion isEqualToString:appVersionString]) {
        return YES;
    }
    
    return NO;
}

-(NSDictionary *)childDetailDataSelectors
{
    return  @{NSStringFromClass([GWMDataItem class]):NSStringFromSelector(@selector(subtitle))};
}

-(NSDictionary *)childDetailLandscapeDataSelectors
{
    return  [self childDetailDataSelectors];
}

@end
