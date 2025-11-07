/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

@implementation TLExecutorAssertPoint

TL_CREATE_ASSERT_POINT(CONTACT_INVARIANT, 2001)
TL_CREATE_ASSERT_POINT(EXCEPTION, 2002)
TL_CREATE_ASSERT_POINT(INVALID_TWINCODE, 2003)
TL_CREATE_ASSERT_POINT(PARAMETER, 2004)

@end

//
// Executor and delegates are running in the SingleThreadExecutor provided by the twinlife library
// Executor and delegates are reachable (not eligible for garbage collection) between start() and stop() calls
//
// version: 1.4
//

//
// Interface: TLAbstractTwinmeExecutor ()
//

@interface TLAbstractTwinmeExecutor ()

@property (nullable) TLTwinmePendingRequest *requestList;

@end

//
// Implementation: TLTwinmePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmePendingRequest"

@implementation TLTwinmePendingRequest
- (nonnull instancetype)initWithRequestId:(int64_t)requestId operationId:(int)operationId next:(nullable TLTwinmePendingRequest *)next {
    DDLogVerbose(@"%@ initWithRequestId: %lld operationId: %d next: %@", LOG_TAG, requestId, operationId, next);

    self = [super init];
    if (self) {
        _requestId = requestId;
        _operationId = operationId;
        _next = next;
    }
    return self;
}

@end

//
// Implementation: TLAbstractTwinmeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLAbstractTwinmeExecutor"

@implementation TLAbstractTwinmeExecutor

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld", LOG_TAG, twinmeContext, requestId);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
        _requestId = requestId;

        _state = 0;
        _stopped = NO;
        _restarted = NO;
        _requestList = nil;
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    [self.twinmeContext addDelegate:self];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    self.stopped = YES;

    [self.twinmeContext removeDelegate:self];
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
    
    [self onOperation];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    self.restarted = NO;
    [self onOperation];
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    self.restarted = YES;
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

//
// Implementation: TLAbstractConnectedTwinmeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLAbstractConnectedTwinmeExecutor"

@implementation TLAbstractConnectedTwinmeExecutor

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld", LOG_TAG, twinmeContext, requestId);
    
    return [super initWithTwinmeContext:twinmeContext requestId:requestId];
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    // Do not start the operation: wait for the onTwinlifeOnline().
    if (![self.twinmeContext isConnected]) {
        [self.twinmeContext connect];
    }
}

@end

