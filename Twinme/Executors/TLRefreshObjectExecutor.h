/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLRefreshObjectExecutor
//

@class TLTwinmeContext;
@class TLPairRefreshInvocation;
@protocol TLOriginator;

@interface TLRefreshObjectExecutor : TLAbstractConnectedTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairRefreshInvocation *)invocation subject:(nonnull id<TLOriginator>)subject;

@end
