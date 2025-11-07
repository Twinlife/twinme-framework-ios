/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Julien Poumarat (Julien.Poumarat@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Synchronization based on copy-on-write pattern
//
// version: 3.4
//

/**
 * <pre>
 *
 * Invariant: Profile <<->> PublicIdentity
 *
 *  profile.publicIdentityId == null
 *  and profile.publicIdentity == null
 *   or
 *  profile.publicIdentityId != null
 *  and profile.publicIdentity != null
 *  and profile.publicIdentityId == publicIdentity.id
 * </pre>
 **/
#import <CocoaLumberjack.h>

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>

#import "TLCapabilities.h"
#import "TLProfile.h"
#import "TLSpace.h"
#import "TLTwinmeAttributes.h"

#define TL_PROFILE_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"cfde3269-ce0f-4a8e-976c-4a9e504ff515"]
#define TL_PROFILE_SCHEMA_VERSION 3

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLProfileFactory ()
//

@interface TLProfileFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

#undef LOG_TAG
#define LOG_TAG @"TLProfile"

//
// Interface: TLProfile ()
//

@interface TLProfile ()

@property (nullable) TLCapabilities *localCapabilities;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

//
// Implementation: TLProfile
//

@implementation TLProfile

static TLProfileFactory *factory;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_PROFILE_SCHEMA_ID;
}

+ (int )SCHEMA_VERSION {
    
    return TL_PROFILE_SCHEMA_VERSION;
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLProfileFactory alloc] initWithSchemaId:TL_PROFILE_SCHEMA_ID schemaVersion:TL_PROFILE_SCHEMA_VERSION ownerFactory:[TLSpace FACTORY] twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND];
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
                if ([name isEqualToString:@"priority"] && [attribute isKindOfClass:[TLAttributeNameLongValue class]]) {
                    self.priority = ((NSNumber *)(TLAttributeNameLongValue*)attribute.value).longLongValue;

                }  else if ([name isEqualToString:@"twincodeFactoryId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.twincodeFactoryId = [[NSUUID alloc] initWithUUIDString:value];
                }
            }
        }
    }
}

- (nonnull TLCapabilities *)identityCapabilities {
    
    return self.localCapabilities != nil ? self.localCapabilities : [[TLCapabilities alloc] init];
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    NSString *name, *description;
    TLTwincodeInbound *twincodeInbound;
    TLTwincodeOutbound *twincodeOutbound;
    NSUUID *twincodeFactoryId;
    TLSpace *space;
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
    [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:@"priority" longValue:self.priority]];
    return attributes;
}

- (void)setTwincodeOutbound:(nullable TLTwincodeOutbound *)identityTwincodeOutbound {
    DDLogVerbose(@"%@ setTwincodeOutbound: %@", LOG_TAG, identityTwincodeOutbound);

    @synchronized(self) {
        [super setTwincodeOutbound:identityTwincodeOutbound];
        if (identityTwincodeOutbound) {
            self.name = identityTwincodeOutbound.name;
            self.objectDescription = identityTwincodeOutbound.twincodeDescription;

            NSString *capabilities = identityTwincodeOutbound.capabilities;
            if (capabilities) {
                self.localCapabilities = [[TLCapabilities alloc] initWithCapabilities:capabilities];
            } else {
                self.localCapabilities = nil;
            }
        } else {
            self.name = @"";
            self.objectDescription = @"";
            self.localCapabilities = nil;
        }
    }
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The profile is valid if we have a twincode inbound and twincode outbound.
    // The profile will be deleted when this becomes invalid.
    return self.twincodeInbound && self.twincodeOutbound;
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
        if ([self.uuid isEqual:self.space.profileId]) {
            self.space.profile = self;
        }
    }
}

- (nullable id<TLRepositoryObject>)owner {
    
    return self.space;
}

- (BOOL)hasPublicIdentity {
    
    @synchronized(self) {
        return self.twincodeOutbound != nil;
    }
}

- (BOOL)checkInvariants {
    
    //
    // Invariant: Profile <<->> PublicIdentity
    //
    
    BOOL invariant = (!self.twincodeInbound && !self.twincodeOutbound)
    || (self.twincodeInbound && self.twincodeOutbound);
    if (!invariant) {
        return NO;
    }

    return  invariant;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"Profile[%@ %@", self.databaseId, self.uuid];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name=%@", self.name];
#endif
    [string appendFormat:@" priority=%lld", self.priority];
    [string appendFormat:@" twincodeOutbound=%@", self.twincodeOutbound];
    [string appendFormat:@" space=%@]", self.space];
    return string;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLProfileFactory"

//
// Implementation: TLProfileFactory
//

@implementation TLProfileFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLProfile alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLProfile *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    NSUUID *twincodeInboundId = nil, *twincodeOutboundId = nil, *twincodeFactoryId = nil, *spaceId = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"twincodeOutboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeOutboundId = [[NSUUID alloc] initWithUUIDString:value];
        }  else if ([name isEqualToString:@"twincodeInboundId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeInboundId = [[NSUUID alloc] initWithUUIDString:value];
        }  else if ([name isEqualToString:@"twincodeFactoryId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            twincodeFactoryId = [[NSUUID alloc] initWithUUIDString:value];
        //}  else if ([name isEqualToString:@"twincodeSwitchId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
        //    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
        //    _twincodeSwitchId = [[NSUUID alloc] initWithUUIDString:value];
        }
    }

    // When we migrate to V20 (or import from the server), the Profile repository object is not linked to the Space because
    // we don't have the spaceId.
    // 5 attributes: name, description, twincodeInboundId, twincodeFactoryId, twincodeOutboundId, spaceId are mapped to repository
    // columns and they are dropped.  The Profile object will be updated by GetSpacesExecutor if necessary.
    TLProfile *profile = [[TLProfile alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    [importService importWithObject:profile twincodeFactoryId:twincodeFactoryId twincodeInboundId:twincodeInboundId twincodeOutboundId:twincodeOutboundId peerTwincodeOutboundId:nil ownerId:spaceId];
    return profile;
}

@end

