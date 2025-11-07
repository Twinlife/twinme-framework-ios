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
// Interface: TLCreateGroupExecutor
//

@class TLTwinmeContext;
@class TLGroup;
@class TLSpace;
@class TLTwincodeOutbound;
@class TLInvitationDescriptor;

@interface TLCreateGroupExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space invitationTwincode:(nonnull TLTwincodeOutbound *)invitationTwincode;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space invitation:(nonnull TLInvitationDescriptor *)invitation;

@end
