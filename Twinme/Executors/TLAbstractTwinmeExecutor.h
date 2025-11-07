/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeContextImpl.h"
#import <Twinlife/TLAssertion.h>

//
// Interface: TLExecutorAssertPoint ()
//

@interface TLExecutorAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)CONTACT_INVARIANT;
+(nonnull TLAssertPoint *)EXCEPTION;
+(nonnull TLAssertPoint *)PARAMETER;
+(nonnull TLAssertPoint *)INVALID_TWINCODE;

@end

//
// Interface: TLTwinmePendingRequest
//

@interface TLTwinmePendingRequest : NSObject

@property (readonly) int64_t requestId;
@property (readonly) int operationId;
@property (nullable) TLTwinmePendingRequest* next;

- (nonnull instancetype)initWithRequestId:(int64_t)requestId operationId:(int)operationId next:(nullable TLTwinmePendingRequest *)next;

@end

//
// Interface: TLAbstractTwinmeExecutor
//

@class TLTwinmeContext;
@protocol TLTwinmeContextDelegate;

@interface TLAbstractTwinmeExecutor : NSObject <TLTwinmeContextDelegate>

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, readonly) int64_t requestId;
@property (nonatomic) BOOL restarted;
@property (nonatomic) int state;
@property (nonatomic) BOOL stopped;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId;

- (void)start;

- (void)stop;

- (int64_t)newOperation:(int) operationId;

- (int)getOperationWithRequestId:(int64_t)requestId;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: TLAbstractConnectedTwinmeExecutor
//

@interface TLAbstractConnectedTwinmeExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId;

- (void)onTwinlifeReady;

@end

