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

@class GWMDatabaseController;
@class GWMDataItem;
/*!
 * @brief A block that will run after a database save operation.
 * @discussion If the save is successful, the itemID will be the value assigned from the database and the error will be nil. If there is an error, the itemID will be -1 and error will be an NSError object.
 * @param itemID The NSInteger identifier of the item if the save is successful.
 * @param error An NSError.
 */
typedef void (^GWMSaveDataItemCompletionBlock)(NSInteger itemID, NSError *_Nullable error);

/*!
 * GWMDataItem is a class that can represent a record in a SQLite table. It can be used as is or it can be subclassed.
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
 * @brief Tells the GWMDataItem object it needs to be refreshed.
 * @discussion Call this method if you want cause any data to be reread from the database.
 */
-(void)setNeedsDataRefresh;
/*!
 * @discussion Determines whether a row in the UITableView will be selectable
 * @return A boolean value
 */
-(BOOL)isSelectableInTableRow;
/*!
 * @brief Identifies the GWMDataItem in a UITableView or UICollectionView.
 * @return A NSString value.
 */
-(NSString *_Nullable)rowIdentifier;
-(NSString *_Nullable)title;
-(NSString *_Nullable)subtitle;
/*!
 * @brief Identifies the GWMDataItem in a SQLite database.
 * @discussion By default this property maps to the primary key column SQLite table.
 * @return A NSInteger value.
 */
-(NSInteger)itemID;
///@return An NSString value from the database.
-(NSString *_Nullable)name;
-(void)setName:(NSString *_Nullable)name;
///@return An NSString value from the database.
-(NSString *_Nullable)abstract;
-(void)setAbstract:(NSString *_Nullable)abstract;
/*!
 *@brief The date the record was inserted.
 *@return An NSDate value from the database.
 */
-(NSDate *_Nullable)inserted;
-(void)setInserted:(NSDate *_Nullable)inserted;
/*!
 *@brief The date the record was most recently updated.
 *@return An NSDate value from the database.
 */
-(NSDate *_Nullable)updated;
-(void)setUpdated:(NSDate *_Nullable)updated;
/*!
 * @brief Columns to exclude from SELECT, CREATE TABLE, and other SQLite statements.
 * @discussion Subclasses of GWMDataItem will inherit all the properties defined by GWMDataItem: itemID, name, abstract, inserted, updated. Subclasses that want to exclude any of these properties should override this method and return the properties that should be excluded. This does not stop subclasses from inheriting these properties, but it will cause the coresponding table columns from being included in any automatically created SQLite tables.
 * @return A NSArray of NSString objects.
 */
+(NSArray<NSString*>*_Nullable)excludedColumns;
/*!
 * @brief Replace table column names with more desirable table column names.
 * @discussion The default implementation of this method maps the old table column names to themselves. Subclasses that want to change any table column names should create a NSMutableDictionary from the result of calling super. Then replace the old column name with the new column name using the old column name as the key.
 * @return A NSDictionary object where the key is the old table column name and the value is the new table column name.
 */
+(NSDictionary<GWMColumnName,GWMColumnName>*)columnOverrideInfo;
/*!
 *@brief Used to create and select data from tables in a SQLite database.
 *@return An NSArray of GWMColumnDefinition objects.
 */
+(NSArray<GWMColumnDefinition*>*)columnDefinitionItems;
/*!
 *@brief Used to create table constraints in a SQLite database.
 *@discussion An NSArray of GWMTableConstraintDefinition items.
 *@return A NSArray object.
 */
+(NSArray<GWMTableConstraintDefinition*>*_Nullable)constraintDefinitionItems;
/*!
 *@brief Used to create indexes in a SQLite database.
 *@return An NSArray of GWMIndexDefinition objects.
 */
+(NSArray<GWMIndexDefinition*>*_Nullable)indexDefinitionItems;
/*!
 *@brief Used to create triggers in a SQLite database.
 *@return An NSArray of GWMTriggerDefinition objects.
 */
+(NSArray<GWMTriggerDefinition*>*_Nullable)triggerDefinitionItems;
/*!
 *@brief Column to property mappings.
 *@return An NSDictionary containing column to property mappings where the key is the table column and the value is the object property.
 */
