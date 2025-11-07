/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLConversationService.h>

#import "TLGroupRegisteredExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLGroupRegisteredInvocation.h"
#import "TLGroup.h"

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

static const int SUBSCRIBE_MEMBER = 1 << 0;

//
// Interface: TLGroupRegisteredExecutor ()
//

@class TLGroupRegisteredExecutorTwinmeContextDelegate;

@interface TLGroupRegisteredExecutor ()

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, readonly) int64_t requestId;
@property (nonatomic, readonly) NSUUID *invocationId;
@property (nonatomic, readonly, nonnull) TLGroup *group;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *adminTwincodeOutbound;
@property (nonatomic, readonly) long adminPermissions;
@property (nonatomic, readonly) long permissions;

@property (nonatomic) int state;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *requestIds;
@property (nonatomic) BOOL restarted;
@property (nonatomic) BOOL stopped;

@property (nonatomic, readonly, nonnull) TLGroupRegisteredExecutorTwinmeContextDelegate *twinmeContextDelegate;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: TLGroupRegisteredExecutorTwinmeContextDelegate
//

@interface TLGroupRegisteredExecutorTwinmeContextDelegate : NSObject <TLTwinmeContextDelegate>

@property TLGroupRegisteredExecutor *executor;

- (instancetype)initWithExecutor:(TLGroupRegisteredExecutor *)executor;

- (void)dispose;

@end

//
// Implementation: TLGroupRegisteredExecutorTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupRegisteredExecutorTwinmeContextDelegate"

@implementation TLGroupRegisteredExecutorTwinmeContextDelegate

- (instancetype)initWithExecutor:(TLGroupRegisteredExecutor *)executor {
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
// Implementation: TLGroupRegisteredExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupRegisteredExecutor"

@implementation TLGroupRegisteredExecutor

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId groupRegisteredInvocation:(nonnull TLGroupRegisteredInvocation *)groupRegisteredInvocation group:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld TLGroupRegisteredInvocation: %@ group: %@", LOG_TAG, twinmeContext, requestId, groupRegisteredInvocation, group);
    
    self = [super init];
    if (self) {
        _twinmeContext = twinmeContext;
        _requestId = requestId;
        
        _invocationId = groupRegisteredInvocation.uuid;
        _adminTwincodeOutbound = groupRegisteredInvocation.adminMemberTwincode;
        _permissions = groupRegisteredInvocation.memberPermissions;
        _adminPermissions = groupRegisteredInvocation.adminPermissions;
        _group = group;

        TL_ASSERT_NOT_NULL(twinmeContext, _group, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

        _state = 0;
        _requestIds = [NSMutableDictionary dictionary];
        _restarted = NO;
        _stopped = NO;
        
        _twinmeContextDelegate = [[TLGroupRegisteredExecutorTwinmeContextDelegate alloc] initWithExecutor:self];
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    [self.twinmeContext addDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (int64_t)newOperation:(int)operationId {
    DDLogVerbose(@"%@ newOperation", LOG_TAG);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    self.requestIds[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:operationId];
    return requestId;
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
    
    //
    // Step 1
    //

    if (self.adminTwincodeOutbound && self.group.groupTwincodeOutboundId) {
        if ((self.state & SUBSCRIBE_MEMBER) == 0) {
            self.state |= SUBSCRIBE_MEMBER;
        
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.group, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

            int64_t requestId = [self newOperation:SUBSCRIBE_MEMBER];

            [[self.twinmeContext getConversationService] registeredGroupWithRequestId:requestId group:self.group adminTwincodeOutbound:self.adminTwincodeOutbound adminPermissions:self.adminPermissions permissions:self.permissions];
        }
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

    [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:errorCode errorParameter:errorParameter];
    [self stop];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    self.stopped = YES;

    [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];

    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
    [self.twinmeContextDelegate dispose];
}

@end
