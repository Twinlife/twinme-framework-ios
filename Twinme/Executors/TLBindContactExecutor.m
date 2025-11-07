/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>

#import "TLBindContactExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLPairProtocol.h"
#import "TLPairBindInvocation.h"
#import "TLContact.h"
#import "TLNotificationCenter.h"
#import "TLTwinmeAttributes.h"

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

static const int UPDATE_TWINCODE_OUTBOUND = 1 << 0;
static const int UPDATE_TWINCODE_OUTBOUND_DONE = 1 << 1;
static const int UPDATE_TWINCODE_INBOUND = 1 << 2;
static const int UPDATE_TWINCODE_INBOUND_DONE = 1 << 3;
static const int UPDATE_OBJECT = 1 << 4;
static const int UPDATE_OBJECT_DONE = 1 << 5;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 6;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 7;
static const int GET_PEER_TWINCODE_IMAGE = 1 << 8;
static const int GET_PEER_TWINCODE_IMAGE_DONE = 1 << 9;

//
// Interface: TLBindContactExecutor ()
//

@interface TLBindContactExecutor ()

@property (nonatomic, nullable) NSUUID *invocationId;
@property (nonatomic, readonly, nonnull) TLContact *contact;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *twincodeInbound;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *previousPeerTwincodeOutbound;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, readonly, nullable) TLImageId *avatarId;
@property (nonatomic) BOOL modified;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)stop;

@end

//
// Implementation: TLBindContactExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLBindContactExecutor"

@implementation TLBindContactExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairBindInvocation *)invocation contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ invocation: %@ contact: %@ ", LOG_TAG, twinmeContext, invocation, contact);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID]];
    
    if (self) {
        _invocationId = invocation.uuid;
        _contact = contact;
        _peerTwincodeOutbound = invocation.twincodeOutbound;
        _twincodeInbound = contact.twincodeInbound;
        _twincodeOutbound = contact.twincodeOutbound;
        _previousPeerTwincodeOutbound = contact.peerTwincodeOutbound;
        _avatarId = invocation.twincodeOutbound.avatarId;
        _modified = NO;

        TL_ASSERT_NOT_NULL(twinmeContext, _invocationId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);
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
        if ((self.state & UPDATE_TWINCODE_INBOUND) != 0 && (self.state & UPDATE_TWINCODE_INBOUND_DONE) == 0) {
            self.state &= ~UPDATE_TWINCODE_INBOUND;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) != 0 && (self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~INVOKE_TWINCODE_OUTBOUND;
        }
        if ((self.state & GET_PEER_TWINCODE_IMAGE) != 0 && (self.state & GET_PEER_TWINCODE_IMAGE_DONE) == 0) {
            self.state &= ~GET_PEER_TWINCODE_IMAGE;
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
    // Step 1: update identity twincode to indicate to the peer that we trust its twincode.
    //
    if (self.twincodeOutbound) {
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_TWINCODE_OUTBOUND;
            
            if (self.previousPeerTwincodeOutbound && [self.previousPeerTwincodeOutbound isSigned]) {
                [[self.twinmeContext getTwincodeOutboundService] associateTwincodes:self.twincodeOutbound previousPeerTwincode:self.previousPeerTwincodeOutbound peerTwincode:self.peerTwincodeOutbound];
            }
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

    if (self.twincodeInbound && self.peerTwincodeOutbound) {
        
        //
        // Step 2: update the inbound twincode unless the contact was invalidated.
        //
        if ((self.state & UPDATE_TWINCODE_INBOUND) == 0) {
            self.state |= UPDATE_TWINCODE_INBOUND;

            NSMutableArray *twincodeInboundAttributes = [NSMutableArray array];
            [TLPairProtocol setTwincodeAttributePairTwincodeId:twincodeInboundAttributes twincodeId:self.peerTwincodeOutbound.uuid];
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
        // Step 3: save the object with the private peer twincode.
        //
        if ((self.state & UPDATE_OBJECT) == 0) {
            self.state |= UPDATE_OBJECT;

            // Update the contact's peer twincode.
            self.modified = [self.contact updatePeerTwincodeOutbound:self.peerTwincodeOutbound];
            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.contact localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onUpdateObject:object errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_OBJECT_DONE) == 0) {
            return;
        }

        //
        // Step 4: invoke a refresh on the peer twincode if we have updated our identity.
        //
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

        //
        // Step 5: force a synchronize conversation in case we have some pending messages
        // but we don't want to create the conversation instance if it does not exist.
        //
        [[self.twinmeContext getConversationService] updateConversationWithSubject:self.contact peerTwincodeOutbound:self.peerTwincodeOutbound];
    }

    // Acknowledge the invocation as soon as we have finished to setup the contact and
    // before releasing the previous peer and get the image.  As soon as we drop the previous
    // peer twincode, the same `pair::bind` will not be handled because we don't know the public key.
    // (it is fine because the contact is now finalized).  If we are interrupted immediately after
    // the acknowledge, we won't cleanup the peer (it's ok) or we won't pre-fetch the avatar (it's ok too).
    if (self.invocationId) {
        [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
        self.invocationId = nil;
    }

    // Drop the previous peer twincode which comes from the profile that was scanned.
    if (self.previousPeerTwincodeOutbound && self.previousPeerTwincodeOutbound != self.peerTwincodeOutbound) {
        [[self.twinmeContext getTwincodeOutboundService] evictWithTwincode:self.previousPeerTwincodeOutbound];
    }

    //
    // Step 6: get the contact image so that we have it in the cache when we are done.
    //
    if (self.twincodeInbound && self.avatarId) {
        
        if ((self.state & GET_PEER_TWINCODE_IMAGE) == 0) {
            self.state |= GET_PEER_TWINCODE_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_PEER_TWINCODE_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_PEER_TWINCODE_IMAGE_DONE) == 0) {
            return;;
        }
    }

    //
    // Last Step
    //
    if (self.modified) {
        // Report the update only when the contact is still valid.
        if (!self.contact.checkInvariants) {
            [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint CONTACT_INVARIANT], [TLAssertValue initWithSubject:self.contact], [TLAssertValue initWithInvocationId:self.invocationId], nil];
        }

        // Post a notification for the new contact (contactPhase2 received asynchronously).
        if ([self.twinmeContext isVisible:self.contact]) {
            [self.twinmeContext.notificationCenter onNewContactWithContact:self.contact];
        }

        [self.twinmeContext onUpdateContactWithRequestId:self.requestId contact:self.contact];
    }
    [self stop];
}

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_TWINCODE_OUTBOUND_DONE;
    
    self.contact.twincodeOutbound = twincodeOutbound;
    [self onOperation];
}

- (void)onUpdateTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeInbound: %@", LOG_TAG, twincodeInbound);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeInbound == nil) {
        [self onErrorWithOperationId:UPDATE_TWINCODE_INBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_TWINCODE_INBOUND_DONE;
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
    DDLogVerbose(@"%@ onInvokeTwincode: %@", LOG_TAG, invocationId);

    if (errorCode != TLBaseServiceErrorCodeSuccess || invocationId == nil) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (operationId == INVOKE_TWINCODE_OUTBOUND) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            // The peer twincode is invalid, unbind/delete the contact.
            [self.twinmeContext unbindContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] invocationId:self.invocationId contact:self.contact];
            self.invocationId = nil;
        }
    }
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    if (self.invocationId) {
        [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
    }
    [super stop];
}

@end
