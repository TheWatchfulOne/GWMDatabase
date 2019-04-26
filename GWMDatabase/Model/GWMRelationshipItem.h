//
//  GWMRelationshipItem.h
//  GWMKit
//
//  Created by Gregory Moore on 4/26/18.
//  Copyright © 2018 Gregory Moore. All rights reserved.
//

#import "GWMDataItem.h"

NS_ASSUME_NONNULL_BEGIN

extern GWMColumnName const GWMTableColumnDataItemKey;
extern GWMColumnName const GWMTableColumnRelatedDataItemKey;
extern GWMColumnName const GWMTableColumnRelationshipKey;

@interface GWMRelationshipItem : GWMDataItem

@property (nonatomic, assign) NSInteger dataItemID;
@property (nonatomic, assign) NSInteger relatedDataItemID;
@property (nonatomic, assign) NSInteger relationshipID;

+(instancetype)relationshipItemWithDataID:(NSInteger)dataItemID relatedID:(NSInteger)relatedID;

-(instancetype)initWithDataID:(NSInteger)dataID relatedID:(NSInteger)relatedID;

@end

NS_ASSUME_NONNULL_END
