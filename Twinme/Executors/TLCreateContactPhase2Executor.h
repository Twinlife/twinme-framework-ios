/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLCreateContactPhase2Executor
//

@class TLTwinmeContext;
@class TLProfile;
@class TLInvitation;
@class TLSpace;
@class TLPairInviteInvocation;

@interface TLCreateContactPhase2Executor : TLAbstractConnectedTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairInviteInvocation *)invocation space:(nonnull TLSpace*)space profile:(nonnull TLProfile *)profile;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairInviteInvocation *)invocation invitation:(nonnull TLInvitation *)invitation;

- (void)start;

@end
