/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLUpdateContactAndIdentityExecutor
//

@class TLTwinmeContext;
@class TLContact;
@class TLSpace;
@class TLCapabilities;

@interface TLUpdateContactAndIdentityExecutor : TLAbstractTimeoutTwinmeExecutor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact contactName:(nonnull NSString *)contactName description:(nullable NSString *)description;

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact identityName:(nonnull NSString *)identityName identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities;

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact identityName:(nullable NSString *)identityName identityAvatarId:(nullable TLImageId *)identityAvatarId identityDescription:(nullable NSString *)identityDescription capabilities:(nullable TLCapabilities*)capabilities timeout:(NSTimeInterval)timeout;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact space:(nonnull TLSpace *)space;

@end
