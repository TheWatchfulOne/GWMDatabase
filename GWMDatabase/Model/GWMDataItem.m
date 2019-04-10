//
//  GWMDataItem.m
//  GWMKit
//
//  Created by Gregory Moore on 2/2/16.
//
//

#import "GWMDataItem.h"
#import "GWMConstants.h"
#import "GWMDetailTableViewModel.h"
#import "GWMDatabaseResult.h"

const NSInteger kGWMNewRecordValue = -1;
const NSInteger kGWMColumnSequenceItemClass = -2;
const NSInteger kGWMColumnSequenceItemId = -1;
const NSInteger kGWMColumnSequenceInserted = 1001;
const NSInteger kGWMColumnSequenceUpdated = 1002;

NSString * const GWMColumnAffinityText = @"TEXT";
NSString * const GWMColumnAffinityInteger = @"INTEGER";
NSString * const GWMColumnAffinityBoolean = @"BOOLEAN";
NSString * const GWMColumnAffinityReal = @"REAL";
NSString * const GWMColumnAffinityBlob = @"BLOB";
NSString * const GWMColumnAffinityNull = @"NULL";
NSString * const GWMColumnAffinityDateTime = @"DATE_TIME";
NSString * const GWMColumnAffinityHistoricDateTime = @"HISTORIC_DATE_TIME";

NSString * const GWMTableColumnClass = @"class";
NSString * const GWMTableColumnPkey = @"pKey";
NSString * const GWMTableColumnName = @"name";
NSString * const GWMTableColumnDescription = @"description";
NSString * const GWMTableColumnInserted = @"inserted";
NSString * const GWMTableColumnUpdated = @"updated";

#pragma mark Error Domain
NSString * const GWMErrorDomainDataModel = @"GWMErrorDomainDataModel";

@implementation GWMDataItem

#pragma mark - GWMSearchableDataObject

-(NSString *)searchableStringWithObject:(GWMDataItem *)object
{
    return self.name;
}

-(NSString *)scopeStringKey
{
    return GWMTRV_ZeroLengthString;
}

-(BOOL)isInScope:(NSString *)scope
{
    return NO;
}

#pragma mark - GWMCollationDataObject methods

-(NSString *)alphabeticalCollationValue
{
    return [self collationTitle];
}

-(NSString *)collationTitle
{
    if ([self.name length] >= 4) {
        
        NSString *string = [self.name substringToIndex:4];
        
        if ([string isEqualToString:@"The "]) {
            
            // Trim 'The ' from the beginning of the title
            NSString *collationTitle = [self.name substringFromIndex:4];
            return collationTitle;
            
        } else {
            
            return self.name;
        }
        
    } else {
        
        return self.name;
    }
}

-(NSString *)numericalCollationValue
{
    return [NSString stringWithFormat:@"%ld", (long)self.itemID];
}

-(NSComparisonResult)numericalCompare:(GWMDataItem *)item
{
    if (self.itemID < item.itemID){
        return NSOrderedAscending;
    } else if (self.itemID == item.itemID){
        return NSOrderedSame;
    } else {
        return NSOrderedDescending;
    }
}

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
            NSDictionary *criteria = @{GWMTableColumnPkey:@(self.itemID)};
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
            NSDictionary *criteria = @{GWMTableColumnPkey:@(self.itemID)};
            NSString *columns = [[[self class] tableColumns] componentsJoinedByString:@", "];
            NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@", columns,table];
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

+(NSArray<NSString*>*)excludedColumns
{
    return nil;
}

