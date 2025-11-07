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

#import "TLProfile.h"
#import "TLSpace.h"
#import "TLGroup.h"
#import "TLPairProtocol.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLAbstractTwinmeExecutor.h"
#import "TLCreateSpaceExecutor.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.5
//

/**
 * Executor to create a new Space either local to use user or imported from a SpaceCard:
 *
 * - get the space twincode which gives us the name/avatar/permissions (optional),
 *   if this fails, the space is not created and onError is called with ITEM_NOT_FOUND
 * - create a profile associated with the space,
 * - create the space settings object that holds user's local configuration (saved locally in the repository),
 * - create the space object,
 * - get the invitations defined by the SpaceCard (optional),
 *   if this fails, failed invitations are ignored and silently dropped,
 * - create the groups defined by the SpaceCard (optional).
 *   if this fails, failed groups are ignored and silently dropped
 */
static const int GET_SPACE_TWINCODE = 1 << 0;
static const int GET_SPACE_TWINCODE_DONE = 1 << 1;
static const int CREATE_PROFILE = 1 << 2;
static const int CREATE_PROFILE_DONE = 1 << 3;
static const int CREATE_SPACE_IMAGE = 1 << 4;
static const int CREATE_SPACE_IMAGE_DONE = 1 << 5;
static const int CREATE_SETTINGS_OBJECT = 1 << 6;
static const int CREATE_SETTINGS_OBJECT_DONE = 1 << 7;
static const int CREATE_OBJECT = 1 << 8;
static const int CREATE_OBJECT_DONE = 1 << 9;
static const int GET_INVITATION_TWINCODE = 1 << 10;
static const int GET_INVITATION_TWINCODE_DONE = 1 << 11;
static const int CREATE_GROUP = 1 << 12;
static const int CREATE_GROUP_DONE = 1 << 13;

//
// Interface: TLCreateSpaceExecutor ()
//

@interface TLCreateSpaceExecutor ()

@property (nonatomic, readonly, nullable) NSString *identityName;
@property (nonatomic, readonly, nullable) UIImage *identityAvatar;
@property (nonatomic, readonly, nullable) UIImage *identityLargeAvatar;
@property (nonatomic, readonly, nullable) UIImage *spaceAvatar;
@property (nonatomic, readonly, nullable) UIImage *spaceLargeAvatar;
@property (nonatomic, readonly, nonnull) NSString *name;
@property (nonatomic, readonly, nullable) UIImage *avatar;
@property (nonatomic, readonly, nonnull) NSMutableArray<NSUUID *> *invitations;
@property (nonatomic, readonly) BOOL isDefault;
@property (nonatomic, readonly, nullable) NSUUID *spaceCardId;
@property (nonatomic, readonly, nullable) NSUUID *spaceTwincodeId;

@property (nonatomic, nonnull) TLSpaceSettings *settings;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) NSUUID *invitationTwincodeOutboundId;
@property (nonatomic, nullable) TLTwincodeOutbound *invitationTwincodeOutbound;
@property (nonatomic, nullable) TLTwincodeOutbound *spaceTwincodeOutbound;
@property (nonatomic, nullable) TLExportedImageId *spaceAvatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onGetInvitationTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onGetSpaceTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateProfile:(nonnull TLProfile *)profile;

- (void)onCreateGroup:(nonnull TLGroup *)group;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLCreateSpaceExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateSpaceExecutor"

@implementation TLCreateSpaceExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar name:(nullable NSString *)name avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar isDefault:(BOOL)isDefault {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld settings: %@ name: %@", LOG_TAG, twinmeContext, requestId, settings, name);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _identityName = name;
        _identityAvatar = avatar;
        _identityLargeAvatar = largeAvatar;
        _spaceAvatar = spaceAvatar;
        _spaceLargeAvatar = spaceLargeAvatar;
        _settings = settings;
        _isDefault = isDefault;
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings profile:(nullable TLProfile *)profile isDefault:(BOOL)isDefault {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld settings: %@ profile: %@ isDefault: %d", LOG_TAG, twinmeContext, requestId, settings, profile, isDefault);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _profile = profile;
        _identityName = profile ? profile.name : nil;
        _settings = settings;
        _isDefault = isDefault;
    }
    return self;
}

