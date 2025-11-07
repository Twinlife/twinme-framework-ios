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
// version: 1.3
//
#import <CocoaLumberjack.h>

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>

#define SPACE_SETTINGS_IMPLEMENTATION
#import "TLTwinmeAttributes.h"
#import "TLSpaceSettings.h"
#import "TLTwinmeRepositoryObject.h"
#import "UIImage+ToData.h"

#define TL_SPACE_SETTINGS_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"3ec683a9-1856-420a-a849-d47c48dd9111"]
#define TL_SPACE_SETTINGS_SCHEMA_VERSION 3

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static TLSpaceSettings *defaultSpaceSettings = nil;
static NSString *oldDefaultLabel = nil;

//
// Interface: TLSpaceSettingsFactory ()
//

@interface TLSpaceSettingsFactory : TLTwinmeObjectFactory <TLRepositoryObjectFactory>

@end

//
// Interface: TLSpaceSettings ()
//

@interface TLSpaceSettings ()

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

#undef LOG_TAG
#define LOG_TAG @"TLSpaceSettings"

//
// Implementation: TLSpaceSettings
//

@implementation TLSpaceSettings

@synthesize owner;
@synthesize peerTwincodeOutbound;

static TLSpaceSettingsFactory *factory;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_SPACE_SETTINGS_SCHEMA_ID;
}

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY {

    if (!factory) {
        factory = [[TLSpaceSettingsFactory alloc] initWithSchemaId:TL_SPACE_SETTINGS_SCHEMA_ID schemaVersion:TL_SPACE_SETTINGS_SCHEMA_VERSION ownerFactory:nil twincodeUsage:0];
    }
    return factory;
}

+ (void)setDefaultSpaceSettingsWithSettings:(nonnull TLSpaceSettings *)settings oldDefaultName:(nonnull NSString *)oldDefaultName {
    
    defaultSpaceSettings = settings;
    oldDefaultLabel = oldDefaultName;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ uuid: %@ creationDate: %lld name: %@ description: %@ attributes: %@ modificationDate: %lld", LOG_TAG, identifier, uuid, creationDate, name, description, attributes, modificationDate);

    self = [super init];
    if (self) {
        _databaseId = identifier;
        _uuid = uuid;
        _creationDate = creationDate;
        [self updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
    }
    return self;
}

- (nullable instancetype)initWithName:(nonnull NSString *)name settings:(nullable TLSpaceSettings *)settings {
    
    self = [super initWithSettings:settings];
    if (self) {
        if (settings) {
            _databaseId = settings.databaseId;
            _uuid = settings.uuid;
            _creationDate = settings.creationDate;
            _messageCopyAllowed = settings.messageCopyAllowed;
            _fileCopyAllowed = settings.fileCopyAllowed;
            _isSecret = settings.isSecret;
            _avatarId = settings.avatarId;
            _style = settings.style;
            self.objectDescription = settings.objectDescription;
        } else {
            _messageCopyAllowed = YES;
            _fileCopyAllowed = YES;
            _isSecret = NO;
            _avatarId = nil;
        }
        _name = name;
    }
    return self;
}

- (nullable instancetype)initWithSettings:(nonnull TLSpaceSettings *)settings {
    
    self = [super initWithSettings:settings];
    if (self) {
        _databaseId = settings.databaseId;
        _uuid = settings.uuid;
        _creationDate = settings.creationDate;
        _modificationDate = settings.modificationDate;
        _messageCopyAllowed = settings.messageCopyAllowed;
        _fileCopyAllowed = settings.fileCopyAllowed;
        _name = settings.name;
        _style = settings.style;
        _isSecret = settings.isSecret;
        _avatarId = settings.avatarId;
        self.objectDescription = settings.objectDescription;
    }
    return self;
}

- (void)copyWithSettings:(nonnull TLSpaceSettings *)settings {
    DDLogVerbose(@"%@ copyWithSettings: %@", LOG_TAG, settings);

    @synchronized (self) {
        self.name = settings.name;
        self.style = settings.style;
        self.isSecret = settings.isSecret;
        self.objectDescription = settings.objectDescription;
        self.messageCopyAllowed = settings.messageCopyAllowed;
        self.fileCopyAllowed = settings.fileCopyAllowed;
        self.properties = [[NSMutableDictionary alloc] initWithDictionary:settings.properties];
    }
}

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ updateWithName: %@ description: %@ attributes: %@ modificationDate: %lld", LOG_TAG, name, description, attributes, modificationDate);

    @synchronized (self) {
        self.name = name ? name : @"";
        self.objectDescription = description;
        self.modificationDate = modificationDate;
        if (attributes) {
            for (TLAttributeNameValue *attribute in attributes) {
                NSString *name = attribute.name;
                if ([name isEqualToString:@"isSecret"] && [attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
                    NSNumber *value = (NSNumber *) [(TLAttributeNameBooleanValue *)attribute value];
                    self.isSecret = [value boolValue];
                } else if ([name isEqualToString:@"messageCopyAllowed"] && [attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
                    NSNumber *value = (NSNumber *) [(TLAttributeNameBooleanValue *)attribute value];
                    self.messageCopyAllowed = [value boolValue];
                } else if ([name isEqualToString:@"fileCopyAllowed"] && [attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
                    NSNumber *value = (NSNumber *) [(TLAttributeNameBooleanValue *)attribute value];
                    self.fileCopyAllowed = [value boolValue];
                } else if ([name isEqualToString:@"avatarId"] && [attribute isKindOfClass:[TLAttributeNameUUIDValue class]]) {
                    self.avatarId = (NSUUID *)[(TLAttributeNameUUIDValue *)attribute value];
                } else if ([name isEqualToString:@"style"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    self.style = (NSString *) [(TLAttributeNameStringValue *)attribute value];
                } else if ([name isEqualToString:@"properties"] && [attribute isKindOfClass:[TLAttributeNameListValue class]]) {
                    NSArray *list = (NSArray *) [(TLAttributeNameListValue *)attribute value];

                    NSMutableDictionary *props = [[NSMutableDictionary alloc] init];
                    for (NSObject *object in list) {
                        if ([object isKindOfClass:[TLAttributeNameValue class]]) {
                            TLAttributeNameValue *item = (TLAttributeNameValue *)object;
                            [props setObject:(NSString *)item.value forKey:item.name];
                        }
                    }
                    self.properties = props;
                }
            }
        }
    }
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    DDLogVerbose(@"%@ attributesWithAll: %d", LOG_TAG, exportAll);

    NSString *style, *name, *description;
    BOOL messageCopyAllowed, fileCopyAllowed, isSecret;
    NSUUID *avatarId;
    NSMutableDictionary<NSString *, NSString *> *properties;
    @synchronized (self) {
        style = self.style;
        name = self.name;
        description = self.objectDescription;
        messageCopyAllowed = self.messageCopyAllowed;
        fileCopyAllowed = self.fileCopyAllowed;
        isSecret = self.isSecret;
        avatarId = self.avatarId;
        if (self.properties) {
            properties = [[NSMutableDictionary alloc] initWithDictionary:self.properties];
        } else {
            properties = nil;
        }
    }
    NSMutableArray *attributes = [NSMutableArray array];
    if (exportAll) {
        if (name) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"name" stringValue:name]];
        }
        if (description) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"description" stringValue:description]];
        }
    }
    [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"messageCopyAllowed" boolValue:messageCopyAllowed]];
    [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"fileCopyAllowed" boolValue:fileCopyAllowed]];
    [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:@"isSecret" boolValue:isSecret]];
    if (style) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"style" stringValue:style]];
    }
    if (avatarId) {
        [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:@"avatarId" uuidValue:avatarId]];
    }
    if (properties) {
        NSMutableArray *props = [NSMutableArray array];

        for (NSString *name in self.properties) {
            NSString *value = self.properties[name];
            if (value) {
                [props addObject:[[TLAttributeNameStringValue alloc] initWithName:name stringValue:value]];
            }
        }

        [attributes addObject:[[TLAttributeNameListValue alloc] initWithName:@"properties" listValue:props]];
    }
    return attributes;
}

