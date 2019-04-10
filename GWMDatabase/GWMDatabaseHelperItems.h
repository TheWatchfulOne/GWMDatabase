//
//  GWMDatabaseHelperItems.h
//  GWMKit
//
//  Created by Gregory Moore on 11/16/18.
//  Copyright © 2018 Gregory Moore. All rights reserved.
//

@import Foundation;

typedef NS_OPTIONS(NSInteger, GWMColumnOption) {
    GWMColumnOptionNone = 0,
    GWMColumnOptionNotNull = 1 << 0,
    GWMColumnOptionPrimaryKey= 1 << 1,
    GWMColumnOptionAutoIncrement= 1 << 2
};

typedef NS_OPTIONS(NSInteger, GWMColumnInclusion) {
    GWMColumnIncludeInList = 1 << 0,
    GWMColumnIncludeInDetail= 1 << 1
};

typedef NS_ENUM(NSInteger, GWMTriggerTiming) {
    GWMTriggerBefore = 0,
    GWMTriggerAfter,
    GWMTriggerInsteadOf,
    GWMTriggerUnspecified
};

typedef NS_ENUM(NSInteger, GWMTriggerStyle) {
    GWMTriggerInsert = 0,
    GWMTriggerUpdate,
    GWMTriggerDelete
};

typedef NS_ENUM(NSInteger, GWMConstraintStyle) {
    GWMConstraintPrimaryKey = 0,
    GWMConstraintUnique,
    GWMConstraintCheck,
    GWMConstraintForeignKey
};

NS_ASSUME_NONNULL_BEGIN

/*!
 * @class GWMWhereClauseItem
 * @discussion A class that contains the result of processing criteria columns and values to be used in a SQLite select statement.
 */
@interface GWMWhereClauseItem : NSObject

///@discussion The where clause of a SQLite select statement with binding placeholders inserted.
@property (nonatomic, strong) NSString *whereClause;
///@discussion A NSArray containing the criteria values that will be bound when the statemnt is run.
@property (nonatomic, strong) NSArray *whereValues;

@end

/*!
 * @class GWMColumnDefinition
 * @discussion An instance of GWMColumnDefinition contains information about the declaration of a SQLite table column as well as which object property the column will map to.
 */
@interface GWMColumnDefinition : NSObject

@property (nonatomic, readonly) NSString *className;
///@discussion An NSString representation of a column name in a SQLite table.
@property (nonatomic, readonly) NSString *name;
///@discussion An NSString representation of the affinity of a column in a SQLite table. Natively, SQLite supports datatypes of Integer, Text, Real, Blob, and Null. GWMDatabase adds affinity for Boolean and Date/Time. Constants are provided for all affinities. This property can be nil.
@property (nonatomic, readonly) NSString *_Nullable affinity;
///@discussion An NSString representation of the default value of the column in the SQLite database. Can be nil.
@property (nonatomic, readonly) NSString *_Nullable defaultValue;
///@discussion An NSString representation of the object property the column maps to.
@property (nonatomic, readonly) NSString *property;
///@discussion A bitmask of column options for the column definition.
@property (nonatomic, readonly) GWMColumnOption options;
///@discussion GWMDatabase assumes we are querying for a list of items or the details of an item. The column can be inluded in a list or detail or both.
@property (nonatomic, readonly) GWMColumnInclusion include;
///@discussion An NSInteger that wil be used to determine the order the columns will appear in the table.
@property (nonatomic, assign) NSInteger sequence;
///@discussion An NSString substring that will be used to build a SQLite CREATE TABLE statement. Returns nil if the property name equals 'class'
@property (nonatomic, readonly) NSString *_Nullable createString;
///@discussion An NSString substring that will be used to build a SQLite SELECT statement.
@property (nonatomic, readonly) NSString *selectString;

+(instancetype)columnDefinitionWithName:(NSString*)name affinity:(NSString *_Nullable)affinity defaultValue:(NSString *_Nullable)defaultValue property:(NSString *)property include:(GWMColumnInclusion)include options:(GWMColumnOption)options className:(NSString *_Nullable)className sequence:(NSInteger)sequence;

-(instancetype)initWithName:(NSString*)name affinity:(NSString *_Nullable)affinity defaultValue:(NSString *_Nullable)defaultValue property:(NSString *)property include:(GWMColumnInclusion)include options:(GWMColumnOption)options className:(NSString *_Nullable)className sequence:(NSInteger)sequence;

@end

/*!
 * @class GWMTableConstraintDefinition
 * @discussion An instance of GWMTableConstraintDefinition contains information for constructing a table constraint.
 */
@interface GWMTableConstraintDefinition : NSObject

///@discussion An NSString representation of the name of the constraint.
@property (nonatomic, readonly) NSString *name;
///@discussion The style of the constraint. Choices are PRIMARY KEY, UNIQUE, CHECK, or FOREIGN KEY.
@property (nonatomic, readonly) GWMConstraintStyle style;
///@discussion An NSArray of NSStrings that represent the names of columns to be involved in the constraint.
@property (nonatomic, readonly) NSArray<NSString*> *columns;
///@discussion An NSString substring that will be used to build a SQLite SELECT statement.
@property (nonatomic, readonly) NSString *body;

