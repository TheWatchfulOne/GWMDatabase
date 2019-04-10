//
//  GWMDataItem.h
//  GWMKit
//
//  Created by Gregory Moore on 2/2/16.
//
//

#import "GWMDatabaseHelperItems.h"

NS_ASSUME_NONNULL_BEGIN

@import CoreSpotlight;

typedef NS_ENUM(NSInteger, GWMReadWriteDestination) {
    GWMReadWriteLocal = 0,
    GWMReadWriteCloud
};

@class GWMViewController;
@class GWMViewModel;
@class GWMDetailTableViewModel;

typedef void (^GWMSaveDataItemCompletionBlock)(NSInteger itemID, NSError *_Nullable error);

/*!
 * Your documentation comment will go here.
 */
@protocol GWMDataItem
/*!
 * @discussion A class method for creating a GWMDataItem or subclass of GWMDataItem.
 * @param itemID The NSInteger used to determine which GWMDataItem to read from the database.
 * @return A GWMDataItem.
 */
+(instancetype)dataItemWithItemID:(NSInteger)itemID;
/*!
 * @discussion A class method for creating a GWMDataItem or subclass of GWMDataItem.
 * @param name A string used to determine which GWMDataItem to retrieve from the database.
 * @return A GWMDataItem
 */
+(instancetype)dataItemWithName:(NSString*)name;
/*!
 * @discussion Call this method if you want cause any data to be reread from the database.
 */
-(void)setNeedsDataRefresh;
/*!
 * @discussion Determines whether a row in the UITableView will be selectable
 * @return A boolean value
 */
-(BOOL)isSelectableInTableRow;
///@return An NSString that identifies the GWMDataItem in a UITableView.
-(NSString *_Nullable)rowIdentifier;
-(NSString *_Nullable)title;
-(NSString *_Nullable)subtitle;

///@return An NSInteger that identifies the GWMDataItem in a database.
-(NSInteger)itemID;
///@return An NSString value from the database.
-(NSString *_Nullable)name;
-(void)setName:(NSString *_Nullable)name;
///@return An NSString value from the database.
-(NSString *_Nullable)abstract;
-(void)setAbstract:(NSString *_Nullable)abstract;
///@return An NSDate value from the database. The date the record was inserted.
-(NSDate *_Nullable)inserted;
-(void)setInserted:(NSDate *_Nullable)inserted;
///@return An NSDate value from the database. The date the record was most recently updated.
-(NSDate *_Nullable)updated;
-(void)setUpdated:(NSDate *_Nullable)updated;
+(NSArray<NSString*>*_Nullable)excludedColumns;

+(NSDictionary<NSString*,NSString*>*)columnOverrideInfo;
+(NSArray<GWMColumnDefinition*>*)columnDefinitionItems;
///@return An NSDictionary containing SQLite table constraint definations where the key is the name of the constraint and the value is a string containing the details of the constraint.
+(NSDictionary<NSString*,NSString*> *_Nullable)constraintDefinitions;
+(NSArray<GWMTriggerDefinition*>*)triggerDefinitionItems;
///@return An NSDictionary containing column to property mappings where the key is the table column and the value is the object property.
+(NSDictionary<NSString*,NSString*> *)tableColumnInfo;
///@return An NSArray of NSString objects derived from the tableColumnInfo method.
+(NSArray<NSString*> *)tableColumns;
///@return An NSArray of NSString objects where each entry represents a desired table column when retrieving a list of GWMDataItems from the database.
+(NSArray<NSString*> *)listTableColumns;
///@return An NSArray of NSString objects where each entry represents a desired table column when retrieving a detail of a single GWMDataItem from the database.
+(NSArray<NSString*> *)detailTableColumns;
///@return An NSString representing the table represented by the class.
+(NSString *)tableString;
///@return An NSString representing the alias to use for the table represented by the class.
+(NSString *)tableAlias;

