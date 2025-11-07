/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLUpdateCallReceiverExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLPairProtocol.h"
#import "TLSpace.h"
#import "TLCallReceiver.h"
#import "TLCapabilities.h"

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

static const int CREATE_IMAGE = 1 << 0;
static const int CREATE_IMAGE_DONE = 1 << 1;
static const int UPDATE_OBJECT = 1 << 2;
static const int UPDATE_OBJECT_DONE = 1 << 3;
static const int UPDATE_TWINCODE_OUTBOUND = 1 << 4;
static const int UPDATE_TWINCODE_OUTBOUND_DONE = 1 << 5;
static const int DELETE_OLD_IMAGE = 1 << 6;
static const int DELETE_OLD_IMAGE_DONE = 1 << 7;

//
// Interface: TLUpdateCallReceiverExecutor ()
//

@interface TLUpdateCallReceiverExecutor ()

@property (nonatomic, readonly, nonnull) TLCallReceiver *callReceiver;

@property (nonatomic, readonly, nonnull) NSString *name;
@property (nonatomic, readonly, nullable) NSString *callReceiverDescription;
@property (nonatomic, readonly, nonnull) NSString *identityName;
@property (nonatomic, readonly, nullable) NSString *identityDescription;
@property (nonatomic, readonly, nullable) UIImage *avatar;
@property (nonatomic, readonly, nullable) UIImage *largeAvatar;
@property (nonatomic, readonly, nullable) NSString *capabilities;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, readonly, nullable) TLImageId *oldAvatarId;

@property (nonatomic, nullable) TLExportedImageId *avatarId;

@property (nonatomic, readonly) BOOL createImage;
@property (nonatomic, readonly) BOOL updateTwincode;
@property (nonatomic) BOOL updateObject;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLUpdateCallReceiverExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateCallReceiverExecutor"

@implementation TLUpdateCallReceiverExecutor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities*)capabilities {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld callReceiver: %@ name:%@", LOG_TAG, twinmeContext, requestId, callReceiver, name);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _callReceiver = callReceiver;
                
        _name = name;
        _callReceiverDescription = description;
        _identityName = identityName;
        _identityDescription = identityDescription;
        _avatar = avatar;
        _largeAvatar = largeAvatar;
        _oldAvatarId = callReceiver.avatarId;
        _capabilities = [capabilities attributeValue];
        _twincodeOutbound = callReceiver.twincodeOutbound;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _callReceiver, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        _createImage = largeAvatar != nil;
        
        BOOL updateIdentityDescription = ![_identityDescription isEqualToString:callReceiver.identityDescription];
        BOOL updateIdentityName = ![_identityName isEqualToString:callReceiver.identityName];
        BOOL updateCapabilities = ![_capabilities isEqualToString:[callReceiver.capabilities attributeValue]];
        
        _updateTwincode = _createImage || updateIdentityDescription || updateIdentityName || updateIdentityDescription || updateCapabilities;
        
        _updateObject = ![_name isEqualToString:callReceiver.name] || ![_callReceiverDescription isEqualToString:callReceiver.objectDescription];
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CREATE_IMAGE) != 0 && (self.state & CREATE_IMAGE_DONE) == 0) {
            self.state &= ~CREATE_IMAGE;
        }
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) != 0 && (self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~UPDATE_TWINCODE_OUTBOUND;
        }
        if ((self.state & DELETE_OLD_IMAGE) != 0 && (self.state & DELETE_OLD_IMAGE_DONE) == 0) {
            self.state &= ~DELETE_OLD_IMAGE;
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
    // Step 1: a new image must be setup, create it.
    //
    if (self.avatar && self.createImage) {
        
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
    // Step 2: update the contact object when the space or contact's name is modified.
    //
    
    if (self.updateObject) {
        
        if ((self.state & UPDATE_OBJECT) == 0) {
            self.state |= UPDATE_OBJECT;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.callReceiver, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);

            self.callReceiver.name = self.name;
            self.callReceiver.objectDescription = self.callReceiverDescription;

            DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.callReceiver);
            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.callReceiver localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onUpdateObject:object errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_OBJECT_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: update the private identity name and avatar.
    //
    
    if (self.updateTwincode) {
        
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_TWINCODE_OUTBOUND;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.identityName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:6], nil);

            NSMutableArray *attributes = [NSMutableArray array];
            if (self.identityName && ![self.identityName isEqualToString:self.callReceiver.identityName]) {
                [TLTwinmeAttributes setTwincodeAttributeName:attributes name:self.identityName];
            }
            if (self.avatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:attributes imageId:self.avatarId];
            }
            if (self.identityDescription && ![self.identityDescription isEqualToString:self.callReceiver.identityDescription]) {
                [TLTwinmeAttributes setTwincodeAttributeDescription:attributes description:self.callReceiverDescription];
            }
            if (self.capabilities && ![self.capabilities isEqualToString:[self.callReceiver.capabilities attributeValue]]) {
                [TLTwinmeAttributes setTwincodeAttributeCapabilities:attributes capabilities:self.capabilities];
            }

            DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.twincodeOutbound, attributes);
            [[self.twinmeContext getTwincodeOutboundService] updateTwincodeWithTwincode:self.twincodeOutbound attributes:attributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onUpdateTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: delete the old avatar image..
    //
    if (self.oldAvatarId && self.createImage) {
        
        if ((self.state & DELETE_OLD_IMAGE) == 0) {
            self.state |= DELETE_OLD_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.oldAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                [self onDeleteImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & DELETE_OLD_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.callReceiver, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:7], nil);

    [self.twinmeContext onUpdateCallReceiverWithRequestId:self.requestId callReceiver:self.callReceiver];
    [self stop];
}

- (void)onCreateImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_IMAGE_DONE;
    
    self.avatarId = imageId;
    [self onOperation];
}

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_TWINCODE_OUTBOUND_DONE;
    
    [self.callReceiver setTwincodeOutbound:twincodeOutbound];
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_OBJECT_DONE;
    [self onOperation];
}

- (void)onDeleteImage:(nullable TLImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    // Ignore the error and proceed!!!
    self.state |= DELETE_OLD_IMAGE_DONE;
    [self onOperation];
}

@end
