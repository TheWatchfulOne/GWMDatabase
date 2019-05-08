//
//  GWMDatabaseHelperItems.m
//  GWMKit
//
//  Created by Gregory Moore on 11/16/18.
//  Copyright © 2018 Gregory Moore. All rights reserved.
//

#import "GWMDatabaseHelperItems.h"
#import "GWMDatabaseController.h"
#import "GWMDataItem.h"

@implementation GWMWhereClauseItem

@end

@interface GWMColumnDefinition ()

@property (nonatomic, readonly) GWMDatabaseController *_Nonnull databaseController;

@end

@implementation GWMColumnDefinition

-(GWMDatabaseController *)databaseController
{
    return [GWMDatabaseController sharedController];
}

+(instancetype)columnDefinitionWithName:(GWMColumnName)name affinity:(GWMColumnAffinity)affinity defaultValue:(NSString *)defaultValue property:(NSString *)property include:(GWMColumnInclusion)include options:(GWMColumnOption)options className:(NSString * _Nullable)className sequence:(NSInteger)sequence
{
    return [[self alloc] initWithName:name affinity:affinity defaultValue:defaultValue property:property include:include options:options className:className sequence:sequence];
}

-(instancetype)initWithName:(GWMColumnName)name affinity:(GWMColumnAffinity)affinity defaultValue:(NSString *_Nullable)defaultValue property:(NSString *)property include:(GWMColumnInclusion)include options:(GWMColumnOption)options className:(NSString * _Nullable)className sequence:(NSInteger)sequence
{
    if (self = [super init]) {
        _name = name;
        _affinity = affinity;
        _defaultValue = defaultValue;
        _property = property;
        _include = include;
        _options = options;
        _className = className;
        _sequence = sequence;
    }
    return self;
}

-(NSString *)createString
{
    if ([self.property isEqualToString:GWMTableColumnClass] || ([self.name hasPrefix:@"'"] && [self.name hasSuffix:@"'"]))
        return nil;
    
    NSString *createString = [NSString stringWithFormat:@"%@ %@", self.name,self.affinity];
    
    if(self.options &GWMColumnOptionNone)
        return createString;
    
    NSMutableString *mutableCreate = [[NSMutableString alloc] initWithString:createString];
    
    if (self.options &GWMColumnOptionNotNull)
       [mutableCreate appendString:@" NOT NULL"];
    
    if (self.options &GWMColumnOptionPrimaryKey)
        [mutableCreate appendString:@" PRIMARY KEY"];
    
    if (self.options &GWMColumnOptionAutoIncrement)
        [mutableCreate appendString:@" AUTOINCREMENT"];
    
    if (self.defaultValue)
        [mutableCreate appendString:[NSString stringWithFormat:@" DEFAULT %@", self.defaultValue]];
    
    return [NSString stringWithString:mutableCreate];
}

-(NSString *)selectString
{
    if (self.className && ![self.property isEqualToString:GWMTableColumnClass]) {
        Class<GWMDataItem> item = NSClassFromString(self.className);
        NSString *alias = [item tableAlias];
        return [NSString stringWithFormat:@"%@.%@ AS %@", alias,self.name,self.property];
    }
    return [NSString stringWithFormat:@"%@ AS %@",self.name,self.property];
}

@end

@implementation GWMTableConstraintDefinition

+(instancetype)tableConstraintWithName:(GWMConstraintName)name style:(GWMConstraintStyle)style columns:(NSArray<GWMColumnName> *)columns referenceTable:(GWMTableName _Nullable)refTable referenceColumn:(GWMColumnName _Nullable)refColumn onConflict:(GWMDBOnConflict)onConflict
{
    return [[self alloc] initWithName:name style:style columns:columns referenceTable:refTable referenceColumn:refColumn onConflict:onConflict];
}

-(instancetype)initWithName:(GWMConstraintName)name style:(GWMConstraintStyle)style columns:(NSArray<GWMColumnName> *)columns referenceTable:(GWMTableName _Nullable)refTable referenceColumn:(GWMColumnName _Nullable)refColumn onConflict:(GWMDBOnConflict)onConflict
{
    if (self = [super init]) {
        _name = name;
        _style = style;
        _columns = columns;
        _referenceTable = refTable;
        _referenceColumn= refColumn;
        _onConflict = onConflict;
    }
    return self;
}