-(__kindof GWMViewModel *)detailViewModel;
///@return A UIImage.
-(UIImage *_Nullable)mainImage;
/*!
 * @param key An NSString representation of a property of the reciever whose return type is an NSArray, NSDictionary, or NSSet. Cannot be nil.
 * @return An NSInteger that tells the count of the collection.
 */
-(NSInteger)countOfRelatedItemsForKey:(NSString *)key;

-(NSString *_Nullable)searchPlaceholderString;
-(NSArray<NSString *> *_Nullable)searchScopeButtonTitles;
/*!
 * @return An NSArray of UIMenuItem objects that are specific to the receiver.
 */
-(NSArray<UIMenuItem *> *_Nullable)menuItems;
/*!
 * @return An NSArray of UITableViewRowAction objects that are specific to the receiver.
 */
-(NSArray<UITableViewRowAction *>*_Nullable)tableRowActions;
/*!
 * @return An NSArray of UIContextualAction objects that are specific to the receiver.
 * @availability iOS 11 and later
 */
-(NSArray<UIContextualAction *>*_Nullable)contextualActions NS_AVAILABLE_IOS(11_0);

-(NSString *_Nullable)addedInAppVersion;
-(BOOL)isNew;

-(GWMViewController *)detailViewController;

/*!
 * @return An NSDictionary of entries where the key is the class and the value is a NSString representation of the selector to use.
 */
-(NSDictionary<NSString*,NSString*> *)childDetailDataSelectors;
/*!
 * @return An NSDictionary of entries where the key is the class and the value is a NSString representation of the selector to use when the device is rotated to landscape.
 */
-(NSDictionary<NSString*,NSString*> *)childDetailLandscapeDataSelectors;

/*!
 * @discussion Save the record represented by the receiver.
 * @param destination The database to save to. Current choices are local and cloud.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)saveTo:(GWMReadWriteDestination)destination completion:(GWMSaveDataItemCompletionBlock _Nullable)completion;

/*!
 * @discussion Delete the record represented by the receiver.
 * @param destination The database to save to. Current choices are local and cloud.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)deleteFrom:(GWMReadWriteDestination)destination completion:(GWMSaveDataItemCompletionBlock _Nullable)completion;


@end


@protocol GWMSearchableDataItem

-(NSString *)searchableStringWithObject:(__kindof GWMDataItem *)object;
-(NSString *)scopeStringKey;
-(BOOL)isInScope:(NSString *)scope;

@end

@protocol GWMCollationDataItem

-(NSString *)alphabeticalCollationValue;
-(NSString *)numericalCollationValue;

-(NSComparisonResult)numericalCompare:(__kindof GWMDataItem *)item;

@end

extern const NSInteger kGWMNewRecordValue;
extern const NSInteger kGWMColumnSequenceItemClass;
extern const NSInteger kGWMColumnSequenceItemId;
extern const NSInteger kGWMColumnSequenceInserted;
extern const NSInteger kGWMColumnSequenceUpdated;

///@discussion An NSString representing the 'text' column affinity in a SQLite table.
extern NSString * const GWMColumnAffinityText;
///@discussion An NSString representing the 'integer' column affinity in a SQLite table.
extern NSString * const GWMColumnAffinityInteger;
///@discussion An NSString representing the 'real' column affinity in a SQLite table.
extern NSString * const GWMColumnAffinityReal;
///@discussion An NSString representing the 'blob' column affinity in a SQLite table.
extern NSString * const GWMColumnAffinityBlob;
///@discussion An NSString representing the 'null' column affinity in a SQLite table.
extern NSString * const GWMColumnAffinityNull;
///@discussion An NSString representing the 'BOOLEAN' column affinity in a SQLite table. SQLite does not have a true boolean data type, rather boolean values may be stored in the database as integers 0 (false) and 1 (true) or strings 'TRUE' and 'FALSE'. When GWMDatabase reads data from a column declared as a boolean, it will create a NSNumber object of type boolean to represent it.
extern NSString * const GWMColumnAffinityBoolean;
///@discussion An NSString representing the 'DATE_TIME' column affinity in a SQLite table. SQLite does not have a true date/time datatype, rather dates are stored as text in ISO8601 strings. When GWMDatabase reads data from a column declared as a date/time, it will create a NSDate object to represent it. Currently, dates stored or read using GWMDatabase are assumed to be in UTC time.
extern NSString * const GWMColumnAffinityDateTime;
///@discussion An NSString representing the 'HISTORIC_DATE_TIME' column affinity in a SQLite table.
extern NSString * const GWMColumnAffinityHistoricDateTime;

///@discussion An NSString representing the 'class' column in a SQLite select statement. The coresponding value is a NSString representation of the class that will be instantiated by the GWMDatabaseController.
extern NSString * const GWMTableColumnClass;
///@discussion An NSString representing the 'pKey' column in a SQLite table.
extern NSString * const GWMTableColumnPkey;
///@discussion An NSString representing the 'name' column in a SQLite table.
extern NSString * const GWMTableColumnName;
///@discussion An NSString representing the 'description' column in a SQLite table.
extern NSString * const GWMTableColumnDescription;
///@discussion An NSString representing the 'inserted' column in a SQLite table.
extern NSString * const GWMTableColumnInserted;
///@discussion An NSString representing the 'updated' column in a SQLite table.
extern NSString * const GWMTableColumnUpdated;

#pragma mark Error Domain
extern NSString * const GWMErrorDomainDataModel;

/*!
 * @class GWMDataItem
 * @discussion A GWMDataItem object represents a row in a database table. This class is usable as is, but you might wish to create a custom subclass.
 */
