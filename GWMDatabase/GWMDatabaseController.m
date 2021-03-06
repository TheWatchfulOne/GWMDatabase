//
//  GWMDatabaseController.m
//  GWMKit
//
//  Created by Gregory Moore on 8/18/12.
//  Copyright (c) 2012 Gregory Moore All rights reserved.
//

#import "GWMDatabaseController.h"
#import "GWMDatabaseResult.h"
#import "GWMDataItem.h"

@import os.log;

#pragma mark - Data Types

typedef NS_ENUM(int, GWMDBDataType) {
    GWMDBDataTypeInteger = SQLITE_INTEGER,
    GWMDBDataTypeFloat  = SQLITE_FLOAT,
    GWMDBDataTypeText   = SQLITE_TEXT,
    GWMDBDataTypeBlob   = SQLITE_BLOB,
    GWMDBDataTypeNull   = SQLITE_NULL
};

// https://www.sqlite.org/c3ref/open.html
typedef NS_OPTIONS(int, GWMDBOpenFlags) {
    GWMDBOpenCreate     = SQLITE_OPEN_CREATE,
    /*The database is opened for reading and writing (if combined with SQLITE_OPEN_READWRITE),
     and is created if it does not already exist.
     This is the behavior that is always used for sqlite3_open() and sqlite3_open16().*/
    GWMDBOpenReadWrite  = SQLITE_OPEN_READWRITE,
    /*The database is opened for reading and writing if possible, or reading only if the file is write protected by the operating system.
     In either case the database must already exist, otherwise an error is returned.*/
    GWMDBOpenReadOnly   = SQLITE_OPEN_READONLY,
    /*The database is opened in read-only mode.
     If the database does not already exist, an error is returned.*/
    GWMDBOpenFullMutex  = SQLITE_OPEN_FULLMUTEX,
    /*The database connection opens in the serialized threading mode unless single-thread was previously selected at compile-time or start-time.*/
    GWMDBOpenNoMutex    = SQLITE_OPEN_NOMUTEX
    /*The database connection opens in the multi-thread threading mode
     as long as the single-thread mode has not been set at compile-time or start-time.*/
};

// https://www.sqlite.org/threadsafe.html
typedef NS_ENUM(int, GWMDBThreadingMode) {
    GWMDBThreadingSingle        = SQLITE_CONFIG_SINGLETHREAD,
    /* In this mode, all mutexes are disabled and SQLite is unsafe to use in more than a single thread at once. */
    GWMDBThreadingMultiple      = SQLITE_CONFIG_MULTITHREAD,
    /* In this mode, SQLite can be safely used by multiple threads provided that no single database connection is used simultaneously in two or more threads. */
    GWMDBThreadingSerialized    = SQLITE_CONFIG_SERIALIZED
    /* In serialized mode, SQLite can be safely used by multiple threads with no restriction. */
};

#pragma mark Notification Keys
NSString * const GWMDatabaseControllerDidUpdateDataNotification = @"GWMDatabaseControllerDidUpdateDataNotification";
NSString * const GWMDatabaseControllerDidBeginUserDataMigrationNotification = @"GWMDatabaseControllerDidBeginUserDataMigrationNotification";
NSString * const GWMDatabaseControllerDidFinishUserDataMigrationNotification = @"GWMDatabaseControllerDidFinishUserDataMigrationNotification";
#pragma mark Notification UserInfo Keys
NSString * const GWMDBStatementKey = @"GWMDBStatementKey";

#pragma mark Date & Time Strings
NSString * const GWMDBDateFormatDateTime = @"yyyy-MM-dd HH:mm:ss";
NSString * const GWMDBDateFormatShortDate = @"yyyy-MM-dd";
NSString * const GWMDBDateFormatYearAndMonth = @"yyyy-MM";
NSString * const GWMDBDateFormatYear = @"yyyy";

#pragma mark SQLite Error Strings
GWMSQLiteErrorName const GWMSQLiteErrorOpeningDatabase = @"Error opening database";
GWMSQLiteErrorName const GWMSQLiteErrorClosingDatabase = @"Error closing database";
GWMSQLiteErrorName const GWMSQLiteErrorPreparingStatement = @"Error preparing statement";
GWMSQLiteErrorName const GWMSQLiteErrorExecutingStatement = @"Error executing statement";
GWMSQLiteErrorName const GWMSQLiteErrorBindingNullValue = @"Error binding null value";
GWMSQLiteErrorName const GWMSQLiteErrorBindingTextValue = @"Error binding text value";
GWMSQLiteErrorName const GWMSQLiteErrorBindingIntegerValue = @"Error binding integer value";
GWMSQLiteErrorName const GWMSQLiteErrorBindingDoubleValue = @"Error binding double value";
GWMSQLiteErrorName const GWMSQLiteErrorSteppingToRow = @"Error stepping to row";
GWMSQLiteErrorName const GWMSQLiteErrorFinalizingStatement = @"Error finalizing statement";

#pragma mark Error Domain
NSErrorDomain const GWMErrorDomainDatabase = @"GWMDatabase";

#pragma mark Exceptions
NSExceptionName const GWMPreparingStatementException = @"GWMPreparingStatementException";
NSExceptionName const GWMBindingValueException = @"GWMBindingValueException";
NSExceptionName const GWMExecutingStatementException = @"GWMExecutingStatementException";
NSExceptionName const GWMFinalizingStatementException = @"GWMFinalizingStatementException";

#pragma mark Schema Names
GWMSchemaName const GWMSchemaNameMain = @"main";

#pragma mark Preferences
NSString * const GWMPK_MainDatabaseName = @"GWMPK_MainDatabaseName";
NSString * const GWMPK_MainDatabaseExtension = @"GWMPK_MainDatabaseExtension";
NSString * const GWMPK_UserDatabaseName = @"GWMPK_UserDatabaseName";
NSString * const GWMPK_UserDatabaseAlias = @"GWMPK_UserDatabaseAlias";
NSString * const GWMPK_VersionOfMainDatabase = @"GWMPK_VersionOfMainDatabase";
NSString * const GWMPK_VersionOfUserDatabase = @"GWMPK_VersionOfUserDatabase";
NSString * const GWMPK_UserDatabaseSchemaVersion = @"GWMPK_UserDatabaseSchemaVersion";

@interface GWMDatabaseController ()
{
//    sqlite3 *_database;
//    sqlite3 *_tempDatabase;
    
    
}

@property (nonatomic) sqlite3 *_Nullable database;
@property (nonatomic, strong) NSString *_Nullable databasePath;
@property (assign) BOOL isTransactionInProgress;
@property (nonatomic, strong) NSString *_Nullable transactionName;

@property (assign) GWMDBOpenFlags openFlags;

-(GWMBindValuesEnumerationBlock)bindValuesEnumerationBlockWithResult:(GWMDatabaseResult *_Nullable)databaseResult preparedStatement:(sqlite3_stmt *)sqlite3PreparedStatement;

@end

@implementation GWMDatabaseController

#pragma mark - Life Cycle

+(instancetype)sharedController
{
    static GWMDatabaseController *_databaseController = nil;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        _databaseController = [[self alloc] init];
    });
    
    return _databaseController;
}

-(NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [NSDateFormatter new];
    }
    return _dateFormatter;
}

-(NSNotificationCenter *)notificationCenter
{
    if (!_notificationCenter)
        _notificationCenter = [NSNotificationCenter defaultCenter];
    return _notificationCenter;
}

#pragma mark - SQLite Version

-(NSString *)sqliteVersion
{
    return [NSString stringWithUTF8String:SQLITE_VERSION];
}

-(NSString *)sqliteLibraryVersion
{
    const char *versionC = sqlite3_libversion();
    return [NSString stringWithUTF8String:versionC];
}

#pragma mark - Introspection

-(int)databaseVersionAtPath:(NSString *)filePath withExtension:(NSString *)extension
{
    /*
     this method temporarily opens a database to get PRAGMA user_version and then closes the database
     */
    
//    [self closeDatabase];
    
    NSString *databasePathNS = [[NSBundle mainBundle] pathForResource:filePath ofType:extension];
    const char *databasePathC = [databasePathNS UTF8String];
    int databaseVersion = -1;
    
    sqlite3 *tempDatabase = NULL;
    
    int openCode = sqlite3_open(databasePathC, &tempDatabase);
    if(openCode != GWMSQLiteResultOK) {
        NSLog(@"%@: %s", GWMSQLiteErrorOpeningDatabase, sqlite3_errmsg(tempDatabase));
        os_log(OS_LOG_DEFAULT,  "%s: %s", [GWMSQLiteErrorOpeningDatabase UTF8String], sqlite3_errmsg(tempDatabase));
    } else {
        static sqlite3_stmt *sqlite3PreparedStatement;
        int prepareCode = sqlite3_prepare_v2(tempDatabase, "PRAGMA user_version;", -1, &sqlite3PreparedStatement, NULL);
        if(prepareCode != GWMSQLiteResultOK)
            NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(tempDatabase));
        else {
            int stepCode = GWMSQLiteResultRow;
            while(stepCode == GWMSQLiteResultRow) {
                stepCode = sqlite3_step(sqlite3PreparedStatement);
                if (stepCode == GWMSQLiteResultRow) {
                    databaseVersion = sqlite3_column_int(sqlite3PreparedStatement, 0);
                    NSLog(@"Database: %@ version: %d", databasePathNS, databaseVersion);
                    os_log(OS_LOG_DEFAULT, "Database: %s version: %d", [databasePathNS UTF8String], databaseVersion);
                }
            }
            if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
                NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(tempDatabase));
        }
        int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
        if(finalizeCode != GWMSQLiteResultOK)
            NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(tempDatabase));
        
        int closeCode = sqlite3_close(tempDatabase);
        if(closeCode != GWMSQLiteResultOK)
            NSLog(@"%@: %@ Message: %s", GWMSQLiteErrorClosingDatabase, databasePathNS, sqlite3_errmsg(tempDatabase));
        
        tempDatabase = NULL;
    }
    
    return databaseVersion;
}

-(int)databaseVersionAtFilePath:(NSString *)filePath
{
    /*
     this method temporarily opens a database to get PRAGMA user_version and then closes the database
     */
    
//    [self closeDatabase];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths firstObject];
    NSString *databasePathNS = [documentsDirectoryPath stringByAppendingPathComponent:filePath];
    const char *databasePathC = [databasePathNS UTF8String];
    int databaseVersion = -1;
    
    sqlite3 *tempDatabase = NULL;
    
    int openCode = sqlite3_open(databasePathC, &tempDatabase);
    if(openCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorOpeningDatabase, sqlite3_errmsg(tempDatabase));
    
    else {
        
        static sqlite3_stmt *sqlite3PreparedStatement;
        
        int prepareCode = sqlite3_prepare_v2(tempDatabase, "PRAGMA user_version;", -1, &sqlite3PreparedStatement, NULL);
        if(prepareCode != GWMSQLiteResultOK)
            NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(tempDatabase));
        else {
            int stepCode = GWMSQLiteResultRow;
            while(stepCode == GWMSQLiteResultRow) {
                stepCode = sqlite3_step(sqlite3PreparedStatement);
                if (stepCode == GWMSQLiteResultRow) {
                    databaseVersion = sqlite3_column_int(sqlite3PreparedStatement, 0);
                    NSLog(@"Database: %@ version: %d", databasePathNS, databaseVersion);
                }
            }
            if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
                NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(tempDatabase));
        }
        int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
        if(finalizeCode != GWMSQLiteResultOK)
            NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(tempDatabase));
        
        int closeCode = sqlite3_close(tempDatabase);
        if(closeCode != GWMSQLiteResultOK)
            NSLog(@"%@: %@ Message: %s", GWMSQLiteErrorClosingDatabase, databasePathNS, sqlite3_errmsg(tempDatabase));
        
        tempDatabase = NULL;
    }
    
    return databaseVersion;
}

