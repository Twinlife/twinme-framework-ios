/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLCreateCallReceiverExecutor
//

@class TLTwinmeContext;
@class TLSpace;
@class TLCapabilities;

@interface TLCreateCallReceiverExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nullable NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities *)capabilities space:(nullable TLSpace *)space;

@end