+(NSDictionary<GWMColumnName,NSString*> *)tableColumnInfo;
///@return An NSArray of NSString objects derived from the tableColumnInfo method.
+(NSArray<GWMColumnName> *)tableColumns;
///@return An NSArray of NSString objects where each entry represents a desired table column when reading a list of GWMDataItems from the database.
+(NSArray<GWMColumnName> *)listTableColumns;
///@return An NSArray of NSString objects where each entry represents a desired table column when reading a detail of a single GWMDataItem from the database.
+(NSArray<GWMColumnName> *)detailTableColumns;
///@return An NSString representing the table represented by the class.
+(NSString *)tableString;
/*!
 *@brief Alias for a SQLite database table.
 *@discussion Custom subclasses of GWMDataItem should override this method and return the desired alias for the table represented by the subclass.
 *@return A NSString object.
 */
+(NSString *)tableAlias;
/*!
 * @param key An NSString representation of a property of the reciever whose return type is an NSArray, NSDictionary, or NSSet. Cannot be nil.
 * @return An NSInteger that tells the count of the collection.
 */
-(NSInteger)countOfRelatedItemsForKey:(NSString *)key;

-(NSString *_Nullable)searchPlaceholderString;
-(NSArray<NSString *> *_Nullable)searchScopeButtonTitles;

-(NSString *_Nullable)addedInAppVersion;
-(BOOL)isNew;

/*!
 * @return An NSDictionary of entries where the key is the class and the value is a NSString representation of the selector to use.
 */
-(NSDictionary<NSString*,NSString*> *)childDetailDataSelectors;
/*!
 * @return An NSDictionary of entries where the key is the class and the value is a NSString representation of the selector to use when the device is rotated to landscape.
 */
-(NSDictionary<NSString*,NSString*> *)childDetailLandscapeDataSelectors;
/*!
 * @brief Save the record represented by the receiver.
 * @discussion The first thing this method does is determine whether the record being saved already exists. For a GWMDataItem, the record is queried based on the itemID. For a GWMRelationshipItem, the record is queried based on the itemID and the relatedItemID.
 * @param destination The database to save to. Current choices are local and cloud.
 * @param completion A block that will run after the query has finished. The block takes an NSInteger and an NSError as arguments and returns void. This paramter can be nil.
 */
-(void)saveTo:(GWMReadWriteDestination)destination completion:(GWMSaveDataItemCompletionBlock _Nullable)completion;
/*!
 * @brief Delete the record represented by the receiver.
 * @discussion The first thing this method does is determine whether the record being saved already exists. For a GWMDataItem, the record is queried based on the itemID. For a GWMRelationshipItem, the record is queried based on the itemID and the relatedItemID.
 * @param destination The database to save to. Current choices are local and cloud.
 * @param completion A block that will run after the query has finished. The block takes an NSInteger and an NSError as arguments and returns void. This paramter can be nil.
 */
-(void)deleteFrom:(GWMReadWriteDestination)destination completion:(GWMSaveDataItemCompletionBlock _Nullable)completion;


@end


//@protocol GWMSearchableDataItem
//
//-(NSString *)searchableStringWithObject:(__kindof GWMDataItem *)object;
//-(NSString *)scopeStringKey;
//-(BOOL)isInScope:(NSString *)scope;
//
//@end

//@protocol GWMCollationDataItem
//
//-(NSString *)alphabeticalCollationValue;
//-(NSString *)numericalCollationValue;
//
//-(NSComparisonResult)numericalCompare:(__kindof GWMDataItem *)item;
//
//@end