-(NSArray<GWMDatabaseItem*>*)databases
{
    /*
     PRAGMA database_list;
     
     This pragma works like a query to return one row for each database attached to the current database connection. The second column is the "main" for the main database file, "temp" for the database file used to store TEMP objects, or the name of the ATTACHed database for other database files. The third column is the name of the database file itself, or an empty string if the database is not associated with a file.
     */
    if (!self.isDatabaseOpen)
        return nil;
    
    NSMutableArray<GWMDatabaseItem*> *mutableDatabases = [NSMutableArray<GWMDatabaseItem*> new];
    
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, "PRAGMA database_list;", -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                GWMDatabaseItem *dataItem = [GWMDatabaseItem new];
                
                char *schemaNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 1);
                dataItem.name = [NSString stringWithUTF8String:schemaNameC];
                
                char *flieNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 2);
                dataItem.filename = [NSString stringWithUTF8String:flieNameC];
                
                [mutableDatabases addObject:dataItem];
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    
    return [NSArray<GWMDatabaseItem*> arrayWithArray:mutableDatabases];
}

-(NSArray<GWMTableName>*)tablesWithSchema:(GWMSchemaName)schema
{
    if (!self.isDatabaseOpen)
        return nil;
    //char *sql = "SELECT name FROM sqlite_master WHERE type='table'";
    NSMutableArray<GWMTableName> *mutableTables = [NSMutableArray<GWMTableName> new];
    
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    schema = schema ? schema : @"main";
    
    NSString *statement = [NSString stringWithFormat:@"SELECT name FROM %@.sqlite_master WHERE type='table'",schema];
    
    int prepareCode = sqlite3_prepare_v2(self.database, statement.UTF8String, -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                
                char *tableNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 0);
                GWMTableName table = (GWMTableName)[NSString stringWithUTF8String:tableNameC];
                
                [mutableTables addObject:table];
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    
    return [NSArray<GWMTableName> arrayWithArray:mutableTables];
}

-(NSArray<GWMColumnItem*>*)columnsWithTable:(GWMTableName)table
{
    /*
     PRAGMA table_info(table-name)
     */
    NSString *statement = nil;
    
    if(table)
        statement = [NSString stringWithFormat:@"PRAGMA table_info(%@);",table];
    else
        return @[];
    
    NSMutableArray *mutableColumns = [NSMutableArray new];
    
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, statement.UTF8String, -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                GWMColumnItem *columnItem = [GWMColumnItem new];
                
                int columnId = sqlite3_column_int(sqlite3PreparedStatement, 0);
                columnItem.columnId = columnId;
                
                char *columnNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 1);
                columnItem.name = [NSString stringWithUTF8String:columnNameC];
                
                char *fileNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 2);
                columnItem.affinity = [NSString stringWithUTF8String:fileNameC];
                
                int notNull = sqlite3_column_int(sqlite3PreparedStatement, 3);
                columnItem.notNull = [NSNumber numberWithBool:notNull].boolValue;
                
                char *defaultValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 4);
                columnItem.defaultValue = defaultValueC ? [NSString stringWithUTF8String:defaultValueC] : nil;
                
                int primaryKeyIndex = sqlite3_column_int(sqlite3PreparedStatement, 5);
                columnItem.primaryKeyIndex = primaryKeyIndex;
                
                [mutableColumns addObject:columnItem];
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    
    return [NSArray arrayWithArray:mutableColumns];
}

-(BOOL)foreignKeysEnabled
{
    /*
    PRAGMA foreign_keys;
     */
    
    BOOL isEnabled = NO;
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, "PRAGMA foreign_keys;", -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                NSInteger enabled = sqlite3_column_int(sqlite3PreparedStatement, 0);
                isEnabled = enabled != 0;
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    
    return isEnabled;
}

-(void)setForeignKeysEnabled:(BOOL)foreignKeysEnabled
{
    // PRAGMA foreign_keys = boolean;
    NSString *statement = nil;
    
    if(foreignKeysEnabled)
        statement = [NSString stringWithFormat:@"PRAGMA foreign_keys = ON"];
    else
        statement = [NSString stringWithFormat:@"PRAGMA foreign_keys = OFF"];
    
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, statement.UTF8String, -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                NSInteger enabled = sqlite3_column_int(sqlite3PreparedStatement, 0);
//                isEnabled = enabled != 0;
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
}

#pragma mark - Maintenance

-(void)vacuum:(GWMSchemaName)schema
{
    // VACUUM
    
    NSString *statement = nil;
    if(schema)
        statement = [NSString stringWithFormat:@"VACUMM %@;",schema];
    else
        statement = @"VACUUM;";
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    } @finally {
        
    }
    
}

-(NSArray<NSString*>*)checkIntegrity:(GWMSchemaName)schema rows:(NSInteger)rowCount
{
    /*
     PRAGMA schema.integrity_check;
     PRAGMA schema.integrity_check(N);
     
     This pragma does an integrity check of the entire database. The integrity_check pragma looks for out-of-order records, missing pages, malformed records, missing index entries, and UNIQUE, CHECK, and NOT NULL constraint errors. If the integrity_check pragma finds problems, strings are returned (as multiple rows with a single column per row) which describe the problems. Pragma integrity_check will return at most N errors before the analysis quits, with N defaulting to 100. If pragma integrity_check finds no errors, a single row with the value 'ok' is returned.
     
     PRAGMA integrity_check does not find FOREIGN KEY errors. Use the PRAGMA foreign_key_check command for to find errors in FOREIGN KEY constraints.
     
     See also the PRAGMA quick_check command which does most of the checking of PRAGMA integrity_check but runs much faster.
     */
    if(!schema)
        schema = GWMSchemaNameMain;
    
    NSString *statement;
    
    if (rowCount > 0) {
        statement = [NSString stringWithFormat:@"PRAGMA %@.integrity_check(%li);",schema,rowCount];
    } else {
        statement = [NSString stringWithFormat:@"PRAGMA %@.integrity_check;",schema];
    }
    
    NSMutableArray<NSString*> *mutableErrorStrings = [NSMutableArray<NSString*> new];
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, statement.UTF8String, -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                
                char *schemaNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 0);
                NSString *message = [NSString stringWithUTF8String:schemaNameC];
                
                [mutableErrorStrings addObject:message];
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    
    return [NSArray<NSString*> arrayWithArray:mutableErrorStrings];
}

-(NSArray<GWMForeignKeyIntegrityCheckItem*> *)checkForeignKeysIntegrity:(GWMSchemaName)schema table:(GWMTableName)table
{
    /*
     PRAGMA schema.foreign_key_check;
     PRAGMA schema.foreign_key_check(table-name);
     
     The foreign_key_check pragma checks the database, or the table called "table-name", for foreign key constraints that are violated and returns one row of output for each violation. There are four columns in each result row. The first column is the name of the table that contains the REFERENCES clause. The second column is the rowid of the row that contains the invalid REFERENCES clause, or NULL if the child table is a WITHOUT ROWID table. The third column is the name of the table that is referred to. The fourth column is the index of the specific foreign key constraint that failed. The fourth column in the output of the foreign_key_check pragma is the same integer as the first column in the output of the foreign_key_list pragma. When a "table-name" is specified, the only foreign key constraints checked are those created by REFERENCES clauses in the CREATE TABLE statement for table-name.
     */
    
    NSMutableArray<GWMForeignKeyIntegrityCheckItem*> *mutableCheckItems = [NSMutableArray<GWMForeignKeyIntegrityCheckItem*> new];
    
    NSString *statement = nil;
    
    if(!schema)
        schema = GWMSchemaNameMain;
    
    if(!table)
        statement = [NSString stringWithFormat:@"PRAGMA %@.foreign_key_check",schema];
    else
        statement = [NSString stringWithFormat:@"PRAGMA %@.foreign_key_check(%@)",schema,table];
    
    static sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, statement.UTF8String, -1, &sqlite3PreparedStatement, NULL);
    if(prepareCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
    else {
        int stepCode = GWMSQLiteResultRow;
        while(stepCode == GWMSQLiteResultRow) {
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            if (stepCode == GWMSQLiteResultRow) {
                GWMForeignKeyIntegrityCheckItem *checkItem = [GWMForeignKeyIntegrityCheckItem new];
                
                char *tableC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 0);
                checkItem.table = [NSString stringWithUTF8String:tableC];
                
                int rowID = sqlite3_column_int(sqlite3PreparedStatement, 1);
                checkItem.rowID = rowID;
                
                char *referedTableC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 2);
                checkItem.referredTable = [NSString stringWithUTF8String:referedTableC];
                
                int failedRowID = sqlite3_column_int(sqlite3PreparedStatement, 3);
                checkItem.failedRowID = failedRowID;
                
                [mutableCheckItems addObject:checkItem];
            }
        }
        if(stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    }
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if(finalizeCode != GWMSQLiteResultOK)
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    
    return [NSArray<GWMForeignKeyIntegrityCheckItem*> arrayWithArray:mutableCheckItems];
}

#pragma mark - Attach and Detach Database

