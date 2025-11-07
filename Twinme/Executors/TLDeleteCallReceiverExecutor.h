/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLDeleteObjectExecutor.h"

//
// Interface: TLDeleteCallReceiverExecutor
//

@class TLTwinmeContext;
@class TLCallReceiver;


@interface TLDeleteCallReceiverExecutor : TLDeleteObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver timeout:(NSTimeInterval)timeout;

@end
