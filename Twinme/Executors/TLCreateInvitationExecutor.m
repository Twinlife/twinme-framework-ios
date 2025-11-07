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
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLCreateInvitationExecutor.h"

#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLProfile.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLSpace.h"
#import "TLGroupMember.h"
#import "TLInvitation.h"
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
// version: 1.7
//

static const int COPY_IMAGE = 1 << 0;
static const int COPY_IMAGE_DONE = 1 << 1;
static const int CREATE_INVITATION_TWINCODE = 1 << 2;
static const int CREATE_INVITATION_TWINCODE_DONE = 1 << 3;
static const int CREATE_INVITATION_OBJECT = 1 << 6;
static const int CREATE_INVITATION_OBJECT_DONE = 1 << 7;
static const int PUSH_INVITATION = 1 << 8;
static const int PUSH_INVITATION_DONE = 1 << 9;
static const int UPDATE_INVITATION_OBJECT = 1 << 10;
static const int UPDATE_INVITATION_OBJECT_DONE = 1 << 11;

//
// Interface: TLCreateInvitationExecutor ()
//
@class TLCreateInvitationExecutorConversationServiceDelegate;

@interface TLCreateInvitationExecutor ()

@property (nonatomic, readonly, nullable) TLContact *contact;
@property (nonatomic, readonly, nullable) NSUUID *groupId;
@property (nonatomic, readonly, nullable) NSUUID *sendTo;
@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) TLTwincodeFactory *invitationTwincode;
@property (nonatomic, nullable) NSString *identityName;
@property (nonatomic, nullable) TLImageId *identityAvatarId;
@property (nonatomic, nullable) TLExportedImageId *copiedIdentityAvatarId;
@property (nonatomic, nullable) TLTwincodeOutbound *identityTwincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *invitationTwincodeOutbound;
@property (nonatomic, nullable) TLInvitation *invitation;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, nullable) TLTwincodeURI *twincodeURI;

@property (nonatomic, readonly, nonnull) TLCreateInvitationExecutorConversationServiceDelegate *conversationServiceDelegate;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateInvitationTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onPushDescriptor:(TLDescriptor *)descriptor;

- (void)stop;

@end

//
// Interface: TLCreateInvitationExecutorConversationServiceDelegate
//

@interface TLCreateInvitationExecutorConversationServiceDelegate : NSObject <TLConversationServiceDelegate>

@property (weak) TLCreateInvitationExecutor* executor;

- (instancetype)initWithExecutor:(nonnull TLCreateInvitationExecutor *)executor;

@end

//
// Implementation: TLCreateInvitationExecutorConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateInvitationExecutorConversationServiceDelegate"

@implementation TLCreateInvitationExecutorConversationServiceDelegate