-(NSString *)body
{
    NSMutableString *mutableString = [NSMutableString stringWithFormat:@"CONSTRAINT %@",self.name];
    switch (self.style) {
        case GWMConstraintPrimaryKey:{
            // CONSTRAINT %@ PRIMARY KEY
            NSMutableString *mutableColumnString = [NSMutableString stringWithString: [self.columns componentsJoinedByString:@", "]];
            [mutableString appendFormat:@" PRIMARY KEY (%@)",[NSString stringWithString:mutableColumnString]];
            break;
        }
        case GWMConstraintForeignKey:
            // CONSTRAINT %@ FOREIGN KEY (%@) REFERENCES Marker (markerKey) ON DELETE SET NULL ON UPDATE CASCADE
            [mutableString appendFormat:@" FOREIGN KEY (%@) REFERENCES %@ (%@)",self.columns.firstObject,self.referenceTable,self.referenceColumn];
            break;
        case GWMConstraintCheck:
            // CONSTRAINT %@ CHECK (%@)
            [mutableString appendFormat:@" CHECK (%@)",@""];
            break;
        case GWMConstraintUnique:{
            // CONSTRAINT %@ UNIQUE (%@ ASC, %@ ASC, %@ ASC) ON CONFLICT IGNORE
            NSMutableString *mutableColumnString = [NSMutableString stringWithString: [self.columns componentsJoinedByString:@" ASC, "]];
            [mutableColumnString appendString:@" ASC"];
            [mutableString appendFormat:@" UNIQUE (%@)",[NSString stringWithString:mutableColumnString]];
            break;
        }
        default:
            break;
    }
    
    if (self.style == GWMConstraintPrimaryKey || self.style == GWMConstraintUnique) {
        switch (self.onConflict) {
            case GWMDBOnConflictRollback:
                [mutableString appendString: @" ON CONFLICT ROLLBACK"];
                break;
            case GWMDBOnConflictAbort:
                [mutableString appendString: @" ON CONFLICT ABORT"];
                break;
            case GWMDBOnConflictFail:
                [mutableString appendString: @" ON CONFLICT FAIL"];
                break;
            case GWMDBOnConflictIgnore:
                [mutableString appendString: @" ON CONFLICT IGNORE"];
                break;
            case GWMDBOnConflictReplace:
                [mutableString appendString: @" ON CONFLICT REPLACE"];
                break;
            default:
                [mutableString appendString: @" ON CONFLICT ABORT"];
                break;
        }
    } else if (self.style == GWMConstraintForeignKey){
        [mutableString appendString: @" ON UPDATE CASCADE ON DELETE SET NULL"];
    }
    
    return [NSString stringWithString:mutableString];
}

@end

@implementation GWMTableDefinition

+(instancetype)tableDefinitionWithTable:(GWMTableName)table alias:(GWMTableAlias)alias schema:(GWMSchemaName)schema
{
    return [[self alloc] initWithTable:table alias:alias schema:schema];
}

-(instancetype)initWithTable:(GWMTableName)table alias:(GWMTableAlias)alias schema:(GWMSchemaName)schema
{
    if (self = [super init]) {
        _table = table;
        _alias = alias;
        _schema = schema;
    }
    return self;
}

@end

@implementation GWMIndexDefinition

+(instancetype)indexDefintionWithName:(GWMIndexName)name table:(GWMTableName)table schema:(GWMSchemaName)schema columns:(NSArray<GWMColumnName> *)columns where:(NSString *)whereExpression unique:(BOOL)isUnique
{
    return [[self alloc] initWithName:name table:table schema:schema columns:columns where:whereExpression unique:isUnique];
}

-(instancetype)initWithName:(GWMIndexName)name table:(GWMTableName)table schema:(GWMSchemaName)schema columns:(NSArray<GWMColumnName> *)columns where:(NSString *)whereExpression unique:(BOOL)isUnique
{
    if (self = [super init]) {
        _name = name;
        _table = table;
        _schema = schema;
        _columns = columns;
        _whereExpression = whereExpression;
        _isUnique = isUnique;
    }
    return self;
}

