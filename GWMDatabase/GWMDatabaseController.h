//
//  GWMDatabaseController.h
//  GWMKit
//
//  Created by Gregory Moore on 8/18/12.
//  Copyright (c) 2012 Gregory Moore All rights reserved.
//

@import Foundation;

@class GWMDataItem;
@class GWMDatabaseResult;
@class GWMTableDefinition;
@class GWMColumnDefinition;
@class GWMTriggerDefinition;
@class GWMForeignKeyIntegrityCheckItem;

#pragma mark - Data Types

typedef NS_ENUM (NSInteger, GWMDBDateStringLength) {
    GWMDBDateStringLengthDateTime = 19,
    GWMDBDateStringLengthShortDate = 10,
    GWMDBDateStringLengthYearMonth = 7,
    GWMDBDateStringLengthYearOnly = 4
};

typedef NS_ENUM (NSInteger, GWMDBOperationResult) {
    GWMDBOperationAlreadyOpen = 0,
    GWMDBOperationJustOpened,
    GWMDBOperationAlreadyClosed,
    GWMDBOperationJustClosed,
    GWMDBOperationUnableToOpen,
    GWMDBOperationUnableToClose
};

typedef NS_ENUM(NSInteger, GWMDBOnConflict) {
    GWMDBOnConflictRollback = 0,
    GWMDBOnConflictAbort,
    GWMDBOnConflictFail,
    GWMDBOnConflictIgnore,
    GWMDBOnConflictReplace
};

NS_ASSUME_NONNULL_BEGIN

/*!
 * @brief A block that runs on completion of some SQLite queries. Can be nil.
 */
typedef void (^GWMDBCompletionBlock)(void);
/*!
 * @brief A block that runs on completion of some SQLite queries. Can be nil.
 * @param error An NSError object that is generated if there was a problem.
 */
typedef void (^GWMDBErrorCompletionBlock)(NSError *_Nullable error);
/*!
 * @brief A block that runs on completion of some SQLite queries. Can be nil.
 * @param itm A GWMDataItem containing the itemID of the record that was just inserted or updated.
 * @param error An NSError object that is generated if there was a problem.
 */
typedef void(^GWMDatabaseResultBlock)(GWMDataItem *_Nullable itm, NSError *_Nullable error);
typedef void(^GWMBindValuesEnumerationBlock)(id value, NSUInteger idx, BOOL  *stop);

#pragma mark Notification Names
/*!
 *@brief Posted when data is updated or deleted in a database.
 *@discussion This notification has no userInfo dictionary.
 */
extern NSNotificationName const GWMDatabaseControllerDidUpdateDataNotification;
/*!
 *@brief Posted when user data will start to be migrated from one database to another.
 *@discussion This notification has no userInfo dictionary.
 */
extern NSNotificationName const GWMDatabaseControllerDidBeginUserDataMigrationNotification;
/*!
 *@brief Posted when user data has finished migrating from one database to another.
 *@discussion This notification has no userInfo dictionary.
 */
extern NSNotificationName const GWMDatabaseControllerDidFinishUserDataMigrationNotification;
#pragma mark Notification UserInfo Keys
/*!
 *@brief Key to retrieve the executed SQLite statement from the userInfo dictionary.
 *@discussion The value is a NSString.
 */
extern NSString * const GWMDBStatementKey;

#pragma mark Date & Time Strings
/*!
 *@brief Short date format.
 *@discussion The format is 'yyyy-MM-dd HH:mm:ss'.
 */
extern NSString * const GWMDBDateFormatDateTime;
/*!
 *@brief Short date format.
 *@discussion The format is 'yyyy-MM-dd'.
 */
extern NSString * const GWMDBDateFormatShortDate;
/*!
 *@brief Short date format.
 *@discussion The format is 'yyyy-MM'.
 */
extern NSString * const GWMDBDateFormatYearAndMonth;
/*!
 *@brief Short date format.
 *@discussion The format is 'yyyy'.
 */
extern NSString * const GWMDBDateFormatYear;