-(GWMDBOperationResult)attachDatabase:(GWMDatabaseFileName)databaseFileName schemaName:(GWMSchemaName)alias
{
    NSArray<GWMDatabaseItem*> *databases = self.databases;
    
    __block BOOL attached = NO;
    [databases enumerateObjectsUsingBlock:^(GWMDatabaseItem *_Nonnull db, NSUInteger idx, BOOL *stop){
        if ([db.name isEqualToString:alias]) {
            attached = YES;
            *stop = YES;
        }
    }];
    if(attached){
        NSLog(@"Database with alias '%@' already attached", alias);
        return GWMDBOperationDatabaseAttached;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [paths firstObject];
    
    NSString *fullPath = [documentPath stringByAppendingPathComponent:databaseFileName];
    NSString *statement = [NSString stringWithFormat:@"ATTACH DATABASE \'%@\' AS %@;", fullPath, alias];
    char *errorMessageC;
    
    int executeCode = sqlite3_exec(self.database, statement.UTF8String, NULL, NULL, &errorMessageC);
    
    if (executeCode != GWMSQLiteResultOK) {

        NSLog(@"Error while attaching database '%@' (%@): '%s'", databaseFileName, alias, errorMessageC);
        sqlite3_free(errorMessageC);
        return GWMDBOperationDatabaseNotAttached;
    }

    NSLog(@"Successfully attached database: '%@' as '%@'", databaseFileName, alias);
    return GWMDBOperationDatabaseAttached;
}

-(GWMDBOperationResult)detachDatabase:(GWMDatabaseAlias)databaseName
{
    if (self.isTransactionInProgress) {
        NSLog(@"Can't detach database: %@ while transaction: '%@' is in progress", databaseName, self.transactionName);
        return GWMDBOperationDatabaseNotDetached;
    }
    NSString *statement = [NSString stringWithFormat:@"DETACH DATABASE \'%@\';", databaseName];
    char *errorMessageC;
    
    int result = sqlite3_exec(self.database, statement.UTF8String, NULL, NULL, &errorMessageC);
    
    if (result != GWMSQLiteResultOK) {
        NSLog(@"Error while detaching database: '%@' Message: '%s'", databaseName, errorMessageC);
        sqlite3_free(errorMessageC);
        return GWMDBOperationDatabaseNotDetached;
    } else {
        NSLog(@"Successfully detached database: '%@'", databaseName);
        return GWMDBOperationDatabaseDetached;
    }
}

#pragma mark - Open and close the Database; check if Database is open

-(void)openDatabase
{
    NSString *mainDatabaseName = [[NSUserDefaults standardUserDefaults] stringForKey:GWMPK_MainDatabaseName];
    NSString *mainDatabaseExtension = [[NSUserDefaults standardUserDefaults] stringForKey:GWMPK_MainDatabaseExtension];
    NSString *userDatabaseName = [[NSUserDefaults standardUserDefaults] stringForKey:GWMPK_UserDatabaseName];
    NSString *userDatabaseAlias = [[NSUserDefaults standardUserDefaults] stringForKey:GWMPK_UserDatabaseAlias];
    
    if (mainDatabaseName && mainDatabaseExtension) {
        BOOL success = [self openDatabase:mainDatabaseName extension:mainDatabaseExtension];
        
        if (success && userDatabaseName && userDatabaseAlias) {
            success = [self attachDatabase:userDatabaseName schemaName:userDatabaseAlias];
            
        }
    }
}

-(GWMDBOperationResult)openDatabase:(NSString *)name extension:(NSString *)extension
{
    if ([self isDatabaseOpen])
        return GWMDBOperationDatabaseOpened;
    
    self.databasePath = [[NSBundle mainBundle] pathForResource:name ofType:extension];
    
    sqlite3 *db = NULL;
    
//    sqlite3_shutdown();
//    sqlite3_config(SQLITE_CONFIG_SERIALIZED);
//    sqlite3_initialize();
//    int openCode = sqlite3_open(self.databasePath.UTF8String, &db);
    
//    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX;
    
    self.openFlags = GWMDBOpenReadWrite | GWMDBOpenFullMutex;
    int openCode = sqlite3_open_v2(self.databasePath.UTF8String, &db, self.openFlags, NULL);
    
    self.database = db;
    
    if (openCode != GWMSQLiteResultOK) {
        NSLog(@"*** %@ at path: %@ with error: '%s' ***", GWMSQLiteErrorOpeningDatabase, self.databasePath, sqlite3_errmsg(self.database));
        [self closeDatabase];
        return GWMDBOperationDatabaseNotOpened;
    }
    
    NSLog(@"*** SQLite version: %@ ***", [self sqliteVersion]);
    NSLog(@"*** SQLite library version: %@ ***", [self sqliteLibraryVersion]);
    
    return GWMDBOperationDatabaseOpened;
}

-(GWMDBOperationResult)closeDatabase
{
    
    if (![self isDatabaseOpen])
        return GWMDBOperationDatabaseClosed;

    if (self.isTransactionInProgress) {
        NSLog(@"*** Can't close database because transaction: '%@' is in progress ***", self.transactionName);
        return GWMDBOperationDatabaseNotClosed;
    }
    
    NSArray<GWMDatabaseItem*> *databases = self.databases;
    
    [databases enumerateObjectsUsingBlock:^(GWMDatabaseItem *_Nonnull db, NSUInteger idx, BOOL *stop){
        if(![db.name isEqualToString:GWMSchemaNameMain])
            [self detachDatabase:db.name];
    }];
    
    int closeCode = sqlite3_close(self.database);
    
    if (closeCode != GWMSQLiteResultOK) {
        NSLog(@"*** %@: Message:'%s' ***", GWMSQLiteErrorClosingDatabase, sqlite3_errmsg(self.database));
        return GWMDBOperationDatabaseNotClosed;
    }
    self.database = NULL;
    
    NSLog(@"*** Database was closed ***");
    return GWMDBOperationDatabaseClosed;
}

-(BOOL)isDatabaseOpen
{
    return self.database != NULL;
}

#pragma mark -  Helper Methods

-(NSDate *)dateWithFormat:(NSString *)dateFormat string:(NSString *)dateString andTimeZone:(NSTimeZone *)timeZone
{
    NSDate *resultDate;
    
    [self.dateFormatter setDateFormat:dateFormat];// format for going from sqlite table to NSDate object
    [self.dateFormatter setTimeZone:timeZone];
    resultDate = [self.dateFormatter dateFromString:dateString];
    
    return resultDate;
}

-(GWMBindValuesEnumerationBlock)bindValuesEnumerationBlockWithResult:(GWMDatabaseResult *)databaseResult preparedStatement:(sqlite3_stmt *)sqlite3PreparedStatement
{
    return ^(id _Nonnull value, NSUInteger idx, BOOL  * _Nonnull stop){
        
        int statementIdx = (int)idx + 1;
        int bindCode = GWMSQLiteResultOK;
        NSError *error = nil;
        
        if ([value isKindOfClass:[NSDate class]]) {
            
            NSDate *date = (NSDate*)value;
            [self.dateFormatter setDateFormat:GWMDBDateFormatDateTime];
            NSString *string = [self.dateFormatter stringFromDate:date];
            bindCode = sqlite3_bind_text(sqlite3PreparedStatement, statementIdx, string.UTF8String, -1, SQLITE_TRANSIENT);
            if (bindCode != GWMSQLiteResultOK) {
                NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingNullValue,sqlite3_errmsg(self.database)];
                databaseResult.resultCode = bindCode;
                databaseResult.resultMessage = message;
                databaseResult.errors[@(bindCode)] = message;
                NSLog(@"*** %@ ***", message);
                NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
            }
            
        } else if ([value isKindOfClass:[NSNull class]]) {
            
            bindCode = sqlite3_bind_null(sqlite3PreparedStatement, statementIdx);
            if (bindCode != GWMSQLiteResultOK) {
                NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingNullValue,sqlite3_errmsg(self.database)];
                databaseResult.resultCode = bindCode;
                databaseResult.resultMessage = message;
                databaseResult.errors[@(bindCode)] = message;
                NSLog(@"*** %@ ***", message);
                NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
            }
            
        } else if ([value isKindOfClass:[NSString class]]) {
            
            NSString *string = (NSString*)value;
            bindCode = sqlite3_bind_text(sqlite3PreparedStatement, statementIdx, string.UTF8String, -1, SQLITE_TRANSIENT);
            if (bindCode != GWMSQLiteResultOK) {
                NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingTextValue,sqlite3_errmsg(self.database)];
                databaseResult.resultCode = bindCode;
                databaseResult.resultMessage = message;
                databaseResult.errors[@(bindCode)] = message;
                NSLog(@"*** %@ ***", message);
                NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
            }
            
        } else if ([value isKindOfClass:[NSNumber class]]){
            //TODO: number type IMPROVING
            // https://stackoverflow.com/questions/2518761/get-type-of-nsnumber
            NSNumber *numberNS = (NSNumber *)value;
            CFNumberType numberType = CFNumberGetType((CFNumberRef)numberNS);
            //                    const char *type = [value objCType];
            //                    const char *encoding = @encode(char);
            //                    BOOL same = (strcmp(type, encoding) == 0);
            switch (numberType) {
                case kCFNumberFloatType:
                case kCFNumberFloat32Type:
                case kCFNumberFloat64Type:
                case kCFNumberCGFloatType:
                {
                    float numberF = [numberNS floatValue];
                    bindCode = sqlite3_bind_double(sqlite3PreparedStatement, statementIdx, numberF);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingDoubleValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberDoubleType:
                {
                    double numberD = [numberNS doubleValue];
                    bindCode = sqlite3_bind_double(sqlite3PreparedStatement, (statementIdx), numberD);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingDoubleValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberCharType:
                {
                    char numberC = [numberNS charValue];
                    bindCode = sqlite3_bind_int(sqlite3PreparedStatement, (statementIdx), numberC);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberIntType:
                case kCFNumberSInt8Type:
                case kCFNumberSInt16Type:
                case kCFNumberSInt32Type:
                {
                    int numberI = [numberNS intValue];
                    bindCode = sqlite3_bind_int(sqlite3PreparedStatement, (statementIdx), numberI);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberShortType:
                {
                    short numberI = [numberNS shortValue];
                    bindCode = sqlite3_bind_int(sqlite3PreparedStatement, (statementIdx), numberI);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberSInt64Type:
                {
                    SInt64 numberI = [numberNS integerValue];
                    bindCode = sqlite3_bind_int64(sqlite3PreparedStatement, (statementIdx), numberI);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberNSIntegerType:
                {
                    NSInteger numberI = [numberNS integerValue];
                    bindCode = sqlite3_bind_int64(sqlite3PreparedStatement, (statementIdx), numberI);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberLongType:
                {
                    long numberL = [numberNS longValue];
                    bindCode = sqlite3_bind_int64(sqlite3PreparedStatement, (statementIdx), numberL);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberLongLongType:
                {
                    long long numberLL = [numberNS longLongValue];
                    bindCode = sqlite3_bind_int64(sqlite3PreparedStatement, (statementIdx), numberLL);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                case kCFNumberCFIndexType:
                {
                    int numberI = [numberNS intValue];
                    bindCode = sqlite3_bind_int64(sqlite3PreparedStatement, (statementIdx), numberI);
                    if (bindCode != GWMSQLiteResultOK) {
                        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorBindingIntegerValue,sqlite3_errmsg(self.database)];
                        databaseResult.resultCode = bindCode;
                        databaseResult.resultMessage = message;
                        databaseResult.errors[@(bindCode)] = message;
                        NSLog(@"*** %@ ***", message);
                        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
                        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
                    }
                    break;
                }
                default:
                    break;
            }
        }
    };
}

-(void)processStatement:(NSString *_Nonnull)statement
{
    char *errorMessageC;
    int executeCode = sqlite3_exec(self.database, statement.UTF8String, NULL, NULL, &errorMessageC);
//    NSError *error = nil;
    if (executeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: Message: %s Database: '%@'", GWMSQLiteErrorExecutingStatement, errorMessageC, self.databasePath];
        NSLog(@"%@", message);
        sqlite3_free(errorMessageC);
        NSDictionary *info = @{GWMDBStatementKey:statement};
//        error = [NSError errorWithDomain:@"GWMKit" code:<#(NSInteger)#> userInfo:info];
        NSException *exception = [NSException exceptionWithName:GWMExecutingStatementException reason:message userInfo:info];
        @throw exception;
    }
//    return error;
}

-(NSString *)stringWithConflict:(GWMDBOnConflict)conflict
{
    switch (conflict) {
        case GWMDBOnConflictRollback:
            return @"OR ROLLBACK";
            break;
        case GWMDBOnConflictAbort:
            return @"OR ABORT";
            break;
        case GWMDBOnConflictFail:
            return @"OR FAIL";
            break;
        case GWMDBOnConflictIgnore:
            return @"OR IGNORE";
            break;
        case GWMDBOnConflictReplace:
            return @"OR REPLACE";
            break;
        default:
            return @"OR ABORT";
            break;
    }
}

-(GWMWhereClauseItem *)whereClauseWithCriteria:(NSArray<NSDictionary<NSString*,id>*>*)criteria
{
    // build the WHERE clause
    GWMWhereClauseItem *container = [GWMWhereClauseItem new];
    
    if (criteria) {
        
        NSMutableArray<NSString*> *mutableOrPredicates = [NSMutableArray<NSString*> new];
        NSMutableArray<NSString*> *mutableValues = [NSMutableArray<NSString*> new];
        
        [criteria enumerateObjectsUsingBlock:^(NSDictionary<NSString*,id> *_Nonnull info, NSUInteger idx, BOOL *stop){
            
            NSMutableArray<NSString*> *mutableAndPredicates = [NSMutableArray<NSString*> new];
            
            [info enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, id val, BOOL *stop){
                [mutableValues addObject:val];
                
                NSString *predicate = nil;
                // support other comparisons besides 'equals'
                if ([key containsString:@"?"])
                    predicate = key;
                else
                    predicate = [NSString stringWithFormat:@"%@ = ?", key];
                [mutableAndPredicates addObject:predicate];
            }];
            
            NSString *andPredicate = [[NSArray arrayWithArray:mutableAndPredicates] componentsJoinedByString:@" AND "];
            [mutableOrPredicates addObject:andPredicate];
            
        }];
        
        NSString *orPredicate = [[NSArray arrayWithArray:mutableOrPredicates] componentsJoinedByString:@") OR ("];
        NSString *finalOrPredicate = nil;
        if (mutableOrPredicates.count > 1)
            finalOrPredicate = [NSString stringWithFormat:@"(%@)", orPredicate];
        else
            finalOrPredicate = orPredicate;
        
        container.whereClause = [NSString stringWithFormat:@" WHERE %@", finalOrPredicate];
        container.whereValues = [NSArray arrayWithArray:mutableValues];
    }
    return container;
}

#pragma mark - DDL Database Operations

#pragma mark Tables
-(void)createTableWithClassName:(NSString *)className schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    Class<GWMDataItem> class = NSClassFromString(className);
    
    NSArray<GWMColumnDefinition*> *tableColumnDefinitions = [class columnDefinitionItems];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(sequence)) ascending:YES];
//    NSArray<GWMColumnDefinition*> *sortedColumns = [tableColumnDefinitions sortedArrayUsingSelector:@selector(sequence)];
    NSArray<GWMColumnDefinition*> *sortedColumns = [tableColumnDefinitions sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    NSArray *constraintDefs = [class constraintDefinitionItems];
    NSString *table = self.classToTableMapping[className];
    
    [self createTable:table columns:sortedColumns constraints:constraintDefs schema:schema completion:completion];
}

-(void)createTable:(GWMTableName)tableName columns:(nonnull NSArray<GWMColumnDefinition *> *)columnDefinitions constraints:(NSArray<GWMTableConstraintDefinition*>*)constraintDefinitions schema:(GWMSchemaName _Nullable)schema completion:(GWMDBErrorCompletionBlock _Nullable)completion
{
    NSMutableArray<NSString*> *mutableTableColumnDefinitions = [NSMutableArray new];
    
    [columnDefinitions enumerateObjectsUsingBlock:^(GWMColumnDefinition *_Nonnull definition, NSUInteger idx, BOOL *_Nonnull stop){
        if (definition.createString)
            [mutableTableColumnDefinitions addObject:definition.createString];
    }];
    
    NSString *columnDefString = [mutableTableColumnDefinitions componentsJoinedByString:@", "];
    
    NSString *constraintDefString = nil;
    if(constraintDefinitions){
        NSMutableArray *mutableConstraintDefs = [NSMutableArray new];
        [constraintDefinitions enumerateObjectsUsingBlock:^(GWMTableConstraintDefinition *_Nullable def, NSUInteger idx, BOOL *stop){
            [mutableConstraintDefs addObject:def.body];
        }];
        constraintDefString = [mutableConstraintDefs componentsJoinedByString:@", "];
    }
    
    NSString *statement = nil;
    if(constraintDefString)
        statement = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@.%@ (%@, %@)", schema, tableName, columnDefString, constraintDefString];
    else
        statement = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@.%@ (%@)", schema, tableName, columnDefString];
    
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

-(void)dropTableWithClassName:(NSString *)className schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    NSString *table = self.classToTableMapping[className];
    
    [self dropTable:table schema:schema completion:completion];
}

-(void)dropTable:(NSString *)tableName schema:(GWMSchemaName _Nullable)schema completion:(GWMDBErrorCompletionBlock _Nullable)completion
{
    NSString *statement = nil;
    if(schema)
        statement = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@.%@", schema, tableName];
    else
        statement = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tableName];
    
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

-(void)renameTable:(GWMTableName)oldName newName:(GWMTableName)newName schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    NSString *alias = schema ? schema : GWMSchemaNameMain;
    
    NSString *statement = [NSString stringWithFormat:@"ALTER TABLE %@.%@ RENAME TO %@", alias, oldName, newName];
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
    
}

-(void)renameColumn:(GWMColumnName)oldName newName:(GWMColumnName)newName table:(GWMTableName)table schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    NSString *alias = schema ? schema : GWMSchemaNameMain;
    
    NSString *statement = [NSString stringWithFormat:@"ALTER TABLE %@.%@ RENAME COLUMN %@ TO %@", alias, table, oldName, newName];
    
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

-(void)addColumn:(GWMColumnDefinition *)columnDefinition toTable:(GWMTableName)table schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    NSString *alias = schema ? schema : GWMSchemaNameMain;
    
    NSString *statement = [NSString stringWithFormat:@"ALTER TABLE %@.%@ ADD COLUMN %@", alias, table, [columnDefinition createString]];
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

#pragma mark Indexes

-(void)createIndex:(GWMIndexDefinition *)indexDefinition completion:(GWMDBErrorCompletionBlock)completion
{
    NSError *error = nil;
    @try {
        [self processStatement:indexDefinition.indexCreationString];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

-(void)dropIndex:(GWMIndexName)index schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    NSString *statement = nil;
    
    if(schema)
        statement = [NSString stringWithFormat:@"DROP INDEX IF EXISTS %@.%@", schema, index];
    else
        statement = [NSString stringWithFormat:@"DROP INDEX IF EXISTS %@", index];
    
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

#pragma mark Triggers

-(void)createTrigger:(GWMTriggerDefinition *)triggerDefinition completion:(GWMDBErrorCompletionBlock)completion
{
    NSError *error = nil;
    
    @try {
        [self processStatement:triggerDefinition.triggerString];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
    
}

-(void)dropTrigger:(GWMTriggerName)trigger schema:(GWMSchemaName)schema completion:(GWMDBErrorCompletionBlock)completion
{
    NSString *statement = nil;
    
    if(schema)
        statement = [NSString stringWithFormat:@"DROP TRIGGER IF EXISTS %@.%@", schema, trigger];
    else
        statement = [NSString stringWithFormat:@"DROP TRIGGER IF EXISTS %@", trigger];
    
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completion)
            completion(error);
    }
}

#pragma mark - CRUD Database Operations

#pragma mark Create

-(void)insertIntoTable:(GWMTableName)table newValues:(NSArray<NSDictionary<GWMColumnName,id> *> *)valuesToInsert completion:(GWMDatabaseResultBlock)completionHandler
{
    // build statement
    
    NSMutableArray<NSString*> *mutableKeys = [NSMutableArray<NSString*> new];
    NSMutableArray<NSString*> *mutableValuePlaceholders = [NSMutableArray<NSString*> new];
    NSMutableArray<NSString*> *mutableValuesToBind = [NSMutableArray<NSString*> new];
    
    [valuesToInsert enumerateObjectsUsingBlock:^(NSDictionary<NSString*,id> *_Nonnull dictionary, NSUInteger idx, BOOL *stop){
        
        [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, id _Nonnull obj, BOOL *stop){
            
            NSArray *keys = [NSArray arrayWithArray:mutableKeys];
            if (![keys containsObject:key])
                [mutableKeys addObject:key];
            
            [mutableValuePlaceholders addObject:@"?"];
            [mutableValuesToBind addObject:obj];
        }];
        
    }];
    
    NSString *columns = [[NSArray arrayWithArray:mutableKeys] componentsJoinedByString:@","];
    NSString *valuePlaceholders = [[NSArray arrayWithArray:mutableValuePlaceholders] componentsJoinedByString:@","];
    NSString *insertStatement = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", table, columns, valuePlaceholders];
    
    // prepare statement
    sqlite3_stmt *sqlite3PreparedStatement; // database prepared statment
    
    const char *statementC = [insertStatement UTF8String];
    
    int prepareCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, NULL);
    if (prepareCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s sql: %@", GWMSQLiteErrorPreparingStatement,sqlite3_errmsg(self.database),insertStatement];
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if (completionHandler)
            completionHandler(nil,error);
        
    } else {
        
        sqlite3_exec(self.database, "BEGIN TRANSACTION", NULL, NULL, NULL);
        
        NSArray *valuesToBind = [NSArray arrayWithArray:mutableValuesToBind];
        // bind values
        [valuesToBind enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:nil preparedStatement:sqlite3PreparedStatement]];
        
        int stepCode = sqlite3_step(sqlite3PreparedStatement);
        if (stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone) {
            NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorSteppingToRow,sqlite3_errmsg(self.database)];
            NSLog(@"*** %@ ***", message);
            NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
            NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
            if (completionHandler)
                completionHandler(nil,error);
        }
        
        sqlite3_exec(self.database, "END TRANSACTION", NULL, NULL, NULL);
    }
    
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorFinalizingStatement,sqlite3_errmsg(self.database)];
        NSLog(@"*** %@ ***", message);
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if (completionHandler)
            completionHandler(nil,error);
        return;
    }
    // execute statement
    
    NSString *statement = [NSString stringWithFormat:@"SELECT '%@' AS class, pKey AS itemID FROM %@ ORDER BY inserted DESC LIMIT 1", NSStringFromClass([GWMDataItem class]), table];
    GWMDatabaseResult *result = [self resultWithStatement:statement criteria:nil completion:nil];
    GWMDataItem *obj = result.data.firstObject;
    
    if (completionHandler) {
        completionHandler(obj,nil);
    }
}

