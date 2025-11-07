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
// version: 1.2
//
#import <CocoaLumberjack.h>

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLSpace.h"
#import "TLSpaceSettings.h"
#import "TLProfile.h"
#import "TLOriginator.h"
#import "TLTwinmeAttributes.h"

#define TL_SPACE_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"71637589-5fb0-4ec0-b11a-e56accaa60a0"]
#define TL_SPACE_SCHEMA_VERSION 1

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLSpaceFactory ()
//

@interface TLSpaceFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

//
// Interface: TLSpace ()
//

@interface TLSpace ()

@property long permissions;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

#undef LOG_TAG
#define LOG_TAG @"TLSpace"

//
// Implementation: TLSpace
//

@implementation TLSpace

static TLSpaceFactory *factory;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_SPACE_SCHEMA_ID;
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLSpaceFactory alloc] initWithSchemaId:TL_SPACE_SCHEMA_ID schemaVersion:TL_SPACE_SCHEMA_VERSION ownerFactory:[TLSpaceSettings FACTORY] twincodeUsage:TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND];
    }
    return factory;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ uuid: %@ creationDate: %lld name: %@ description: %@ attributes: %@ modificationDate: %lld", LOG_TAG, identifier, uuid, creationDate, name, description, attributes, modificationDate);

    self = [super initWithIdentifier:identifier uuid:uuid creationDate:creationDate modificationDate:modificationDate];
    if (self) {
        _permissions = -1L; // permissions are retrieved from the spaceTwincode.
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
                if ([name isEqualToString:@"profileId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                    self.profileId = [[NSUUID alloc] initWithUUIDString:value];
                }
            }
        }
    }
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    TLTwincodeOutbound *twincodeOutbound;
    TLSpaceSettings *spaceSettings;
    NSUUID *profileId;
    @synchronized (self) {
        twincodeOutbound = self.spaceTwincode;
        spaceSettings = self.settings;
        profileId = self.profileId;
    }
    NSMutableArray *attributes = [NSMutableArray array];
    if (exportAll) {
        if (spaceSettings) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"settingsId" stringValue:spaceSettings.uuid.UUIDString]];
        }
        if (twincodeOutbound) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"spaceTwincodeId" stringValue:twincodeOutbound.uuid.UUIDString]];
        }
    }
    if (profileId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"profileId" stringValue:profileId.UUIDString]];
    }
    return attributes;
}

- (void)setPeerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ setPeerTwincodeOutbound: %@", LOG_TAG, peerTwincodeOutbound);

    @synchronized(self) {
        self.spaceTwincode = peerTwincodeOutbound;
        if (peerTwincodeOutbound) {
            self.settings.name = peerTwincodeOutbound.name;
            // NSString *permissions = [TLTwinmeAttributes getPermissionsFromTwincode:(TLTwincode *)spaceTwincodeOutbound];
        } else {
            self.name = @"";
            self.objectDescription = @"";
        }
    }
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The space is always valid.
    return YES;
}

- (BOOL)canCreateP2P {
    DDLogVerbose(@"%@ canCreateP2P", LOG_TAG);

    return NO;
}

- (void)setOwner:(nullable id<TLRepositoryObject>)owner {
    DDLogVerbose(@"%@ setOwner: %@", LOG_TAG, owner);

    // Called when an object is loaded from the database and linked to its owner.
    // Take the opportunity to link back the Space to its profile if there is a match.
    if ([(NSObject *) owner isKindOfClass:[TLSpaceSettings class]]) {
        self.settings = (TLSpaceSettings *) owner;
    }
}

- (nullable id<TLRepositoryObject>)owner {
    
    return self.settings;
}

- (NSUUID *)avatarId {
    
    return self.settings.avatarId;
}

- (void)setAvatarId:(nullable TLImageId *)avatarId {
    
}

- (BOOL)isOwner:(nonnull id<TLOriginator>)originator {
    
    TLSpace *space = [originator space];
    return self == space;
}

- (BOOL)isManagedSpace {
    
    return self.spaceTwincode != nil;
}

- (BOOL)hasPermission:(TLSpacePermissionType)permission {
    
    return self.permissions & (1 << permission);
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"Space[%@ %@", self.databaseId, self.uuid];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name=%@", self.settings.name];
#endif
    if (self.profileId) {
        [string appendFormat:@" profileId=%@", self.profileId];
    }
    [string appendFormat:@" settingsId=%@", self.settings.uuid];
    if (self.spaceTwincode) {
        [string appendFormat:@" spaceTwincodeId=%@", self.spaceTwincode.uuid];
    }
    [string appendFormat:@"]"];
    return string;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLSpaceFactory"

//
// Implementation: TLSpaceFactory
//

@implementation TLSpaceFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLSpace alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLSpace *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    NSUUID *settindsId = nil, *spaceTwincodeId = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"name"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectName = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"description"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectDescription = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"settingsId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            settindsId = [[NSUUID alloc] initWithUUIDString:value];
        } else if ([name isEqualToString:@"spaceTwincodeId"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            NSString *value = (NSString *) [(TLAttributeNameStringValue *)attribute value];
            spaceTwincodeId = [[NSUUID alloc] initWithUUIDString:value];
        }
    }

    // 4 attributes: name, description, spaceTwincodeId, settingsId are mapped to repository columns and they are dropped.
    TLSpace *space = [[TLSpace alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    [importService importWithObject:space twincodeFactoryId:nil twincodeInboundId:nil twincodeOutboundId:nil peerTwincodeOutboundId:spaceTwincodeId ownerId:settindsId];
    return space;
}

@end

