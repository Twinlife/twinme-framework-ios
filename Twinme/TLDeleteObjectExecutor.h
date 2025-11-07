/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTimeoutTwinmeExecutor.h"

@class TLTwinmeObject;

#define TL_DELETE_OBJECT_LAST_STATE_BIT  (20)

//
// Interface: TLDeleteObjectExecutor
//

@interface TLDeleteObjectExecutor : TLAbstractTimeoutTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId object:(nonnull TLTwinmeObject *)object invocationId:(nullable NSUUID *)invocationId timeout:(NSTimeInterval)timeout;

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object;

@end