extern const NSInteger kGWMNewRecordValue;
extern const NSInteger kGWMColumnSequenceItemClass;
extern const NSInteger kGWMColumnSequenceItemId;
extern const NSInteger kGWMColumnSequenceInserted;
extern const NSInteger kGWMColumnSequenceUpdated;
///@brief Represents the 'text' column affinity in a SQLite table.
extern GWMColumnAffinity const GWMColumnAffinityText;
///@brief Represents the 'integer' column affinity in a SQLite table.
extern GWMColumnAffinity const GWMColumnAffinityInteger;
///@brief Represents the 'real' column affinity in a SQLite table.
extern GWMColumnAffinity const GWMColumnAffinityReal;
///@brief Represents the 'blob' column affinity in a SQLite table.
extern GWMColumnAffinity const GWMColumnAffinityBlob;
///@brief Represents the 'null' column affinity in a SQLite table.
extern GWMColumnAffinity const GWMColumnAffinityNull;
/*!
 *@brief Represents the 'BOOLEAN' column affinity in a SQLite table.
 *@discussion SQLite does not have a true boolean data type, rather boolean values may be stored in the database as integers 0 (false) and 1 (true) or strings 'TRUE' and 'FALSE'. When GWMDatabase reads data from a column declared as a 'BOOLEAN', it will create a NSNumber object of type boolean to represent it.
 */
extern GWMColumnAffinity const GWMColumnAffinityBoolean;
/*!
 *@brief Represents the 'DATE_TIME' column affinity in a SQLite table.
 *@discussion SQLite does not have a true date/time datatype, rather dates are stored as text in ISO8601 strings. When GWMDatabase reads data from a column declared as a 'DATE_TIME', it will create a NSDate object to represent it. Currently, dates stored or read using GWMDatabase are assumed to be in UTC time.
 */
extern GWMColumnAffinity const GWMColumnAffinityDateTime;
/*!
 *@brief Represents the 'HISTORIC_DATE_TIME' column affinity in a SQLite table.
 *@discussion Dates stored as historic dates consist of
 */
extern GWMColumnAffinity const GWMColumnAffinityHistoricDateTime;
/*!
 *@brief Represents the 'class' column in a SQLite select statement.
 *@discussion The coresponding value is a NSString representation of the class that will be instantiated by the GWMDatabaseController. This column is a derived column, it is not used in table creation neither is the class value stored in any table.
 */
extern GWMColumnName const GWMTableColumnClass;
/*!
 *@brief Represents the 'pKey' column in a SQLite table.
 *@discussion This is currently the default primary key column of any table that coresponds to a GWMDataItem.
 */
extern GWMColumnName const GWMTableColumnPkey;
///@brief Represents the 'name' column in a SQLite table.
extern GWMColumnName const GWMTableColumnName;
///@brief Represents the 'description' column in a SQLite table.
extern GWMColumnName const GWMTableColumnDescription;
///@brief Represents the 'insertDate' column in a SQLite table.
extern GWMColumnName const GWMTableColumnInsertDate;
///@brief Represents the 'updateDate' column in a SQLite table.
extern GWMColumnName const GWMTableColumnUpdateDate;

#pragma mark Error Domain
extern NSErrorDomain const GWMErrorDomainDataModel;

/*!
 * @class GWMDataItem
 * @discussion A GWMDataItem object represents a row in a database table. This class is usable as is, but you might wish to create a custom subclass.
 */
@interface GWMDataItem : NSObject<GWMDataItem>

@property (nonatomic, readonly) GWMDatabaseController *databaseController;
/*!
 * @brief Identifies the GWMDataItem in a UITableView or UICollectionView.
 * @return A NSString value.
 */
@property (nonatomic, readonly) NSString *_Nullable rowIdentifier;

#pragma mark Table Column Properties
/*!
 * @brief Identifies the GWMDataItem in a SQLite database.
 * @discussion By default this property maps to the primary key column SQLite table.
 * @return A NSInteger value.
 */
@property (nonatomic, assign) NSInteger itemID;
///@discussion A NSString value.
@property (nonatomic, strong) NSString *_Nullable name;
///@discussion A NSString value.
@property (nonatomic, strong) NSString *_Nullable abstract;
/*!
 *@brief The date the record was inserted.
 *@return An NSDate value from the database.
 */
@property (nonatomic, strong) NSDate * _Nullable inserted;
/*!
 *@brief The date the record was most recently updated.
 *@return An NSDate value from the database.
 */
@property (nonatomic, strong) NSDate * _Nullable updated;

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
