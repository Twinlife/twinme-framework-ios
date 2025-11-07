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
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLRefreshObjectExecutor.h"
#import "TLNotificationCenter.h"
#import "TLTwinmeContextImpl.h"
#import "TLPairProtocol.h"
#import "TLPairRefreshInvocation.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLOriginator.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.7
//

static const int REFRESH_PEER_TWINCODE_OUTBOUND = 1;
static const int REFRESH_PEER_TWINCODE_OUTBOUND_DONE = 1 << 1;
static const int GET_PEER_IMAGE = 1 << 2;
static const int GET_PEER_IMAGE_DONE = 1 << 3;
static const int UPDATE_OBJECT = 1 << 4;
static const int UPDATE_OBJECT_DONE = 1 << 5;

//
// Interface: TLRefreshObjectExecutor ()
//

@interface TLRefreshObjectExecutor ()

@property (nonatomic, nonnull, readonly) id<TLOriginator> subject;
@property (nonatomic, nullable) NSUUID *invocationId;
@property (nonatomic, nullable, readonly) TLContact *contact;
@property (nonatomic, nullable, readonly) TLGroup *group;
@property (nonatomic, nullable, readonly) id<TLGroupMemberConversation> groupMember;
@property (nonatomic, nullable, readonly) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, nonnull, readonly) NSString *oldName;
@property (nonatomic, nullable) TLImageId *oldAvatarId;
@property (nonatomic, nullable) TLImageId *avatarId;
@property (nonatomic, nullable) NSMutableArray<TLAttributeNameValue *> *previousAttributes;

- (void)onTwinlifeOnline;

- (void)onRefreshTwincodeOutbound:(nullable NSMutableArray<TLAttributeNameValue *> *)updatedAttributes errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLRefreshObjectExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLRefreshObjectExecutor"

