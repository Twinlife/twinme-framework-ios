/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLCreateContactPhase1Executor
//

@class TLTwinmeContext;
@class TLSpace;
@class TLProfile;

@interface TLCreateContactPhase1Executor : TLAbstractTimeoutTwinmeExecutor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound space:(nonnull TLSpace *)space profile:(nonnull TLProfile *)profile;

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound space:(nonnull TLSpace *)space identityName:(nonnull NSString *)identityName identityAvatarId:(nonnull TLImageId *)identityAvatarId;

@end