#pragma mark - Private methods

- (void)onCreateProfileWithRequestId:(const int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self onCreateProfile:profile];
    }
}

- (void)onCreateGroupWithRequestId:(const int64_t)requestId group:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroupWithRequestId: %lld group: %@ conversation: %@", LOG_TAG, requestId, group, conversation);

    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self onCreateGroup:group];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & GET_SPACE_TWINCODE) != 0 && (self.state & GET_SPACE_TWINCODE_DONE) == 0)  {
            self.state &= ~GET_SPACE_TWINCODE;
        }

        if ((self.state & CREATE_SPACE_IMAGE) != 0 && (self.state & CREATE_SPACE_IMAGE_DONE) == 0)  {
            self.state &= ~CREATE_SPACE_IMAGE;
        }
        if ((self.state & CREATE_SETTINGS_OBJECT) != 0 && (self.state & CREATE_SETTINGS_OBJECT_DONE) == 0)  {
            self.state &= ~CREATE_SETTINGS_OBJECT;
        }

        // Restart the get invitation twincode only when there is a pending invitation to get.
        // Don't restart the group creation.
        if (self.invitationTwincodeOutboundId && (self.state & GET_INVITATION_TWINCODE) != 0 && (self.state & GET_INVITATION_TWINCODE_DONE) == 0)  {
            self.state &= ~GET_INVITATION_TWINCODE;
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
    // Step 1: get the space twincode.
    //
    if (self.spaceTwincodeId) {
        
        if ((self.state & GET_SPACE_TWINCODE) == 0) {
            self.state |= GET_SPACE_TWINCODE;

            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.spaceTwincodeId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetSpaceTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_SPACE_TWINCODE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 2: create the Profile object.
    //
    if (!self.profile && self.identityName && self.identityAvatar) {
    
        if ((self.state & CREATE_PROFILE) == 0) {
            self.state |= CREATE_PROFILE;
        
            int64_t requestId = [self newOperation:CREATE_PROFILE];
        
            [self.twinmeContext createProfileWithRequestId:requestId name:self.identityName avatar:self.identityAvatar largeAvatar:self.identityLargeAvatar description:nil capabilities:nil];
            return;
        }
        if ((self.state & CREATE_PROFILE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: create the space image id for the settings.
    //
    if (self.spaceAvatar) {
      
        if ((self.state & CREATE_SPACE_IMAGE) == 0) {
            self.state |= CREATE_SPACE_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService createLocalImageWithImage:self.spaceLargeAvatar thumbnail:self.spaceAvatar withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_SPACE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: allocate a UUID for the space settings and create its instance locally in the repository.
    //
    
    if ((self.state & CREATE_SETTINGS_OBJECT) == 0) {
        self.state |= CREATE_SETTINGS_OBJECT;

        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLSpaceSettings FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLSpaceSettings *settings = (TLSpaceSettings *)object;
            [settings copyWithSettings:self.settings];
            if (self.spaceAvatarId) {
                settings.avatarId = self.spaceAvatarId.publicId;
            }
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateSettingsObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_SETTINGS_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Step 5: create the Space object.
    //
        
    if ((self.state & CREATE_OBJECT) == 0) {
        self.state |= CREATE_OBJECT;

        // self.space = [[TLSpace alloc] initWithSettings:self.settings profile:self.profile spaceCardId:self.spaceCardId];
        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLSpace FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLSpace *space = (TLSpace *)object;
            space.profile = self.profile;
            space.twincodeOutbound = self.spaceTwincodeOutbound;
            space.settings = self.settings;
            
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_OBJECT_DONE) == 0) {
        return;
    }
    
    if (self.invitations && self.invitations.count > 0) {
        //
        // Step 6: get a pending invitation twincode.
        //
        
        if ((self.state & GET_INVITATION_TWINCODE) == 0) {
            self.state |= GET_INVITATION_TWINCODE;
            
            self.invitationTwincodeOutboundId = self.invitations[0];

            [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.invitationTwincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onGetInvitationTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_INVITATION_TWINCODE_DONE) == 0) {
            return;
        }

        //
        // Step 7: create the group with the pending invitation twincode.
        //
        
        if ((self.state & CREATE_GROUP) == 0) {
            self.state |= CREATE_GROUP;
            
            int64_t requestId = [self newOperation:CREATE_GROUP];
            
            [self.twinmeContext createGroupWithRequestId:requestId invitationTwincode:self.invitationTwincodeOutbound space:self.space];
            return;
        }
        if ((self.state & CREATE_GROUP_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step.
    //
    if (self.isDefault) {
        [self.twinmeContext setDefaultSpace:self.space];
    }
 
    [self.twinmeContext onCreateSpaceWithRequestId:self.requestId space:self.space];
    [self stop];
}

- (void)onCreateProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfile: %@", LOG_TAG, profile);

    self.state |= CREATE_PROFILE_DONE;
    
    self.profile = profile;
    [self onOperation];
}

- (void)onCreateImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_SPACE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_SPACE_IMAGE_DONE;
    
    self.spaceAvatarId = imageId;
    [self onOperation];
}

- (void)onGetSpaceTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetSpaceTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        
        [self onErrorWithOperationId:GET_SPACE_TWINCODE errorCode:errorCode errorParameter:self.spaceTwincodeId.UUIDString];
        return;
    }

    TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.spaceTwincodeId, [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterFactoryId, [TLAssertValue initWithNumber:3], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);

    self.state |= GET_SPACE_TWINCODE_DONE;
    
    self.spaceTwincodeOutbound = twincodeOutbound;
    [self onOperation];
}

- (void)onGetInvitationTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetInvitationTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        
        [self onErrorWithOperationId:GET_INVITATION_TWINCODE errorCode:errorCode errorParameter:self.invitationTwincodeOutboundId.UUIDString];
        return;
    }

    TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound.uuid, self.invitationTwincodeOutboundId, [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterFactoryId, [TLAssertValue initWithNumber:4], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);

    self.state |= GET_INVITATION_TWINCODE_DONE;
    
    self.invitationTwincodeOutbound = twincodeOutbound;
    [self onOperation];
}

- (void)onCreateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateSettingsObject: %@", LOG_TAG, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:CREATE_SETTINGS_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_SETTINGS_OBJECT_DONE;
    
    self.settings = (TLSpaceSettings *)object;
    [self onOperation];
}

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: %@", LOG_TAG, object);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:CREATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_OBJECT_DONE;
    
    self.space = (TLSpace *)object;
    [self onOperation];
}

- (void)onCreateGroup:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ onCreateGroup: %@", LOG_TAG, group);

    self.state |= CREATE_GROUP_DONE;
    
    self.invitationTwincodeOutboundId = nil;
    self.invitationTwincodeOutbound = nil;
    [self.invitations removeObjectAtIndex:0];
    if (self.invitations.count > 0) {
        self.state &= ~(GET_INVITATION_TWINCODE | GET_INVITATION_TWINCODE_DONE | CREATE_GROUP | CREATE_GROUP_DONE);
    }
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (operationId == GET_INVITATION_TWINCODE && errorCode == TLBaseServiceErrorCodeItemNotFound) {
        [self.invitations removeObjectAtIndex:0];
        self.state &= ~(GET_INVITATION_TWINCODE | GET_INVITATION_TWINCODE_DONE);
        self.invitationTwincodeOutboundId = nil;
        [self onOperation];
        return;
    }
    
    if (operationId == CREATE_GROUP && errorCode == TLBaseServiceErrorCodeItemNotFound) {
        [self.invitations removeObjectAtIndex:0];
        self.state &= ~(GET_INVITATION_TWINCODE | GET_INVITATION_TWINCODE_DONE | CREATE_GROUP);
        self.invitationTwincodeOutboundId = nil;
        self.invitationTwincodeOutbound = nil;
        [self onOperation];
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
