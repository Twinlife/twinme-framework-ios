/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInvitedGroupMember.h"

//
// Implementation: TLInvitedGroupMember
//

@implementation TLInvitedGroupMember

- (nullable instancetype)initWithContact:(nonnull TLContact *)contact invitation:(nonnull TLDescriptorId *)invitation {
    
    self = [super init];
    if (self) {
        _contact = contact;
        _invitation = invitation;
    }
    return self;
}

- (void)setOwner:(nullable id<TLRepositoryObject>)owner {
    
    self.contact.owner = owner;
}

- (nullable id<TLRepositoryObject>)owner {
    
    return self.contact.owner;
}

- (void)setTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound {
    
    self.contact.twincodeInbound = twincodeInbound;
}

- (nullable TLTwincodeInbound *)twincodeInbound {
    
    return self.contact.twincodeInbound;
}

- (void)setTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound {
    
    self.contact.twincodeOutbound = twincodeOutbound;
}

- (nullable TLTwincodeOutbound *)twincodeOutbound {
    
    return self.contact.twincodeOutbound;
}

- (void)setPeerTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound {
    
    self.contact.peerTwincodeOutbound = twincodeOutbound;
}

- (nullable TLTwincodeOutbound *)peerTwincodeOutbound {
    
    return self.contact.peerTwincodeOutbound;
}

- (void)setModificationDate:(int64_t)date {
    
    // No, do not update modification date.
}

- (int64_t)modificationDate {
    
    return self.contact.modificationDate;
}

- (NSUUID *)uuid {
    
    return self.contact.uuid;
}

- (NSString *)name {
    
    return self.contact.name;
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    
    return [self.contact attributesWithAll:exportAll];
}


- (BOOL)isValid {
    
    return [self.contact isValid];
}

- (nonnull NSString *)objectDescription {
    
    return self.contact.objectDescription;
}

- (BOOL)canCreateP2P {
    
    return NO;
}

- (BOOL)canAcceptP2PWithTwincodeId:(nullable NSUUID *)twincodeId {

    return NO;
}

- (TLImageId *)avatarId {
    
    return self.contact.avatarId;
}

- (NSString *)identityName {
    
    return self.contact.identityName;
}

- (TLImageId *)identityAvatarId {
    
    return self.contact.identityAvatarId;
}

- (NSUUID *)twincodeInboundId {
    
    return self.contact.twincodeInboundId;
}

- (NSUUID *)twincodeOutboundId {
    
    return self.contact.twincodeOutboundId;
}

- (TLSpace *)space {
    
    return self.contact.space;
}

- (BOOL)hasPeer {
    
    return self.contact.hasPeer;
}

- (BOOL)isGroup {
    
    return true;
}

- (double)usageScore {
    
    return [self.contact usageScore];
}

- (int64_t)lastMessageDate {
    
    return [self.contact lastMessageDate];
}

- (nullable NSString *)peerDescription {
    
    return [self.contact peerDescription];
}

- (nonnull TLCapabilities *)capabilities {
    
    return [self.contact capabilities];
}

- (nullable NSString *)identityDescription {
    
    return [self.contact identityDescription];
}

- (nullable NSUUID *)peerTwincodeOutboundId {
    
    return [self.contact peerTwincodeOutboundId];
}

- (BOOL)hasPrivateIdentity {
    
    return [self.contact hasPrivateIdentity];
}

- (nonnull TLCapabilities *)identityCapabilities {
    
    return [self.contact identityCapabilities];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"\nInvitedGroupMember\n"];
    [string appendFormat:@" contact:                       %@\n", self.contact];
    return string;
}

- (nonnull TLDatabaseIdentifier *)identifier { 
    
    return self.contact.identifier;
}

- (nonnull NSUUID *)objectId { 
    
    return self.contact.objectId;
}

@end
