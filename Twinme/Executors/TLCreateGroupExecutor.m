/*
 *  Copyright (c) 2018-2025 twinlife SA.
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
#import <Twinlife/TLGroupProtocol.h>
#import <Twinlife/TLImageService.h>

#import "TLProfile.h"
#import "TLGroup.h"
#import "TLGroupMember.h"
#import "TLSpace.h"
#import "TLPairProtocol.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLAbstractTwinmeExecutor.h"
#import "TLCreateGroupExecutor.h"
#import "TLDeleteGroupExecutor.h"
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
// version: 1.8
//

/**
 * Executor for the creation of a group.
 *
 * - create the group twincode with the group name and group avatar (optional),
 * - create the group member twincode with the member name and avatar,
 * - get the group member twincode outbound,
 * - get the group twincode outbound,
 * - create the group local object in the repository,
 *
 * The step2 (create the group twincode) is optional and is not made when a user joins the group.
 */
static const int FIND_GROUP = 1 << 0;
static const int CREATE_IMAGE = 1 << 1;
static const int CREATE_IMAGE_DONE = 1 << 2;
static const int COPY_PROFILE_IMAGE = 1 << 3;
static const int COPY_PROFILE_IMAGE_DONE = 1 << 4;
static const int CREATE_MEMBER_TWINCODE = 1 << 5;
static const int CREATE_MEMBER_TWINCODE_DONE = 1 << 6;
static const int CREATE_GROUP_TWINCODE = 1 << 7;
static const int CREATE_GROUP_TWINCODE_DONE = 1 << 8;
static const int GET_GROUP_TWINCODE_OUTBOUND = 1 << 9;
static const int GET_GROUP_TWINCODE_OUTBOUND_DONE = 1 << 10;
static const int GET_GROUP_IMAGE = 1 << 11;
static const int GET_GROUP_IMAGE_DONE = 1 << 12;
static const int CREATE_GROUP_OBJECT = 1 << 13;
static const int CREATE_GROUP_OBJECT_DONE = 1 << 14;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 15;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 16;
static const int ACCEPT_INVITATION = 1 << 17;
static const int UPDATE_GROUP = 1 << 19;
static const int UPDATE_GROUP_DONE = 1 << 20;

//
// Interface: TLCreateGroupExecutor ()
//

@interface TLCreateGroupExecutor ()

@property (nonatomic, readonly, nonnull) NSString *name;
@property (nonatomic, readonly, nullable) NSString *groupDescription;
@property (nonatomic, readonly, nullable) UIImage *avatar;
@property (nonatomic, readonly, nullable) UIImage *largeAvatar;
@property (nonatomic, readonly) BOOL isOwner;
@property (nonatomic, readonly, nullable) NSUUID *invitedByMemberTwincodeId;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *invitationTwincode;
@property (nonatomic, readonly, nullable) TLInvitationDescriptor *invitation;

@property (nonatomic, nullable) TLGroup *group;
@property (nonatomic, nullable) NSUUID *groupTwincodeId;
@property (nonatomic, nullable) NSUUID *groupTwincodeFactoryId;
@property (nonatomic, nullable) TLTwincodeFactory *memberTwincode;
@property (nonatomic, nullable) NSString *identityName;
@property (nonatomic, nullable) TLImageId *identityAvatarId;
@property (nonatomic, nullable) TLExportedImageId *copiedIdentityAvatarId;
@property (nonatomic, nullable) TLImageId *groupAvatarId;
@property (nonatomic, nullable) TLExportedImageId *createdGroupAvatarId;
@property (nonatomic, nullable) TLTwincodeOutbound *groupTwincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *memberTwincodeOutbound;
@property (nonatomic, nullable) id<TLGroupConversation> groupConversation;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateGroupTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateMemberTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onGetGroupTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLCreateGroupExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateGroupExecutor"