+(NSDictionary<NSString*,NSString*>*)columnOverrideInfo
{
    return @{GWMTableColumnPkey:GWMTableColumnPkey,
             GWMTableColumnName:GWMTableColumnName,
             GWMTableColumnDescription:GWMTableColumnDescription,
             GWMTableColumnInserted:GWMTableColumnInserted,
             GWMTableColumnUpdated:GWMTableColumnUpdated};
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
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnInserted
                                                    affinity:GWMColumnAffinityDateTime
                                                defaultValue:@"(datetime('now'))" property:NSStringFromSelector(@selector(inserted))
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:kGWMColumnSequenceInserted],
             [GWMColumnDefinition columnDefinitionWithName:GWMTableColumnUpdated
                                                    affinity:GWMColumnAffinityDateTime
                                                defaultValue:nil
                                                    property:NSStringFromSelector(@selector(updated))
                                                     include:includeInAll
                                                     options:GWMColumnOptionNone
                                                   className:NSStringFromClass([self class])
                                                  sequence:kGWMColumnSequenceUpdated]];
}

//+(NSDictionary<NSString*,NSString*> *_Nonnull)columnDefinitions
//{
//    return @{GWMTableColumnPkey:[NSString stringWithFormat:@"%@ %@ NOT NULL PRIMARY KEY AUTOINCREMENT",GWMColumnAffinityInteger,GWMTableColumnPkey],
//             GWMTableColumnName:[NSString stringWithFormat:@"%@ %@", GWMColumnAffinityText, GWMTableColumnName],
//             GWMTableColumnDescription:[NSString stringWithFormat:@"%@ %@", GWMColumnAffinityText,GWMTableColumnDescription],
//             GWMTableColumnInserted:[NSString stringWithFormat:@"%@ %@ DEFAULT (datetime('now'))", GWMColumnAffinityDateTime,GWMTableColumnInserted],
//             GWMTableColumnUpdated:[NSString stringWithFormat:@"%@ %@",GWMColumnAffinityDateTime,GWMTableColumnUpdated]};
//}

+(NSDictionary<NSString*,NSString*> *_Nullable)constraintDefinitions
{
    return nil;
}

+(NSArray<GWMTriggerDefinition*>*)triggerDefinitionItems
{
    return nil;
}

+(NSDictionary<NSString*,NSString*> *)tableColumnInfo
{
    return @{[NSString stringWithFormat:@"'%@'", NSStringFromClass([self class])]:GWMTableColumnClass,
             GWMTableColumnPkey:NSStringFromSelector(@selector(itemID)),
             GWMTableColumnName:NSStringFromSelector(@selector(name)),
             GWMTableColumnDescription:NSStringFromSelector(@selector(description)),
             GWMTableColumnInserted:NSStringFromSelector(@selector(inserted)),
             GWMTableColumnUpdated:NSStringFromSelector(@selector(updated))
    };
}

+(NSArray<NSString*> *)tableColumns
{
    NSMutableArray<NSString*> *mutableColumnDefs = [NSMutableArray<NSString*> new];
    [[self columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        [mutableColumnDefs addObject:definition.selectString];
    }];
    return [NSArray<NSString*> arrayWithArray:mutableColumnDefs];
}

+(NSArray<NSString*> *)listTableColumns
{
    NSMutableArray<NSString*> *mutableColumnDefs = [NSMutableArray<NSString*> new];
    [[self columnDefinitionItems] enumerateObjectsUsingBlock:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        if (definition.include &GWMColumnIncludeInList)
            [mutableColumnDefs addObject:definition.selectString];
    }];
    return [NSArray<NSString*> arrayWithArray:mutableColumnDefs];
}

+(NSArray<NSString*> *)detailTableColumns
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

-(__kindof GWMDetailTableViewModel *)detailViewModel
{
    return [GWMDetailTableViewModel viewModelWithDataItem:self];
}

-(UIImage *)mainImage
{
    return nil;
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

-(NSArray<UIMenuItem *> *)menuItems
{
    return @[];
}

-(NSArray<UITableViewRowAction *> *)tableRowActions
{
    return @[];
}

-(NSArray<UIContextualAction*>*)contextualActions  NS_AVAILABLE_IOS(11_0)
{
    return @[];
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
