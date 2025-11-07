/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLCallReceiver.h"
#import "TLSpace.h"

#import "TLTwinmeAttributes.h"

#define TL_CALL_RECEIVER_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"3b74a66c-db31-4c93-b0ac-f2c08ff3cf31"]
#define TL_CALL_RECEIVER_SCHEMA_VERSION 1

#define TL_CALL_RECEIVER_DUMMY_PEER_TWINCODE_OUTBOUND_ID [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"]

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLCallReceiverFactory ()
//

@interface TLCallReceiverFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

#undef LOG_TAG
#define LOG_TAG @"TLCallReceiver"

//
// Interface: TLCallReceiver ()
//

@interface TLCallReceiver ()

@property (nullable) TLCapabilities *capabilities;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

//
// Implementation: TLCallReceiver
//

@implementation TLCallReceiver

static TLCallReceiverFactory *factory;

+ (nonnull NSUUID *)SCHEMA_ID {

    return TL_CALL_RECEIVER_SCHEMA_ID;
}

+ (nonnull NSUUID *)DUMMY_PEER_TWINCODE_OUTBOUND_ID {
    
    return TL_CALL_RECEIVER_DUMMY_PEER_TWINCODE_OUTBOUND_ID;
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLCallReceiverFactory alloc] initWithSchemaId:TL_CALL_RECEIVER_SCHEMA_ID schemaVersion:TL_CALL_RECEIVER_SCHEMA_VERSION ownerFactory:[TLSpace FACTORY] twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND];
    }
    return factory;
}

- (instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ uuid: %@ creationDate: %lld name: %@ description: %@ attributes: %@ modificationDate: %lld", LOG_TAG, identifier, uuid, creationDate, name, description, attributes, modificationDate);

    self = [super initWithIdentifier:identifier uuid:uuid creationDate:creationDate modificationDate:modificationDate];
    if (self) {
        [self updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
    }
    return self;
}

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ updateWithName: %@ description: %@ attributes: %@ modificationDate: %lld", LOG_TAG, name, description, attributes, modificationDate);

    @synchronized (self) {
        self.name = name ? name : @"";
        self.objectDescription = description ? description : @"";
        self.modificationDate = modificationDate;
    }
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    NSString *name, *description;
    TLTwincodeInbound *twincodeInbound;
    TLTwincodeOutbound *twincodeOutbound;
    TLSpace *space;
    NSUUID *twincodeFactoryId;
    @synchronized (self) {
        name = self.name;
        description = self.objectDescription;
        space = self.space;
        twincodeInbound = self.twincodeInbound;
        twincodeOutbound = self.twincodeOutbound;
        twincodeFactoryId = self.twincodeFactoryId;
    }
    NSMutableArray *attributes = [NSMutableArray array];
    if (exportAll) {
        [self exportAttributes:attributes name:name description:description twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId space:space];
    }
    return attributes;
}

- (void)setTwincodeOutbound:(nullable TLTwincodeOutbound *)identityTwincodeOutbound {
    DDLogVerbose(@"%@ setTwincodeOutbound: %@", LOG_TAG, identityTwincodeOutbound);

    @synchronized(self) {
        [super setTwincodeOutbound:identityTwincodeOutbound];
        if (identityTwincodeOutbound) {
            NSString *capabilities = identityTwincodeOutbound.capabilities;
            if (capabilities) {
                self.capabilities = [[TLCapabilities alloc] initWithCapabilities:capabilities];
            } else {
                self.capabilities = nil;
            }
        } else {
            self.capabilities = nil;
        }
    }
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The contact is valid if we have an identity twincode (inbound and outbound) and it has an associated space.
    // The contact will be deleted when this becomes invalid.
    return self.twincodeInbound && self.twincodeOutbound && self.space;
}

- (BOOL)canCreateP2P {
    DDLogVerbose(@"%@ canCreateP2P", LOG_TAG);

    return NO;
}

- (BOOL)canAcceptP2PWithTwincodeId:(nullable NSUUID *)twincodeId {
    DDLogVerbose(@"%@ canAcceptP2PWithTwincodeId: %@", LOG_TAG, twincodeId);

    // For the click-to-call, we accept every peer.
    return YES;
}

- (void)setOwner:(nullable id<TLRepositoryObject>)owner {
    DDLogVerbose(@"%@ setOwner: %@", LOG_TAG, owner);

    // Called when an object is loaded from the database and linked to its owner.
    // Take the opportunity to link back the Space to its profile if there is a match.
    if ([(NSObject *) owner isKindOfClass:[TLSpace class]]) {
        self.space = (TLSpace *) owner;
    }
}

- (nullable id<TLRepositoryObject>)owner {
    
    return self.space;
}

- (nullable TLImageId *)avatarId {
    return [self.twincodeOutbound avatarId];
}

#if 0
// SCz must fix
- (nonnull TLCapabilities *)capabilities {
    return [[TLCapabilities alloc] initWithCapabilities:[self.twincodeOutbound capabilities]];
}
#endif

- (BOOL)hasPeer {
    return YES;
}


- (nullable TLImageId *)identityAvatarId {
    return [self.twincodeOutbound avatarId];
}

- (nullable NSString *)identityName {
    return [self.twincodeOutbound name];
}

- (nullable NSString *)identityDescription {
    return [self.twincodeOutbound twincodeDescription];
}

/// true if this Call Receiver accepts group calls (i.e. multiple participants using the same CallReceiver).
- (BOOL)isGroup {
    return [self.capabilities hasGroupCall];
}


- (int64_t)lastMessageDate {
    return 0;
}


- (nullable NSString *)peerDescription {
    return @"";
}


- (double)usageScore {
    return 0;
}

- (BOOL)hasPrivateIdentity {
    @synchronized(self) {
        return self.twincodeOutbound != nil;
    }
}


- (nonnull TLCapabilities *)identityCapabilities {
    return self.capabilities;
}

- (BOOL)isTransfer {
    return [self.capabilities hasTransfer];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLCallReceiverFactory"

//
// Implementation: TLCallReceiverFactory
//

@implementation TLCallReceiverFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLCallReceiver alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLCallReceiver *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    NSUUID *twincodeInboundId = key, *twincodeOutboundId = nil, *twincodeFactoryId = nil, *spaceId = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"name"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectName = (NSString *) attribute.value;
        } else if (([name isEqualToString:@"description"] || [name isEqualToString:@"callReceiverDescription"]) && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectDescription = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"twincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
        } else if ([name isEqualToString:@"twincodeInboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeInboundId = [[NSUUID alloc] initWithUUIDString:value];
        }  else if ([name isEqualToString:@"twincodeFactoryId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeFactoryId = [[NSUUID alloc] initWithUUIDString:value];
        } else if ([name isEqualToString:@"spaceId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            spaceId = [[NSUUID alloc] initWithUUIDString:value];
        }
    }

    // 7 attributes: name, description, twincodeInboundId, twincodeFactoryId, twincodeOutboundId, privatePeerTwincodeOutboundId
    // spaceId are mapped to repository columns and they are dropped.
    TLCallReceiver *callReceiver = [[TLCallReceiver alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    [importService importWithObject:callReceiver twincodeFactoryId:twincodeFactoryId twincodeInboundId:twincodeInboundId twincodeOutboundId:twincodeOutboundId peerTwincodeOutboundId:nil ownerId:spaceId];
    return callReceiver;
}

@end

