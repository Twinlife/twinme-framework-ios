/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Julien Poumarat (Julien.Poumarat@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLCreateProfileExecutor
//

@class TLTwinmeContext;
@class TLSpace;
@class TLCapabilities;

@interface TLCreateProfileExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities space:(nullable TLSpace *)space;

@end