-(NSString *)indexCreationString
{
    NSMutableString *mutableString = nil;
    if (self.isUnique)
        mutableString = [[NSMutableString alloc] initWithString:@"CREATE UNIQUE INDEX IF NOT EXISTS"];
    else
        mutableString = [[NSMutableString alloc] initWithString:@"CREATE INDEX IF NOT EXISTS"];
    
    if(self.schema)
        [mutableString appendString:[NSString stringWithFormat:@" %@.%@ ON", self.schema, self.name]];
    else
        [mutableString appendString:[NSString stringWithFormat:@" %@ ON", self.name]];
    
    NSString *columnString = [self.columns componentsJoinedByString:@", "];
    
    [mutableString appendFormat:@" %@ (%@)",self.table, columnString];
    
    if (self.whereExpression)
        [mutableString appendFormat:@" %@",self.whereExpression];
    
    return [NSString stringWithString:mutableString];
}

@end

@implementation GWMTriggerDefinition

+(instancetype)triggerDefinitionWithName:(GWMTriggerName)name schema:(GWMSchemaName)schema table:(GWMTableName)table timing:(GWMTriggerTiming)timing style:(GWMTriggerStyle)style when:(NSString *)when columns:(NSArray<GWMColumnName> *)columns body:(NSString *)body
{
    return [[self alloc] initWithName:name schema:schema table:table timing:timing style:style when:when columns:columns body:body];
}

-(instancetype)initWithName:(GWMTriggerName)name schema:(GWMSchemaName)schema table:(GWMTableName)table timing:(GWMTriggerTiming)timing style:(GWMTriggerStyle)style when:(NSString *)when columns:(NSArray<GWMColumnName> *)columns body:(NSString *)body
{
    if (self = [super init]) {
        _name = name;
        _schema = schema;
        _table = table;
        _timing = timing;
        _style = style;
        _whenExpression = when;
        _columns = columns;
        _body = body;
    }
    return self;
}

-(NSString *)triggerString
{
    NSMutableString *mutableString = [[NSMutableString alloc] initWithString:@"CREATE TRIGGER IF NOT EXISTS"];
    if(self.schema)
        [mutableString appendString:[NSString stringWithFormat:@" %@.%@", self.schema, self.name]];
    else
        [mutableString appendString:[NSString stringWithFormat:@" %@", self.name]];
    
    switch (self.timing) {
        case GWMTriggerBefore:
            [mutableString appendString:@" BEFORE"];
            break;
        case GWMTriggerAfter:
            [mutableString appendString:@" AFTER"];
            break;
        case GWMTriggerInsteadOf:
            [mutableString appendString:@" INSTEAD OF"];
            break;
        case GWMTriggerUnspecified:
            break;
        default:
            break;
    }
    
    switch (self.style) {
        case GWMTriggerInsert:
            [mutableString appendString:@" INSERT"];
            break;
        case GWMTriggerUpdate:
            [mutableString appendString:@" UPDATE"];
            break;
        case GWMTriggerDelete:
            [mutableString appendString:@" DELETE"];
            break;
            
        default:
            break;
    }
    // columns
    if (self.style == GWMTriggerUpdate) {
        [self.columns enumerateObjectsUsingBlock:^(NSString *_Nonnull col, NSUInteger idx, BOOL *stop){
            if (idx == 0)
                [mutableString appendString:[NSString stringWithFormat:@" OF %@",col]];
            else
                [mutableString appendString:[NSString stringWithFormat:@", %@",col]];
        }];
    }
    
    // table
    [mutableString appendString:[NSString stringWithFormat:@" ON %@",self.table]];
    
    [mutableString appendString:@" FOR EACH ROW"];
    
    if (self.whenExpression)
        [mutableString appendString:[NSString stringWithFormat:@" %@",self.whenExpression]];
    
    [mutableString appendString:[NSString stringWithFormat: @" BEGIN %@ END",self.body]];
    
    return [NSString stringWithString:mutableString];
}

@end

@implementation GWMDatabaseItem

@end

@implementation GWMColumnItem

@end

@implementation GWMForeignKeyIntegrityCheckItem

@end
