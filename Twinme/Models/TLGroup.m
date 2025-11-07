/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Synchronization based on copy-on-write pattern
//
// version: 1.3
//
#import <CocoaLumberjack.h>

/**
 * <pre>
 *
 * Invariant: Contact <<->> PrivateIdentity
 *
 *  contact.privateIdentityId == null
 *  and contact.privateIdentity == null
 *   or
 *  contact.privateIdentityId != null
 *  and contact.privateIdentity != null
 *  and contact.privateIdentityId == contact.privateIdentity.id
 *
 *
 * Invariant: Contact <<->> PeerTwincodeOutbound
 *
 *  contact.publicPeerTwincodeOutboundId == null
 *  and contact.privatePeerTwincodeOutboundId == null
 *  and contact.peerTwincodeOutbound == null
 *   or
 *  contact.privatePeerTwincodeOutboundId != null
 *  and contact.peerTwincodeOutbound != null
 *  and contact.privatePeerTwincodeOutboundId == contact.peerTwincodeOutbound.id
 *   or
 *  contact.publicPeerTwincodeOutboundId != null
 *  and contact.privatePeerTwincodeOutboundId == null
 *  and contact.peerTwincodeOutbound != null
 *  and contact.publicPeerTwincodeOutboundId == contact.peerTwincodeOutbound.id
 * </pre>
 **/

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLGroup.h"
#import "TLGroupMember.h"
#import "TLTwinmeAttributes.h"
#import "TLSpace.h"
#import "TLCapabilities.h"

#define TL_GROUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"a70f964c-7147-4825-afe2-d14da222f181"]
#define TL_GROUP_SCHEMA_VERSION 1

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLGroupFactory ()
//

@interface TLGroupFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

#undef LOG_TAG
#define LOG_TAG @"TLGroupFactory"

//
// Interface: TLGroup ()
//

@interface TLGroup ()

@property (nullable) TLCapabilities *peerCapabilities;
@property (nullable) TLCapabilities *localCapabilities;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

//
// Implementation: TLGroup
//

@implementation TLGroup

static TLGroupFactory *factory;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_GROUP_SCHEMA_ID;
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLGroupFactory alloc] initWithSchemaId:TL_GROUP_SCHEMA_ID schemaVersion:TL_GROUP_SCHEMA_VERSION ownerFactory:[TLSpace FACTORY] twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_ALL];
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
        if (attributes) {
            for (TLAttributeNameValue *attribute in attributes) {
                NSString *name = attribute.name;
                if ([name isEqualToString:@"groupTwincodeFactoryId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.groupTwincodeFactoryId = [[NSUUID alloc] initWithUUIDString:value];
                } else if ([name isEqualToString:@"leaving"] && [attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
                    NSNumber *value = (NSNumber *) [(TLAttributeNameBooleanValue *)attribute value];
                    self.isLeaving = [value boolValue];
                }
            }
        }
    }
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    NSString *name, *description;
    TLTwincodeInbound *twincodeInbound;
    TLTwincodeOutbound *twincodeOutbound;
    TLTwincodeOutbound *groupTwincodeOutbound;
    TLSpace *space;
    NSUUID *twincodeFactoryId, *groupTwincodeFactoryId;
    BOOL isLeaving;
    @synchronized (self) {
        name = self.name;
        description = self.objectDescription;
        space = self.space;
        twincodeInbound = self.twincodeInbound;
        twincodeOutbound = self.twincodeOutbound;
        groupTwincodeOutbound = self.groupTwincodeOutbound;
        groupTwincodeFactoryId = self.groupTwincodeFactoryId;
        twincodeFactoryId = self.twincodeFactoryId;
        isLeaving = self.isLeaving;
    }
    NSMutableArray *attributes = [NSMutableArray array];
    if (exportAll) {
        [self exportAttributes:attributes name:name description:description twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId space:space];
        if (groupTwincodeOutbound) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"groupTwincodeOutboundId" stringValue:groupTwincodeOutbound.uuid.UUIDString]];
        }
    }
    if (groupTwincodeFactoryId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"groupTwincodeFactoryId" stringValue:groupTwincodeFactoryId.UUIDString]];
    }
    if (isLeaving) {
        [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"leaving" boolValue:true]];
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
                self.localCapabilities = [[TLCapabilities alloc] initWithCapabilities:capabilities];
            } else {
                self.localCapabilities = nil;
            }
        } else {
            self.localCapabilities = nil;
        }
    }
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The group is valid if we have an identity twincode (inbound and outbound) and it has an associated space.
    // The group will be deleted when this becomes invalid.
    return self.twincodeInbound && self.twincodeOutbound && self.space;
}

- (BOOL)canCreateP2P {
    DDLogVerbose(@"%@ canCreateP2P", LOG_TAG);

    // We must be able to create the P2P even if we are leaving.
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

- (void)setPeerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ setPeerTwincodeOutbound: %@", LOG_TAG, peerTwincodeOutbound);

    @synchronized(self) {
        [super setPeerTwincodeOutbound:peerTwincodeOutbound];
        if (peerTwincodeOutbound) {
            self.groupAvatarId = peerTwincodeOutbound.avatarId;
            self.peerCapabilities = [[TLCapabilities alloc] initWithCapabilities:peerTwincodeOutbound.capabilities];
            self.objectDescription = peerTwincodeOutbound.twincodeDescription;
            if ([self.name length] == 0) {
                self.name = peerTwincodeOutbound.name;
            }
        } else {
            self.groupAvatarId = nil;
            self.peerCapabilities = nil;
        }
    }
}