@implementation TLCreateGroupExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld name: %@ space: %@", LOG_TAG, twinmeContext, requestId, name, space);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _name = name;
        _groupDescription = description;
        _avatar = avatar;
        _largeAvatar = largeAvatar;
        _groupTwincodeId = nil;
        _identityName = nil;
        _groupTwincodeFactoryId = nil;
        _isOwner = YES;
        _invitedByMemberTwincodeId = nil;
        _space = space;
        _invitationTwincode = nil;
        self.state = FIND_GROUP;
        if (!_name) {
            TL_ASSERT_NOT_NULL(twinmeContext, _name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

            _name = NSLocalizedString(@"anonymous", nil);
        }
        
        TLProfile *profile = space.profile;
        _identityName = profile.name;
        _identityAvatarId = profile.avatarId;
    }
    return self;
}

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space invitation:(nonnull TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld invitation: %@", LOG_TAG, twinmeContext, requestId, invitation);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    if (self) {
        _invitation = invitation;
        _name = invitation.name;
        _groupDescription = nil;
        _avatar = nil;
        _largeAvatar = nil;
        _groupTwincodeId = invitation.groupTwincodeId;
        _identityName = nil;
        _groupTwincodeFactoryId = nil;
        _isOwner = NO;
        _invitedByMemberTwincodeId = invitation.descriptorId.twincodeOutboundId;
        _space = space;
        _invitationTwincode = nil;
        if (!_name) {
            TL_ASSERT_NOT_NULL(twinmeContext, _name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

            _name = NSLocalizedString(@"anonymous", nil);
        }
        
        TLProfile *profile = space.profile;
        _identityName = profile.name;
        _identityAvatarId = profile.avatarId;
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space invitationTwincode:(nonnull TLTwincodeOutbound *)invitationTwincode {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld invitationTwincode: %@ space: %@", LOG_TAG, twinmeContext, requestId, invitationTwincode, space);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _invitationTwincode = invitationTwincode;
        _name = [invitationTwincode name];
        _groupDescription = [invitationTwincode twincodeDescription];
        _groupAvatarId = [invitationTwincode avatarId];
        _groupTwincodeId = [TLTwinmeAttributes getChannelIdFromTwincode:(TLTwincode *)invitationTwincode];
        _identityName = nil;
        _identityAvatarId = nil;
        _groupTwincodeFactoryId = nil;
        _isOwner = NO;
        _invitedByMemberTwincodeId = nil;
        _space = space;
        _invitationTwincode = invitationTwincode;
        if (!_name) {
            TL_ASSERT_NOT_NULL(twinmeContext, _name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);
            
            _name = NSLocalizedString(@"anonymous", nil);
        }
        
        TLProfile *profile = space.profile;
        if (profile) {
            _identityName = profile.name;
            _identityAvatarId = profile.avatarId;
        }
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CREATE_IMAGE) != 0 && (self.state & CREATE_IMAGE_DONE) == 0)  {
            self.state &= ~CREATE_IMAGE;
        }
        if ((self.state & COPY_PROFILE_IMAGE) != 0 && (self.state & COPY_PROFILE_IMAGE_DONE) == 0)  {
            self.state &= ~COPY_PROFILE_IMAGE;
        }
        if ((self.state & CREATE_GROUP_TWINCODE) != 0 && (self.state & CREATE_GROUP_TWINCODE_DONE) == 0)  {
            self.state &= ~CREATE_GROUP_TWINCODE;
        }
        if ((self.state & CREATE_MEMBER_TWINCODE) != 0 && (self.state & CREATE_MEMBER_TWINCODE_DONE) == 0) {
            self.state &= ~CREATE_MEMBER_TWINCODE;
        }
        if ((self.state & GET_GROUP_TWINCODE_OUTBOUND) != 0 && (self.state & GET_GROUP_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~GET_GROUP_TWINCODE_OUTBOUND;
        }
        if ((self.state & GET_GROUP_IMAGE) != 0 && (self.state & GET_GROUP_IMAGE_DONE) == 0) {
            self.state &= ~GET_GROUP_IMAGE;
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
    // Step 1a: look for an existing group conversation and retrieve the associated group and group member identity.
    //
    if (self.groupTwincodeId && (self.state & FIND_GROUP) == 0) {
        self.state |= FIND_GROUP;

        self.groupConversation = [[self.twinmeContext getConversationService] getGroupConversationWithGroupTwincodeId:self.groupTwincodeId];
        if (self.groupConversation) {
            self.group = (TLGroup *) self.groupConversation.subject;
            self.memberTwincodeOutbound = self.group.twincodeOutbound;
            if (self.memberTwincodeOutbound) {
                self.state |= CREATE_IMAGE | CREATE_IMAGE_DONE;
                self.state |= COPY_PROFILE_IMAGE | COPY_PROFILE_IMAGE_DONE;
                self.state |= CREATE_MEMBER_TWINCODE | CREATE_MEMBER_TWINCODE_DONE;
                self.state |= CREATE_GROUP_OBJECT | CREATE_GROUP_OBJECT_DONE;
            }
        }
    }

    //
    // Step 1a: create the group image if there is one.
    //
    if (self.avatar) {
        
        if ((self.state & CREATE_IMAGE) == 0) {
            self.state |= CREATE_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService createImageWithImage:self.largeAvatar thumbnail:self.avatar withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 1a: create a copy of the identity image if there is one (privacy constraint).
    //
    if (self.identityAvatarId) {
        
        if ((self.state & COPY_PROFILE_IMAGE) == 0) {
            self.state |= COPY_PROFILE_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService copyImageWithImageId:self.identityAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCopyImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & COPY_PROFILE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 1: create the group member twincode.
    //
    
    if ((self.state & CREATE_MEMBER_TWINCODE) == 0) {
        self.state |= CREATE_MEMBER_TWINCODE;
        
        NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];
        
        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        if (self.identityName) {
            [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.identityName];
        }
        if (self.copiedIdentityAvatarId) {
            [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.copiedIdentityAvatarId];
        }
        if (self.invitedByMemberTwincodeId) {
            [TLTwinmeAttributes setTwincodeAttributeInvitedBy:twincodeOutboundAttributes twincodeId:self.invitedByMemberTwincodeId];
        }
        
        DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, nil,
                     twincodeOutboundAttributes, nil);
        
        [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLGroupMember SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
            [self onCreateMemberTwincodeFactory:twincodeFactory errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_MEMBER_TWINCODE_DONE) == 0) {
        return;
    }

    //
    // Step 3: create the group twincode (unless we are joining a group).
    //
    if (self.groupTwincodeId == nil) {
        
        if ((self.state & CREATE_GROUP_TWINCODE) == 0) {
            self.state |= CREATE_GROUP_TWINCODE;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

            NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
            [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];
            
            NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
            [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.name];
            
            if (self.createdGroupAvatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.createdGroupAvatarId];
            }
            
            if (self.groupDescription) {
                [TLTwinmeAttributes setTwincodeAttributeDescription:twincodeOutboundAttributes description:self.groupDescription];
            }
            
            [TLTwinmeAttributes setTwincodeAttributeCreatedBy:twincodeOutboundAttributes twincodeId:self.memberTwincode.twincodeOutbound.uuid];
            
            DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, nil, twincodeOutboundAttributes, nil);
            
            [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLGroup SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
                [self onCreateGroupTwincodeFactory:twincodeFactory errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_GROUP_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: get the group twincode outbound.
    //
    
    if ((self.state & GET_GROUP_TWINCODE_OUTBOUND) == 0) {
        self.state |= GET_GROUP_TWINCODE_OUTBOUND;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.groupTwincodeId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        DDLogVerbose(@"%@ getTwincodeWithTwincodeId: %@", LOG_TAG, self.groupTwincodeId);
        if (self.invitation && self.invitation.publicKey) {
            [[self.twinmeContext getTwincodeOutboundService] getSignedTwincodeWithTwincodeId:self.groupTwincodeId publicKey:self.invitation.publicKey trustMethod:TLTrustMethodPeer withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetGroupTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
        } else {
            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.groupTwincodeId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetGroupTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
        }
        return;
    }
    if ((self.state & GET_GROUP_TWINCODE_OUTBOUND_DONE) == 0) {
        return;
    }
    
    //
    // Step 4a: get the group image so that we have it in the cache when we are done.
    //
    if (self.groupAvatarId && !self.avatar) {
        
        if ((self.state & GET_GROUP_IMAGE) == 0) {
            self.state |= GET_GROUP_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.groupAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_GROUP_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_GROUP_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 5: create the group object that links the group ID and the member twincode.
    //
    
    if ((self.state & CREATE_GROUP_OBJECT) == 0) {
        self.state |= CREATE_GROUP_OBJECT;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.memberTwincode, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLGroup FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLGroup *group = (TLGroup *)object;
            [group setTwincodeFactory:self.memberTwincode];
            group.peerTwincodeOutbound = self.groupTwincodeOutbound;
            group.groupTwincodeFactoryId = self.groupTwincodeFactoryId;
            group.space = self.space;
            group.name = self.name;
            group.objectDescription = self.groupDescription;
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_GROUP_OBJECT_DONE) == 0) {
        return;
    }
    
    //
    // Step 6: send the subscribe invocation on the invitation twincode.
    //
    if (self.invitationTwincode) {
        
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
            self.state |= INVOKE_TWINCODE_OUTBOUND;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.memberTwincode, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);

            NSMutableArray *attributes = [NSMutableArray array];
            [TLGroupProtocol setInvokeTwincodeActionGroupSubscribeMemberTwincodeId:attributes memberTwincodeId:self.memberTwincode.twincodeOutbound.uuid];
            
            DDLogVerbose(@"%@ invokeTwincodeWithTwincode:%@ attributes: %@", LOG_TAG, self.invitationTwincode.uuid, attributes);
            
            [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.invitationTwincode options:TLInvokeTwincodeUrgent action:[TLGroupProtocol invokeTwincodeActionGroupSubscribe] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }

    // If we were leaving this group, update because we have now accepted a new invitation.
    if (self.group) {
        if (self.group.isLeaving && (self.state & UPDATE_GROUP) == 0) {
            self.state |= UPDATE_GROUP;
            self.group.isLeaving = NO;
            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.group localOnly:YES withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onUpdateObject:object errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_GROUP) != 0 && (self.state & UPDATE_GROUP_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step: create the group conversation.  If this fails (database creation error),
    // cleanup the group that was created and report the error.
    //
    if (!self.groupConversation) {
        self.groupConversation = [[self.twinmeContext getConversationService] createGroupConversationWithSubject:self.group owner:self.isOwner];
        if (!self.groupConversation) {
            TLDeleteGroupExecutor *deleteGroupExecutor = [[TLDeleteGroupExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID] group:self.group timeout:0];
            [deleteGroupExecutor start];
            [self onErrorWithOperationId:CREATE_GROUP_OBJECT errorCode:TLBaseServiceErrorCodeDatabaseError errorParameter:nil];
            return;
        }
    }

    // We must accept the group invitation and we have not done it yet.
    if (self.group && self.invitation) {
        if ((self.state & ACCEPT_INVITATION) == 0) {
            self.state |= ACCEPT_INVITATION;

            int64_t requestId = [self newOperation:ACCEPT_INVITATION];
            TLBaseServiceErrorCode errorCode = [[self.twinmeContext getConversationService] joinGroupWithRequestId:requestId descriptorId:self.invitation.descriptorId group:self.group];
            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                [self onErrorWithOperationId:ACCEPT_INVITATION errorCode:errorCode errorParameter:nil];
                return;
            }
        }
    }

    TL_ASSERT_NOT_NULL(self.twinmeContext, self.group, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);

    [self.twinmeContext onCreateGroupWithRequestId:self.requestId group:self.group conversation:self.groupConversation];
    [self stop];
}

- (void)onCreateImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_IMAGE_DONE;
    
    self.createdGroupAvatarId = imageId;
    [self onOperation];
}

- (void)onCopyImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCopyImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:COPY_PROFILE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= COPY_PROFILE_IMAGE_DONE;
    
    self.copiedIdentityAvatarId = imageId;
    [self onOperation];
}

- (void)onCreateGroupTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateGroupTwincodeFactory: %@", LOG_TAG, twincodeFactory);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactory == nil) {
        
        [self onErrorWithOperationId:CREATE_GROUP_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_GROUP_TWINCODE_DONE | GET_GROUP_TWINCODE_OUTBOUND | GET_GROUP_TWINCODE_OUTBOUND_DONE;
    
    self.groupTwincodeOutbound = twincodeFactory.twincodeOutbound;
    self.groupTwincodeId = twincodeFactory.twincodeOutbound.uuid;
    self.groupTwincodeFactoryId = twincodeFactory.uuid;
    [self onOperation];
}

- (void)onCreateMemberTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateMemberTwincodeFactory: %@", LOG_TAG, twincodeFactory);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactory == nil) {
        
        [self onErrorWithOperationId:CREATE_MEMBER_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_MEMBER_TWINCODE_DONE;
    
    self.memberTwincode = twincodeFactory;
    [self onOperation];
}

- (void)onGetGroupTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        
        [self onErrorWithOperationId:GET_GROUP_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:self.groupTwincodeId.UUIDString];
        return;
    }
    
    TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.groupTwincodeId, [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterTwincodeId, [TLAssertValue initWithNumber:3], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);

    self.state |= GET_GROUP_TWINCODE_OUTBOUND_DONE;
    
    self.groupTwincodeOutbound = twincodeOutbound;
    self.groupAvatarId = [twincodeOutbound avatarId];
    [self onOperation];
}

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: %@", LOG_TAG, object);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:CREATE_GROUP_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= CREATE_GROUP_OBJECT_DONE;
    self.group = (TLGroup *)object;
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateObject: %@", LOG_TAG, object);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:UPDATE_GROUP errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= UPDATE_GROUP_DONE;
    [self onOperation];
}

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onInvokeTwincode: %@", LOG_TAG, invocationId);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || invocationId == nil) {
        
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }
    
    if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) != 0) {
        return;
    }
    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
    [self onOperation];
}

@end