-(void)insertIntoTable:(GWMTableName)table values:(NSDictionary<GWMColumnName,id> *)values completion:(GWMDatabaseResultBlock)completionHandler
{
    [self insertIntoTable:table values:values onConflict:GWMDBOnConflictAbort completion:completionHandler];
}

-(void)insertIntoTable:(GWMTableName)table values:(NSDictionary<GWMColumnName,id> *)values onConflict:(GWMDBOnConflict)onConflict completion:(GWMDatabaseResultBlock)completionHandler
{
    // conflict resolution
    NSString *conflict = [self stringWithConflict:onConflict];
    
    // build statement
    NSMutableArray<NSString*> *mutableKeys = [NSMutableArray<NSString*> new];
    NSMutableArray<NSString*> *mutableValuePlaceholders = [NSMutableArray<NSString*> new];
    NSMutableArray<NSString*> *mutableValuesToBind = [NSMutableArray<NSString*> new];
    [values enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key,id _Nonnull obj,BOOL *stop){
        [mutableKeys addObject:key];
        [mutableValuePlaceholders addObject:@"?"];
        [mutableValuesToBind addObject:obj];
    }];
    NSString *columns = [[NSArray arrayWithArray:mutableKeys] componentsJoinedByString:@","];
    NSString *valuePlaceholders = [[NSArray arrayWithArray:mutableValuePlaceholders] componentsJoinedByString:@","];
    NSString *insertStatement = [NSString stringWithFormat:@"INSERT %@ INTO %@ (%@) VALUES (%@)", conflict, table, columns, valuePlaceholders];
    
    // prepare statement
    sqlite3_stmt *sqlite3PreparedStatement; // database prepared statment
    
    const char *statementC = [insertStatement UTF8String];
    
    //TODO: prepare DONE
    int prepareCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, NULL);
    if (prepareCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s sql: %@", GWMSQLiteErrorPreparingStatement,sqlite3_errmsg(self.database),insertStatement];
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if (completionHandler)
            completionHandler(nil,error);
        
    } else {
        
        sqlite3_exec(self.database, "BEGIN TRANSACTION", NULL, NULL, NULL);
        
        NSArray *valuesToBind = [NSArray arrayWithArray:mutableValuesToBind];
        // bind values
        [valuesToBind enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:nil preparedStatement:sqlite3PreparedStatement]];
        
        //TODO: fix step error DONE
        int stepCode = sqlite3_step(sqlite3PreparedStatement);
        if (stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone) {
            NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorSteppingToRow,sqlite3_errmsg(self.database)];
            NSLog(@"*** %@ ***", message);
            NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
            NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
            if (completionHandler)
                completionHandler(nil,error);
        }
        
        sqlite3_exec(self.database, "END TRANSACTION", NULL, NULL, NULL);
    }
    
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorFinalizingStatement,sqlite3_errmsg(self.database)];
        NSLog(@"*** %@ ***", message);
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if (completionHandler)
            completionHandler(nil,error);
        return;
    }
    // execute statement
    
    NSString *statement = [NSString stringWithFormat:@"SELECT '%@' AS class, pKey AS itemID FROM %@ ORDER BY inserted DESC LIMIT 1", NSStringFromClass([GWMDataItem class]), table];
    GWMDatabaseResult *result = [self resultWithStatement:statement criteria:nil completion:nil];
    GWMDataItem *obj = result.data.firstObject;
    
    if (completionHandler) {
        completionHandler(obj,nil);
    }
}