- (nullable NSUUID *)createdByMemberTwincodeOutboundId {
    
    TLTwincodeOutbound *groupTwincodeOutbound = self.peerTwincodeOutbound;
    if (!groupTwincodeOutbound) {
        return nil;
    }
    return [TLTwinmeAttributes getCreatedByFromTwincode:(TLTwincode *)groupTwincodeOutbound];
}

- (nullable NSUUID *)invitedByMemberTwincodeOutboundId {

    TLTwincodeOutbound *memberTwincodeOutbound = self.twincodeOutbound;
    if (!memberTwincodeOutbound) {
        return nil;
    }
    return [TLTwinmeAttributes getInvitedByFromTwincode:(TLTwincode *)memberTwincodeOutbound];
}


- (BOOL)hasPeer {
    
    return !self.isLeaving && self.twincodeOutboundId != nil;
}

- (nonnull NSString *)groupPublicName {
    
    TLTwincodeOutbound *groupTwincode = self.peerTwincodeOutbound;
    return groupTwincode ? groupTwincode.name : @"";
}

- (nullable NSUUID *)groupTwincodeOutboundId {
    
    return self.peerTwincodeOutboundId;
}

- (nullable TLTwincodeOutbound *)groupTwincodeOutbound {
    
    return self.peerTwincodeOutbound;
}

- (BOOL)isGroup {
    
    return YES;
}

- (nonnull TLCapabilities *)capabilities {

    @synchronized (self) {
        return self.peerCapabilities != nil ? self.peerCapabilities : [[TLCapabilities alloc] init];
    }
}

- (BOOL)hasPrivateIdentity {
    return YES;
}

- (nonnull TLCapabilities *)identityCapabilities {

    @synchronized (self) {
        return self.localCapabilities != nil ? self.localCapabilities : [[TLCapabilities alloc] init];
    }
}

- (BOOL)isOwner {
 
    return self.createdByMemberTwincodeOutboundId && [self.createdByMemberTwincodeOutboundId isEqual:self.twincodeOutbound.uuid];
}

- (BOOL)updatePeerName:(TLTwincodeOutbound *)peerTwincodeOutbound oldName:(NSString *)oldName{
    
    if (!peerTwincodeOutbound || !oldName) {
        return NO;
    }
    
    NSString *newName = peerTwincodeOutbound.name;
    if (!newName) {
        return NO;
    }
    @synchronized(self) {
        if ((![oldName isEqual:self.name] && self.name.length > 0) || [oldName isEqual:newName]) {
            return NO;
        }
        self.name = newName;
    }
    return YES;
}

- (BOOL)checkInvariants {

    return true;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"Group[%@", self.identifier];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name=%@ groupPublicName=%@", self.name, self.groupPublicName];
#endif
    if (self.groupTwincodeOutboundId) {
        [string appendFormat:@" groupTwincodeOutboundId=%@", self.groupTwincodeOutboundId];
    }
    [string appendFormat:@" memberTwincodeOutboundId=%@", self.twincodeOutbound];
    if (self.createdByMemberTwincodeOutboundId) {
        [string appendFormat:@" createdByMemberTwincodeOutboundId=%@", self.createdByMemberTwincodeOutboundId];
    }
    if (self.invitedByMemberTwincodeOutboundId) {
        [string appendFormat:@" invitedByMemberTwincodeOutboundId=%@", self.invitedByMemberTwincodeOutboundId];
    }
    [string appendString:@"]"];
    return string;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLGroupFactory"

//
// Implementation: TLGroupFactory
//

@implementation TLGroupFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLGroup alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLGroup *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    NSUUID *twincodeOutboundId = nil, *twincodeFactoryId = nil, *groupTwincodeOutboundId, *spaceId = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"name"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectName = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"description"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectDescription = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"groupTwincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            groupTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
        } else if (([name isEqualToString:@"twincodeOutboundId"] || [name isEqualToString:@"memberTwincodeOutboundId"]) && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
        }  else if ([name isEqualToString:@"twincodeFactoryId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeFactoryId = [[NSUUID alloc] initWithUUIDString:value];
        } else if ([name isEqualToString:@"spaceId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            spaceId = [[NSUUID alloc] initWithUUIDString:value];
        }
    }

    // 6 attributes: name, description, twincodeFactoryId, twincodeOutboundId, groupTwincodeOutboundId
    // spaceId are mapped to repository columns and they are dropped.
    TLGroup *group = [[TLGroup alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    [importService importWithObject:group twincodeFactoryId:twincodeFactoryId twincodeInboundId:key twincodeOutboundId:twincodeOutboundId peerTwincodeOutboundId:groupTwincodeOutboundId ownerId:spaceId];
    return group;
}

@end