@implementation TLRefreshObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairRefreshInvocation *)invocation subject:(nonnull id<TLOriginator>)subject {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ invocation: %@ subject: %@", LOG_TAG, twinmeContext, invocation, subject);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID]];
    if (self) {
        _invocationId = invocation.uuid;
        _subject = subject;

        TLTwincodeOutbound *peerTwincodeOutbound = subject.peerTwincodeOutbound;
        id<TLGroupMemberConversation> groupMember = nil;
        if ([subject isKindOfClass:[TLContact class]]) {
            _contact = (TLContact *)subject;

        } else if ([subject isKindOfClass:[TLGroup class]]) {
            _group = (TLGroup *)subject;
            NSUUID *peerTwincodeId = [TLAttributeNameUUIDValue getUUIDAttributeWithName:PAIR_PROTOCOL_PARAM_TWINCODE_OUTBOUND_ID list:invocation.invocationAttributes];
            if (peerTwincodeId && peerTwincodeOutbound) {
                NSUUID *groupTwincodeId = peerTwincodeOutbound.uuid;

                // If the twincode outbound attribute in the invocation does not match the group twincode
                // the updated twincode is a group member and we have to get it from the group conversation.
                if (peerTwincodeId && ![peerTwincodeId isEqual:groupTwincodeId]) {
                    groupMember = [[self.twinmeContext getConversationService] getGroupMemberConversationWithGroupTwincodeId:groupTwincodeId memberTwincodeId:peerTwincodeId];
                    if (groupMember) {
                        peerTwincodeOutbound = [groupMember peerTwincodeOutbound];
                    }
                }
            }
        } else {
            _contact = nil;
            _group = nil;
        }
        
        TL_ASSERT_NOT_NULL(twinmeContext, _subject, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

        _peerTwincodeOutbound = peerTwincodeOutbound;
        _groupMember = groupMember;
        _oldName = peerTwincodeOutbound ? [peerTwincodeOutbound name] : @"";
        _oldAvatarId = peerTwincodeOutbound ? [peerTwincodeOutbound avatarId] : nil;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & REFRESH_PEER_TWINCODE_OUTBOUND) != 0 && (self.state & REFRESH_PEER_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~REFRESH_PEER_TWINCODE_OUTBOUND;
        }
        if ((self.state & GET_PEER_IMAGE) != 0 && (self.state & GET_PEER_IMAGE_DONE) == 0) {
            self.state &= ~GET_PEER_IMAGE;
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
    // Step 1: refresh the current contact private peer twincode outbound id.
    //
    if (self.peerTwincodeOutbound) {
     
        if ((self.state & REFRESH_PEER_TWINCODE_OUTBOUND) == 0) {
            self.state |= REFRESH_PEER_TWINCODE_OUTBOUND;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.subject, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

            DDLogVerbose(@"%@ refreshTwincodeWithTwincode: %@", LOG_TAG, self.peerTwincodeOutbound);
            [[self.twinmeContext getTwincodeOutboundService] refreshTwincodeWithTwincode:self.peerTwincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLAttributeNameValue *> *updatedAttributes) {
                [self onRefreshTwincodeOutbound:updatedAttributes errorCode:errorCode];
            }];
            return;
        }
        
        if ((self.state & REFRESH_PEER_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2b: get the peer thumbnail image so that we have it in our local cache before displaying the notification.
    //
    if (self.avatarId) {
        
        if ((self.state & GET_PEER_IMAGE) == 0) {
            self.state |= GET_PEER_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_PEER_IMAGE_DONE;
                
                // Delete the old avatar id (this is a local delete, ignore the result).
                if (self.oldAvatarId) {
                    [imageService deleteImageWithImageId:self.oldAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {}];
                }
                
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_PEER_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: if the peer's name was changed and was not modified locally, update it.
    //
    
    if ((self.state & UPDATE_OBJECT) == 0) {
        self.state |= UPDATE_OBJECT;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.subject, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

        DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.subject);
        [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.subject localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onUpdateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & UPDATE_OBJECT_DONE) == 0) {
        return;
    }
    
    // Post a notification when the subject's attributes was changed (except if it was a group member).
    if ([self.twinmeContext isVisible:self.subject] && self.previousAttributes && !self.groupMember) {
        [self.twinmeContext.notificationCenter onUpdateContactWithContact:self.subject updatedAttributes:self.previousAttributes];
    }
    
    //
    // Last Step
    //
    
    if (self.contact) {
        if (!self.contact.checkInvariants) {
            [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint CONTACT_INVARIANT], [TLAssertValue initWithSubject:self.contact], [TLAssertValue initWithInvocationId:self.invocationId], nil];
        }
        
        // Trigger the onUpdateContact to give a chance to take into account the name update.
        [self.twinmeContext onUpdateContactWithRequestId:self.requestId contact:self.contact];

    } else if (self.group && !self.groupMember) {
        // Trigger the onUpdateGroup to give a chance to take into account the name update.
        [self.twinmeContext onUpdateGroupWithRequestId:self.requestId group:self.group];
    }
    [self stop];
}

- (void)onRefreshTwincodeOutbound:(nullable NSMutableArray<TLAttributeNameValue *> *)previousAttributes errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onRefreshTwincodeOutbound: %@ errorCode: %d", LOG_TAG, previousAttributes, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || previousAttributes == nil) {
        
        [self onErrorWithOperationId:REFRESH_PEER_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= REFRESH_PEER_TWINCODE_OUTBOUND_DONE;
    
    //
    // Invariant: Subject <<->> PeerTwincodeOutbound
    //
    self.previousAttributes = previousAttributes;
    [self.subject setPeerTwincodeOutbound:self.peerTwincodeOutbound];
    
    // Check if we have a new avatarId for this subject.
    if (!self.oldAvatarId || ![self.oldAvatarId isEqual:self.subject.avatarId]) {
        self.avatarId = self.subject.avatarId;
    }
    
    // Update the contact's name if it was not modified locally.
    if (self.contact && ![self.contact updatePeerName:self.peerTwincodeOutbound oldName:self.oldName]) {
        self.state |= UPDATE_OBJECT | UPDATE_OBJECT_DONE;

        // Likewise for the group name if it was the group twincode.
    } else if (!self.groupMember && self.group && ![self.group updatePeerName:self.peerTwincodeOutbound oldName:self.oldName]) {
        self.state |= UPDATE_OBJECT | UPDATE_OBJECT_DONE;

        // If it was a group member, no need to update the object.
    } else if (self.groupMember) {
        self.state |= UPDATE_OBJECT | UPDATE_OBJECT_DONE;
    }
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:UPDATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_OBJECT_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // If the peer twincode does not exist anymore, proceed with an unbind: this contact is dead now.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound && operationId == REFRESH_PEER_TWINCODE_OUTBOUND) {
        self.state |= REFRESH_PEER_TWINCODE_OUTBOUND_DONE | UPDATE_OBJECT | UPDATE_OBJECT_DONE;
        if (self.contact) {
            [self.twinmeContext unbindContactWithRequestId:self.requestId invocationId:self.invocationId contact:self.contact];
            self.invocationId = nil;
        }
        [self stop];
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    if (self.invocationId) {
        [self.twinmeContext acknowledgeInvocationWithInvocationId: self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
    }

    [super stop];
}

@end
