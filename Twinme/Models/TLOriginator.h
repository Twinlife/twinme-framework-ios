/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLRepositoryService.h>

@class TLSpace;
@class TLCapabilities;
@class TLImageId;

//
// Protocol: TLOriginator
//

/**
 * Protocol that describes the originator of a notification event.
 *
 * This interface is implemented by TLContact, TLCallReceiver, TLGroup, TLGroupMember and TLInvitedGroupMember.
 */
@protocol TLOriginator <TLRepositoryObject>

- (nonnull NSUUID *)uuid;

- (nonnull NSString *)name;

- (nullable NSString *)peerDescription;

- (nullable TLImageId *)avatarId;

- (nullable NSString *)identityName;

- (nullable NSString *)identityDescription;

- (nullable TLImageId *)identityAvatarId;

- (nullable NSUUID *)twincodeInboundId;

- (nullable NSUUID *)twincodeOutboundId;

- (nullable NSUUID *)peerTwincodeOutboundId;

- (nullable TLSpace *)space;

- (double)usageScore;

- (int64_t)lastMessageDate;

- (BOOL)hasPeer;

- (BOOL)isGroup;

- (BOOL)hasPrivateIdentity;

/// Check whether it is possible to accept incoming P2P connection with the given peer twincode Id.
- (BOOL)canAcceptP2PWithTwincodeId:(nullable NSUUID *)twincodeId;

/// Get the peer's capabilities describing the operations we can do on this relation.
- (nonnull TLCapabilities *)capabilities;

- (nonnull TLCapabilities *)identityCapabilities;

@end
