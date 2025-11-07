/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLGroupProtocol.h>
#import <Twinlife/TLCryptoService.h>

#import "TLProcessInvocationExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLContact.h"
#import "TLProfile.h"
#import "TLGroup.h"
#import "TLInvitation.h"
#import "TLAccountMigration.h"
#import "TLPairInviteInvocation.h"
#import "TLPairBindInvocation.h"
#import "TLPairUnbindInvocation.h"
#import "TLPairRefreshInvocation.h"
#import "TLPairProtocol.h"
#import "TLGroupRegisteredInvocation.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.15
//

static const int GET_TWINCODE_OUTBOUND = 1 << 2;
static const int GET_TWINCODE_OUTBOUND_DONE = 1 << 3;

//
// Interface: TLProcessInvocationExecutor ()
//

@interface TLProcessInvocationExecutor ()

@property (nonatomic, readonly, nonnull) NSUUID *invocationId;
@property (nonatomic, readonly, nonnull) void (^consumer) (TLBaseServiceErrorCode status, TLInvocation *invocation);

@property (nonatomic, readonly, nonnull) id<TLRepositoryObject> receiver;
@property (nonatomic, readonly, nonnull) TLTwincodeInvocation *invocation;
@property (nonatomic) BOOL pairInviteAction;
@property (nonatomic) BOOL pairBindAction;
@property (nonatomic, nullable) NSUUID *peerTwincodeOutboundId;
@property (nonatomic, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic) BOOL pairUnbindAction;
@property (nonatomic) BOOL pairRefreshAction;
@property (nonatomic) BOOL groupRegisteredAction;
@property (nonatomic) long adminPermissions;
@property (nonatomic) long memberPermissions;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onGetTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLProcessInvocationExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLProcessInvocationExecutor"

@implementation TLProcessInvocationExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLTwincodeInvocation *)invocation withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvocation* _Nullable invocation))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ invocation: %@", LOG_TAG, twinmeContext, invocation);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID]];
    
    if (self) {
        _invocationId = invocation.invocationId;
        _receiver = invocation.subject;
        _consumer = block;
        _invocation = invocation;
        
        NSArray<TLAttributeNameValue *> *attributes = invocation.attributes;
        NSString *action = invocation.action;

        TL_ASSERT_NOT_NULL(twinmeContext, _invocationId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, action, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        _pairInviteAction = NO;
        _pairBindAction = NO;
        _pairUnbindAction = NO;
        _pairRefreshAction = NO;
        
        if ([[TLPairProtocol ACTION_PAIR_INVITE] isEqualToString:action]) {
            _pairInviteAction = YES;
            for (TLAttributeNameValue *attribute in attributes) {
                if ([[TLPairProtocol invokeTwincodeActionPairBindAttributeTwincodeId] isEqualToString:attribute.name]) {
                    _peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:(NSString *)attribute.value];
                }
            }
        } else if ([[TLPairProtocol ACTION_PAIR_BIND] isEqualToString:action]) {
            _pairBindAction = YES;
            for (TLAttributeNameValue *attribute in attributes) {
                if ([[TLPairProtocol invokeTwincodeActionPairBindAttributeTwincodeId] isEqualToString:attribute.name]) {
                    _peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:(NSString *)attribute.value];
                }
            }
        } else if ([[TLPairProtocol ACTION_PAIR_UNBIND] isEqualToString:action]) {
            _pairUnbindAction = YES;
        } else if ([[TLPairProtocol ACTION_PAIR_REFRESH] isEqualToString:action]) {
            _pairRefreshAction = YES;
        } else if ([[TLGroupProtocol invokeTwincodeActionGroupRegistered] isEqualToString:action]) {
            _groupRegisteredAction = YES;
            for (TLAttributeNameValue *attribute in attributes) {
                if ([[TLGroupProtocol invokeTwincodeActionAdminTwincodeId] isEqualToString:attribute.name]) {
                    _peerTwincodeOutboundId = [[NSUUID alloc] initWithUUIDString:(NSString *)attribute.value];
                } else if ([[TLGroupProtocol invokeTwincodeActionAdminPermissions] isEqualToString:attribute.name]) {
                    _adminPermissions = [(NSString *)attribute.value intValue];
                } else if ([[TLGroupProtocol invokeTwincodeActionMemberPermissions] isEqualToString:attribute.name]) {
                    _memberPermissions = [(NSString *)attribute.value intValue];
                }
            }
        }
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & GET_TWINCODE_OUTBOUND) != 0 && (self.state & GET_TWINCODE_OUTBOUND_DONE) == 0)  {
            self.state &= ~GET_TWINCODE_OUTBOUND;
        }
    }
    [super onTwinlifeOnline];
}

