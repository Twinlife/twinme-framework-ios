/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLProfile.h"
#import "TLSpace.h"
#import "TLPairProtocol.h"
#import "TLCapabilities.h"
#import "TLCreateCallReceiverExecutor.h"
#import "TLCallReceiver.h"

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
static const int CREATE_TWINCODE = 1 << 2;
static const int CREATE_TWINCODE_DONE = 1 << 3;
static const int CREATE_OBJECT = 1 << 6;
static const int CREATE_OBJECT_DONE = 1 << 7;

//
// Interface: TLCreateCallReceiverExecutor ()
//

@interface TLCreateCallReceiverExecutor ()

@property(nonatomic, readonly, nonnull) NSString *name;
@property(nonatomic, readonly, nullable) NSString *callReceiverDescription;
@property(nonatomic, readonly, nonnull) NSString *identityName;
@property(nonatomic, readonly, nullable) NSString *identityDescription;
@property(nonatomic, readonly, nullable) UIImage *avatar;
@property(nonatomic, readonly, nullable) UIImage *largeAvatar;
@property(nonatomic, readonly, nullable) TLSpace *space;
@property(nonatomic, readonly, nullable) NSString *capabilities;

@property(nonatomic, nullable) TLCallReceiver *callReceiver;
@property(nonatomic, nullable) TLTwincodeFactory *twincodeFactory;
@property(nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property(nonatomic, nullable) NSUUID *twincodeOutboundId;
@property(nonatomic, nullable) TLImageId *profileAvatarId;
@property(nonatomic, nullable) TLExportedImageId *copiedAvatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLCreateCallReceiverExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateCallReceiverExecutor"

@implementation TLCreateCallReceiverExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nullable NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities *)capabilities space:(nullable TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld name: %@ avatar: %@ callReceiverDescription: %@ capabilities: %@ space:%@", LOG_TAG, twinmeContext, requestId, name, avatar, description, capabilities, space);

    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _name = name;

        TL_ASSERT_NOT_NULL(twinmeContext, space, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _name, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        TLProfile *profile = space.profile;

        _callReceiverDescription = description;

        if (identityName) {
            _identityName = identityName;
        } else {
            _identityName = profile.name;
        }

        if (identityDescription) {
            _identityDescription = identityDescription;
        } else {
            _identityDescription = profile.objectDescription;
        }

        if (avatar) {
            _profileAvatarId = nil;
            _avatar = avatar;
            _largeAvatar = largeAvatar;
        } else {
            _profileAvatarId = profile.avatarId;
            _avatar = nil;
            _largeAvatar = nil;
        }

        _space = space;
        
        TLCapabilities *caps;
        
        if (capabilities && [capabilities attributeValue]){
            caps = [[TLCapabilities alloc] initWithCapabilities:[capabilities attributeValue]];
            [caps setKindWithValue:TLTwincodeKindCallReceiver];
        } else {
            caps = [[TLCapabilities alloc] initWithTwincodeKind:TLTwincodeKindCallReceiver admin:false];
        }
        
        _capabilities = [caps attributeValue];
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
        if ((self.state & CREATE_TWINCODE) != 0 && (self.state & CREATE_TWINCODE_DONE) == 0) {
            self.state &= ~CREATE_TWINCODE;
        }
        if ((self.state & CREATE_OBJECT) != 0 && (self.state & CREATE_OBJECT_DONE) == 0) {
            self.state &= ~CREATE_OBJECT;
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
    // Step 1: create the image id (or copy the profile's avatar if no custom avatar is defined)
    //

    if ((self.state & CREATE_IMAGE) == 0) {
        self.state |= CREATE_IMAGE;

        TLImageService *imageService = [self.twinmeContext getImageService];

        void (^consumer)(TLBaseServiceErrorCode, TLExportedImageId *) =  ^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
            [self onCreateImage:imageId errorCode:errorCode];
        };

        if (_avatar) {
            [imageService createImageWithImage:self.largeAvatar thumbnail:self.avatar withBlock:consumer];
        } else {
            [imageService copyImageWithImageId:self.profileAvatarId withBlock:consumer];
        }

        return;
    }
    if ((self.state & CREATE_IMAGE_DONE) == 0) {
        return;
    }


    //
    // Step 2: create the public callReceiver twincode.
    //

    if ((self.state & CREATE_TWINCODE) == 0) {
        self.state |= CREATE_TWINCODE;

        TL_ASSERT_NOT_NULL(self.twinmeContext, self.identityName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

        NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];

        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.identityName];

        if (self.identityDescription) {
            [TLTwinmeAttributes setTwincodeAttributeDescription:twincodeOutboundAttributes description:self.identityDescription];
        }
        if (self.capabilities) {
            [TLTwinmeAttributes setTwincodeAttributeCapabilities:twincodeOutboundAttributes capabilities:self.capabilities];
        }
        if (self.copiedAvatarId) {
            [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.copiedAvatarId];
        }
        DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, nil, twincodeOutboundAttributes, nil);
        [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLCallReceiver SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
            [self onCreateTwincodeFactory:twincodeFactory errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_TWINCODE_DONE) == 0) {
        return;
    }

    //
    // Step 4: create the callReceiver.
    //

    if ((self.state & CREATE_OBJECT) == 0) {
        self.state |= CREATE_OBJECT;

        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLCallReceiver FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLCallReceiver *callReceiver = (TLCallReceiver *)object;
            callReceiver.name = self.name;
            callReceiver.objectDescription = self.callReceiverDescription;
            callReceiver.space = self.space;
            [callReceiver setTwincodeFactory:self.twincodeFactory];
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Last Step
    //

    TL_ASSERT_NOT_NULL(self.twinmeContext, self.callReceiver, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

    [self.twinmeContext onCreateCallReceiverWithRequestId:self.requestId callReceiver:self.callReceiver];

    [self stop];
}

- (void)onCreateImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_IMAGE_DONE;

    self.copiedAvatarId = imageId;
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

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {

        [self onErrorWithOperationId:CREATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_OBJECT_DONE;
    self.callReceiver = (TLCallReceiver *)object;
    [self onOperation];
}

@end

