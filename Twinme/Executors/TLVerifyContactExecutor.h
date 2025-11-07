/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

//
// Interface: TLVerifyContactExecutor
//

@class TLTwinmeContext;
@class TLContact;
@class TLTwincodeURI;

@interface TLVerifyContactExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twincodeURI:(nonnull TLTwincodeURI *)twincodeURI trustMethod:(TLTrustMethod)trustMethod  withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block;

@end