- (BOOL)acceptInvite {
    DDLogVerbose(@"%@ acceptInvite", LOG_TAG);

    Class clazz = [self.receiver class];
    return clazz == [TLProfile class] || clazz == [TLInvitation class] || clazz == [TLAccountMigration class];
}

- (BOOL)acceptBind {
    DDLogVerbose(@"%@ acceptBind", LOG_TAG);

    Class clazz = [self.receiver class];
    return clazz == [TLContact class] || clazz == [TLGroup class] || clazz == [TLAccountMigration class];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 2
    //
    if (self.peerTwincodeOutboundId) {
        if ((self.state & GET_TWINCODE_OUTBOUND) == 0) {
            self.state |= GET_TWINCODE_OUTBOUND;
            
            DDLogVerbose(@"%@ getTwincodeWithTwincodeId: %@", LOG_TAG, self.peerTwincodeOutboundId);
            if (self.invocation.publicKey) {
                [[self.twinmeContext getTwincodeOutboundService] getSignedTwincodeWithTwincodeId:self.peerTwincodeOutboundId publicKey:self.invocation.publicKey keyIndex:self.invocation.keyIndex secretKey:self.invocation.secretKey trustMethod:self.invocation.trustMethod withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                    [self onGetTwincodeOutbound:twincodeOutbound errorCode:errorCode];
                }];
            } else {
                [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.peerTwincodeOutboundId refreshPeriod:TL_LONG_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                    [self onGetTwincodeOutbound:twincodeOutbound errorCode:errorCode];
                }];
            }
            return;
        }
        if ((self.state & GET_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //
    TLInvocation *invocation = nil;
    TLBaseServiceErrorCode errorCode;
    if (self.pairInviteAction) {
        if (!self.peerTwincodeOutboundId || !self.peerTwincodeOutbound) {
            errorCode = TLBaseServiceErrorCodeExpired;
        } else if ([self acceptInvite]) {
            errorCode = TLBaseServiceErrorCodeSuccess;
            invocation = [[TLPairInviteInvocation alloc] initWithId:self.invocationId receiver:self.receiver twincodeOutbound:self.peerTwincodeOutbound];
        } else {
            errorCode = TLBaseServiceErrorCodeBadRequest;
        }
    } else if (self.pairBindAction) {
        if (!self.peerTwincodeOutboundId || !self.peerTwincodeOutbound) {
            errorCode = TLBaseServiceErrorCodeExpired;
        } else if ([self acceptBind]) {
            errorCode = TLBaseServiceErrorCodeSuccess;
            invocation = [[TLPairBindInvocation alloc] initWithId:self.invocationId receiver:self.receiver twincodeOutbound:self.peerTwincodeOutbound];
        } else {
            errorCode = TLBaseServiceErrorCodeBadRequest;
        }
    } else if (self.pairUnbindAction) {
        if ([self acceptBind]) {
            errorCode = TLBaseServiceErrorCodeSuccess;
            invocation = [[TLPairUnbindInvocation alloc] initWithId:self.invocationId receiver:self.receiver];
        } else {
            errorCode = TLBaseServiceErrorCodeBadRequest;
        }
    } else if (self.pairRefreshAction) {
        if ([self acceptBind]) {
            errorCode = TLBaseServiceErrorCodeSuccess;
            invocation = [[TLPairRefreshInvocation alloc] initWithId:self.invocationId receiver:self.receiver invocationAttributes:self.invocation.attributes];
        } else {
            errorCode = TLBaseServiceErrorCodeBadRequest;
        }
    } else if (self.groupRegisteredAction) {
        if ([self.receiver class] == [TLGroup class]) {
            errorCode = TLBaseServiceErrorCodeSuccess;
            invocation = [[TLGroupRegisteredInvocation alloc] initWithId:self.invocationId receiver:self.receiver adminMemberTwincode:self.peerTwincodeOutbound adminPermissions:self.adminPermissions memberPermissions:self.memberPermissions];
        } else {
            errorCode = TLBaseServiceErrorCodeBadRequest;
        }
    } else {
        errorCode = TLBaseServiceErrorCodeBadRequest;
    }
    self.consumer(errorCode, invocation);
    [self stop];
}

- (void)onGetTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;

    } else if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        // The receiver was found for this invocation but the twincode associated with the invocation
        // is now obsolete: this invocation has expired.
        self.consumer(TLBaseServiceErrorCodeExpired, nil);
        [self stop];
        return;
    } else if (!twincodeOutbound) {
        self.consumer(TLBaseServiceErrorCodeBadRequest, nil);
        [self stop];
        return;
    }

    self.state |= GET_TWINCODE_OUTBOUND_DONE;
    self.peerTwincodeOutbound = twincodeOutbound;
    [self onOperation];
}

@end
