/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>

#import "TLBindAccountMigrationExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLPairProtocol.h"
#import "TLAccountMigration.h"
#import "TLNotificationCenter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.5
//

static const int GET_PEER_TWINCODE_OUTBOUND = 1 << 0;
static const int GET_PEER_TWINCODE_OUTBOUND_DONE = 1 << 1;
static const int UPDATE_TWINCODE_INBOUND = 1 << 2;
static const int UPDATE_TWINCODE_INBOUND_DONE = 1 << 3;
static const int UPDATE_OBJECT = 1 << 4;
static const int UPDATE_OBJECT_DONE = 1 << 5;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 6;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 7;

//
// Interface: TLBindAccountMigrationExecutor ()
//

@interface TLBindAccountMigrationExecutor ()

@property (nonatomic, nullable) NSUUID *invocationId;
@property (nonatomic, readonly, nonnull) TLAccountMigration *accountMigration;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *twincodeInbound;
@property (nonatomic, readonly, nonnull) NSUUID *peerTwincodeOutboundId;
@property (nonatomic, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic) BOOL invokePeer;
@property (copy, nonatomic) void (^consumer) (TLBaseServiceErrorCode, TLAccountMigration * _Nullable);

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onGetTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)stop;

@end

//
// Implementation: TLBindContactExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLBindAccountMigrationExecutor"

@implementation TLBindAccountMigrationExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId invocationId:(nonnull NSUUID *)invocationId accountMigration:(nonnull TLAccountMigration *)accountMigration peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld invocationId: %@ accountMigration: %@ peerTwincodeOutboundId: %@", LOG_TAG, twinmeContext, requestId, invocationId, accountMigration, peerTwincodeOutboundId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId];
    
    if (self) {
        _invocationId = invocationId;
        _accountMigration = accountMigration;
        _peerTwincodeOutboundId = peerTwincodeOutboundId;
        _twincodeInbound = accountMigration.twincodeInbound;
        _invokePeer = !accountMigration.isBound;
        
        if (!_twincodeInbound) {
            [NSString stringWithFormat:@"twincodeInboundId == nil in deviceMigration %@", accountMigration];
            
            self.stopped = YES;
        }
        _consumer = nil;
    }
    return self;
}

/*- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairInviteInvocation *)invocation accountMigration:(nonnull TLAccountMigration *)accountMigration {
    self = [super initWithTwinmeContext:twinmeContext requestId:TLBaseService.DEFAULT_REQUEST_ID];

    if (self) {
        _invocationId = invocation.uuid;
        _accountMigration = accountMigration;
        _peerTwincodeOutboundId = invocation.twincodeOutboundId;
        _twincodeInbound = invocation.twin
    }
    
    return self;
}*/

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext accountMigration:(nonnull TLAccountMigration *)accountMigration peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound consumer:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))consumer {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ accountMigration: %@ peerTwincodeOutbound: %@", LOG_TAG, twinmeContext, accountMigration, peerTwincodeOutbound);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:TLBaseService.DEFAULT_REQUEST_ID];
    
    if (self) {
        _invocationId = nil;
        _accountMigration = accountMigration;
        _peerTwincodeOutbound = peerTwincodeOutbound;
        _peerTwincodeOutboundId = peerTwincodeOutbound.uuid;
        _twincodeInbound = accountMigration.twincodeInbound;
        _invokePeer = YES;
        _consumer = consumer;

        TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutboundId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _twincodeInbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);
    }
    return self;
}

#pragma mark - Private methods

- (void) start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    if (!self.stopped) {
        [super start];
    } else {
        [self stop];
        
        [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & GET_PEER_TWINCODE_OUTBOUND) != 0 && (self.state & GET_PEER_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~GET_PEER_TWINCODE_OUTBOUND;
        }
        if ((self.state & UPDATE_TWINCODE_INBOUND) != 0 && (self.state & UPDATE_TWINCODE_INBOUND_DONE) == 0) {
            self.state &= ~UPDATE_TWINCODE_INBOUND;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) != 0 && (self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~INVOKE_TWINCODE_OUTBOUND;
        }
    }
    [super onTwinlifeOnline];
}


- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: get the peer twincode.
    //
    
    if ((self.state & GET_PEER_TWINCODE_OUTBOUND) == 0) {
        self.state |= GET_PEER_TWINCODE_OUTBOUND;

        DDLogVerbose(@"%@ getTwincodeWithTwincodeId: %@", LOG_TAG, self.peerTwincodeOutboundId);
        [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.peerTwincodeOutboundId refreshPeriod:TL_LONG_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
            [self onGetTwincodeOutbound:twincodeOutbound errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_PEER_TWINCODE_OUTBOUND_DONE) == 0) {
        return;
    }
    
    //
    // Step 2
    //
    
    if ((self.state & UPDATE_TWINCODE_INBOUND) == 0) {
        self.state |= UPDATE_TWINCODE_INBOUND;
                
        NSMutableArray *twincodeInboundAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributePairTwincodeId:twincodeInboundAttributes twincodeId:self.peerTwincodeOutboundId];
        DDLogVerbose(@"%@ updateTwincodeWithRequestTwincode: %@ attributes: %@ deleteAttributeNames: %@", LOG_TAG, self.twincodeInbound, twincodeInboundAttributes, nil);
        [[self.twinmeContext getTwincodeInboundService] updateTwincodeWithTwincode:self.twincodeInbound attributes:twincodeInboundAttributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *twincodeInbound) {
            [self onUpdateTwincodeInbound:twincodeInbound errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & UPDATE_TWINCODE_INBOUND_DONE) == 0) {
        return;
    }
    
    //
    // Step 3
    //
    if ((self.state & UPDATE_OBJECT) == 0) {
        self.state |= UPDATE_OBJECT;
        
        if (self.invocationId) {
            self.accountMigration.isBound = YES;
        }
        
        self.accountMigration.peerTwincodeOutbound = self.peerTwincodeOutbound;
        
        DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.accountMigration);
        [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.accountMigration localOnly:YES withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onUpdateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & UPDATE_OBJECT_DONE) == 0) {
        return;
    }
    
    //
    // Step 4: invoke the peer device migration twincode to bind with the device migration on the other side.
    //
    
    if (self.invokePeer) {
        if (self.peerTwincodeOutbound) {
            if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
                self.state |= INVOKE_TWINCODE_OUTBOUND;
                
                NSMutableArray *attributes = [NSMutableArray array];
                [TLPairProtocol setInvokeTwincodeActionPairBindAttributeTwincodeId:attributes twincodeId:self.accountMigration.twincodeOutbound.uuid];
                
                DDLogVerbose(@"%@ invokeTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.peerTwincodeOutbound, attributes);
                
                [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeUrgent action:[TLPairProtocol ACTION_PAIR_INVITE] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable invocationId) {
                    [self onInvokeTwincode:invocationId errorCode:errorCode];
                }];
                return;
            }
        }
        
        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    if (self.consumer) {
        self.consumer(TLBaseServiceErrorCodeSuccess, self.accountMigration);
    }
    [self.twinmeContext onUpdateAccountMigrationWithRequestId:self.requestId accountMigration:self.accountMigration];
    
    [self stop];
}

- (void)onGetTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        [self onErrorWithOperationId:GET_PEER_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:self.peerTwincodeOutboundId.UUIDString];
        return;
    }
    
    TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.peerTwincodeOutboundId, [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterTwincodeId, [TLAssertValue initWithNumber:3], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);

    self.state |= GET_PEER_TWINCODE_OUTBOUND_DONE;

    self.peerTwincodeOutbound = twincodeOutbound;
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateObject: %d object: %@", LOG_TAG, errorCode, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_OBJECT_DONE;
    [self onOperation];
}

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onInvokeTwincode: %d invocationId=%@", LOG_TAG, errorCode, invocationId.UUIDString);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !invocationId) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
    [self onOperation];
}

- (void)onUpdateTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeInbound: %d twincodeInbound=%@", LOG_TAG, errorCode, twincodeInbound);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeInbound) {
        [self onErrorWithOperationId:GET_PEER_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:self.peerTwincodeOutboundId.UUIDString];
        return;
    }
    
    self.state |= UPDATE_TWINCODE_INBOUND_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    if (operationId == INVOKE_TWINCODE_OUTBOUND) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
            return;
        }
    }
    
    if (operationId == GET_PEER_TWINCODE_OUTBOUND) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self stop];
            return;
        }
    }
    
    // Mark the executor as stopped before calling the result method either fireOnError() or onGet().
    [self stop];
    
    if (self.consumer) {
        self.consumer(errorCode, nil);
    } else {
        [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:errorCode errorParameter:errorParameter];
    }
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    if (self.invocationId) {
        [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
    }
    
    [super stop];
}

@end
