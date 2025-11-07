/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLNotificationService.h>

#import "TLDeleteContactExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLPairProtocol.h"
#import "TLContact.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.17
//

static const int INVOKE_TWINCODE_OUTBOUND = 1 << (TL_DELETE_OBJECT_LAST_STATE_BIT + 1);
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << (TL_DELETE_OBJECT_LAST_STATE_BIT + 2);

//
// Interface(): TLDeleteContactExecutor
//

@interface TLDeleteContactExecutor()

@property (nonatomic, readonly, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, readonly, nullable) NSUUID *publicPeerTwincodeOutboundId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLDeleteContactExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteContactExecutor"

@implementation TLDeleteContactExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact invocationId:(nullable NSUUID *)invocationId timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld contact: %@ invocationId: %@", LOG_TAG, twinmeContext, requestId, contact, invocationId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId object:contact invocationId:invocationId timeout:timeout];
    
    if (self) {
        _peerTwincodeOutbound = contact.hasPrivatePeer ? contact.peerTwincodeOutbound : nil;
        _publicPeerTwincodeOutboundId = contact.publicPeerTwincodeOutboundId;
    }
    return self;
}

#pragma mark - Private methods
- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
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
    // Step 1: invoke peer to unbind the contact on its side.
    //
    if (self.peerTwincodeOutbound) {
        
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
            self.state |= INVOKE_TWINCODE_OUTBOUND;
            
            DDLogVerbose(@"%@ invokeTwincodeWithTwincodeId: %@", LOG_TAG, self.peerTwincodeOutbound);
            [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeWakeup action:[TLPairProtocol ACTION_PAIR_UNBIND] attributes:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }

    [super onOperation];
}

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onInvokeTwincode: %@", LOG_TAG, invocationId);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || invocationId == nil) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
    [self onOperation];
}

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object {

    //
    // Step 4: remove the public peer twincode with its avatar from the cache.
    //
    if (self.publicPeerTwincodeOutboundId) {
        [[self.twinmeContext getTwincodeOutboundService] evictTwincode:self.publicPeerTwincodeOutboundId];
    }

    [self.twinmeContext onDeleteContactWithRequestId:self.requestId contactId:object.uuid];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {

            case INVOKE_TWINCODE_OUTBOUND:
                self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
                [self onOperation];
                return;

            default:
                break;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end

