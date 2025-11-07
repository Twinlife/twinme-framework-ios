/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLAbstractTimeoutTwinmeExecutor.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the SingleThreadExecutor provided by the twinlife library
// Executor and delegates are reachable (not eligible for garbage collection) between start() and stop() calls
//
// version: 1.1
//

//
// Interface: TLAbstractTimeoutTwinmeExecutor ()
//

@interface TLAbstractTimeoutTwinmeExecutor ()

@property (nullable) TLTwinmePendingRequest *requestList;
@property BOOL connected;

@end

//
// Implementation: TLAbstractTwinmeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLAbstractTimeoutTwinmeExecutor"

@implementation TLAbstractTimeoutTwinmeExecutor

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld", LOG_TAG, twinmeContext, requestId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeLimit:timeout];
    
    if (self) {
        _state = 0;
        _stopped = NO;
        _restarted = NO;
        _requestList = nil;
        _connected = NO;
        _needOnline = YES;
    }
    return self;
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    self.stopped = YES;

    [self onFinish];
}

- (int64_t)newOperation:(int)operationId {
    DDLogVerbose(@"%@ newOperation; %d", LOG_TAG, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    @synchronized (self) {
        self.requestList = [[TLTwinmePendingRequest alloc] initWithRequestId:requestId operationId:operationId next:self.requestList];
    }
    return requestId;
}

- (int)getOperationWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ getOperationWithRequestId; %lld", LOG_TAG, requestId);

    @synchronized (self) {
        TLTwinmePendingRequest *prev = nil;
        TLTwinmePendingRequest *current = self.requestList;
        while (current) {
            if (current.requestId == requestId) {
                if (prev) {
                    prev.next = current.next;
                } else {
                    self.requestList = current.next;
                }
                return current.operationId;
            }
            prev = current;
            current = current.next;
        }
    }
    return 0;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    // If we don't need to be online, start the operation now.
    if (!self.needOnline) {
        [self onOperation];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    self.connected = YES;
    self.restarted = NO;
    [super onTwinlifeOnline];
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    // Keep connected set for fireErrorWithErrorCode().
    self.restarted = YES;
    [super onTwinlifeOffline];
}

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ fireErrorWithErrorCode %d", LOG_TAG, errorCode);

    [super fireErrorWithErrorCode:errorCode];
    [self stop];
    [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:errorCode errorParameter:nil];
}

- (void)fireTimeout {
    DDLogVerbose(@"%@ fireTimeout", LOG_TAG);

    // If we were connected, we cannot interrupt the executor and we have to wait
    // to reconnection until everything completes.  We can report the timeout only
    // when we never reached connection.
    if (!self.connected) {
        [self fireErrorWithErrorCode:TLBaseServiceErrorCodeTimeoutError];
    }
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Last Step
    //
    [self stop];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    // Mark the executor as stopped before calling fireOnError().
    [self stop];

    [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:errorCode errorParameter:errorParameter];
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        [self onOperation];
    }
}

@end
