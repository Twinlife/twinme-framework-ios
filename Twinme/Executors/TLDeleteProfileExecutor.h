/*
 *  Copyright (c) 2016-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLDeleteObjectExecutor.h"

//
// Interface: TLDeleteProfileExecutor
//

@class TLTwinmeContext;
@class TLProfile;

@interface TLDeleteProfileExecutor : TLDeleteObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId profile:(nonnull TLProfile *)profile timeout:(NSTimeInterval)timeout withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable profileId))block;

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object;

@end