#pragma mark SQLite Error Strings
extern NSString * const GWMSQLiteErrorOpeningDatabase;
extern NSString * const GWMSQLiteErrorClosingDatabase;
extern NSString * const GWMSQLiteErrorPreparingStatement;
extern NSString * const GWMSQLiteErrorExecutingStatement;
extern NSString * const GWMSQLiteErrorBindingNullValue;
extern NSString * const GWMSQLiteErrorBindingTextValue;
extern NSString * const GWMSQLiteErrorBindingIntegerValue;
extern NSString * const GWMSQLiteErrorBindingDoubleValue;
extern NSString * const GWMSQLiteErrorSteppingToRow;
extern NSString * const GWMSQLiteErrorFinalizingStatement;

#pragma mark Error Domain
/*!
 *@brief The error domain for GWMDatabase.
 */
extern NSErrorDomain const GWMErrorDomainDatabase;

#pragma mark Exceptions
extern NSString * const GWMPreparingStatementException;
extern NSString * const GWMExecutingStatementException;
extern NSString * const GWMFinalizingStatementException;

#pragma mark Preferences
extern NSString * const GWMPK_MainDatabaseName;
extern NSString * const GWMPK_MainDatabaseExtension;
extern NSString * const GWMPK_UserDatabaseName;
extern NSString * const GWMPK_UserDatabaseAlias;
extern NSString * const GWMPK_VersionOfMainDatabase;
extern NSString * const GWMPK_VersionOfUserDatabase;
extern NSString * const GWMPK_UserDatabaseSchemaVersion;

/*!
 * @class GWMDatabaseController
 * @discussion A class that lets you interact with a SQLite database. GWMDatabaseController has methods for performing DML operations such as creating, reading, updating and deleting records from a SQLite database. Currently, you must use a SQLite editor for performing any DDL operations such as creating or droping tables.
 */
@interface GWMDatabaseController : NSObject
{
    NSDateFormatter *_dateFormatter;
    NSArray<NSString*> *_attachedDatabases;
}

@property (nonatomic, readonly) NSDateFormatter *dateFormatter;

@property (nonatomic, strong) NSString *_Nullable mainDatabaseName;
@property (nonatomic, strong) NSString *_Nullable mainDatabaseExtension;
///@discussion An NSDictionary where the key is an NSString representation of the class and the value is an NSString representation of the table.
@property (nonatomic, strong) NSDictionary<NSString*,NSString*> *_Nonnull classToTableMapping;

@property (nonatomic, strong) NSDictionary<NSString*,GWMTableDefinition*> *_Nonnull classToTableDefinitionMapping;

@property (nonatomic) BOOL foreignKeysEnabled;

+(instancetype)sharedController;

#pragma mark - SQLite Version
/*!
 * @discussion Returns the SQLite version.
 * @return An NSString stating the SQLite version.
 */
-(NSString *)sqliteVersion;
/*!
 * @discussion Returns the SQLite library version.
 * @return An NSString stating the SQLite library version.
 */
-(NSString *)sqliteLibraryVersion;

#pragma mark - Introspection
/*!
 * @discussion Returns the schema version (set using pragma) of the specified SQLite database.
 * @param databaseFilePath The file path where the database is located.
 * @param extension The file extension.
 * @return The int value from the SQLite database using the schema pragma.
 */
-(int)databaseVersionAtPath:(NSString *)databaseFilePath withExtension:(NSString *)extension;
/*!
 * @discussion Returns the schema version (set using pragma) of the specified SQLite database.
 * @param filePath The file path where the database is located.
 * @return The int value from the SQLite database using the schema pragma.
 */
-(int)databaseVersionAtFilePath:(NSString *)filePath;

-(NSArray<GWMDataItem*> *_Nonnull)databases;

#pragma mark - Maintenance

/*!
 * @discussion Runs the VACUUM command on the specified SQLite database.
 * @param schema The database on which to run the VACUUM command. Can be nil.
 */
-(void)vacuum:(NSString *_Nullable)schema;

