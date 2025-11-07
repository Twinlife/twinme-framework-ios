/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOriginator.h"
#import "TLCapabilities.h"
#import "TLTwinmeRepositoryObject.h"

//
// Interface: TLGroup
//

@class TLRepositoryService;
@class TLObject;
@class TLTwincodeOutbound;
@class TLGroupMember;

@interface TLGroup : TLTwinmeOriginatorObject

/// The group twincode factory (only known by the creator of the group).
@property (nullable) NSUUID *groupTwincodeFactoryId;

/// The group picture as defined on the group twincode outbound (set by the group owner).
@property (nullable) TLImageId *groupAvatarId;

/// The group usage score.
// @property double usageScore;

/// The date in ms when the contact has received/sent a message/photo/file/image/video.
// @property int64_t lastMessageDate;

/// When TRUE, indicates that the user asked to leave this group.  The group object must be hidden to the user
/// but kept until other group members are informed about the leave.
@property BOOL isLeaving;

/// When TRUE, indicates that the group object has been deleted.
@property BOOL isDeleted;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

/// Update the group score information.
// - (BOOL)updateStatsWithObject:(nonnull TLObject *)object;

/// The member twincode outbound id that created this group.
- (nullable NSUUID *)createdByMemberTwincodeOutboundId;

/// The member twincode outbound id that invited this member.
- (nullable NSUUID *)invitedByMemberTwincodeOutboundId;

/// Returns YES if the user is owner of this group.
- (BOOL)isOwner;

- (BOOL)checkInvariants;

/// The group public name.
- (nonnull NSString *)groupPublicName;

/// The group twincode outbound used to identify the group globally.
- (nullable NSUUID *)groupTwincodeOutboundId;

/// The group twincode object (holds the group twincode attributes: name, image).
- (nullable TLTwincodeOutbound *)groupTwincodeOutbound;

- (BOOL)updatePeerName:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound oldName:(nonnull NSString *)oldName;

@end
