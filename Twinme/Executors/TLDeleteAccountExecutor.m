/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLAccountService.h>

#import "TLDeleteAccountExecutor.h"
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
// version: 1.2
//

static const int DELETE_ACCOUNT = 1 << 0;
static const int DELETE_ACCOUNT_DONE = 1 << 1;

//
// Interface(): TLDeleteAccountExecutor
//

@class TLDeleteAccountExecutorAccountServiceDelegate;

@interface TLDeleteAccountExecutor()

@property (nonatomic, readonly, nonnull) TLDeleteAccountExecutorAccountServiceDelegate *accountServiceDelegate;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onDeleteAccount;

- (void)stop;

@end

//
// Interface: TLDeleteAccountExecutorAccountServiceDelegate
//

@interface TLDeleteAccountExecutorAccountServiceDelegate:NSObject <TLAccountServiceDelegate>

@property (weak) TLDeleteAccountExecutor* executor;

- (instancetype)initWithExecutor:(nonnull TLDeleteAccountExecutor *)executor;

@end

//
// Implementation: TLDeleteAccountExecutorAccountServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteAccountExecutorAccountServiceDelegate"

@implementation TLDeleteAccountExecutorAccountServiceDelegate

- (instancetype)initWithExecutor:(nonnull TLDeleteAccountExecutor *)executor {
    DDLogVerbose(@"%@ initWithExecutor: %@", LOG_TAG, executor);
    
    self = [super init];
    
    if (self) {
        _executor = executor;
    }
    return self;
}

- (void)onDeleteAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ onDeleteAccountWithRequestId: %lld", LOG_TAG, requestId);
    
    int operationId = [self.executor getOperationWithRequestId:requestId];
    if (operationId) {
        [self.executor onDeleteAccount];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.executor getOperationWithRequestId:requestId];
    if (operationId) {
        [self.executor onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        [self.executor onOperation];
    }
}

@end

//
// Implementation: TLDeleteAccountExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteAccountExecutor"

@implementation TLDeleteAccountExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld", LOG_TAG, twinmeContext, requestId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _accountServiceDelegate = [[TLDeleteAccountExecutorAccountServiceDelegate alloc] initWithExecutor:self];
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getAccountService] addDelegate:self.accountServiceDelegate];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    // Restart everything!
    self.state = 0;
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 1: delete the account (all contact unbind and twincode undeploy is handled by the server).
    //
    
    if ((self.state & DELETE_ACCOUNT) == 0) {
        self.state |= DELETE_ACCOUNT;
        
        int64_t requestId = [self newOperation:DELETE_ACCOUNT];
        DDLogVerbose(@"%@ deleteAccount: %lld", LOG_TAG, requestId);
        
        [[self.twinmeContext getAccountService] deleteAccountWithRequestId:requestId];
        return;
    }
    if ((self.state & DELETE_ACCOUNT_DONE) == 0) {
        return;
    }

    //
    // Last Step
    //
    
    [self.twinmeContext onDeleteAccountWithRequestId:self.requestId];
    [self stop];
}


- (void)onDeleteAccount {
    DDLogVerbose(@"%@ onDeleteAccount", LOG_TAG);

    self.state |= DELETE_ACCOUNT_DONE;
    [self onOperation];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    [[self.twinmeContext getAccountService] removeDelegate:self.accountServiceDelegate];

    [super stop];
}

@end

