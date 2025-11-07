/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLUpdateCallReceiverExecutor
//

@class TLTwinmeContext;
@class TLCallReceiver;
@class TLCapabilities;

@interface TLUpdateCallReceiverExecutor : TLAbstractTimeoutTwinmeExecutor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities*)capabilities;

@end
