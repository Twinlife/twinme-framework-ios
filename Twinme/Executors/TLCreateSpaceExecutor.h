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
// Interface: TLCreateSpaceExecutor
//

@class TLTwinmeContext;
@class TLSpace;
@class TLProfile;
@class TLSpaceSettings;

@interface TLCreateSpaceExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar name:(nullable NSString *)name avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar isDefault:(BOOL)isDefault;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings profile:(nullable TLProfile *)profile isDefault:(BOOL)isDefault;

@end