- (BOOL)isValid {
    DDLogVerbose(@"%@ isValid", LOG_TAG);

    // The space settings is always valid.
    return YES;
}

- (BOOL)canCreateP2P {
    DDLogVerbose(@"%@ canCreateP2P", LOG_TAG);

    return NO;
}

- (void)setOwner:(nullable id<TLRepositoryObject>)owner {
    DDLogVerbose(@"%@ setOwner: %@", LOG_TAG, owner);

}

- (nullable id<TLRepositoryObject>)getOwner {
    
    return nil;
}

- (nonnull TLDatabaseIdentifier *)identifier {
    
    return self.databaseId;
}

- (nonnull NSUUID *)objectId {
    
    return self.uuid;
}

- (BOOL)fixSpaceSettingName {

    if (self.isSecret) {
        return NO;
    }

    if (!self.name || [self.name isEqualToString:@""] || [self.name isEqualToString:oldDefaultLabel] || [self.name isEqualToString:@"Default"]) {
        self.name = defaultSpaceSettings.name;
        return YES;
    }

    return NO;
}
@end

#undef LOG_TAG
#define LOG_TAG @"TLSpaceSettingsFactory"

//
// Implementation: TLSpaceSettingsFactory
//

@implementation TLSpaceSettingsFactory

- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    return [[TLSpaceSettings alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
}

- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    
    [(TLSpaceSettings *)object updateWithName:name description:description attributes:attributes modificationDate:modificationDate];
}

- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {

    NSString *objectName = nil, *objectDescription = nil;
    for (TLAttributeNameValue *attribute in attributes) {
        NSString *name = attribute.name;
        if ([name isEqualToString:@"name"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectName = (NSString *) attribute.value;
        } else if ([name isEqualToString:@"description"] && [attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            objectDescription = (NSString *) attribute.value;
        }
    }

    // 2 attributes: name, description are mapped to repository columns and they are dropped.
    // No need to call the importService since there is no relations.
    TLSpaceSettings *spaceSettings = [[TLSpaceSettings alloc] initWithIdentifier:identifier uuid:uuid creationDate:creationDate name:objectName description:objectDescription attributes:attributes modificationDate:creationDate];
    return spaceSettings;
}

@end

