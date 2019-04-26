//
//  GWMRelationshipItem.h
//  GWMKit
//
//  Created by Gregory Moore on 4/26/18.
//  Copyright © 2018 Gregory Moore. All rights reserved.
//

#import "GWMDataItem.h"

NS_ASSUME_NONNULL_BEGIN

///@brief Represents the 'itemKey' column in a SQLite table.
extern GWMColumnName const GWMTableColumnDataItemKey;
///@brief Represents the 'relatedItemKey' column in a SQLite table.
extern GWMColumnName const GWMTableColumnRelatedDataItemKey;
///@brief Represents the 'relationshipKey' column in a SQLite table.
extern GWMColumnName const GWMTableColumnRelationshipKey;
/*!
 * @class GWMRelationshipItem
 * @discussion A GWMRelationshipItem object represents a row in a database relationship table. This class is usable as is, but you might wish to create a custom subclass.
 */
@interface GWMRelationshipItem : GWMDataItem

@property (nonatomic, assign) NSInteger dataItemID;
@property (nonatomic, assign) NSInteger relatedDataItemID;
@property (nonatomic, assign) NSInteger relationshipID;

+(instancetype)relationshipItemWithDataID:(NSInteger)dataID relatedID:(NSInteger)relatedID;

-(instancetype)initWithDataID:(NSInteger)dataID relatedID:(NSInteger)relatedID;

@end

NS_ASSUME_NONNULL_END