-(void)insertWithStatement:(NSString *)statement values:(nonnull NSArray *)values completion:(GWMDBCompletionBlock _Nullable)completion
{
    GWMDatabaseResult *databaseResult = [[GWMDatabaseResult alloc] init];
    
    sqlite3_stmt *sqlite3PreparedStatement; // database prepared statment
    
    const char *statementC = [statement UTF8String];
    
    //TODO: prepare DONE
    int prepareCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, NULL);
    if (prepareCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorPreparingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = prepareCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(prepareCode)] = message;
        NSLog(@"*** %@ ***", message);
    } else {
        
        sqlite3_exec(self.database, "BEGIN TRANSACTION", NULL, NULL, NULL);
        
        [values enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:databaseResult preparedStatement:sqlite3PreparedStatement]];
        
        //TODO: fix step error DONE
        int stepCode = sqlite3_step(sqlite3PreparedStatement);
        if (stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone) {
            NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorSteppingToRow,sqlite3_errmsg(self.database)];
            databaseResult.resultCode = stepCode;
            databaseResult.resultMessage = message;
            databaseResult.errors[@(stepCode)] = message;
            NSLog(@"*** %@ ***", message);
        }
        
        sqlite3_exec(self.database, "END TRANSACTION", NULL, NULL, NULL);
    }
    
    //TODO: fix finalize error DONE
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorFinalizingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = finalizeCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(finalizeCode)] = message;
        NSLog(@"*** %@ ***", message);
    }
    
//    NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
//
//    [columns enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop){
//        mutableUserInfo[key] = values[idx];
//    }];
    
    if (completion) {
        completion();
    }
}

#pragma mark Read

-(GWMDatabaseResult *)resultWithStatement:(NSString *)statement criteria:(NSArray *)criteria completion:(GWMDBCompletionBlock)completionHandler
{
    [self openDatabase];
    
    GWMDatabaseResult *databaseResult = [[GWMDatabaseResult alloc] init];
    
    NSArray<NSString*> *statementComponents = [statement componentsSeparatedByString:@"?"];
    
    NSMutableString *mutableStatement = [[NSMutableString alloc] init];
    
    [statementComponents enumerateObjectsUsingBlock:^(NSString *_Nonnull str, NSUInteger idx, BOOL *stop){
        
        [mutableStatement appendString:str];
        
        if (idx < [criteria count]) {
            id value = criteria[idx];
            
            if ([value isKindOfClass:[NSString class]]) {
                NSString *stringNS = (NSString *)value;
                [mutableStatement appendString:stringNS];
            } else if ([value isKindOfClass:[NSNumber class]]){
                NSNumber *numberNS = (NSNumber *)value;
                [mutableStatement appendString:[numberNS stringValue]];
            }
        }
    }];
    
    databaseResult.statement = [NSString stringWithString:mutableStatement];
    
    /* instantiate object to contain the result */
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    
    /* prepare the statement object */
    sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, [statement UTF8String], -1, &sqlite3PreparedStatement, NULL);
    
    if (prepareCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorPreparingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = prepareCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(prepareCode)] = message;
        NSLog(@"*** %@ ***", message);
        NSDictionary *info = @{GWMDBStatementKey:databaseResult.statement};
        NSException *exception = [NSException exceptionWithName:GWMPreparingStatementException reason:message userInfo:info];
        @throw exception;
    } else {
        
        if (criteria && criteria.count > 0) {
            
            /* bind values to statement */
            [criteria enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:databaseResult preparedStatement:sqlite3PreparedStatement]];
        }
        
        int stepCode = GWMSQLiteResultRow;
        
        while (stepCode == GWMSQLiteResultRow) {
            
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            
            if (stepCode == GWMSQLiteResultDone)
                break;
            
            //TODO: step
            if (stepCode != GWMSQLiteResultRow) {
                
                NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorSteppingToRow,sqlite3_errmsg(self.database)];
                int extendedResultCode = sqlite3_extended_errcode(self.database);
                const char *extendedResultMessageC = sqlite3_errstr(extendedResultCode);
                databaseResult.resultCode = stepCode;
                databaseResult.resultMessage = message;
                databaseResult.errors[@(stepCode)] = message;
                databaseResult.extendedResultCode = extendedResultCode;
                databaseResult.extendedResultMessage = [NSString stringWithUTF8String:extendedResultMessageC];
                NSLog(@"*** %@ ***", message);
                
            } else {
                
                /*
                 1. each row has a class that will be used to contain the values from the row
                 2. each row can have a different class associated with than all the other rows have
                 3. the class name should always be returned by the first column
                 */
                int columnCount = sqlite3_column_count(sqlite3PreparedStatement);
                
                char *classNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, 0);
                NSString *classNameNS = [NSString stringWithUTF8String:classNameC];
                
                Class class = NSClassFromString(classNameNS);
                
                id obj = [[class alloc] init];
                
                // return the values from the sqlite table
                for (int index = 1; index < columnCount; index++) {
                    
                    int dataTypeI = sqlite3_column_type(sqlite3PreparedStatement, index);
                    
                    const char *declaredDataTypeC = sqlite3_column_decltype(sqlite3PreparedStatement, index);
                    
                    if (declaredDataTypeC == NULL) {
                        declaredDataTypeC = "TEXT";
                    }
                    
                    const char *columnNameC = sqlite3_column_name(sqlite3PreparedStatement, index);
                    NSString *columnNameNS = [NSString stringWithUTF8String:columnNameC];
                    
                    /*
                    Get the column names as understood by the SQL statement and use those to compare with the keys in the data object.
                    Should not compare with the objects in the columnKeys array!!!
                    */
                    
                    // Dates are stored in the database as a String but they will be stored in the custom class as a NSDate
                    
                    if ((!strcmp(declaredDataTypeC, "DATE_TIME") && dataTypeI != GWMDBDataTypeNull) || ([columnNameNS containsString:@"Date"] && ![columnNameNS containsString:@"String"])) {
                        
                        char *stringValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, index);
                        if (stringValueC != NULL) {
                            NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                            
                            NSDate *dateTimeD = [self dateWithFormat:GWMDBDateFormatDateTime string:stringValueNS andTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
                            
                            [obj setValue:dateTimeD forKey:columnNameNS];
                        }
                        
                    } else if ((!strcmp(declaredDataTypeC, "HISTORIC_DATE") && dataTypeI != GWMDBDataTypeNull) || ([columnNameNS containsString:@"Date"] && ![columnNameNS containsString:@"String"])) {
                        
                        //TODO: don't let a NULL cString through!
                        char *stringValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, index);
                        
                        if (stringValueC) {
                            
                            int stringValueLengthI = (int)strlen(stringValueC);
                            
                            NSString *dateFormatNS = nil;
                            NSTimeZone *timeZoneNS = [NSTimeZone localTimeZone];
                            
                            // determine and set the date format
                            switch (stringValueLengthI) {
                                    
                                case GWMDBDateStringLengthDateTime:
                                {
                                    dateFormatNS = GWMDBDateFormatDateTime;
                                    timeZoneNS = [NSTimeZone timeZoneWithName:@"UTC"];
                                    break;
                                }
                                case GWMDBDateStringLengthShortDate:
                                {
                                    dateFormatNS = GWMDBDateFormatShortDate;
                                    break;
                                }
                                case GWMDBDateStringLengthYearMonth:
                                {
                                    dateFormatNS = GWMDBDateFormatYearAndMonth;
                                    break;
                                }
                                case GWMDBDateStringLengthYearOnly:
                                {
                                    dateFormatNS = GWMDBDateFormatYear;
                                    break;
                                }
                                default:
                                    break;
                            }
                            
                            // set the value on the result object
                            if (stringValueLengthI == GWMDBDateStringLengthYearOnly) {
                                
                                NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                                [obj setValue:stringValueNS forKey:columnNameNS];
                                
                            } else {
                                
                                NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                                
                                NSDate *date = [self dateWithFormat:dateFormatNS string:stringValueNS andTimeZone:timeZoneNS];
                                
                                [obj setValue:date forKey:columnNameNS];
                            }
                        }
                        
                    } else {
                        
                        // TODO: sqlite data types IMPROVING
                        switch (dataTypeI) {
                            case GWMDBDataTypeInteger:{
                                
                                int integerValueI = sqlite3_column_int(sqlite3PreparedStatement, index);
                                
                                NSNumber *integerValueNS = nil;
                                
                                if (strcmp(declaredDataTypeC, "BOOLEAN") == 0) {
                                    
                                    BOOL boolValueB = integerValueI == 0 ? NO : YES;
                                    
                                    integerValueNS = [NSNumber numberWithBool:boolValueB];
                                    
                                } else {
                                    
                                    integerValueNS = [NSNumber numberWithInt:integerValueI];
                                    
                                }
                                
                                if ([obj respondsToSelector:NSSelectorFromString(columnNameNS)]) {
                                    [obj setValue:integerValueNS forKey:columnNameNS];
                                }
                                
                                break;
                            }
                            case GWMDBDataTypeFloat:{
                                
                                float floatValueF = sqlite3_column_double(sqlite3PreparedStatement, index);
                                NSNumber *floatValueNS = [NSNumber numberWithDouble:floatValueF];
                                [obj setValue:floatValueNS forKey:columnNameNS];
                                break;
                            }
                            case GWMDBDataTypeText:{
                                //TODO: check for custom data types: DATE, DATETIME
                                
                                char *stringValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, index);
                                NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                                
                                SEL selectorSEL = NSSelectorFromString(columnNameNS);
                                
                                if (![columnNameNS isEqualToString:@"class"]) {
                                    
                                    if (strcmp(declaredDataTypeC, "BOOLEAN") == 0) {
                                        
                                        NSNumber *integerValueNS = nil;
                                        
                                        BOOL boolValueB = ([stringValueNS isEqualToString:@"TRUE"] || [stringValueNS isEqualToString:@"true"]) ? YES : NO;
                                        
                                        integerValueNS = [NSNumber numberWithBool:boolValueB];
                                        
                                        if ([obj respondsToSelector:NSSelectorFromString(columnNameNS)])
                                            [obj setValue:integerValueNS forKey:columnNameNS];
                                        
                                    } else {
                                        
                                        if ([obj respondsToSelector:selectorSEL]) {
                                            
                                            [obj setValue:stringValueNS forKey:columnNameNS];
                                            
                                        } else {
                                            //TODO: Need to document why I did the following:
                                            obj = stringValueNS;
                                        }
                                        
                                    }
                                    
                                }
                                
                                break;
                            }
                            case GWMDBDataTypeBlob:{
                                
                                break;
                            }
                            case GWMDBDataTypeNull:{
                                
                                break;
                            }
                                
                            default:
                                break;
                        }
                    }
                }
                
                [resultArray addObject:obj];
            }
        }
    }
    //TODO: fix finalize error DONE
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorFinalizingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = finalizeCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(finalizeCode)] = message;
        NSLog(@"*** %@ ***", message);
        NSDictionary *info = @{GWMDBStatementKey:databaseResult.statement};
        NSException *exception = [NSException exceptionWithName:GWMFinalizingStatementException reason:message userInfo:info];
        @throw exception;
    }
    
    databaseResult.data = [NSArray arrayWithArray:resultArray];
    databaseResult.resultCode = prepareCode;
    databaseResult.resultMessage = [NSString stringWithFormat:@"%s",sqlite3_errmsg(self.database)];
    
    if (completionHandler) {
        completionHandler();
    }
    
    return databaseResult;
}

