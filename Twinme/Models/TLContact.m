/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Synchronization based on copy-on-write pattern
//
// version: 1.11
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
 *
 * </pre>
 **/

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLContact.h"
#import "TLSpace.h"

#import "TLTwinmeAttributes.h"

#define TL_CONTACT_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"52872aa7-73a9-47f2-b4ad-83bcb412dc4c"]
#define TL_CONTACT_SCHEMA_VERSION 1

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLContactFactory ()
//

@interface TLContactFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

#undef LOG_TAG
#define LOG_TAG @"TLContact"

//
// Interface: TLContact ()
//

@interface TLContact ()

@property (nullable) TLCapabilities *peerCapabilities;
@property (nullable) TLCapabilities *localCapabilities;
@property  BOOL hasPrivatePeerTwincode;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

//
// Implementation: TLContact
//

@implementation TLContact

static TLContactFactory *factory;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_CONTACT_SCHEMA_ID;
}

+ (NSString *)ANONYMOUS_NAME {
    
    return NSLocalizedString(@"anonymous", nil);
}

+ (UIImage *)ANONYMOUS_AVATAR {
    
    return [UIImage imageNamed:@"anonymous_avatar"];
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLContactFactory alloc] initWithSchemaId:TL_CONTACT_SCHEMA_ID schemaVersion:TL_CONTACT_SCHEMA_VERSION ownerFactory:[TLSpace FACTORY] twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_ALL];
    }
    return factory;
}

- (instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ uuid: %@ creationDate: %lld name: %@ description: %@ attributes: %@ modificationDate: %lld", LOG_TAG, identifier, uuid, creationDate, name, description, attributes, modificationDate);

    self = [super initWithIdentifier:identifier uuid:uuid creationDate:creationDate modificationDate:modificationDate];
    if (self) {
        _hasPrivatePeerTwincode = YES;
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
        self.hasPrivatePeerTwincode = YES;
        if (attributes) {
            for (TLAttributeNameValue *attribute in attributes) {
                NSString *name = attribute.name;
                if ([name isEqualToString:@"publicPeerTwincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.publicPeerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
                } else if ([name isEqualToString:@"noPrivatePeer"] && [attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
                    self.hasPrivatePeerTwincode = NO;
                }
            }
        }
    }
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    NSString *name, *description;
    NSUUID *publicPeerTwincodeOutboundId;
    TLTwincodeInbound *twincodeInbound;
    TLTwincodeOutbound *twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound;
    TLSpace *space;
    NSUUID *twincodeFactoryId;
    BOOL hasPrivatePeer;
    @synchronized (self) {
        name = self.name;
        description = self.objectDescription;
        space = self.space;
        twincodeInbound = self.twincodeInbound;
        twincodeOutbound = self.twincodeOutbound;
        publicPeerTwincodeOutboundId = self.publicPeerTwincodeOutboundId;
        peerTwincodeOutbound = self.peerTwincodeOutbound;
        twincodeFactoryId = self.twincodeFactoryId;
        hasPrivatePeer = self.hasPrivatePeerTwincode;
    }
    NSMutableArray *attributes = [NSMutableArray array];
    if (exportAll) {
        [self exportAttributes:attributes name:name description:description twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId space:space];

        if (peerTwincodeOutbound) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"privatePeerTwincodeOutboundId" stringValue:peerTwincodeOutbound.uuid.UUIDString]];
        }
    }
    if (publicPeerTwincodeOutboundId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"publicPeerTwincodeOutboundId" stringValue:publicPeerTwincodeOutboundId.UUIDString]];
    }
    if (!hasPrivatePeer) {
        [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"noPrivatePeer" boolValue:true]];
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

    // The contact is valid if we have an identity twincode (inbound and outbound) and it has an associated space.
    // The contact will be deleted when this becomes invalid.
    return self.twincodeInbound && self.twincodeOutbound && self.space;
}

- (BOOL)canCreateP2P {
    DDLogVerbose(@"%@ canCreateP2P", LOG_TAG);

    return [self hasPrivatePeer];
}

