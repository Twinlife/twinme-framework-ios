/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLUpdateGroupExecutor
//

@class TLTwinmeContext;
@class TLGroup;
@class TLSpace;
@class TLCapabilities;

@interface TLUpdateGroupExecutor : TLAbstractTimeoutTwinmeExecutor

/// Initialize the executor to update the group name and group avatar.
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name groupDescription:(nullable NSString *)groupDescription groupAvatar:(nullable UIImage *)groupAvatar groupLargeAvatar:(nullable UIImage *)groupLargeAvatar groupCapabilities:(nullable TLCapabilities *)capabilities;

/// Initialize the executor to move the group to the given space.
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group space:(nonnull TLSpace *)space;

/// Initialize the executor to update the user's profile and avatar within the group.
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name profileAvatar:(nullable UIImage *)profileAvatar profileLargeAvatar:(nullable UIImage *)profileLargeAvatar;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group identityName:(nonnull NSString *)identityName identityAvatarId:(nullable TLImageId *)identityAvatarId identityDescription:(nullable NSString *)identityDescription timeout:(NSTimeInterval)timeout;

@end
