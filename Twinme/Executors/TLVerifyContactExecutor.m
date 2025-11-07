/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeURI.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLVerifyContactExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLContact.h"
#import "TLCapabilities.h"
#import "TLPairProtocol.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.1
//

static const int FIND_CONTACT = 1 << 0;
static const int UPDATE_TWINCODE_OUTBOUND = 1 << 1;
static const int UPDATE_TWINCODE_OUTBOUND_DONE = 1 << 2;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 3;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 4;

//
// Interface: TLVerifyContactExecutor ()
//

@interface TLVerifyContactExecutor ()

@property (nonatomic, readonly, nonnull) TLTwincodeURI *twincodeURI;
@property (nonatomic, readonly) TLTrustMethod trustMethod;
@property (nonatomic, readonly, nonnull) void (^onVerifyContact) (TLBaseServiceErrorCode errorCode, TLContact *contact);

@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, nullable) TLContact *contact;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLVerifyContactExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLVerifyContactExecutor"

@implementation TLVerifyContactExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twincodeURI:(nonnull TLTwincodeURI *)twincodeURI trustMethod:(TLTrustMethod)trustMethod  withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block {
    
    self = [super initWithTwinmeContext:twinmeContext requestId:0 timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _twincodeURI = twincodeURI;
        _trustMethod = trustMethod;
        _onVerifyContact = block;

        TL_ASSERT_NOT_NULL(twinmeContext, _twincodeURI, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) != 0 && (self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~UPDATE_TWINCODE_OUTBOUND;
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
    // Step 1: find the contact knowing the authenticate signature.
    //
    if ((self.state & FIND_CONTACT) == 0) {
        self.state |= FIND_CONTACT;

        NSArray *factories = [NSArray arrayWithObjects: [TLContact FACTORY], nil];

        TLFindResult * result;
        if (self.twincodeURI.kind == TLTwincodeURIKindAuthenticate && self.twincodeURI.publicKey) {
            result = [[self.twinmeContext getRepositoryService] findObjectWithSignature:self.twincodeURI.publicKey factories:factories];
        } else {
            result = [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeBadRequest];
        }

        if (result.errorCode != TLBaseServiceErrorCodeSuccess) {
            self.onVerifyContact(result.errorCode, nil);
            [self stop];
            return;
        }
        if (![result.object isKindOfClass:[TLContact class]]) {
            self.onVerifyContact(TLBaseServiceErrorCodeLibraryError, nil);
            [self stop];
            return;
        }

        // This is verified and the contact was found.
        self.contact = (TLContact *)result.object;
        self.twincodeOutbound = self.contact.twincodeOutbound;
        self.peerTwincodeOutbound = self.contact.peerTwincodeOutbound;

        // Check if the authenticate URL was created by us or by the peer.
        [[self.twinmeContext getTwincodeOutboundService] createURIWithTwincodeKind:TLTwincodeURIKindAuthenticate twincodeOutbound:self.twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *twincodeURI) {
            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                self.onVerifyContact(errorCode, nil);
                [self stop];
                return;
            }

            // Authenticate URL was signed by us: it does not prove we trust the peer.
            if ([self.twincodeURI.uri isEqual:twincodeURI.uri]) {
                self.onVerifyContact(TLBaseServiceErrorCodeSuccess, self.contact);
                [self stop];
                return;
            }

            // Authenticate URL was signed by the peer: we can trust it now.
            [self onOperation];
        }];
        return;
    }
    
    //
    // Step 2: update identity twincode to indicate to the peer that we trust its twincode.
    //
    if (self.twincodeOutbound) {
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_TWINCODE_OUTBOUND;
            
            // Mark the relation as certified now with the given trust method.
            [[self.twinmeContext getTwincodeOutboundService] setCertifiedWithTwincode:self.twincodeOutbound peerTwincode:self.peerTwincodeOutbound trustMethod:self.trustMethod];

            if ([self.twincodeOutbound isSigned] && [self.peerTwincodeOutbound isTrusted]) {
                TLCapabilities *identityCapabilities = [self.contact identityCapabilities];
                [identityCapabilities setTrustedWithValue:self.peerTwincodeOutbound.uuid];
                
                NSMutableArray *attributes = [NSMutableArray array];
                [TLTwinmeAttributes setTwincodeAttributeCapabilities:attributes capabilities:[identityCapabilities attributeValue]];

                DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.twincodeOutbound, attributes);
                [[self.twinmeContext getTwincodeOutboundService] updateTwincodeWithTwincode:self.twincodeOutbound attributes:attributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                    [self onUpdateTwincodeOutbound:twincodeOutbound errorCode:errorCode];
                }];
                return;
            }

            // Identity twincode is not modified, no need to inform the peer.
            self.state |= UPDATE_TWINCODE_OUTBOUND_DONE;
            self.state |= INVOKE_TWINCODE_OUTBOUND | INVOKE_TWINCODE_OUTBOUND_DONE;
        }
        if ((self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }

    }

    //
    // Step 3: invoke a refresh on the peer twincode if we have updated our identity.
    //
    if (self.peerTwincodeOutbound) {
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
            self.state |= INVOKE_TWINCODE_OUTBOUND;
            
            DDLogVerbose(@"%@ invokeTwincodeWithTwincodeId: %@", LOG_TAG, self.peerTwincodeOutbound);
            [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeWakeup action:[TLPairProtocol ACTION_PAIR_REFRESH] attributes:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //

    self.onVerifyContact(TLBaseServiceErrorCodeSuccess, self.contact);
    [self stop];
}

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= UPDATE_TWINCODE_OUTBOUND_DONE;
    self.contact.twincodeOutbound = twincodeOutbound;
    [self onOperation];
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

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d", LOG_TAG, operationId, errorCode);

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    self.onVerifyContact(errorCode, nil);
    [self stop];
}

@end