/*!
 * @discussion Check the integrity of a SQLite database by running PRAGMA schema.integrity_check or PRAGMA schema.integrity_check(N) where N is the maximum number of errors to return.
 * @param schema The database in which to run the integrity check.
 * @param rowCount The maximum number of errors to return. Entering a value of 0 or less will cause maximum number of rows to be 100 which is the defualt in SQLite.
 * @return An NSArray of NSString objects, each representing a found error. If no errors are found, a single string, "ok" is returned. This method does not find foreign key errors.
 */
-(NSArray<NSString*> *)checkIntegrity:(NSString *_Nullable)schema rows:(NSInteger)rowCount;
/*!
 * @discussion Check the integrity of foreign keys in a SQLite database by running PRAGMA schema.foreign_key_check or PRAGMA schema.foreign_key_check(table-name) on the database.
 * @param schema The database in which to run the integrity check.
 * @param table The table for which to run the integrity check.
 * @return An NSArray of GWMForeignKeyIntegrityCheckItem objects.
 */
-(NSArray<GWMForeignKeyIntegrityCheckItem*> *)checkForeignKeysIntegrity:(NSString *_Nullable)schema table:(NSString *_Nullable)table;

#pragma mark - Connection
/*!
 * @discussion Uses an ATTACH statment to open an additional SQLite database.
 * @param databaseName The file name of the SQLite database to open.
 * @param alias The desired alias to be used to refer to the SQLite database.
 * @return A BOOL value indicating whether the statement execution was successful.
 */
-(BOOL)attachDatabase:(NSString *)databaseName alias:(NSString *)alias;
/*!
 * @discussion Uses an DETACH statment to close the specified SQLite database.
 * @param databaseName The alias name of the SQLite database to close.
 * @return A BOOL value indicating whether the statement execution was successful.
 */
-(BOOL)detachDatabase:(NSString *)databaseName;
-(GWMDBOperationResult)openDatabase:(NSString *)name extension:(NSString *)extension;
-(GWMDBOperationResult)closeDatabase;
-(BOOL)isDatabaseOpen;

#pragma mark - DDL Database Operations
/*!
 * @discussion Create a table in a SQLite database.
 * @param className A NSString representation of the class associated with the table to create.
 * @param schema The database in which to create the table.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)createTableWithClassName:(NSString *)className schema:(NSString *_Nullable)schema completion:(GWMDBCompletionBlock _Nullable)completion;

/*!
 * @discussion Create a table in a SQLite database.
 * @param tableName A NSString representation of the desired name of the table to create.
 * @param columnDefinitions A NSArray of GWMColumnDefinition objects.
 * @param constraintDefinitions A NSDictionary containing SQLite table constraint definations where the key is the name of the constraint and the value is a string containing the details of the constraint.
 * @param schema The database in which to create the table.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)createTable:(NSString *)tableName columns:(NSArray<GWMColumnDefinition*>*)columnDefinitions constraints:(NSDictionary<NSString*,NSString*>*)constraintDefinitions schema:(NSString *_Nullable)schema completion:(GWMDBCompletionBlock _Nullable)completion;

/*!
 * @discussion Drop a table from a SQLite database.
 * @param className A NSString representation of the class associated with the table to drop.
 * @param schema The database from which to create the table.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)dropTableWithClassName:(NSString *)className schema:(NSString *_Nullable)schema completion:(GWMDBCompletionBlock _Nullable)completion;

/*!
 * @discussion Drop a table from a SQLite database.
 * @param tableName A NSString representation of the class associated with the table to drop.
 * @param schema The database from which to create the table.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)dropTable:(NSString *)tableName schema:(NSString *_Nullable)schema completion:(GWMDBCompletionBlock _Nullable)completion;

/*!
 * @discussion Rename a table in a SQLite database.
 * @param oldName The name of the table to alter.
 * @param newName The desired new name for the table.
 * @param schema The database that contains the table to be renamed. Leaving this parameter nil will have the same result as inputing @"main".
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)renameTable:(NSString *)oldName newName:(NSString *)newName schema:(NSString *_Nullable)schema completion:(GWMDBErrorCompletionBlock _Nullable)completion;

/*!
 * @discussion Rename a column in a given table in a SQLite database.
 * @param oldName The name of the table column to alter.
 * @param newName The desired new name for the table column.
 * @param schema The database that contains the table column to be renamed. Leaving this parameter nil will have the same result as inputing @"main".
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)renameColumn:(NSString *)oldName newName:(NSString *)newName table:(NSString *)table schema:(NSString *_Nullable)schema completion:(GWMDBErrorCompletionBlock _Nullable)completion;

/*!
 * @discussion Add a column to a given table in a SQLite database.
 * @param columnDefinition A GWMColumnDefinition object that represents the table column to be added.
 * @param table The table to add the new column to.
 * @param schema The database that contains the table column to be renamed. Leaving this parameter nil will have the same result as inputing @"main".
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)addColumn:(GWMColumnDefinition *)columnDefinition toTable:(NSString *)table schema:(NSString *_Nullable)schema completion:(GWMDBErrorCompletionBlock _Nullable)completion;

/*!
 * @discussion Add a trigger to a given SQLite database.
 * @param triggerDefinition A GWMTriggerDefinition object that represents the trigger to be added.
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)createTrigger:(GWMTriggerDefinition*)triggerDefinition completion:(GWMDBCompletionBlock _Nullable)completion;

/*!
 * @discussion Drop a trigger from a given SQLite database.
 * @param trigger A NSString representation of the name of the trigger to drop.
 * @param schema The database that contains the table column to be renamed. Leaving this parameter nil will have the same result as inputing @"main".
 * @param completion A block that will run after the query has finished. This paramter can be nil.
 */
