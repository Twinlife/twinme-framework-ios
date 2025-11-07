/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLGetInvitationCodeExecutor
//

@class TLTwinmeContext;
@class TLTwincodeOutbound;

@interface TLGetInvitationCodeExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId code:(nonnull NSString *)code;

@end
