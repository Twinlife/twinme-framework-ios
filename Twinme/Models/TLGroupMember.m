/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

/**
 * Group member representation for the UI.
 *
 * getName           -> name of the member
 * getAvatar         -> picture of the member
 * getIdentityName   -> name of the member
 * getIdentityAvatar -> picture of the member
 *
 * The group member information is initialized from the group member twincode passed in the constructor.
 * The GroupMember instance is not stored in the repository but it is cached in the Twinme context.
 */

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLGroup.h"
#import "TLGroupMember.h"

#import "TLTwinmeAttributes.h"

#define TL_GROUP_MEMBER_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"1f3b4ea2-0863-4eec-885e-b9d17efd84b7"]

//
// Implementation: TLGroupMember
//

@implementation TLGroupMember

@synthesize modificationDate;

+ (NSUUID *)SCHEMA_ID {
    
    return TL_GROUP_MEMBER_SCHEMA_ID;
}

- (nullable instancetype)initWithOwner:(nonnull id<TLOriginator>)owner twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {

    self = [super init];
    if (self) {
        _group = owner;
        _peerTwincodeOutbound = twincodeOutbound;
        _invitedByMemberTwincodeOutboundId = [TLTwinmeAttributes getInvitedByFromTwincode:(TLTwincode *)twincodeOutbound];
        self.owner = owner;
    }
    return self;
}

- (void)setOwner:(nullable id<TLRepositoryObject>)owner {

    // Called when an object is loaded from the database and linked to its owner.
    // Take the opportunity to link back the Space to its profile if there is a match.
    if ([(NSObject *) owner isKindOfClass:[TLGroup class]]) {
        self.group = (TLGroup *) owner;
    }
}

- (nullable id<TLRepositoryObject>)owner {
    
    return self.group;
}

- (NSUUID *)uuid {

    return self.peerTwincodeOutbound.uuid;
}

- (NSString *)name {
    
    return self.memberName ? self.memberName : NSLocalizedString(@"anonymous", nil);
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {

    return [[NSArray alloc] init];
}


- (BOOL)isValid {

    return YES;
}

- (BOOL)canCreateP2P {

    return YES;
}

- (BOOL)canAcceptP2PWithTwincodeId:(nullable NSUUID *)twincodeId {

    // We don't look at the peer twincode Id to accept the incoming P2P.
    return YES;
}

- (nonnull NSString *)objectDescription {

    return self.name;
}

- (TLImageId *)avatarId {
    
    return self.memberAvatarId;
}

- (NSString *)identityName {
    
    return [self.group identityName];
}

- (TLImageId *)identityAvatarId {
    
    return [self.group identityAvatarId];
}

- (nullable TLTwincodeInbound *)twincodeInbound {
    
    return [self.group twincodeInbound];
}

- (void)setTwincodeInbound:(TLTwincodeInbound *)twincodeInbound {
    
    // Do nothing.
}

- (NSUUID *)twincodeInboundId {
    
    return [self.group twincodeInboundId];
}

- (nullable TLTwincodeOutbound *)twincodeOutbound {

    return [self.group twincodeOutbound];
}

- (void)setTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound {
    
    // Do nothing.
}

- (NSUUID *)twincodeOutboundId {
    
    return [self.group twincodeOutboundId];
}

- (nonnull NSUUID *)memberTwincodeOutboundId {
    
    return self.peerTwincodeOutbound.uuid;
}

- (nullable NSString *)memberName {

    return [self.peerTwincodeOutbound name];
}

- (nullable TLImageId *)memberAvatarId {
    
    return [self.peerTwincodeOutbound avatarId];
}

- (TLSpace *)space {
    
    return self.group.space;
}

- (BOOL)hasPeer {
    
    return self.peerTwincodeOutbound != nil;
}

- (BOOL)isGroup {
    
    return [self.group isGroup];
}

- (double)usageScore {
    
    return [self.group usageScore];
}

- (int64_t)lastMessageDate {
    
    return [self.group lastMessageDate];
}

- (nullable NSString *)peerDescription {
    
    return [self.group peerDescription];
}

- (nonnull TLCapabilities *)capabilities {
    
    return [self.group capabilities];
}

- (nonnull TLCapabilities *)identityCapabilities {
    
    return [self capabilities];
}

- (nullable NSString *)identityDescription {
    
    return [self peerDescription];
}

- (nullable NSUUID *)peerTwincodeOutboundId {

    return self.peerTwincodeOutbound.uuid;
}

- (BOOL)hasPrivateIdentity {
 
    return true;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"\nGroupMember\n"];
#if defined(DEBUG) && DEBUG == 1
    [string appendFormat:@" name:                          %@\n", self.name];
#endif
    [string appendFormat:@" memberTwincodeOutboundId:      %@\n", self.memberTwincodeOutboundId];
    return string;
}

- (nonnull TLDatabaseIdentifier *)identifier {
    
    return self.group.identifier;
}

- (nonnull NSUUID *)objectId {
    
    return self.uuid;
}

@end