-(void)dropTrigger:(NSString*)trigger schema:(NSString*_Nullable)schema completion:(GWMDBCompletionBlock _Nullable)completion;

#pragma mark - CRUD Database Operations

#pragma mark Create

/*!
 * @discussion Insert multiple records into a SQLite database table with new values for columns that you specify.
 * @param table The name of the table to insert into. This parameter cannot be nil.
 * @param valuesToInsert An NSArray of NSDictionary values to insert where each dictionary represents a record to be inserted. Within each dictionary, the key is the table column and the value is the value to insert. Every dictionary must have the same number of entries and the keys must be in the same order. SQLite's binding functions are used to bind the values to the statement.
 * @param completionHandler A block that will run after the query has finished. This paramter can be nil.
 */
-(void)insertIntoTable:(NSString *)table newValues:(NSArray<NSDictionary<NSString *,id> *> *)valuesToInsert completion:(GWMDatabaseResultBlock _Nullable)completionHandler;

/*!
 * @discussion Insert records into a SQLite database table with new values for columns that you specify.
 * @param table The name of the table to insert into. This parameter cannot be nil.
 * @param values An NSDictionary of values to insert where the key is the table column and the value is the value to insert. SQLite's binding functions are used to bind the values to the statement.
 * @param completionHandler A block that will run after the query has finished. This paramter can be nil.
 */
-(void)insertIntoTable:(NSString *)table values:(NSDictionary<NSString*,id> *)values completion:(GWMDatabaseResultBlock _Nullable)completionHandler;
/*!
 * @discussion Insert a single record into a SQLite database table with new values for columns that you specify.
 * @param table The name of the table to insert into. This parameter cannot be nil.
 * @param values An NSDictionary of values to insert where the key is the table column and the value is the value to insert. SQLite's binding functions are used to bind the values to the statement.
 * @param onConflict The SQLite conflict resolution algorithm to use. GWMDBOnConflictAbort is the default.
 * @param completionHandler A block that will run after the query has finished. This paramter can be nil.
 */
-(void)insertIntoTable:(NSString *)table values:(NSDictionary<NSString*,id> *)values onConflict:(GWMDBOnConflict)onConflict completion:(GWMDatabaseResultBlock _Nullable)completionHandler;

-(void)insertWithStatement:(NSString *)statement values:(NSArray *)values completion:(GWMDBCompletionBlock _Nullable)completion;

