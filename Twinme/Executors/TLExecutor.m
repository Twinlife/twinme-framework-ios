/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLBaseService.h>

#import "TLExecutor.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.0
//

//
// Interface: TLExecutor ()
//

@interface TLExecutor ()

@property (nonatomic, readonly, nonnull) NSMutableArray *executors;

@end

//
// Implementation: TLExecutorTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLExecutorTwinmeContextDelegate"

@implementation TLExecutorTwinmeContextDelegate

- (instancetype)initWithExecutor:(TLExecutor *)executor {
    DDLogVerbose(@"%@ initWithExecutor: %@", LOG_TAG, executor);
    
    self = [super init];
    if (self) {
        _executor = executor;
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    self.executor = nil;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeReady];
        [self.executor onOperation];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeOnline];
        [self.executor onOperation];
    }
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeOffline];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (self.executor) {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        NSNumber *operationId = self.executor.requestIds[lRequestId];
        if (operationId != nil) {
            [self.executor.requestIds removeObjectForKey:lRequestId];
            [self.executor onErrorWithOperationId:operationId.intValue errorCode:errorCode errorParameter:errorParameter];
            [self.executor onOperation];
        }
    }
}

@end

//
// Implementation: TLExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLExecutor"

@implementation TLExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld", LOG_TAG, twinmeContext, requestId);
    
    self = [super init];
    if (self) {
        _twinmeContext = twinmeContext;
        _requestId = requestId;

        _state = 0;
        _requestIds = [NSMutableDictionary dictionary];
        _restarted = NO;
        _stopped = NO;
        
        _executors = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
}

- (void)execute:(nonnull void (^)(void))block {
    DDLogVerbose(@"%@ execute", LOG_TAG);

    BOOL isStopped;
    @synchronized (self) {
        isStopped = self.stopped;
        if (!isStopped) {
            [self.executors addObject:block];
        }
    }

    // If we are stopped, we must run the block immediately (nobody else will do it).
    if (isStopped) {
        block();
    }
}

#pragma mark - Private methods

- (int64_t)newOperation:(int) operationId {
    DDLogVerbose(@"%@ newOperation: %d", LOG_TAG, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    self.requestIds[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:operationId];
    return requestId;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
    }
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
    [self stop];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:errorCode errorParameter:errorParameter];
    [self stop];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    while (YES) {
        void (^block)(void);

        @synchronized (self) {
            self.stopped = YES;

            if (self.executors.count == 0) {
                return;
            }
            block = [self.executors lastObject];
            [self.executors removeLastObject];
        }
        block();
    }
}

@end