-(GWMDatabaseResult *)resultWithStatement:(NSString *)statement criteria:(NSArray<NSDictionary<GWMColumnName,id> *> *)criteriaValues exclude:(NSArray<__kindof GWMDataItem *> *)excludedItems sortBy:(GWMColumnName)sortBy ascending:(BOOL)ascending limit:(NSInteger)limit completion:(GWMDBCompletionBlock)completionHandler
{
    // build statement
    
    NSMutableString *mutableStatement = [NSMutableString new];
    [mutableStatement appendString:statement];
    
    // build the WHERE clause
    NSString *whereClause = nil;
    NSArray *whereValues = nil;
    if (criteriaValues) {
        
        NSMutableArray<NSString*> *mutableOrPredicates = [NSMutableArray<NSString*> new];
        NSMutableArray<NSString*> *mutableValues = [NSMutableArray<NSString*> new];
        
        [criteriaValues enumerateObjectsUsingBlock:^(NSDictionary<NSString*,id> *_Nonnull info, NSUInteger idx, BOOL *stop){
            
            NSMutableArray<NSString*> *mutableAndPredicates = [NSMutableArray<NSString*> new];
            
            [info enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, id val, BOOL *stop){
                [mutableValues addObject:val];
                NSString *predicate = [NSString stringWithFormat:@"%@ = ?", key];
                [mutableAndPredicates addObject:predicate];
            }];
            
            NSString *andPredicate = [[NSArray arrayWithArray:mutableAndPredicates] componentsJoinedByString:@" AND "];
            [mutableOrPredicates addObject:andPredicate];
            
        }];
        
        NSString *orPredicate = [[NSArray arrayWithArray:mutableOrPredicates] componentsJoinedByString:@") OR ("];
        NSString *finalOrPredicate = nil;
        if (mutableOrPredicates.count > 1)
            finalOrPredicate = [NSString stringWithFormat:@"(%@)", orPredicate];
        else
            finalOrPredicate = orPredicate;
        
        whereClause = [NSString stringWithFormat:@" WHERE %@", finalOrPredicate];
        whereValues = [NSArray arrayWithArray:mutableValues];
        
        [mutableStatement appendString:whereClause];
    }
    
    if (excludedItems) {
        NSMutableArray *mutableIDs = [NSMutableArray new];
        [excludedItems enumerateObjectsUsingBlock:^(GWMDataItem *_Nonnull obj, NSUInteger idx, BOOL *stop){
            [mutableIDs addObject:@(obj.itemID)];
        }];
        
        NSString *idString = [mutableIDs componentsJoinedByString:@", "];
        
        NSString *extendedWhereClause = [NSString stringWithFormat:@" AND pKey NOT IN (SELECT %@)", idString];
        [mutableStatement appendString:extendedWhereClause];
    }
    
    if (sortBy) {
        if (ascending)
            [mutableStatement appendString:[NSString stringWithFormat:@" ORDER BY %@ ASC", sortBy]];
        else
            [mutableStatement appendString:[NSString stringWithFormat:@" ORDER BY %@ DESC", sortBy]];
    }
    
    if (limit > 0) {
        NSString *LimitClause = [NSString stringWithFormat:@" LIMIT %li", (long)limit];
        [mutableStatement appendString:LimitClause];
    }
    
    NSString *finalStatement = [NSString stringWithString:mutableStatement];
    GWMDatabaseResult *databaseResult = [GWMDatabaseResult new];
    databaseResult.statement = finalStatement;
    
    sqlite3_stmt *sqlite3PreparedStatement;
    
    int prepareCode = sqlite3_prepare_v2(self.database, finalStatement.UTF8String, -1, &sqlite3PreparedStatement, NULL);
    
    /* instantiate object to contain the result */
    NSMutableArray *resultArray = [NSMutableArray new];
    
    if (prepareCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorPreparingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = prepareCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(prepareCode)] = message;
        NSLog(@"*** %@ ***", message);
        NSDictionary *info = @{GWMDBStatementKey:databaseResult.statement};
        NSException *exception = [NSException exceptionWithName:GWMPreparingStatementException reason:message userInfo:info];
        @throw exception;
    } else {
        
        /* bind values to statement */
        NSMutableArray *mutableValuesToBind = [NSMutableArray new];
        if(whereValues)
            [mutableValuesToBind addObjectsFromArray:whereValues];
        
        NSArray *valuesToBind = [NSArray arrayWithArray:mutableValuesToBind];
        
//        __block int bindCode = GWMSQLiteResultOK;
        
        [valuesToBind enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:databaseResult preparedStatement:sqlite3PreparedStatement]];
        
        int stepCode = GWMSQLiteResultRow;
        
        while (stepCode == GWMSQLiteResultRow) {
            
            stepCode = sqlite3_step(sqlite3PreparedStatement);
            
            if (stepCode == GWMSQLiteResultDone)
                break;
            
            //TODO: step
            if (stepCode != GWMSQLiteResultRow) {
                
                NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorSteppingToRow,sqlite3_errmsg(self.database)];
                int extendedResultCode = sqlite3_extended_errcode(self.database);
                const char *extendedResultMessageC = sqlite3_errstr(extendedResultCode);
                databaseResult.resultCode = stepCode;
                databaseResult.resultMessage = message;
                databaseResult.errors[@(stepCode)] = message;
                databaseResult.extendedResultCode = extendedResultCode;
                databaseResult.extendedResultMessage = [NSString stringWithUTF8String:extendedResultMessageC];
                NSLog(@"*** %@ ***", message);
                
            } else {
                
                /*
                 1. each row has a class that will be used to contain the values from the row
                 2. each row can have a different class associated with than all the other rows have
                 3. the class name should always be returned by the first column
                 */
                int columnCount = sqlite3_column_count(sqlite3PreparedStatement);
                
                NSString *classNameNS = nil;
                NSString *columnNameNS = nil;
                
                // find the 'class' column
                for (int idx = 0; idx < columnCount; idx++) {
                    const char *columnNameC = sqlite3_column_name(sqlite3PreparedStatement, idx);
                    columnNameNS = [NSString stringWithUTF8String:columnNameC];
                    if (![columnNameNS isEqualToString:GWMTableColumnClass])
                        continue;
                    
                    char *classNameC = (char *) sqlite3_column_text(sqlite3PreparedStatement, idx);
                    classNameNS = [NSString stringWithUTF8String:classNameC];
                    break;
                    
                }
                if (!classNameNS)
                    classNameNS = NSStringFromClass([GWMDataItem class]);
                
                Class class = NSClassFromString(classNameNS);
                
                id obj = [[class alloc] init];
                
                // return the values from the sqlite table
                for (int index = 1; index < columnCount; index++) {
                    
                    int dataTypeI = sqlite3_column_type(sqlite3PreparedStatement, index);
                    
                    const char *declaredDataTypeC = sqlite3_column_decltype(sqlite3PreparedStatement, index);
                    
                    if (declaredDataTypeC == NULL) {
                        declaredDataTypeC = "TEXT";
                    }
                    
                    const char *columnNameC = sqlite3_column_name(sqlite3PreparedStatement, index);
                    columnNameNS = [NSString stringWithUTF8String:columnNameC];
                    
                    /*
                     Get the column names as understood by the SQL statement and use those to compare with the keys in the data object.
                     Should not compare with the objects in the columnKeys array!!!
                     */
                    
                    // Dates are stored in the database as a String but they will be stored in the custom class as a NSDate
                    
                    if ((!strcmp(declaredDataTypeC, "DATE_TIME") && dataTypeI != GWMDBDataTypeNull) || ([columnNameNS containsString:@"Date"] && ![columnNameNS containsString:@"String"])) {
                        
                        char *stringValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, index);
                        if (stringValueC != NULL) {
                            NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                            
                            NSDate *dateTimeD = [self dateWithFormat:GWMDBDateFormatDateTime string:stringValueNS andTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
                            
                            [obj setValue:dateTimeD forKey:columnNameNS];
                        }
                        
                    } else if ((!strcmp(declaredDataTypeC, "HISTORIC_DATE") && dataTypeI != GWMDBDataTypeNull) || ([columnNameNS containsString:@"Date"] && ![columnNameNS containsString:@"String"])) {
                        
                        //TODO: don't let a NULL cString through!
                        char *stringValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, index);
                        
                        if (stringValueC) {
                            
                            int stringValueLengthI = (int)strlen(stringValueC);
                            
                            NSString *dateFormatNS = nil;
                            NSTimeZone *timeZoneNS = [NSTimeZone localTimeZone];
                            
                            // determine and set the date format
                            switch (stringValueLengthI) {
                                    
                                case GWMDBDateStringLengthDateTime:
                                {
                                    dateFormatNS = GWMDBDateFormatDateTime;
                                    timeZoneNS = [NSTimeZone timeZoneWithName:@"UTC"];
                                    break;
                                }
                                case GWMDBDateStringLengthShortDate:
                                {
                                    dateFormatNS = GWMDBDateFormatShortDate;
                                    break;
                                }
                                case GWMDBDateStringLengthYearMonth:
                                {
                                    dateFormatNS = GWMDBDateFormatYearAndMonth;
                                    break;
                                }
                                case GWMDBDateStringLengthYearOnly:
                                {
                                    dateFormatNS = GWMDBDateFormatYear;
                                    break;
                                }
                                default:
                                    break;
                            }
                            
                            // set the value on the result object
                            if (stringValueLengthI == GWMDBDateStringLengthYearOnly) {
                                
                                NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                                [obj setValue:stringValueNS forKey:columnNameNS];
                                
                            } else {
                                
                                NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                                
                                NSDate *date = [self dateWithFormat:dateFormatNS string:stringValueNS andTimeZone:timeZoneNS];
                                
                                [obj setValue:date forKey:columnNameNS];
                            }
                        }
                        
                    } else {
                        
                        // TODO: sqlite data types IMPROVING
                        switch (dataTypeI) {
                            case GWMDBDataTypeInteger:{
                                
                                int integerValueI = sqlite3_column_int(sqlite3PreparedStatement, index);
                                
                                NSNumber *integerValueNS = nil;
                                
                                if (strcmp(declaredDataTypeC, "BOOLEAN") == 0) {
                                    
                                    BOOL boolValueB = integerValueI == 0 ? NO : YES;
                                    
                                    integerValueNS = [NSNumber numberWithBool:boolValueB];
                                    
                                } else {
                                    
                                    integerValueNS = [NSNumber numberWithInt:integerValueI];
                                    
                                }
                                
                                if ([obj respondsToSelector:NSSelectorFromString(columnNameNS)]) {
                                    [obj setValue:integerValueNS forKey:columnNameNS];
                                }
                                
                                break;
                            }
                            case GWMDBDataTypeFloat:{
                                
                                float floatValueF = sqlite3_column_double(sqlite3PreparedStatement, index);
                                NSNumber *floatValueNS = [NSNumber numberWithDouble:floatValueF];
                                [obj setValue:floatValueNS forKey:columnNameNS];
                                break;
                            }
                            case GWMDBDataTypeText:{
                                //TODO: check for custom data types: DATE, DATETIME
                                
                                char *stringValueC = (char *) sqlite3_column_text(sqlite3PreparedStatement, index);
                                NSString *stringValueNS = [NSString stringWithUTF8String:stringValueC];
                                
                                SEL selectorSEL = NSSelectorFromString(columnNameNS);
                                
                                if (![columnNameNS isEqualToString:@"class"]) {
                                    
                                    if (strcmp(declaredDataTypeC, "BOOLEAN") == 0) {
                                        
                                        NSNumber *integerValueNS = nil;
                                        
                                        BOOL boolValueB = ([stringValueNS isEqualToString:@"TRUE"] || [stringValueNS isEqualToString:@"true"]) ? YES : NO;
                                        
                                        integerValueNS = [NSNumber numberWithBool:boolValueB];
                                        
                                        if ([obj respondsToSelector:NSSelectorFromString(columnNameNS)])
                                            [obj setValue:integerValueNS forKey:columnNameNS];
                                        
                                    } else {
                                        
                                        if ([obj respondsToSelector:selectorSEL]) {
                                            
                                            [obj setValue:stringValueNS forKey:columnNameNS];
                                            
                                        } else {
                                            //TODO: Need to document why I did the following:
                                            obj = stringValueNS;
                                        }
                                        
                                    }
                                    
                                }
                                
                                break;
                            }
                            case GWMDBDataTypeBlob:{
                                
                                break;
                            }
                            case GWMDBDataTypeNull:{
                                
                                break;
                            }
                                
                            default:
                                break;
                        }
                    }
                }
                
                [resultArray addObject:obj];
            }
        }
    }
    
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorFinalizingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = finalizeCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(finalizeCode)] = message;
        NSLog(@"*** %@ ***", message);
        NSDictionary *info = @{GWMDBStatementKey:databaseResult.statement};
        NSException *exception = [NSException exceptionWithName:GWMFinalizingStatementException reason:message userInfo:info];
        @throw exception;
    }
    
    databaseResult.data = [NSArray arrayWithArray:resultArray];
    databaseResult.resultCode = prepareCode;
    databaseResult.resultMessage = [NSString stringWithFormat:@"%s",sqlite3_errmsg(self.database)];
    
    if (completionHandler) {
        completionHandler();
    }
    
    return databaseResult;
}

