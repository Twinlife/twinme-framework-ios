/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLChangeCallReceiverTwincodeExecutor
//

@class TLTwinmeContext;
@class TLCallReceiver;

@interface TLChangeCallReceiverTwincodeExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

@end