- (nonnull instancetype)initWithExecutor:(nonnull TLCreateInvitationExecutor *)executor {
    DDLogVerbose(@"%@ initWithExecutor: %@", LOG_TAG, executor);
    
    self = [super init];
    if (self) {
        _executor = executor;
    }
    return self;
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    int operationId = [self.executor getOperationWithRequestId:requestId];
    if (operationId > 0) {
        [self.executor onPushDescriptor:descriptor];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.executor getOperationWithRequestId:requestId];
    if (operationId > 0) {
        [self.executor onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        [self.executor onOperation];
    }
}

@end

//
// Implementation: TLCreateInvitationExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateInvitationExecutor"

@implementation TLCreateInvitationExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space groupMember:(nullable TLGroupMember*)groupMember {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld space: %@ groupMember: %@", LOG_TAG, twinmeContext, requestId, space, groupMember);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _space = space;
        _contact = nil;
        
        if (groupMember) {
            _sendTo = groupMember.peerTwincodeOutboundId;
            _group = (TLGroup *)groupMember.owner;
            _groupId = _group.uuid;
        }
        
        TLProfile *profile = space.profile;
        _identityName = profile.name;
        _identityAvatarId = profile.avatarId;
        _identityTwincodeOutbound = profile.twincodeOutbound;

        _conversationServiceDelegate = [[TLCreateInvitationExecutorConversationServiceDelegate alloc] initWithExecutor:self];
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space contact:(nonnull TLContact*)contact sendTo:(nonnull NSUUID *)sendTo {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld space: %@ sendTo: %@", LOG_TAG, twinmeContext, requestId, space, sendTo);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _space = space;
        _contact = contact;
        _sendTo = sendTo;
        _group = nil;
        _groupId = nil;

        TLProfile *profile = space.profile;
        _identityName = profile.name;
        _identityAvatarId = profile.avatarId;
        _identityTwincodeOutbound = profile.twincodeOutbound;

        _conversationServiceDelegate = [[TLCreateInvitationExecutorConversationServiceDelegate alloc] initWithExecutor:self];
    }
    return self;

}

#pragma mark - Private methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & COPY_IMAGE) != 0 && (self.state & COPY_IMAGE_DONE) == 0)  {
            self.state &= ~COPY_IMAGE;
        }
        if ((self.state & CREATE_INVITATION_TWINCODE) != 0 && (self.state & CREATE_INVITATION_TWINCODE_DONE) == 0)  {
            self.state &= ~CREATE_INVITATION_TWINCODE;
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
    // Step 1a: create a copy of the identity image if there is one (privacy constraint).
    //
    if (self.identityAvatarId) {
    
        if ((self.state & COPY_IMAGE) == 0) {
            self.state |= COPY_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService copyImageWithImageId:self.identityAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCopyImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & COPY_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 1: create the invitation twincode.
    //
    
    if ((self.state & CREATE_INVITATION_TWINCODE) == 0) {
        self.state |= CREATE_INVITATION_TWINCODE;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.identityName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

        NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];
        
        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.identityName];
        
        if (self.copiedIdentityAvatarId) {
            [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.copiedIdentityAvatarId];
        }
        
        // Copy a number of twincode attributes from the profile identity.
        if (self.identityTwincodeOutbound) {
            [self.twinmeContext copySharedTwincodeAttributesWithTwincode:self.identityTwincodeOutbound attributes:twincodeOutboundAttributes];
        }

        DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, nil, twincodeOutboundAttributes, nil);
        
        [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLInvitation SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
            [self onCreateInvitationTwincodeFactory:twincodeFactory errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_INVITATION_TWINCODE_DONE) == 0) {
        return;
    }

    //
    // Step 4: create the invitation object.
    //
    
    if ((self.state & CREATE_INVITATION_OBJECT) == 0) {
        self.state |= CREATE_INVITATION_OBJECT;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.invitationTwincode, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        [[self.twinmeContext getTwincodeOutboundService] createURIWithTwincodeKind:TLTwincodeURIKindInvitation twincodeOutbound:self.invitationTwincode.twincodeOutbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *twincodeURI) {
            self.twincodeURI = twincodeURI;
        }];
        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLInvitation FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLInvitation *invitation = (TLInvitation *)object;
            invitation.groupMemberTwincodeOutboundId = self.sendTo;
            invitation.groupId = self.groupId;
            invitation.space = self.space;
            [invitation setTwincodeFactory:self.invitationTwincode];
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_INVITATION_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Step 5: send the invitation twincode.
    //
    if (self.sendTo && self.twincodeURI && (self.contact || self.group)) {

        if ((self.state & PUSH_INVITATION) == 0) {
            self.state |= PUSH_INVITATION;

            id<TLConversation> conversation;
            if (self.contact) {
                conversation = [[self.twinmeContext getConversationService] getOrCreateConversationWithSubject:self.contact create:YES];
            } else {
                conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.group];
            }
            int64_t requestId = [self newOperation:PUSH_INVITATION];
            [[self.twinmeContext getConversationService] pushTwincodeWithRequestId:requestId conversation:conversation sendTo:self.sendTo replyTo:nil twincodeId:self.twincodeURI.twincodeId schemaId:[TLInvitation SCHEMA_ID] publicKey:self.twincodeURI.publicKey copyAllowed:NO expireTimeout:0];
            return;
        }
        if ((self.state & PUSH_INVITATION_DONE) == 0) {
            return;
        }

        if ((self.state & UPDATE_INVITATION_OBJECT) == 0) {
            self.state |= UPDATE_INVITATION_OBJECT;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.invitation, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

            DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.invitation);
            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.invitation localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onUpdateObject:object errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_INVITATION_OBJECT_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step.
    //

    [self.twinmeContext onCreateInvitationWithRequestId:self.requestId invitation:self.invitation];
    [self stop];
}

- (void)onCopyImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCopyImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:COPY_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= COPY_IMAGE_DONE;
    
    self.copiedIdentityAvatarId = imageId;
    [self onOperation];
}

- (void)onCreateInvitationTwincodeFactory:(TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateInvitationTwincodeFactory: %@", LOG_TAG, twincodeFactory);

    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactory == nil) {
        
        [self onErrorWithOperationId:CREATE_INVITATION_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_INVITATION_TWINCODE_DONE;
    
    self.invitationTwincode = twincodeFactory;
    [self onOperation];
}

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:CREATE_INVITATION_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_INVITATION_OBJECT_DONE;
    self.invitation = (TLInvitation *)object;
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:UPDATE_INVITATION_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_INVITATION_OBJECT_DONE;
    [self onOperation];
}

- (void)onPushDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptor: %@", LOG_TAG, descriptor);

    self.state |= PUSH_INVITATION_DONE;
    self.invitation.descriptorId = descriptor.descriptorId;
    [self onOperation];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];
    [super stop];
}

@end
