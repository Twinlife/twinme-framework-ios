/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import "TLOriginator.h"

/**
 * Group or Twinroom member representation for the UI.
 *
 * The group member information is initialized from the group member twincode passed in the constructor.
 * The TLGroupMember instance is not stored in the repository but it is cached in the Twinme context.
 */

//
// Interface: TLGroupMember
//

@class TLTwincodeOutbound;
@class TLGroup;

@interface TLGroupMember : NSObject<TLOriginator>

+ (nonnull NSUUID *)SCHEMA_ID;

/// The group or twinroom contact object to which this group member belongs.
@property (nullable) id<TLOriginator> group;

/// The member twincode outbound id that invited this member.
@property (nullable) NSUUID *invitedByMemberTwincodeOutboundId;

@property (nullable) TLTwincodeOutbound *peerTwincodeOutbound;

- (nullable instancetype)initWithOwner:(nonnull id<TLOriginator>)owner twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

/// The group member twincode outbound id.
- (nonnull NSUUID *)memberTwincodeOutboundId;

/// The group member name as found on the twincode attributes.
- (nullable NSString *)memberName;

/// The group member's picture as found on the twincode attributes.
- (nullable TLImageId *)memberAvatarId;

@end
