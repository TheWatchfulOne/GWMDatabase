//
//  GWMDatabaseResult.h
//  GWMKit
//
//  Created by Gregory Moore on 8/30/15.
//
//

@import Foundation;
#import <sqlite3.h>

#pragma mark SQLite Result Codes
// https://sqlite.org/c3ref/c_abort.html
typedef NS_ENUM(NSInteger, GWMSQLiteResult) {
    GWMSQLiteResultOK = SQLITE_OK,
    GWMSQLiteResultError = SQLITE_ERROR,
    GWMSQLiteResultBusy = SQLITE_BUSY,
    GWMSQLiteResultRow = SQLITE_ROW,
    GWMSQLiteResultDone = SQLITE_DONE,
    GWMSqliteResultCantOpenDatabase = SQLITE_CANTOPEN
};

NS_ASSUME_NONNULL_BEGIN

/*!
 * @class GWMDatabaseResult
 * @discussion A container class. An instance of GWMDatabaseResult is returned when a query is executed against a SQLite database using a GWMDatabaseController.
 */
@interface GWMDatabaseResult : NSObject {
    
    NSMutableDictionary<NSNumber*,NSString*> *_errors;
}

///@discussion An NSString representation of the SQLite statement that was executed by the query. The string returned by this property has any criteria values included in it for convenience. The actual statement that is executed uses the SQLite binding API to attach the values.
@property NSString *_Nullable statement;
///@discussion An NSArray containing the query results.
@property NSArray *_Nullable data;
///@discussion An NSString representation of the result message returned from SQLite.
@property NSString *_Nullable resultMessage;
///@discussion The result code returned from SQLite.
@property GWMSQLiteResult resultCode;
///@discussion An NSString representation of the extended result message returned from SQLite.
@property NSString *_Nullable extendedResultMessage;
///@discussion The extended result code returned from SQLite.
@property NSInteger extendedResultCode;
///@discussion An NSMutableDictionary containing errors from SQLite where the key is the code and the value is the message.
@property (nonatomic, readonly) NSMutableDictionary<NSNumber*,NSString*> *errors;

@end

NS_ASSUME_NONNULL_END
