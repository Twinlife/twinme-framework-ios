/*
 *  Copyright (c) 2019-2024 twinlife SA.
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

#import "TLUpdateSpaceExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLSpace.h"
#import "TLSpaceSettings.h"
#import "TLProfile.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the SingleThreadExecutor provided by the twinlife library
// Executor and delegates are reachable (not eligible for garbage collection) between start() and stop() calls
//
// version: 1.5
//

static const int CREATE_SPACE_IMAGE = 1 << 0;
static const int CREATE_SPACE_IMAGE_DONE = 1 << 1;
static const int CREATE_SETTINGS_OBJECT = 1 << 2;
static const int CREATE_SETTINGS_OBJECT_DONE = 1 << 3;
static const int UPDATE_SETTINGS_OBJECT = 1 << 4;
static const int UPDATE_SETTINGS_OBJECT_DONE = 1 << 5;
static const int UPDATE_SPACE = 1 << 6;
static const int UPDATE_SPACE_DONE = 1 << 7;
static const int DELETE_SPACE_IMAGE = 1 << 8;
static const int DELETE_SPACE_IMAGE_DONE = 1 << 9;

//
// Interface: TLUpdateSpaceExecutor ()
//

@interface TLUpdateSpaceExecutor ()

@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nullable) TLProfile *profile;
@property (nonatomic, readonly, nullable) UIImage *spaceAvatar;
@property (nonatomic, readonly, nullable) UIImage *spaceLargeAvatar;
@property (nonatomic, readonly) BOOL createSettings;
@property (nonatomic, readonly) BOOL updateSpace;
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) TLExportedImageId *spaceAvatarId;
@property (nonatomic, nullable) NSUUID *oldSpaceAvatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateSpaceObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLUpdateSpaceExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateSpaceExecutor"

@implementation TLUpdateSpaceExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space profile:(nullable TLProfile *)profile settings:(nullable TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld space: %@ profile: %@ settings: %@", LOG_TAG, twinmeContext, requestId, space, profile, settings);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId];
    
    if (self) {
        _space = space;
        _profile = profile;
        _spaceAvatar = spaceAvatar;
        _spaceLargeAvatar = spaceLargeAvatar;

        // If the spaceSettings parameter has a different ID, build a new instance with our space settings ID.
        TLSpaceSettings *currentSettings = space.settings;
        if (settings && currentSettings && currentSettings.uuid && ![currentSettings.uuid isEqual:settings.uuid]) {
            settings = [[TLSpaceSettings alloc] initWithSettings:settings];
        }
        _spaceSettings = settings;
        _createSettings = settings != nil && !settings.uuid;
        _updateSpace = _createSettings || profile != nil;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        self.state = 0;
    }
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 1: create the space image id for the settings.
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
    // Step 2: update the space object in the repository.
    //
    if (self.spaceSettings) {
        if (self.createSettings) {
        
            if ((self.state & CREATE_SETTINGS_OBJECT) == 0) {
                self.state |= CREATE_SETTINGS_OBJECT;

                [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLSpaceSettings FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
                    TLSpaceSettings *settings = (TLSpaceSettings *)object;
                    [settings copyWithSettings:self.spaceSettings];
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

        } else {
        
            if ((self.state & UPDATE_SETTINGS_OBJECT) == 0) {
                self.state |= UPDATE_SETTINGS_OBJECT;

                if (self.spaceAvatarId) {
                    self.oldSpaceAvatarId = self.spaceSettings.avatarId;
                    self.spaceSettings.avatarId = self.spaceAvatarId.publicId;
                }

                DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.spaceSettings);
                [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.spaceSettings localOnly:YES withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                    [self onUpdateSettingsObject:object errorCode:errorCode];
                }];
                return;
            }
            if ((self.state & UPDATE_SETTINGS_OBJECT_DONE) == 0) {
                return;
            }
        }
    }

    //
    // Step 3: update the space object in the repository.
    //
    if (self.updateSpace) {
        
        if ((self.state & UPDATE_SPACE) == 0) {
            self.state |= UPDATE_SPACE;
        
            if (self.profile) {
                self.space.profile = self.profile;
                self.space.profileId = self.profile.uuid;
                self.profile.space = self.space;
            }

            DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.spaceSettings);
            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.space localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onUpdateSpaceObject:object errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: delete the old space image when it was replaced by a new one.
    //
    if (self.oldSpaceAvatarId) {
    
        if ((self.state & DELETE_SPACE_IMAGE) == 0) {
            self.state |= DELETE_SPACE_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            TLExportedImageId *exportedImageId = [imageService imageWithPublicId:self.oldSpaceAvatarId];
            if (exportedImageId) {
                [imageService deleteImageWithImageId:exportedImageId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                    self.state |= DELETE_SPACE_IMAGE_DONE;
                    [self onOperation];
                }];
                return;
            }
            self.state |= DELETE_SPACE_IMAGE_DONE;
        }
        if ((self.state & DELETE_SPACE_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //
    
    [self.twinmeContext onUpdateSpaceWithRequestId:self.requestId space:self.space];
    [self stop];
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

- (void)onCreateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateSettingsObject: %@ errorCode: %d", LOG_TAG, object, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:CREATE_SETTINGS_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_SETTINGS_OBJECT_DONE;
    
    self.spaceSettings = (TLSpaceSettings *)object;
    self.space.settings = self.spaceSettings;
    [self onOperation];
}

- (void)onUpdateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateSettingsObject: %@ errorCode: %d", LOG_TAG, object, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_SETTINGS_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_SETTINGS_OBJECT_DONE;
    if (self.space.settings != self.spaceSettings) {
        [self.space.settings copyWithSettings:self.spaceSettings];
        self.space.settings.avatarId = self.spaceSettings.avatarId;
    }
    [self onOperation];
}

- (void)onUpdateSpaceObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateSpaceObject: %@ object errorCode: %d", LOG_TAG, object, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_SPACE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_SPACE_DONE;
    [self onOperation];
}

@end
