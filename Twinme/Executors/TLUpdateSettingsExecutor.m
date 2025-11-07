/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>

#import "TLUpdateSettingsExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLSpaceSettings.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the SingleThreadExecutor provided by the twinlife library
// Executor and delegates are reachable (not eligible for garbage collection) between start() and stop() calls
//
// version: 1.3
//

static const int CREATE_SPACE_IMAGE = 1 << 0;
static const int CREATE_SPACE_IMAGE_DONE = 1 << 1;
static const int CREATE_SETTINGS_OBJECT = 1 << 2;
static const int CREATE_SETTINGS_OBJECT_DONE = 1 << 3;
static const int UPDATE_SETTINGS_OBJECT = 1 << 4;
static const int UPDATE_SETTINGS_OBJECT_DONE = 1 << 5;
static const int DELETE_SPACE_IMAGE = 1 << 8;
static const int DELETE_SPACE_IMAGE_DONE = 1 << 9;

//
// Interface: TLUpdateSettingsExecutor ()
//

@interface TLUpdateSettingsExecutor ()

@property (nonatomic, readonly, nullable) UIImage *spaceAvatar;
@property (nonatomic, readonly, nullable) UIImage *spaceLargeAvatar;
@property (nonatomic, readonly) BOOL createSettings;
@property (nonatomic, readonly, nonnull) void (^onUpdateSettings) (TLBaseServiceErrorCode errorCode, TLSpaceSettings *settings);
@property (nonatomic, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, nullable) TLExportedImageId *spaceAvatarId;
@property (nonatomic, nullable) NSUUID *oldSpaceAvatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode ;

- (void)onUpdateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode ;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLUpdateSettingsExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateSettingsExecutor"

@implementation TLUpdateSettingsExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpaceSettings * _Nullable settings))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ settings: %@", LOG_TAG, twinmeContext, settings);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:0];
    
    if (self) {
        _spaceAvatar = spaceAvatar;
        _spaceLargeAvatar = spaceLargeAvatar;
        _onUpdateSettings = block;

        _spaceSettings = settings;
        _createSettings = !settings.uuid;
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
    self.onUpdateSettings(TLBaseServiceErrorCodeSuccess, self.spaceSettings);

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
    self.spaceSettings = (TLSpaceSettings *) object;
    [self onOperation];
}

- (void)onUpdateSettingsObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateSettingsObject: %@ errorCode: %d", LOG_TAG, object, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_SETTINGS_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_SETTINGS_OBJECT_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }
    
    self.onUpdateSettings(errorCode, nil);
    
    [self stop];
}

@end