#pragma mark Update

-(GWMDatabaseResult *)updateTable:(GWMTableName)tableName withValues:(NSDictionary<GWMColumnName,NSObject *> *)newValues criteria:(NSDictionary<GWMColumnName,NSObject *> *)criteria completion:(GWMDatabaseResultBlock)completionHandler
{
    return [self updateTable:tableName withValues:newValues criteria:criteria onConflict:GWMDBOnConflictAbort completion:completionHandler];

}

-(GWMDatabaseResult *)updateTable:(GWMTableName)tableName withValues:(NSDictionary<GWMColumnName,NSObject *> *)newValues criteria:(NSDictionary<GWMColumnName,NSObject *> *)criteria onConflict:(GWMDBOnConflict)onConflict completion:(GWMDatabaseResultBlock)completionHandler
{
    // conflict resolution
    NSString *conflict = [self stringWithConflict:onConflict];
    
    // create the results object
    GWMDatabaseResult *databaseResult = [[GWMDatabaseResult alloc] init];
    __block NSError *error = nil;
    // assemble the statement
    NSMutableArray<NSString*> *mutableComponents = [NSMutableArray new];
    NSMutableArray *mutableValues = [NSMutableArray new];
    [newValues enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSObject *_Nonnull value, BOOL *stop){
        
        if ([value isKindOfClass:[NSNull class]]) {
            NSString *component = [NSString stringWithFormat:@"%@ IS ?", key];
            [mutableComponents addObject:component];
            [mutableValues addObject:value];
        } else {
            NSString *component = [NSString stringWithFormat:@"%@ = ?", key];
            [mutableComponents addObject:component];
            [mutableValues addObject:value];
        }
        
    }];
    NSString *valuesClause = [mutableComponents componentsJoinedByString:@", "];
    
    NSString *statementNS;
    
    // note: there may or may not be any criteria
    NSMutableArray *mutableCriteriaValues = [NSMutableArray new];
    if (criteria && criteria.count > 0) {
        NSMutableArray<NSString*> *mutableCriteriaComponents = [NSMutableArray new];
        [criteria enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSObject *_Nonnull value, BOOL *stop){
            NSString *component = [NSString stringWithFormat:@"%@ = ?", key];
            [mutableCriteriaComponents addObject:component];
            [mutableCriteriaValues addObject:value];
        }];
        NSString *criteriaClause = [mutableCriteriaComponents componentsJoinedByString:@" OR "];
        
        statementNS = [NSString stringWithFormat:@"UPDATE %@ %@ SET %@ WHERE %@", conflict, tableName, valuesClause, criteriaClause];
    } else {
        statementNS = [NSString stringWithFormat:@"UPDATE %@ %@ SET %@", conflict, tableName, valuesClause];
    }
    
    databaseResult.statement = statementNS;
    
    // prepare the statement
    sqlite3_stmt *sqlite3PreparedStatement;
    
    const char *statementC = [statementNS UTF8String];
    int prepareCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, NULL);
    
    if (prepareCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorPreparingStatement,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = prepareCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(prepareCode)] = message;
        NSLog(@"*** %@ ***", message);
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        NSDictionary *info = @{GWMDBStatementKey:databaseResult.statement};
        NSException *exception = [NSException exceptionWithName:GWMPreparingStatementException reason:message userInfo:info];
        @throw exception;
    } else {
        // bind the values. the columns values can all be bound.
        
        /* bind values to statement */
        NSMutableArray *mutableValuesToBind = [NSMutableArray new];
        [mutableValuesToBind addObjectsFromArray:mutableValues];
        [mutableValuesToBind addObjectsFromArray:mutableCriteriaValues];
        
        NSArray *valuesToBind = [NSArray arrayWithArray:mutableValuesToBind];
        
        //        __block int bindCode = GWMSQLiteResultOK;
        
        [valuesToBind enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:databaseResult preparedStatement:sqlite3PreparedStatement]];
    }
    
    int stepCode = sqlite3_step(sqlite3PreparedStatement);
    if (stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone) {
        NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
    };
    
    // finalize the prepared statement
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: %s", GWMSQLiteErrorSteppingToRow,sqlite3_errmsg(self.database)];
        databaseResult.resultCode = finalizeCode;
        databaseResult.resultMessage = message;
        databaseResult.errors[@(finalizeCode)] = message;
        NSLog(@"*** %@ ***", message);
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        NSDictionary *info = @{GWMDBStatementKey:databaseResult.statement};
        NSException *exception = [NSException exceptionWithName:GWMFinalizingStatementException reason:message userInfo:info];
        @throw exception;
    }
    
    NSString *statement = [NSString stringWithFormat:@"SELECT '%@' AS class, pKey AS itemID FROM %@", NSStringFromClass([GWMDataItem class]), tableName];
    
    //    [self resultWithStatement:statement criteria:@[criteria] exclude:nil limit:1 completion:nil completion:nil];
    NSArray *criteriaValues = nil;
    if (criteria)
        criteriaValues = @[criteria];
    GWMDatabaseResult *result = [self resultWithStatement:statement criteria:criteriaValues exclude:nil sortBy:@"updated" ascending:NO limit:1 completion:nil];
    GWMDataItem *obj = result.data.firstObject;
    
    // run completion handler
    if(completionHandler)
        completionHandler(obj,error);
    
    return databaseResult;
    
}

#pragma mark Delete

