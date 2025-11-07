/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>

#import "TLSpace.h"
#import "TLCapabilities.h"
#import "TLTwinmeRepositoryObject.h"

//
// Implementation: TLTwinmeObjectFactory
//

@implementation TLTwinmeObjectFactory : NSObject

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion ownerFactory:(nullable id<TLRepositoryObjectFactory>)ownerFactory twincodeUsage:(int)twincodeUsage {
    
    self = [super init];
    if (self) {
        _schemaId = schemaId;
        _schemaVersion = schemaVersion;
        _ownerFactory = ownerFactory;
        _twincodeUsage = twincodeUsage;
    }
    return self;
}

- (BOOL)isImmutable {
    
    return NO;
}

- (BOOL)isLocal {
    
    return YES;
}

@end

//
// Implementation: TLTwinmeObject
//

@implementation TLTwinmeObject

@synthesize peerTwincodeOutbound;
@synthesize twincodeOutbound;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID*)uuid creationDate:(int64_t)creationDate modificationDate:(int64_t)modificationDate {
    
    self = [super init];
    if (self) {
        _databaseId = identifier;
        _uuid = uuid;
        _creationDate = creationDate;
        _modificationDate = modificationDate;
    }
    return self;
}

- (void)exportAttributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes name:(nullable NSString *)name description:(nullable NSString *)description twincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId space:(nullable TLSpace *)space {
    
    if (space) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"spaceId" stringValue:[space uuid].UUIDString]];
    }
    if (name) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"name" stringValue:name]];
    }
    if (description) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"description" stringValue:description]];
    }
    if (twincodeInbound) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"twincodeInboundId" stringValue:twincodeInbound.uuid.UUIDString]];
    }
    if (twincodeOutbound) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"twincodeOutboundId" stringValue:twincodeOutbound.uuid.UUIDString]];
    }
    if (twincodeFactoryId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:@"twincodeFactoryId" stringValue:twincodeFactoryId.UUIDString]];
    }
}

- (void)setTwincodeFactory:(nonnull TLTwincodeFactory *)twincodeFactory {
    
    @synchronized (self) {
        self.twincodeOutbound = twincodeFactory.twincodeOutbound;
        self.twincodeInbound = twincodeFactory.twincodeInbound;
        self.twincodeFactoryId = twincodeFactory.uuid;
    }
}

- (nullable TLImageId *)avatarId {
    
    @synchronized (self) {
        return self.twincodeOutbound == nil ? nil : self.twincodeOutbound.avatarId;
    }
}

- (BOOL)isValid {
    
    return YES;
}

- (BOOL)canCreateP2P {
    
    return NO;
}

- (void)setOwner:(nullable id<TLRepositoryObject>)owner {

}

- (nullable id<TLRepositoryObject>)owner {
    
    return nil;
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll { 

    return [NSMutableArray array];
}

- (nonnull TLDatabaseIdentifier *)identifier { 

    return self.databaseId;
}

- (nonnull NSUUID *)objectId { 

    return self.uuid;
}

- (nullable NSString *)identityName {
    
    @synchronized (self) {
        return self.twincodeOutbound ? self.twincodeOutbound.name : nil;
    }
}

- (nullable NSString *)identityDescription {
    
    @synchronized (self) {
        return self.twincodeOutbound ? self.twincodeOutbound.twincodeDescription : nil;
    }
}

- (nullable TLImageId *)identityAvatarId {
    
    @synchronized (self) {
        return self.twincodeOutbound ? self.twincodeOutbound.avatarId : nil;
    }
}

@end

//
// Implementation: TLTwinmeOriginatorObject
//

@implementation TLTwinmeOriginatorObject

- (nullable id<TLRepositoryObject>)owner {
    
    return self.space;
}

- (nullable NSString *)peerDescription {
    
    @synchronized (self) {
        return self.peerTwincodeOutbound ? self.peerTwincodeOutbound.twincodeDescription : nil;
    }
}

- (nullable TLImageId *)avatarId {

    @synchronized (self) {
        return self.peerTwincodeOutbound ? self.peerTwincodeOutbound.avatarId : nil;
    }
}

- (nullable NSUUID *)twincodeInboundId {
    
    @synchronized (self) {
        return self.twincodeInbound ? self.twincodeInbound.uuid : nil;
    }
}

- (nullable NSUUID *)twincodeOutboundId {
    
    @synchronized (self) {
        return self.twincodeOutbound ? self.twincodeOutbound.uuid : nil;
    }
}

- (nullable NSUUID *)peerTwincodeOutboundId {
    
    @synchronized (self) {
        return self.peerTwincodeOutbound ? self.peerTwincodeOutbound.uuid : nil;
    }
}

- (BOOL)hasPeer {
    
    return NO;
}

- (BOOL)isGroup {
    
    return NO;
}

- (BOOL)hasPrivateIdentity {
    
    @synchronized (self) {
        return self.twincodeInbound != nil;
    }
}

/// Get the peer's capabilities describing the operations we can do on this relation.
- (nonnull TLCapabilities *)capabilities {
    
    return [[TLCapabilities alloc] init];
}

- (nonnull TLCapabilities *)identityCapabilities {
    
    return [[TLCapabilities alloc] init];
}

- (BOOL)canAcceptP2PWithTwincodeId:(nullable NSUUID *)twincodeId {
    
    return NO;
}

@end

