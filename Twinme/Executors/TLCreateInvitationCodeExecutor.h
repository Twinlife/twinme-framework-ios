/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLCreateInvitationCodeExecutor
//

@class TLTwinmeContext;
@class TLTwincodeOutbound;

@interface TLCreateInvitationCodeExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId validityPeriod:(int)validityPeriod;

@end
