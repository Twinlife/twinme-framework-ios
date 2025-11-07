/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLAccountMigration.h"
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>

#define TL_ACCOUNT_MIGRATION_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"86A86B53-0E2C-4BA2-AD74-DDFB3F6FBB2C"]
#define TL_ACCOUNT_MIGRATION_SCHEMA_VERSION 1

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLAccountMigration"

//
// Interface: TLContactFactory ()
//

@interface TLAccountMigrationFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

//
// Implementation: TLAccountMigration
//

@implementation TLAccountMigration

static TLAccountMigrationFactory *factory;

+ (nonnull NSUUID *)SCHEMA_ID {
    return TL_ACCOUNT_MIGRATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    return TL_ACCOUNT_MIGRATION_SCHEMA_VERSION;
}


+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLAccountMigrationFactory alloc] init];
    }
    return factory;
}


- (nonnull instancetype)initWithIdentifier:(id)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray *)attributes modificationDate:(int64_t)modificationDate {
    
    self = [super initWithIdentifier:identifier uuid:uuid creationDate:creationDate modificationDate:modificationDate];
    
    if (self) {
        _isBound = NO;
        [self updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
    }
    
    return self;
}

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray *)attributes modificationDate:(int64_t)modificationDate {

    @synchronized (self) {
        self.name = name ? name : @"";
        self.objectDescription = description ? description : @"";
        self.modificationDate = modificationDate;
        
        if (attributes) {
            for (TLAttributeNameValue *attribute in attributes) {
                if ([@"isBound" isEqualToString:attribute.name] && [attribute isKindOfClass:TLAttributeNameBooleanValue.class]) {
                    self.isBound = (BOOL) attribute.value;
                }
            }
        }
    }
}

- (nullable NSUUID *)peerTwincodeOutboundId {
    @synchronized (self) {
        if (self.peerTwincodeOutbound) {
            return self.peerTwincodeOutbound.uuid;
        }
        return nil;
    }
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The account migration is valid if it has its connection twincode.
    return self.twincodeInbound && self.twincodeOutbound;
}

#pragma TLTwinmeObject

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    TLTwincodeInbound *twincodeInbound;
    TLTwincodeOutbound *twincodeOutbound;
    NSUUID *peerTwincodeOutboundId;
    NSUUID *twincodeFactoryId;
    BOOL isBound;
    
    @synchronized (self) {
        twincodeInbound = self.twincodeInbound;
        twincodeOutbound = self.twincodeOutbound;
        peerTwincodeOutboundId = self.peerTwincodeOutboundId;
        twincodeFactoryId = self.twincodeFactoryId;
        isBound = self.isBound;
    }
    
    NSMutableArray<TLAttributeNameValue *> *attributes = [[NSMutableArray alloc] init];
    
    if (exportAll) {
        [self exportAttributes:attributes name:nil description:nil twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId space:nil];
        if (peerTwincodeOutboundId) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"peerTwincodeOutboundId" value:[peerTwincodeOutboundId toString]]];
        }
    }
    [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"isBound" boolValue:isBound]];
    
    return attributes;
}

- (BOOL)canCreateP2P {
    return YES;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"AccountMigration[%@ %@", self.databaseId, self.uuid];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name=%@", self.name];
#endif
    [string appendFormat:@" isBound=%@", self.isBound ? @"YES" : @"NO"];
    if (self.peerTwincodeOutboundId) {
        [string appendFormat:@" peerTwincodeOutboundId=%@", self.peerTwincodeOutboundId];
    }
    [string appendFormat:@" twincodeFactoryId=%@", self.twincodeFactoryId];
    if (self.twincodeInbound){
        [string appendFormat:@" twincodeInboundId=%@", self.twincodeInbound.objectId];
    }
    if (self.twincodeOutbound){
        [string appendFormat:@" twincodeOutboundId=%@", self.twincodeOutbound.objectId];
    }
    return string;
}

@end


@implementation TLAccountMigrationFactory

- (nonnull instancetype)init {
    self = [super initWithSchemaId:TL_ACCOUNT_MIGRATION_SCHEMA_ID schemaVersion:TL_ACCOUNT_MIGRATION_SCHEMA_VERSION ownerFactory:nil twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND];
    
    return self;
}

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    return [[TLAccountMigration alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLAccountMigration *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {
    
    NSUUID *twincodeInboundId = nil, *twincodeOutboundId = nil, *twincodeFactoryId = nil, *peerTwincodeOutboundId = nil;

    for (TLAttributeNameValue *attribute in attributes) {
        if ([attribute isKindOfClass:TLAttributeNameStringValue.class]) {
            NSString *name = attribute.name;
            NSString *value = (NSString *)attribute.value;
            
            if ([name isEqualToString:@"twincodeFactoryId"]) {
                twincodeFactoryId = [[NSUUID alloc] initWithUUIDString:value];
            } else if ([name isEqualToString:@"twincodeInboundId"]) {
                twincodeInboundId = [[NSUUID alloc] initWithUUIDString:value];
            } else if ([name isEqualToString:@"twincodeOutboundId"]) {
                twincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
            } else if ([name isEqualToString:@"peerTwincodeOutboundId"]) {
                peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
            }
        }
    }
    
    // 4 attributes: twincodeInboundId, twincodeFactoryId, twincodeOutboundId, peerTwincodeOutboundId
    // are mapped to repository columns and they are dropped.
    TLAccountMigration *accountMigration = [[TLAccountMigration alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:nil description:nil attributes:attributes modificationDate:creationDate];
    
    [importService importWithObject:accountMigration twincodeFactoryId:twincodeFactoryId twincodeInboundId:twincodeInboundId twincodeOutboundId:twincodeOutboundId peerTwincodeOutboundId:peerTwincodeOutboundId ownerId:nil];
    
    return accountMigration;
}

@end