- (BOOL)canAcceptP2PWithTwincodeId:(nullable NSUUID *)twincodeId {
    DDLogVerbose(@"%@ canAcceptP2PWithTwincodeId: %@", LOG_TAG, twincodeId);

    @synchronized (self) {
        // The contact must know the peer private identity.
        return self.hasPrivatePeerTwincode && self.peerTwincodeOutbound != nil
            // If there is no peer twincode, the peer twincode must not be signed.
        && ((!twincodeId && ![self.peerTwincodeOutbound isSigned])
            // And if we have a peer twincode, it must match what we have.
            || [self.peerTwincodeOutbound.uuid isEqual:twincodeId]);
    }
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
    
    @synchronized(self) {
        [super setPeerTwincodeOutbound:peerTwincodeOutbound];
        if (peerTwincodeOutbound) {

            NSString *capabilities = [self.peerTwincodeOutbound capabilities];
            if (capabilities) {
                self.peerCapabilities = [[TLCapabilities alloc] initWithCapabilities:capabilities];
            } else {
                self.peerCapabilities = nil;
            }
        } else {
            self.publicPeerTwincodeOutboundId = nil;
            self.peerCapabilities = nil;
        }
    }
}

- (void)setPublicPeerTwincodeOutbound:(nullable TLTwincodeOutbound *)publicPeerTwincodeOutbound {
    DDLogVerbose(@"%@ setPublicPeerTwincodeOutbound: %@", LOG_TAG, publicPeerTwincodeOutbound);

    @synchronized(self) {
        if (publicPeerTwincodeOutbound) {
            self.publicPeerTwincodeOutboundId = [publicPeerTwincodeOutbound uuid];
            self.hasPrivatePeerTwincode = NO;
            self.peerTwincodeOutbound = publicPeerTwincodeOutbound;
        } else {
            self.publicPeerTwincodeOutboundId = nil;
        }
    }
}

- (BOOL)updatePeerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ updatePeerTwincodeOutbound: %@", LOG_TAG, peerTwincodeOutbound);

    BOOL modified;
    @synchronized(self) {
        modified = self.peerTwincodeOutbound != peerTwincodeOutbound;
        if (modified) {
            self.hasPrivatePeerTwincode = YES;
            self.peerTwincodeOutbound = peerTwincodeOutbound;
        }
    }
    return modified;
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

- (BOOL)hasPrivateIdentity {
    
    @synchronized(self) {
        return self.twincodeOutbound != nil;
    }
}

- (BOOL)hasPeer {
    
    return self.peerTwincodeOutbound != nil;
}

- (BOOL)isGroup {
    
    return NO;
}

- (BOOL)hasPrivatePeer {
    
    @synchronized (self) {
        return self.hasPrivatePeerTwincode && self.peerTwincodeOutbound != nil;
    }
}

- (TLImageId *)avatarId {
    
    @synchronized (self) {
        return self.peerTwincodeOutbound ? self.peerTwincodeOutbound.avatarId : nil;
    }
}

- (NSUUID *)peerTwincodeOutboundId {
    
    @synchronized (self) {
        return self.hasPrivatePeerTwincode && self.peerTwincodeOutbound ? self.peerTwincodeOutbound.uuid : nil;
    }
}

- (BOOL)isTwinroom {
    
    @synchronized (self) {
        return (self.peerCapabilities != nil && [self.peerCapabilities kind] == TLTwincodeKindTwinroom);
    }
}

- (nonnull TLCapabilities *)capabilities {

    @synchronized (self) {
        return self.peerCapabilities != nil ? self.peerCapabilities : [[TLCapabilities alloc] init];
    }
}

- (nonnull TLCapabilities *)identityCapabilities {

    @synchronized (self) {
        return self.localCapabilities != nil ? self.localCapabilities : [[TLCapabilities alloc] init];
    }
}

- (nonnull NSString *)peerTwincodeName {
    
    @synchronized (self) {
        return self.peerTwincodeOutbound ? self.peerTwincodeOutbound.name : @"";
    }
}

- (TLCertificationLevel)certificationLevel {
    
    @synchronized (self) {
        BOOL peerSigned = self.peerTwincodeOutbound && [self.peerTwincodeOutbound isSigned];
        BOOL identitySigned = self.twincodeOutbound && [self.twincodeOutbound isSigned];

        if (!peerSigned || !identitySigned) {
            return TLCertificationLevel0;
        }

        BOOL isTrusted = self.capabilities && [self.capabilities isTrustedWithTwincodeId:self.twincodeOutbound.uuid];
        BOOL isPeerTrusted = self.identityCapabilities && [self.identityCapabilities isTrustedWithTwincodeId:self.peerTwincodeOutbound.uuid] && [self.peerTwincodeOutbound isTrusted];
        if (!isPeerTrusted) {
            // If the peer twincode is not marked as TRUSTED but was obtained from an invitation code we can almost
            // trust its public key and indicate the Level_3.
            return isTrusted ? TLCertificationLevel2 : ([self.peerTwincodeOutbound trustMethod] == TLTrustMethodInvitationCode ? TLCertificationLevel3 : TLCertificationLevel1);
        }
        return isTrusted ? TLCertificationLevel4 : TLCertificationLevel3;
    }
}

