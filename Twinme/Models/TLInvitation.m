/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Synchronization based on copy-on-write pattern
//
// version: 1.1
//

/**
 * Invitation to create a contact.
 *
 * The invitation has a specific twincode (different from the Profile twincode) that is sent by some mechanism to the invitee.
 * The invitation can have constraints such as:
 *
 * - it can be accepted only once,
 * - it can be accepted only if it has not expired,
 * - if can be accepted only by the group member to which the invitation was sent.
 *
 * Unlike sharing the Profile twincode, the invitation can be withdrawn.
 *
 * When the invitation is created, the current profile identity is used to create the invitation twincode.
 * The avatar and user's name are stored in the invitation twincode outbound id.  This is the information that
 * the invitee will see.
 *
 * When the invitation is accepted by the invitee, a PairInviteInvocation is made and received on the Invitation object.
 * We then create the contact by using the invitation twincode.
 *
 * The invitation can be associated with a twincode descriptor to invite a group member to become a contact.
 * We keep track of the lifetime of the twincode descriptor to remove the invitation in case the twincode descriptor
 * is removed.
 */
#import <CocoaLumberjack.h>

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLTwincodeFactoryService.h>

#import "TLInvitation.h"
#import "TLSpace.h"
#import "TLTwinmeAttributes.h"

#define TL_INVITATION_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"1d1545d4-1912-492a-87db-60ffd68461ff"]
#define TL_INVITATION_SCHEMA_VERSION 1

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLInvitationFactory ()
//

@interface TLInvitationFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

#undef LOG_TAG
#define LOG_TAG @"TLInvitation"

//
// Interface: TLInvitation ()
//

@interface TLInvitation ()

@property (nullable) TLCapabilities *localCapabilities;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

//
// Implementation: TLInvitation
//

@implementation TLInvitation

static TLInvitationFactory *factory;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_INVITATION_SCHEMA_ID;
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLInvitationFactory alloc] initWithSchemaId:TL_INVITATION_SCHEMA_ID schemaVersion:TL_INVITATION_SCHEMA_VERSION ownerFactory:[TLSpace FACTORY] twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND];
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
        
        NSString *code;
        int64_t codeCreationDate = -1;
        int codeValidityPeriod = -1;
        NSString *codePublicKey;
        
        if (attributes) {
            for (TLAttributeNameValue *attribute in attributes) {
                NSString *name = attribute.name;
                if ([name isEqualToString:@"groupId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.groupId = [[NSUUID alloc] initWithUUIDString:value];

                } else if ([name isEqualToString:@"groupMemberTwincodeId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.groupMemberTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];

                } else if ([name isEqualToString:@"descriptorId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.descriptorId = [[TLDescriptorId alloc] initWithString:value];

                } else if ([name isEqualToString:@"code"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    code = (NSString *) [(TLAttributeNameStringValue *)attribute value];

                } else if ([name isEqualToString:@"codeCreationDate"] && [attribute isKindOfClass:[TLAttributeNameLongValue class]]) {
                    codeCreationDate = ((NSNumber *) [(TLAttributeNameLongValue *)attribute value]).longLongValue;

                } else if ([name isEqualToString:@"codeValidityPeriod"] && [attribute isKindOfClass:[TLAttributeNameLongValue class]]) {
                    codeValidityPeriod = ((NSNumber *) [(TLAttributeNameLongValue *)attribute value]).intValue;

                } else if ([name isEqualToString:@"codePublicKey"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    codePublicKey = (NSString *) [(TLAttributeNameStringValue *)attribute value];

                }
            }
            
            if (code) {
                self.invitationCode = [[TLInvitationCode alloc] initWithCreationDate:codeCreationDate validityPeriod:codeValidityPeriod code:code publicKey:codePublicKey];
            }
        }
    }
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    NSString *name, *description;
    TLTwincodeInbound *twincodeInbound;
    TLTwincodeOutbound *twincodeOutbound;
    NSUUID *twincodeFactoryId;
    TLSpace *space;
    NSUUID *groupMemberTwincodeId;
    NSUUID *groupId;
    TLDescriptorId *descriptorId;
    
    NSString *code;
    int64_t codeCreationDate = -1;
    int codeValidityPeriod = -1;
    NSString *codePublicKey;
    
    @synchronized (self) {
        name = self.name;
        description = self.objectDescription;
        space = self.space;
        twincodeInbound = self.twincodeInbound;
        twincodeOutbound = self.twincodeOutbound;
        twincodeFactoryId = self.twincodeFactoryId;
        groupMemberTwincodeId = self.groupMemberTwincodeOutboundId;
        groupId = self.groupId;
        descriptorId = self.descriptorId;
        if (self.invitationCode) {
            code = self.invitationCode.code;
            codeCreationDate = self.invitationCode.creationDate;
            codeValidityPeriod = self.invitationCode.validityPeriod;
            codePublicKey = self.invitationCode.publicKey;
        }
    }
    NSMutableArray *attributes = [NSMutableArray array];
    if (exportAll) {
        [self exportAttributes:attributes name:name description:description twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId space:space];
    }
    if (groupMemberTwincodeId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"groupMemberTwincodeId" stringValue:groupMemberTwincodeId.UUIDString]];
    }
    if (groupId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"groupId" stringValue:groupId.UUIDString]];
    }
    if (descriptorId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"descriptorId" stringValue:[descriptorId toString]]];
    }
    if (code) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"code" stringValue:code]];
    }
    if (codeCreationDate != -1) {
        [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:@"codeCreationDate" longValue:codeCreationDate]];
    }
    if (codeValidityPeriod != -1) {
        [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:@"codeValidityPeriod" longValue:codeValidityPeriod]];
    }
    if (codePublicKey) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"codePublicKey" stringValue:codePublicKey]];
    }
    return attributes;
}

