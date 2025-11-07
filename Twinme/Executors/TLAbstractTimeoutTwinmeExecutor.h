/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeAction.h"

#define DEFAULT_TIMEOUT (15.0) // 15s to give enough time for connection to setup...

//
// Interface: TLAbstractTimeoutTwinmeExecutor
//

@class TLTwinmeContext;
@protocol TLTwinmeContextDelegate;

@interface TLAbstractTimeoutTwinmeExecutor : TLTwinmeAction

@property (nonatomic) BOOL restarted;
@property (nonatomic) int state;
@property (nonatomic) BOOL stopped;
@property (nonatomic) BOOL needOnline;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId timeout:(NSTimeInterval)timeout;

- (void)stop;

- (int64_t)newOperation:(int) operationId;

- (int)getOperationWithRequestId:(int64_t)requestId;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end
