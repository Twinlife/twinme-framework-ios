/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Julien Poumarat (Julien.Poumarat@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLCreateProfileExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLProfile.h"
#import "TLSpace.h"
#import "TLPairProtocol.h"
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
// version: 1.12
//

static const int CREATE_IMAGE = 1 << 0;
static const int CREATE_IMAGE_DONE = 1 << 1;
static const int CREATE_TWINCODE = 1 << 2;
static const int CREATE_TWINCODE_DONE = 1 << 3;
static const int CREATE_OBJECT = 1 << 6;
static const int CREATE_OBJECT_DONE = 1 << 7;
static const int UPDATE_SPACE = 1 << 8;
static const int UPDATE_SPACE_DONE = 1 << 9;

//
// Interface: TLCreateProfileExecutor ()
//

@interface TLCreateProfileExecutor ()

@property (nonatomic, readonly, nonnull) NSString *name;
@property (nonatomic, readonly, nonnull) UIImage *avatar;
@property (nonatomic, readonly, nullable) UIImage *largeAvatar;
@property (nonatomic, readonly, nullable) TLSpace *space;
@property (nonatomic, readonly, nullable) NSString *profileDescription;
@property (nonatomic, readonly, nullable) NSString *capabilities;

@property (nonatomic, nullable) TLProfile *profile;
@property (nonatomic, nullable) TLTwincodeFactory *twincodeFactory;
@property (nonatomic, nullable) TLExportedImageId *avatarId;

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateSpace:(nonnull TLSpace *)space;

- (void)onCreateObject:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object;

@end

//
// Implementation: TLCreateProfileExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateProfileExecutor"

@implementation TLCreateProfileExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities space:(nullable TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld name: %@ avatar: %@ description: %@ capabilities: %@ space:%@", LOG_TAG, twinmeContext, requestId, name, avatar, description, capabilities, space);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _name = name;
        _avatar = avatar;
        _largeAvatar = largeAvatar;
        _space = space;
        _profileDescription = description;
        _capabilities = [capabilities attributeValue];
        
        TL_ASSERT_NOT_NULL(twinmeContext, _name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _avatar, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);
    }
    return self;
}

#pragma mark - Private methods

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self onUpdateSpace:space];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CREATE_IMAGE) != 0 && (self.state & CREATE_IMAGE_DONE) == 0) {
            self.state &= ~CREATE_IMAGE;
        }
        if ((self.state & CREATE_TWINCODE) != 0 && (self.state & CREATE_TWINCODE_DONE) == 0) {
            self.state &= ~CREATE_TWINCODE;
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
    // Step 1a: create the image id.
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
    // Step 1: create the public profile twincode.
    //
    
    if ((self.state & CREATE_TWINCODE) == 0) {
        self.state |= CREATE_TWINCODE;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

        NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributeMetaPair:twincodeFactoryAttributes];
        
        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.name];
        
        if (self.profileDescription) {
            [TLTwinmeAttributes setTwincodeAttributeDescription:twincodeOutboundAttributes description:self.profileDescription];
        }
        if (self.capabilities) {
            [TLTwinmeAttributes setTwincodeAttributeCapabilities:twincodeOutboundAttributes capabilities:self.capabilities];
        }
        if (self.avatarId) {
            [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.avatarId];
        }
        DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, nil, twincodeOutboundAttributes, nil);
        [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLProfile SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
            [self onCreateTwincodeFactory:twincodeFactory errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_TWINCODE_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: create the profile.
    //
    
    if ((self.state & CREATE_OBJECT) == 0) {
        self.state |= CREATE_OBJECT;
        
        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLProfile FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLProfile *profile = (TLProfile *)object;
            [profile setTwincodeFactory:self.twincodeFactory];
            [profile setSpace:self.space];
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateObject:errorCode object:object];
        }];
        return;
    }
    if ((self.state & CREATE_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Step 4: associate the profile with the space.
    //
    if (self.space) {
    
        if ((self.state & UPDATE_SPACE) == 0) {
            self.state |= UPDATE_SPACE;
        
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.profile, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);

            int64_t requestId = [self newOperation:UPDATE_SPACE];
            DDLogVerbose(@"%@ updateSpaceWithRequestId: %lld space: %@ profile: %@", LOG_TAG, requestId, self.space, self.profile);
            [self.twinmeContext updateSpaceWithRequestId:requestId space:self.space profile:self.profile];
            return;
        }
        if ((self.state & UPDATE_SPACE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.profile, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);

    [self.twinmeContext onCreateProfileWithRequestId:self.requestId profile:self.profile];
    
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

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateTwincodeFactory: %@", LOG_TAG, twincodeFactory);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactory == nil) {
        
        [self onErrorWithOperationId:CREATE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_TWINCODE_DONE;
    
    self.twincodeFactory = twincodeFactory;
    [self onOperation];
}

- (void)onCreateObject:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onCreateObject: %d object: %@", LOG_TAG, errorCode, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:CREATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_OBJECT_DONE;
    
    self.profile = (TLProfile *)object;
    [self onOperation];
}

- (void)onUpdateSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpace: %@", LOG_TAG, space);
    
    self.state |= UPDATE_SPACE_DONE;
    [self onOperation];
}

@end

