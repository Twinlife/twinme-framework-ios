/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOriginator.h"
#import "TLTwinmeRepositoryObject.h"

//
// Interface: TLInvitation
//

@class TLSpace;
@class TLDescriptorId;
@class TLInvitationCode;

@interface TLInvitation : TLTwinmeObject

/// The group member twincode outbound to which the invitation was sent.
@property (nullable) NSUUID *groupMemberTwincodeOutboundId;

/// The group id to which the invitation was sent.
@property (nullable) NSUUID *groupId;

/// The optional descriptor that contains the invitation twincode.
@property (nullable) TLDescriptorId *descriptorId;

/// The space that owns this invitation.
@property (nullable) TLSpace *space;

@property (nullable) TLInvitationCode *invitationCode;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

@end
