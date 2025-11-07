/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLFilter.h>

#import "TLRebindContactExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLContact.h"
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

static const int FIND_CONTACT = 1;
static const int FIND_CONTACT_DONE = 1 << 1;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 2;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 3;

//
// Interface: TLRebindContactExecutor ()
//

@interface TLRebindContactExecutor ()

@property (nonatomic, readonly, nonnull) NSUUID *peerTwincodeOutboundId;

@property (nonatomic, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *identityTwincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *contactTwincodeOutbound;
@property (nonatomic, nullable) TLContact *contact;
@property (nonatomic) BOOL unbindContact;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLRebindContactExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLRebindContactExecutor"

@implementation TLRebindContactExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext peerTwincodeId:(nonnull NSUUID *)peerTwincodeId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ peerTwincodeId:%@", LOG_TAG, twinmeContext, peerTwincodeId);

    self = [super initWithTwinmeContext:twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID]];
    
    if (self) {
        _peerTwincodeOutboundId = peerTwincodeId;
        _unbindContact = NO;
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
    // Step 1: find the contact with the given peer twincode id (we must also consider this is the private peer twincode id).
    //
    if ((self.state & FIND_CONTACT) == 0) {
        self.state |= FIND_CONTACT;
        
        TLFilter *filter = [TLFilter alloc];
        filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
            if (![object isKindOfClass:[TLContact class]]) {
                return NO;
            }

            TLContact *contact = (TLContact *)object;
            return [contact hasPrivatePeer] && [self.peerTwincodeOutboundId isEqual:contact.peerTwincodeOutboundId];
        };

        DDLogVerbose(@"%@ findContactsWithFilter: %@ peerTwincodeOutbound: %@", LOG_TAG, filter, self.peerTwincodeOutboundId);
        [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
            if (contacts && contacts.count > 0) {
                // The contact was found, get the information to make a `pair::bind` as we do
                // in the createContactPhase2Executor(): this should recover the contact setup on its side
                // for the private peer twincode.
                self.contact = contacts[0];
                self.identityTwincodeOutbound = self.contact.twincodeOutbound;
                self.contactTwincodeOutbound = self.identityTwincodeOutbound;
                self.peerTwincodeOutbound = self.contact.peerTwincodeOutbound;
            }
            
            self.state |= FIND_CONTACT_DONE;
            [self onOperation];
        }];
        return;
    }
    
    if ((self.state & FIND_CONTACT_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: invoke the peer twincode to send our private identity twincode again (a first `pair::bind`
    // was made by `createContactPhase2` but it was not saved correctly on the peer's side.
    //
    if (self.identityTwincodeOutbound && self.contactTwincodeOutbound && self.peerTwincodeOutbound) {
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
            self.state |= INVOKE_TWINCODE_OUTBOUND;

            NSMutableArray *attributes = [NSMutableArray array];
            [TLPairProtocol setInvokeTwincodeActionPairInviteAttributeTwincodeId:attributes twincodeId:self.contactTwincodeOutbound.uuid];
            DDLogVerbose(@"%@ invokeTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.peerTwincodeOutbound, attributes);
            
            if ([self.peerTwincodeOutbound isSigned]) {
                // Unlike the `pair:bind` made in the CreateContactPhase2, we can use the identity twincode
                // for the encryption because the peer trust it.
                // We still send information about our contact twincode to give our public key.
                [[self.twinmeContext getTwincodeOutboundService] secureInvokeTwincodeWithTwincode:self.identityTwincodeOutbound senderTwincode:self.contactTwincodeOutbound receiverTwincode:self.peerTwincodeOutbound options:(TLInvokeTwincodeUrgent | TLInvokeTwincodeCreateSecret) action:[TLPairProtocol ACTION_PAIR_BIND] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                    [self onInvokeTwincode:invocationId errorCode:errorCode];
                }];
            } else {
                [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeUrgent action:[TLPairProtocol ACTION_PAIR_BIND] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                    [self onInvokeTwincode:invocationId errorCode:errorCode];
                }];
            }
            return;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    if (self.unbindContact) {
        [self.twinmeContext unbindContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] invocationId:nil contact:self.contact];
    }
    
    [self stop];
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
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (operationId == INVOKE_TWINCODE_OUTBOUND) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound || errorCode == TLBaseServiceErrorCodeNoPrivateKey || errorCode == TLBaseServiceErrorCodeInvalidPublicKey || errorCode == TLBaseServiceErrorCodeInvalidPrivateKey) {
            self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
            self.unbindContact = YES;
            [self onOperation];
            return;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