+(instancetype)tableConstraintWithName:(NSString*)name style:(GWMConstraintStyle)style columns:(NSArray<NSString*>*_Nullable)columns body:(NSString*)body;
-(instancetype)initWithName:(NSString*)name style:(GWMConstraintStyle)style columns:(NSArray<NSString*>*_Nullable)columns body:(NSString*)body;

@end

/*!
 * @class GWMTableDefinition
 * @discussion An instance of GWMTableDefinition contains information for constructing a SQLite table.
 */
@interface GWMTableDefinition : NSObject

///@discussion An NSString representation of the name of the table to be created.
@property (nonatomic, readonly) NSString *table;
///@discussion An NSString representation of the alias to be used for the table.
@property (nonatomic, readonly) NSString *alias;
///@discussion An NSString representation of the name of the database where the table will be created.
@property (nonatomic, readonly) NSString *_Nullable schema;

///@discussion An NSArray of GWMColumnDefinition items that represent the table's columns.
@property (nonatomic, readonly) NSArray<GWMColumnDefinition*> *columns;
///@discussion An NSArray of GWMTableConstraintDefinition items that represent the table's constraints.
@property (nonatomic, readonly) NSArray<GWMTableConstraintDefinition*> *_Nullable constraints;

+(instancetype)tableDefinitionWithTable:(NSString *)table alias:(NSString *)alias schema:(NSString*_Nullable)schema;
-(instancetype)initWithTable:(NSString *)table alias:(NSString *)alias schema:(NSString*_Nullable)schema;

@end

/*!
 * @class GWMTriggerDefinition
 * @discussion An instance of GWMTriggerDefinition contains information for creating a trigger in a SQLite database.
 */
@interface GWMTriggerDefinition : NSObject

///@discussion An NSString representation of the name of the trigger.
@property (nonatomic, readonly) NSString *name;
///@discussion An NSString representation of the name of the database where the trigger will be created.
@property (nonatomic, readonly) NSString *_Nullable schema;
///@discussion An NSString representation of the name of the table the trigger wil be created for.
@property (nonatomic, readonly) NSString *table;
///@discussion An enum that determines when the trigger will be invoked in relation to data being inserted, updated, or deleted. Choices are BEFORE, AFTER, or INSTEAD OF.
@property (nonatomic, readonly) GWMTriggerTiming timing;
///@discussion An enum that determines the type of change the trigger will be invoked by. Choices are INSERT, UPDATE, or DELETE.
@property (nonatomic, readonly) GWMTriggerStyle style;
///@discussion An NSString representation of the name of the WHEN expression.
@property (nonatomic, readonly) NSString *_Nullable whenExpression;
///@discussion An NSArray of columns that will be monitored for the invoking of the trigger.
@property (nonatomic, readonly) NSArray<NSString*> *columns;
///@discussion An NSString representation of the name of the body of the trigger.
@property (nonatomic, readonly) NSString *body;

///@discussion An NSString representation of a CREATE TRIGGER statement that will create a trigger based on all the property values.
@property (nonatomic, readonly) NSString *triggerString;

+(instancetype)triggerDefinitionWithName:(NSString*)name schema:(NSString*_Nullable)schema table:(NSString*)table timing:(GWMTriggerTiming)timing style:(GWMTriggerStyle)style when:(NSString*_Nullable)when columns:(NSArray<NSString*>*)columns body:(NSString*)body;

-(instancetype)initWithName:(NSString*)name schema:(NSString*_Nullable)schema table:(NSString*)table timing:(GWMTriggerTiming)timing style:(GWMTriggerStyle)style when:(NSString*_Nullable)when columns:(NSArray<NSString*>*)columns body:(NSString*)body;

@end

/*
 PRAGMA schema.foreign_key_check;
 PRAGMA schema.foreign_key_check(table-name);
 
 The foreign_key_check pragma checks the database, or the table called "table-name", for foreign key constraints that are violated and returns one row of output for each violation. There are four columns in each result row. The first column is the name of the table that contains the REFERENCES clause. The second column is the rowid of the row that contains the invalid REFERENCES clause, or NULL if the child table is a WITHOUT ROWID table. The third column is the name of the table that is referred to. The fourth column is the index of the specific foreign key constraint that failed. The fourth column in the output of the foreign_key_check pragma is the same integer as the first column in the output of the foreign_key_list pragma. When a "table-name" is specified, the only foreign key constraints checked are those created by REFERENCES clauses in the CREATE TABLE statement for table-name.
 */

/*!
 * @class GWMForeignKeyIntegrityCheckItem
 * @discussion An instance of GWMForeignKeyIntegrityCheckItem represents a row returned as a result of invoking PRAGMA schema.foreign_key_check or PRAGMA schema.foreign_key_check(table-name).
 */
@interface GWMForeignKeyIntegrityCheckItem : NSObject

///@discussion An NSString representation of the name of the table that contains the REFERENCES clause.
@property (nonatomic, strong) NSString *_Nullable table;
///@discussion An NSInteger. The rowid of the row that contains the invalid REFERENCES clause, or NULL if the child table is a WITHOUT ROWID table.
@property (nonatomic, assign) NSInteger rowID;
///@discussion An NSString representation of the name of the table that is referred to.
@property (nonatomic, strong) NSString *_Nullable referredTable;
///@discussion An NSInteger. The index of the specific foreign key constraint that failed.
@property (nonatomic, assign) NSInteger failedRowID;

@end

NS_ASSUME_NONNULL_END