@interface GWMDataItem : NSObject<GWMDataItem, GWMSearchableDataItem, GWMCollationDataItem>

///@discussion An NSInteger that identifies the GWMDataItem in a UITableView.
@property (nonatomic, readonly) NSString *_Nullable rowIdentifier;
//@property (nonatomic, readonly) NSString *_Nullable title;
//@property (nonatomic, readonly) NSString *_Nullable subtitle;

#pragma mark Table Column Properties
///@discussion An NSInteger that identifies the GWMDataItem in a database.
@property (nonatomic, assign) NSInteger itemID;
///@discussion An NSString value from the database.
@property (nonatomic, strong) NSString *_Nullable name;
///@discussion An NSString value from the database.
@property (nonatomic, strong) NSString *_Nullable abstract;
///@discussion An NSDate value from the database. The date the record was inserted.
@property (nonatomic, strong) NSDate * _Nullable inserted;
///@discussion An NSDate value from the database. The date the record was most recently updated.
@property (nonatomic, strong) NSDate * _Nullable updated;

//@property (nonatomic, readonly) GWMDetailTableViewModel *detailLayout;

@property (nonatomic, readonly) NSArray<NSString *> *searchScopeButtonTitles;

@property (nonatomic, readonly) CSSearchableItemAttributeSet *_Nullable attributeSet;
@property (nonatomic, readonly) CSSearchableItem *_Nullable searchableItem;

///@discussion An NSString representation of the application version the record was added in.
@property (nonatomic, strong) NSString *_Nullable addedInAppVersion;
///@discussion A BOOL value indicating whether the record was added in the current application version.
@property (nonatomic, readonly) BOOL isNew;


#pragma mark Life Cycle
/*!
 * @discussion The designated initializer for returning a GWMDataItem or subclass of GWMDataItem.
 * @param itemID An NSInteger used to determine which GWMDataItem to retrieve from the database.
 * @return A GWMDataItem
 */
-(instancetype)initWithItemID:(NSInteger)itemID;
/*!
 * @discussion The designated initializer for returning a GWMDataItem or subclass of GWMDataItem.
 * @param name A string used to determine which GWMDataItem to retrieve from the database.
 * @return A GWMDataItem
 */
-(instancetype)initWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
