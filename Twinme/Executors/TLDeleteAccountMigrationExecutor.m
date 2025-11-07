/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import <CocoaLumberjack.h>

#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import "TLDeleteAccountMigrationExecutor.h"
#import "TLAccountMigration.h"
#import "TLPairProtocol.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int UNBIND_TWINCODE_INBOUND = 1;
static const int UNBIND_TWINCODE_INBOUND_DONE = 1 << 1;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 2;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 3;
static const int DELETE_TWINCODE = 1 << 4;
static const int DELETE_TWINCODE_DONE = 1 << 5;
static const int DELETE_OBJECT = 1 << 6;
static const int DELETE_OBJECT_DONE = 1 << 7;

@interface TLDeleteAccountMigrationExecutor ()

@property (nonatomic, readonly, nonnull) TLAccountMigration *accountMigration;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *twincodeInbound;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, readonly, nullable) NSUUID *twincodeFactoryId;
@property (nonatomic, readonly, nonnull) void (^onDeleteAccountMigration) (TLBaseServiceErrorCode errorCode, NSUUID *accountMigrationId);

@end

//
// Implementation: TLDeleteAccountMigrationExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteAccountMigrationExecutor"

@implementation TLDeleteAccountMigrationExecutor


- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext accountMigration:(nonnull TLAccountMigration *)accountMigration withBlock:(nonnull void (^)(TLBaseServiceErrorCode, NSUUID * _Nullable __strong))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ accountMigration: %@", LOG_TAG, twinmeContext, accountMigration);

    self = [super initWithTwinmeContext:twinmeContext requestId:0];

    if (self) {
        _accountMigration = accountMigration;
        _twincodeInbound = accountMigration.twincodeInbound;
        _peerTwincodeOutbound = accountMigration.peerTwincodeOutbound;
        _twincodeFactoryId = accountMigration.twincodeFactoryId;
        _onDeleteAccountMigration = block;
    }
    
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & UNBIND_TWINCODE_INBOUND) != 0 && (self.state & UNBIND_TWINCODE_INBOUND_DONE) == 0) {
            self.state &= ~UNBIND_TWINCODE_INBOUND;
        }
        if ((self.state & DELETE_TWINCODE) != 0 && (self.state & DELETE_TWINCODE_DONE) == 0) {
            self.state &= ~DELETE_TWINCODE;
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
    // Step 1: unbind the inbound twincode.
    //
    if (self.twincodeInbound) {
        if ((self.state & UNBIND_TWINCODE_INBOUND) == 0) {
            self.state |= UNBIND_TWINCODE_INBOUND;
            DDLogVerbose(@"%@ TwincodeInboundService.unbindTwincode: twincodeInbound %@", LOG_TAG, self.twincodeInbound);
            [self.twinmeContext.getTwincodeInboundService unbindTwincodeWithTwincode:self.twincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeInbound * _Nullable twincodeInbound) {
                [self onUnbindTwincodeInboundWithErrorCode:errorCode twincodeInbound:twincodeInbound];
            }];
            return;
        }
        
        if((self.state & UNBIND_TWINCODE_INBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: invoke peer to unbind the deviceMigration on its side.
    //

    if (self.peerTwincodeOutbound) {
        
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
            self.state |= INVOKE_TWINCODE_OUTBOUND;
            
            DDLogVerbose(@"%@ TwincodeInboundService.invokeTwincode: peerTwincodeOutbound %@", LOG_TAG, self.peerTwincodeOutbound);
            
            [self.twinmeContext.getTwincodeOutboundService invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeUrgent action:TLPairProtocol.ACTION_PAIR_UNBIND attributes:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable invocationId) {
                [self onInvokeTwincodeWithErrorCode:errorCode invocationId:invocationId];
            }];
            return;
        }
        
        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: delete the twincode.
    //
    if (self.twincodeFactoryId) {
        
        if ((self.state & DELETE_TWINCODE) == 0) {
            self.state |= DELETE_TWINCODE;
            
            DDLogVerbose(@"%@ TwincodeInboundService.deleteTwincode: twincodeFactoryId %@", LOG_TAG, self.twincodeFactoryId.UUIDString);

            [self.twinmeContext.getTwincodeFactoryService deleteTwincodeWithFactoryId:self.twincodeFactoryId withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable twincodeFactoryId) {
                [self onDeleteTwincodeWithErrorCode:errorCode twincodeFactoryId:twincodeFactoryId];
            }];
            return;
        }
        
        if ((self.state & DELETE_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: delete the contact object.
    //
    if ((self.state & DELETE_OBJECT) == 0) {
        self.state |= DELETE_OBJECT;
        
        DDLogVerbose(@"%@ RepositoryService.deleteObject: objectId %@", LOG_TAG, self.accountMigration.uuid);
        [self.twinmeContext.getRepositoryService deleteObjectWithObject:self.accountMigration withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable uuid) {
            [self onDeleteObjectWithErrorCode:errorCode objectId:uuid];
        }];
        
        //
        // Step 4e: remove the peer twincodes from the cache.
        //
        if (self.peerTwincodeOutbound) {
            [self.twinmeContext.getTwincodeOutboundService evictWithTwincode:self.peerTwincodeOutbound];
        }
        return;
    }
    
    if ((self.state & DELETE_OBJECT_DONE) == 0) {
        return;
    }
    
    //
    // Last Step
    //
    
    [self.twinmeContext onDeleteAccountMigrationWithRequestId:self.requestId accountMigrationId:self.accountMigration.uuid];
    self.onDeleteAccountMigration(TLBaseServiceErrorCodeSuccess, self.accountMigration.uuid);
    
    [self stop];
}

- (void)onUnbindTwincodeInboundWithErrorCode:(TLBaseServiceErrorCode)errorCode twincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound {
    DDLogVerbose(@"%@ onUnbindTwincodeInboundWithErrorCode:%d twincodeInboundId:%@", LOG_TAG, errorCode, twincodeInbound.uuid.UUIDString);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeInbound) {
        [self onErrorWithOperationId:UNBIND_TWINCODE_INBOUND errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= UNBIND_TWINCODE_INBOUND_DONE;
    [self onOperation];
}

- (void)onInvokeTwincodeWithErrorCode:(TLBaseServiceErrorCode)errorCode invocationId:(nullable NSUUID *)invocationId {
    DDLogVerbose(@"%@ onInvokeTwincodeWithErrorCode:%d invocationId:%@", LOG_TAG, errorCode, invocationId.UUIDString);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !invocationId) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
    [self onOperation];
}

- (void)onDeleteTwincodeWithErrorCode:(TLBaseServiceErrorCode)errorCode twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId {
    DDLogVerbose(@"%@ onDeleteTwincodeInboundWithErrorCode:%d twincodeFactoryId:%@", LOG_TAG, errorCode, twincodeFactoryId.UUIDString);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeFactoryId) {
        [self onErrorWithOperationId:DELETE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }
    
    TL_ASSERT_EQUAL(self.twinmeContext, twincodeFactoryId, self.twincodeFactoryId, [TLExecutorAssertPoint PARAMETER], TLAssertionParameterFactoryId, [TLAssertValue initWithNumber:3], nil);

    self.state |= DELETE_TWINCODE_DONE;
    [self onOperation];
}

- (void)onDeleteObjectWithErrorCode:(TLBaseServiceErrorCode)errorCode objectId:(nullable NSUUID *)objectId {
    DDLogVerbose(@"%@ onDeleteObjectWithErrorCode:%d objectId:%@", LOG_TAG, errorCode, objectId.UUIDString);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !objectId) {
        [self onErrorWithOperationId:DELETE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= DELETE_OBJECT_DONE;
    [self onOperation];
}

-(void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId:%d errorCode:%u errorParameter:%@", LOG_TAG, operationId, errorCode, errorParameter);

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    // The delete operation succeeds if we get an item not found error.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case UNBIND_TWINCODE_INBOUND:
                self.state |= UNBIND_TWINCODE_INBOUND_DONE;
                [self onOperation];
                return;
                
            case INVOKE_TWINCODE_OUTBOUND:
                self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
                [self onOperation];
                return;
                
            case DELETE_TWINCODE:
                self.state |= DELETE_TWINCODE_DONE;
                [self onOperation];
                return;
                
            case DELETE_OBJECT:
                self.state |= DELETE_OBJECT_DONE;
                [self onOperation];
                return;
                
            default:
                break;
        }
    }
    
    self.onDeleteAccountMigration(errorCode, nil);
    
    [self stop];
}
@end