#pragma mark Read
/*!
 * @discussion You use the returned GWMDatabaseResult object's data property to access an NSArray of data rows.
 * @param statement A SQLite statement string. The statement may or may not contain a WHERE clause. Using ? placeholders in the statement and passing in the actual match values in the criteria array will cause the database to SQLite's binding functions. This parameter cannot be nil.
 * @param criteria An NSArray containing the desired criteria values. It is up to the developer to make sure the number of values in the array matches the number of ? placeholders contained in the statement. This parameter can be nil.
 * @param completionHandler A block that will run after the query is finished. This parameter can be nil.
 * @return A GWMDatabaseResult object.
 */
-(GWMDatabaseResult *)resultWithStatement:(NSString *)statement criteria:(NSArray *_Nullable)criteria completion:(GWMDBCompletionBlock _Nullable)completionHandler;
/*!
 * @discussion You use the returned GWMDatabaseResult object's data property to access an NSArray of data rows.
 * @param statement A SQLite statement string. While it is possible to include a WHERE clause and criteria in the statement, it is recommened to pass criteria into the criteriaValues parameter. This will cause the database controller to add the WHERE clause to the statement for you. SQLite's binding functions will be used when the query is run. This parameter cannot be nil.
 * @param criteriaValues An NSArray of NSDictionary entries where the key is the name of the table column and the value is the value from the row to match against. Entries from different dictionaries will cause an OR comparison. Entries within the same dictionary will cause an AND comparison. This parameter can be nil.
 * @param excludedItems An NSArray of GWMDataItem objects that will be excluded from the query results.  This parameter can be nil.
 * @param sortBy The table column to use to sort the query results. This parameter can be nil.
 * @param ascending Enter NO to sort the query results in descending order.
 * @param limit An NSInteger to limit the number of result rows returned by the query. This uses SQLite LIMIT clause. Entering 0 means there is no limit.
 * @param completionHandler A block that will run after the query is finished. This parameter can be nil.
 * @return A GWMDatabaseResult object.
 */
-(GWMDatabaseResult *)resultWithStatement:(NSString *)statement criteria:(NSArray<NSDictionary<NSString*,id>*> *_Nullable)criteriaValues exclude:(NSArray<__kindof GWMDataItem*>*_Nullable)excludedItems sortBy:(NSString *_Nullable)sortBy ascending:(BOOL)ascending limit:(NSInteger) limit completion:(GWMDBCompletionBlock _Nullable)completionHandler;

#pragma mark Update
/*!
 * @discussion Update records in a SQLite database table with new values for columns that you specify.
 * @param tableName The name of the table to update. This parameter cannot be nil.
 * @param newValues An NSDictionary of values where the key is the table column to update and the value is the new value. This parameter cannot be nil.
 * @param criteria An NSDictionary of values where the key is the table column and the value is the value to match. The criteria determines which records will be updated. If left nil, every record will be updated with the values in the newValues parameter.
 * @param completionHandler A block of code that will run after the query has finished. Within this block, you have access to the record that was updated or an NSError if the query failed.
 * @return A GWMDatabaseResult object.
 * @code GWMDatabaseResult *result = [[GWMDatabaseController sharedController]] updateTable:@"MyTable" withValues:@{@"column":@"New string value"} criteria:@{@"column":@(123)} completion:^(GWMDataItem *_Nullable itm, NSError *_Nullable err){
     if (itm != nil) {
        // do something with the item
     } else if (err != nil) {
        // do something with the error
     }
 }];
 */
-(GWMDatabaseResult *)updateTable:(NSString *)tableName withValues:(NSDictionary<NSString*,NSObject*>*)newValues criteria:(NSDictionary<NSString*,NSObject*>*_Nullable)criteria completion:(GWMDatabaseResultBlock _Nullable)completionHandler;

