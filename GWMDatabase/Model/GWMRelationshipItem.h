//
//  GWMRelationshipItem.h
//  GWMKit
//
//  Created by Gregory Moore on 4/26/18.
//  Copyright © 2018 Gregory Moore. All rights reserved.
//

#import "GWMDataItem.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const GWMTableColumnDataItemKey;
extern NSString * const GWMTableColumnRelatedDataItemKey;
extern NSString * const GWMTableColumnRelationshipKey;

@interface GWMRelationshipItem : GWMDataItem

@property (nonatomic, assign) NSInteger dataItemID;
@property (nonatomic, assign) NSInteger relatedDataItemID;
@property (nonatomic, assign) NSInteger relationshipID;

@end

NS_ASSUME_NONNULL_END
