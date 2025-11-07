/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteObjectExecutor.h"

//
// Interface: TLDeleteInvitationExecutor
//

@class TLTwinmeContext;
@class TLInvitation;

@interface TLDeleteInvitationExecutor : TLDeleteObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation timeout:(NSTimeInterval)timeout;

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object;

@end