- (BOOL)checkInvariants {
    
    NSUUID *publicPeerTwincodeOutboundId;
    NSUUID *privatePeerTwincodeOutboundId;
    NSUUID *twincodeInboundId;
    NSUUID *twincodeOutboundId;
    TLTwincodeOutbound *peerTwincodeOutbound;

    @synchronized (self) {
        publicPeerTwincodeOutboundId = self.publicPeerTwincodeOutboundId;
        peerTwincodeOutbound = self.peerTwincodeOutbound;
        privatePeerTwincodeOutboundId = self.hasPrivatePeerTwincode && peerTwincodeOutbound ? peerTwincodeOutbound.uuid : nil;
        twincodeInboundId = self.twincodeInboundId;
        twincodeOutboundId = self.twincodeOutboundId;
    }

    //
    // Invariant: Contact <<->> PrivateIdentity
    //
    
    BOOL invariant;
    invariant = (!twincodeInboundId && !twincodeOutboundId) ||
    (twincodeInboundId && twincodeOutboundId);
    if (!invariant) {
        return NO;
    }
    
    //
    // Invariant: Contact <<->> PeerTwincodeOutbound
    //
    
    invariant = (!publicPeerTwincodeOutboundId && !privatePeerTwincodeOutboundId && !peerTwincodeOutbound) ||
    (privatePeerTwincodeOutboundId && [privatePeerTwincodeOutboundId isEqual:peerTwincodeOutbound.uuid]) ||
    (publicPeerTwincodeOutboundId && !privatePeerTwincodeOutboundId && [publicPeerTwincodeOutboundId isEqual:peerTwincodeOutbound.uuid]);
    if (!invariant) {
        return NO;
    }

    return invariant;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"Contact[%@ %@", self.databaseId, self.uuid];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name=%@", self.name];
#endif
    if (self.publicPeerTwincodeOutboundId) {
        [string appendFormat:@" publicPeerTwincodeOutboundId=%@", self.publicPeerTwincodeOutboundId];
    }
    [string appendFormat:@" privatePeerTwincodeOutbound:   %@\n", self.peerTwincodeOutbound];
    [string appendFormat:@" twincodeFactoryId=%@", self.twincodeFactoryId];
    [string appendFormat:@" twincodeInboundId=%@", self.twincodeInboundId];
    [string appendFormat:@" twincodeOutboundId=%@", self.twincodeOutboundId];
    [string appendFormat:@" space=%@]", self.space];
    return string;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLContactFactory"

//
// Implementation: TLContactFactory
//

@implementation TLContactFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLContact alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLContact *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    NSUUID *twincodeInboundId = nil, *twincodeOutboundId = nil, *twincodeFactoryId = nil, *peerTwincodeOutboundId, *publicPeerTwincodeOutboundId = nil, *spaceId = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"name"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectName = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"description"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectDescription = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"privatePeerTwincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
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
        } else if ([name isEqualToString:@"publicPeerTwincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            publicPeerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
        }
    }

    // Use the peerTwincodeOutbound to keep track of the public peer twincode
    if (!peerTwincodeOutboundId && publicPeerTwincodeOutboundId) {
        peerTwincodeOutboundId = publicPeerTwincodeOutboundId;
        
        NSMutableArray *newAttributes = [[NSMutableArray alloc] initWithArray:attributes];
        [newAttributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"noPrivatePeer" boolValue:true]];
        attributes = newAttributes;
    }

    // 7 attributes: name, description, twincodeInboundId, twincodeFactoryId, twincodeOutboundId, privatePeerTwincodeOutboundId
    // spaceId are mapped to repository columns and they are dropped.
    TLContact *contact = [[TLContact alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    [importService importWithObject:contact twincodeFactoryId:twincodeFactoryId twincodeInboundId:twincodeInboundId twincodeOutboundId:twincodeOutboundId peerTwincodeOutboundId:peerTwincodeOutboundId ownerId:spaceId];
    return contact;
}

@end

