/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLBindContactExecutor
//

@class TLTwinmeContext;
@class TLContact;
@class TLPairBindInvocation;

@interface TLBindContactExecutor : TLAbstractConnectedTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairBindInvocation *)invocation contact:(nonnull TLContact *)contact;

@end