-(void)deleteFromTable:(GWMTableName)table criteria:(NSArray<NSDictionary<GWMColumnName,NSObject *> *> *)criteria completion:(GWMDBErrorCompletionBlock)completionHandler
{
    //TODO: Implement new delete method
    NSMutableString *mutableWhereClause = [[NSMutableString alloc] init];
    
    // build the WHERE clause
    NSString *whereClause = nil;
    NSArray *whereValues = nil;
    if (criteria) {
        
        NSMutableArray<NSString*> *mutableOrPredicates = [NSMutableArray<NSString*> new];
        NSMutableArray<NSString*> *mutableValues = [NSMutableArray<NSString*> new];
        
        [criteria enumerateObjectsUsingBlock:^(NSDictionary<NSString*,id> *_Nonnull info, NSUInteger idx, BOOL *stop){
            
            NSMutableArray<NSString*> *mutableAndPredicates = [NSMutableArray<NSString*> new];
            
            [info enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, id val, BOOL *stop){
                [mutableValues addObject:val];
                
                NSString *predicate = nil;
                // support other comparisons besides 'equals'
                if ([key containsString:@"?"])
                    predicate = key;
                else
                    predicate = [NSString stringWithFormat:@"%@ = ?", key];
                [mutableAndPredicates addObject:predicate];
            }];
            
            NSString *andPredicate = [[NSArray arrayWithArray:mutableAndPredicates] componentsJoinedByString:@" AND "];
            [mutableOrPredicates addObject:andPredicate];
            
        }];
        
        NSString *orPredicate = [[NSArray arrayWithArray:mutableOrPredicates] componentsJoinedByString:@") OR ("];
        NSString *finalOrPredicate = nil;
        if (mutableOrPredicates.count > 1)
            finalOrPredicate = [NSString stringWithFormat:@"(%@)", orPredicate];
        else
            finalOrPredicate = orPredicate;
        
        whereClause = [NSString stringWithFormat:@" WHERE %@", finalOrPredicate];
        whereValues = [NSArray arrayWithArray:mutableValues];
        
        [mutableWhereClause appendString:whereClause];
    }
    
    NSMutableString *mutableStatement = [[NSMutableString alloc] init];
    
    [mutableStatement appendString:[NSString stringWithFormat:@"DELETE FROM %@ ",table]];
    
    if (whereClause) {
        [mutableStatement appendString:whereClause];
    }
    
    NSString *statement = [NSString stringWithString:mutableStatement];
    
    sqlite3_stmt *sqlite3PreparedStatement; // database prepared statment
    
    const char *statementC = [statement UTF8String];
    
    int prepareCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, NULL);
    if (prepareCode != GWMSQLiteResultOK) {
        NSLog(@"%@: %s", GWMSQLiteErrorPreparingStatement, sqlite3_errmsg(self.database));
        NSString *message = [NSString stringWithFormat:@"%s", statementC];
        NSDictionary *info = @{GWMDBStatementKey:statement};
        NSException *exception = [NSException exceptionWithName:GWMPreparingStatementException reason:message userInfo:info];
        @throw exception;
    }
    else {
        
        sqlite3_exec(self.database, "BEGIN TRANSACTION", NULL, NULL, NULL);
        
        GWMDatabaseResult *databaseResult = [[GWMDatabaseResult alloc] init];
        databaseResult.statement = statement;
        [whereValues enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:databaseResult preparedStatement:sqlite3PreparedStatement]];
        
        int stepCode = sqlite3_step(sqlite3PreparedStatement);
        
        if (stepCode != GWMSQLiteResultRow && stepCode != GWMSQLiteResultDone)
            NSLog(@"%@: %s", GWMSQLiteErrorSteppingToRow, sqlite3_errmsg(self.database));
        
        sqlite3_exec(self.database, "END TRANSACTION", NULL, NULL, NULL);
        
    }
    
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    if (finalizeCode != GWMSQLiteResultOK) {
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
        NSString *message = [NSString stringWithFormat:@"%s", statementC];
        NSDictionary *info = @{GWMDBStatementKey:statement};
        NSException *exception = [NSException exceptionWithName:GWMFinalizingStatementException reason:message userInfo:info];
        @throw exception;
    }
    
    if(completionHandler)
        completionHandler(nil);
    
}

//int callback(void *arg, int argc, char **argv, char **colName) {
//    int i;
//    for(i=0; i<argc; i++){
//        printf("%s = %s\t", colName[i], argv[i] ?  : "NULL");
//    }
//    printf("\n");
//    return 0;
//}

#pragma mark - Convenience

-(void)migrateDataFromTable:(GWMTableName)fromTable fromSchema:(GWMSchemaName)fromSchema toTable:(GWMTableName)toTable toSchema:(GWMSchemaName)toSchema columns:(NSDictionary<GWMColumnName,GWMColumnName> *)columnInfo values:(NSDictionary<GWMColumnName,id> * _Nullable)valueInfo completion:(GWMDBErrorCompletionBlock _Nullable)completionHandler
{
    if (!fromTable) {
        NSString *message = [NSString stringWithFormat:@"%@", @"From table cannot be nil."];
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if(completionHandler)
            completionHandler(error);
        return;
    }
    
    if (!toTable) {
        NSString *message = [NSString stringWithFormat:@"%@", @"To table cannot be nil."];
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if(completionHandler)
            completionHandler(error);
        return;
    }
    
    if ([toTable isEqualToString:fromTable] && [toSchema isEqualToString:fromSchema]) {
        NSString *message = [NSString stringWithFormat:@"%@", @"'To' table cannot be equal to 'from' table."];
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey:message};
        NSError *error = [NSError errorWithDomain:GWMErrorDomainDatabase code:1 userInfo:errorInfo];
        if(completionHandler)
            completionHandler(error);
        return;
    }
    
    // do migration here
    // INSERT INTO <new-table> (<new-table-columns>) SELECT <old-table-columns> FROM <old-table>
    
    NSMutableArray<NSString*> *toColumns = [NSMutableArray new];
    NSMutableArray<NSString*> *fromColumns = [NSMutableArray new];
    NSMutableArray<id> *mutableValues = [NSMutableArray new];
    
    [columnInfo enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull toCol, NSString *_Nonnull fromCol, BOOL *stop){
        [toColumns addObject:toCol];
        [fromColumns addObject:fromCol];
    }];
    
    NSString *toColumnString = [toColumns componentsJoinedByString:@", "];
    NSString *fromColumnString = [fromColumns componentsJoinedByString:@", "];
    NSString *valuesString = nil;
    if(mutableValues.count > 0)
        valuesString = [mutableValues componentsJoinedByString:@", "];
    
    if(valuesString)
        fromColumnString = [NSString stringWithFormat:@"%@, %@",fromColumnString,valuesString];
    
    if(!toSchema)
        toSchema = GWMSchemaNameMain;
    
    if(!fromSchema)
        fromSchema = GWMSchemaNameMain;
    
    NSString *statement = [NSString stringWithFormat:@"INSERT INTO %@.%@ (%@) SELECT %@ FROM %@.%@", toSchema,toTable, toColumnString, fromColumnString, fromSchema, fromTable];
    
    NSError *error = nil;
    
    @try {
        [self processStatement:statement];
    } @catch (NSException *exception) {
        error = [[NSError alloc] initWithDomain:GWMErrorDomainDatabase code:0 userInfo:exception.userInfo];
    } @finally {
        if(completionHandler)
            completionHandler(error);
    }
}

#pragma mark - Transactions

-(BOOL)applyStatements:(NSArray<NSString *> *)statements identifier:(NSString *)identifier completion:(GWMDBCompletionBlock)completion
{
    if(!statements)
        return NO;

    self.transactionName = identifier;
    self.isTransactionInProgress = YES;
    
    NSMutableArray *mutableStatements = [NSMutableArray new];
    
    [mutableStatements addObject:@"BEGIN TRANSACTION"];
    [mutableStatements addObjectsFromArray:statements];
    [mutableStatements addObject:@"END TRANSACTION"];
    
    NSString *statement = [mutableStatements componentsJoinedByString:@";"];
    
    char *errorMessageC;
    NSLog(@"*** Transaction started: '%@' ***", identifier);
    int executeCode = sqlite3_exec(self.database, statement.UTF8String, NULL, NULL, &errorMessageC);

    if (executeCode != GWMSQLiteResultOK) {
        NSString *message = [NSString stringWithFormat:@"%@: '%@' Message: %s Database: '%@'", GWMSQLiteErrorExecutingStatement, identifier, errorMessageC, self.databasePath];
        NSLog(@"%@", message);
        sqlite3_free(errorMessageC);
        NSDictionary *info = @{GWMDBStatementKey:statement};
        NSException *exception = [NSException exceptionWithName:GWMExecutingStatementException reason:message userInfo:info];
        @throw exception;
    }
    NSLog(@"*** Transaction finished: '%@' ***", identifier);
    
    self.isTransactionInProgress = NO;
    self.transactionName = nil;

    if(completion)
        completion();
    
    return YES;
}

-(NSInteger)countOfRecordsFromTable:(GWMTableName)table column:(GWMColumnName)column criteria:(NSArray<NSDictionary<GWMColumnName,id> *> *)criteria
{
    NSInteger qty = 0;
    
    NSMutableString *mutableStatement = [NSMutableString stringWithFormat:@"SELECT count(%@) FROM %@ ",column,table];
    GWMWhereClauseItem *container = [self whereClauseWithCriteria:criteria];
    if(criteria){
        
        NSString *whereClause = container.whereClause;
        [mutableStatement appendString:whereClause];
    }
    
    NSString *statement = [NSString stringWithString:mutableStatement];
    
    const char *statementC = [statement UTF8String];
    
    sqlite3_stmt *sqlite3PreparedStatement;
    
    int dbReturnCode; // database return code
    
    
    dbReturnCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, nil);
    if (dbReturnCode == SQLITE_OK) {
        
        /* bind values to statement */
        NSMutableArray *mutableValuesToBind = [NSMutableArray new];
        if(container.whereValues)
            [mutableValuesToBind addObjectsFromArray:container.whereValues];
        
        NSArray *valuesToBind = [NSArray arrayWithArray:mutableValuesToBind];
        
        //        __block int bindCode = GWMSQLiteResultOK;
        GWMDatabaseResult *result = [GWMDatabaseResult new];
        [valuesToBind enumerateObjectsUsingBlock:[self bindValuesEnumerationBlockWithResult:result preparedStatement:sqlite3PreparedStatement]];
        
        while (sqlite3_step(sqlite3PreparedStatement) == SQLITE_ROW) {
            // return values from sqlite tables
            qty = sqlite3_column_int(sqlite3PreparedStatement, 0);
        }
    }
    
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    
    if (finalizeCode != SQLITE_OK) {
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    }
    
    return qty;
}

-(NSInteger)countOfRecordsWithStatment:(NSString *_Nonnull)statement
{
    [self openDatabase];
    
    NSInteger qty = 0;
    
    const char *statementC = [statement UTF8String];
    
    sqlite3_stmt *sqlite3PreparedStatement;
    
    int dbReturnCode; // database return code
    
    
    dbReturnCode = sqlite3_prepare_v2(self.database, statementC, -1, &sqlite3PreparedStatement, nil);
    if (dbReturnCode == SQLITE_OK)
    {
        while (sqlite3_step(sqlite3PreparedStatement) == SQLITE_ROW)
        {
            // return values from sqlite tables
            qty = sqlite3_column_int(sqlite3PreparedStatement, 0);
        }
    }
    
    int finalizeCode = sqlite3_finalize(sqlite3PreparedStatement);
    
    if (finalizeCode != SQLITE_OK) {
        NSLog(@"%@: %s", GWMSQLiteErrorFinalizingStatement, sqlite3_errmsg(self.database));
    }
    
    return qty;
}

@end