- (void)setTwincodeOutbound:(nullable TLTwincodeOutbound *)identityTwincodeOutbound {
    DDLogVerbose(@"%@ setTwincodeOutbound: %@", LOG_TAG, identityTwincodeOutbound);

    @synchronized(self) {
        [super setTwincodeOutbound:identityTwincodeOutbound];
        if (identityTwincodeOutbound) {
            self.name = identityTwincodeOutbound.name;
            self.objectDescription = identityTwincodeOutbound.twincodeDescription;
        } else {
            self.name = @"";
            self.objectDescription = @"";
        }
    }
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The invitation is valid if we have a twincode inbound and twincode outbound.
    // The profile will be deleted when this becomes invalid.
    return self.twincodeInbound && self.twincodeOutbound && self.space;
}

- (BOOL)canCreateP2P {
    DDLogVerbose(@"%@ canCreateP2P", LOG_TAG);

    return NO;
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

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"\nInvitation\n"];
    [string appendFormat:@" id:                       %@\n", self.uuid ? [self.uuid UUIDString] : @"(null)"];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name:                     %@\n", self.name];
#endif
    [string appendFormat:@" descriptorId:             %@\n", self.descriptorId ? self.descriptorId : @"(null)"];
    return string;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLInvitationFactory"

//
// Implementation: TLInvitationFactory
//

@implementation TLInvitationFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLInvitation alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLInvitation *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    NSUUID *twincodeInboundId = key, *twincodeOutboundId = nil, *twincodeFactoryId = nil, *spaceId = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"name"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectName = (NSString *) attribute.value;

        } else if ([name isEqualToString:@"description"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectDescription = (NSString *) attribute.value;

        } else if ([name isEqualToString:@"twincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];

        }  else if ([name isEqualToString:@"twincodeInboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
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

    // When we migrate to V20 (or import from the server), the Profile repository object is not linked to the Space because
    // we don't have the spaceId.
    // 6 attributes: name, description, twincodeInboundId, twincodeFactoryId, twincodeOutboundId, spaceId are mapped to repository
    // columns and they are dropped.  The Profile object will be updated by GetSpacesExecutor if necessary.
    TLInvitation *invitation = [[TLInvitation alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    [importService importWithObject:invitation twincodeFactoryId:twincodeFactoryId twincodeInboundId:twincodeInboundId twincodeOutboundId:twincodeOutboundId peerTwincodeOutboundId:nil ownerId:spaceId];
    return invitation;
}

@end

