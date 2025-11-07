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
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLConversationService.h>

#import "TLUnbindContactExecutor.h"
#import "TLNotificationCenter.h"
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
// version: 1.9
//

static const int DELETE_PEER_IMAGE = 1 << 0;
static const int DELETE_PEER_IMAGE_DONE = 1 << 1;
static const int UPDATE_OBJECT = 1 << 2;
static const int UPDATE_OBJECT_DONE = 1 << 3;
static const int DELETE_CONVERSATION = 1 << 4;

//
// Interface: TLUnbindContactExecutor ()
//

@interface TLUnbindContactExecutor ()

@property (nonatomic, readonly) NSUUID *invocationId;
@property (nonatomic, readonly) TLContact *contact;
@property (nonatomic, readonly) NSUUID *twincodeOutboundId;

- (void)onOperation;

- (void)onUpdateObject:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object;

@end

//
// Implementation: TLUnbindContactExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUnbindContactExecutor"

@implementation TLUnbindContactExecutor

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId invocationId:(NSUUID *)invocationId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld invocationId: %@ contact: %@", LOG_TAG, twinmeContext, requestId, invocationId, contact);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId];
    if (self) {
        _invocationId = invocationId;
        _contact = contact;
        
        // invocationId == null - unbindContact calls on error
        TL_ASSERT_NOT_NULL(twinmeContext, _contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

        _twincodeOutboundId = contact.twincodeOutboundId;
    }
    return self;
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: before dropping the peer twincode, remove the image from the local cache.
    //
    if (self.contact.avatarId) {
        
        if ((self.state & DELETE_PEER_IMAGE) == 0) {
            self.state |= DELETE_PEER_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.contact.avatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                self.state |= DELETE_PEER_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & DELETE_PEER_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: drop the peer twincode and update the object.
    //
    
    if ((self.state & UPDATE_OBJECT) == 0) {
        self.state |= UPDATE_OBJECT;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        self.contact.peerTwincodeOutbound = nil;
        self.contact.publicPeerTwincodeOutbound = nil;
        
        DDLogVerbose(@"%@ udpateObjectWithObject: %@", LOG_TAG, self.contact);
        [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.contact localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onUpdateObject:errorCode object:object];
        }];
        return;
    }
    if ((self.state & UPDATE_OBJECT_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: delete the conversation.
    //
    
    if (self.twincodeOutboundId) {
        if ((self.state & DELETE_CONVERSATION) == 0) {
            self.state |= DELETE_CONVERSATION;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

            DDLogVerbose(@"%@ deleteConversationWithSubject: %@", LOG_TAG, self.contact);
            [[self.twinmeContext getConversationService] deleteConversationWithSubject:self.contact];
        }
    }
    
    // Post a notification when we unbind the contact.
    if ([self.twinmeContext isVisible:self.contact]) {
        [self.twinmeContext.notificationCenter onUnbindContactWithContact:self.contact];
    }
    
    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);
    if (!self.contact.checkInvariants) {
        [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint CONTACT_INVARIANT], [TLAssertValue initWithSubject:self.contact], [TLAssertValue initWithInvocationId:self.invocationId], nil];
    }
    
    [self.twinmeContext onUpdateContactWithRequestId:self.requestId contact:self.contact];
    [self stop];
}

- (void)onUpdateObject:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onUpdateObject: %@", LOG_TAG, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);

    self.state |= UPDATE_OBJECT_DONE;
    [self onOperation];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    if (self.invocationId) {
        [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
    }

    [super stop];
}

@end
