/*
 *  Copyright (c) 2018-2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import "TLOriginator.h"
#import "TLContact.h"

/**
 * Represents a contact that was invited to join a group.
 *
 * Objects of this class are not stored in the repository nor cached in the Twinme context.
 * They are created on demand by the UI by looking at the pending invitation and the contact.
 *
 * The pending invitation only concern the invitations sent by the current user (not the invitation
 * send by other group members).
 */

//
// Interface: TLInvitedGroupMember
//

@class TLDescriptorId;

@interface TLInvitedGroupMember : NSObject<TLOriginator>

/// The invitation that was sent to the contact so that he joins the group.
@property (readonly, nonnull) TLDescriptorId *invitation;

/// The contact that was invited.
@property (readonly, nonnull) TLContact *contact;

- (nullable instancetype)initWithContact:(nonnull TLContact *)contact invitation:(nonnull TLDescriptorId *)invitation;

@end
