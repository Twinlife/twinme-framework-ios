/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLCreateInvitationExecutor
//

@class TLTwinmeContext;
@class TLGroupMember;
@class TLContact;
@class TLSpace;

@interface TLCreateInvitationExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space groupMember:(nullable TLGroupMember*)groupMember;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space contact:(nonnull TLContact*)contact sendTo:(nonnull NSUUID *)sendTo;

@end