/*!
 * @discussion Update records in a SQLite database table with new values for columns that you specify.
 * @param tableName The name of the table to update. This parameter cannot be nil.
 * @param newValues An NSDictionary of values where the key is the table column to update and the value is the new value. This parameter cannot be nil.
 * @param criteria An NSDictionary of values where the key is the table column and the value is the value to match. The criteria determines which records will be updated. If left nil, every record will be updated with the values in the newValues parameter.
 * @param onConflict The SQLite conflict resolution algorithm to use. GWMDBOnConflictAbort is the default.
 * @param completionHandler A block of code that will run after the query has finished. Within this block, you have access to the record that was updated or an NSError if the query failed.
 * @return A GWMDatabaseResult object.
 */
-(GWMDatabaseResult *)updateTable:(NSString *)tableName withValues:(NSDictionary<NSString*,NSObject*>*)newValues criteria:(NSDictionary<NSString*,NSObject*>*_Nullable)criteria onConflict:(GWMDBOnConflict)onConflict completion:(GWMDatabaseResultBlock _Nullable)completionHandler;

#pragma mark Delete
/*!
 * @discussion Delete one or more records from a SQLite table.
 * @param table The SQLite database table to delete from. This parameter cannot be nil.
 * @param criteria An NSArray of NSDictionary entries where the key is the name of the table column and the value is the value from the row to match against. Entries from different dictionaries will cause an OR comparison. Entries within the same dictionary will cause an AND comparison. This parameter can be nil.
 * @param completionHandler A block of code that will run after the query has finished. This parameter can be nil.
 * @warning If this method is called with nil criteria, all records in the specified table will be deleted.
 */
-(void)deleteFromTable:(NSString *)table criteria:(NSArray<NSDictionary<NSString*,NSObject*>*>*_Nullable)criteria completion:(GWMDBErrorCompletionBlock _Nullable)completionHandler;

#pragma mark - Convenience
/*!
 * @discussion Migrate data from a SQLite table to a different SQLite table.
 * @param fromTable The SQLite database table to migrate data from. This parameter cannot be nil.
 * @param fromSchema The SQLite schema that contains the table to migrate data from. This parameter can be nil.
 * @param toTable The SQLite database table to migrate data to. This parameter cannot be nil.
 * @param toSchema The SQLite schema that contains the table to migrate data to. This parameter can be nil.
 * @param columnInfo An NSDictionary where the key is the new column and the value is the old column. This parameter cannot be nil.
 * @param completionHandler A block of code that will run after the query has finished. The block takes one argument which is of type NSError. This parameter can be nil.
 */
-(void)migrateDataFromTable:(NSString *_Nonnull)fromTable fromSchema:(NSString*_Nullable)fromSchema toTable:(NSString *_Nonnull)toTable toSchema:(NSString*_Nullable)toSchema columns:(NSDictionary<NSString*,NSString*>*_Nonnull)columnInfo completion:(GWMDBErrorCompletionBlock _Nullable)completionHandler;

#pragma mark - Transactions

//int callback(void *arg, int argc, char **argv, char **colName);

-(BOOL)applyStatements:(NSArray<NSString*> *)statements identifier:(NSString *)identifier completion:(GWMDBCompletionBlock _Nullable)completion;

/*!
 * @discussion Get the count of records in a table in a SQLite database. This method does not return any rows, only the number of potential rows.
 * @param table The name of a table in a SQLite database.
 * @param column The name of a table column in a SQLite database.
 * @param criteria An NSArray of NSDictionary entries where the key is the name of the table column and the value is the value from the row to match against. Entries from different dictionaries will cause an OR comparison. Entries within the same dictionary will cause an AND comparison. This parameter can be nil.
 * @return An integer indicating a record count.
 */
-(NSInteger)countOfRecordsFromTable:(NSString *)table column:(NSString*)column criteria:(NSArray<NSDictionary*>*_Nullable)criteria;

/*!
 * @discussion Get the count of records in a table in a SQLite database. This method does not return any rows, only the number of potential rows.
 * @param statement A SQLite select statment. The result should have a single column of which the data type is an integer.
 * @return An integer indicating a record count.
 */
-(NSInteger)countOfRecordsWithStatment:(NSString *)statement;

@end

NS_ASSUME_NONNULL_END
