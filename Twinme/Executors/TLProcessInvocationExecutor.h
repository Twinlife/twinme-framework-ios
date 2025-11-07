/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLProcessInvocationExecutor
//

@class TLTwinmeContext;
@class TLInvocation;
@class TLTwincodeInvocation;
@protocol TLRepositoryObject;

@interface TLProcessInvocationExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLTwincodeInvocation *)invocation withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvocation* _Nullable invocation))block;

@end
