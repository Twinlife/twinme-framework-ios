/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLUpdateContactAndIdentityExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLPairProtocol.h"
#import "TLSpace.h"
#import "TLContact.h"
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
// version: 1.18
//

static const int CREATE_IMAGE = 1 << 0;
static const int CREATE_IMAGE_DONE = 1 << 1;
static const int COPY_IMAGE = 1 << 2;
static const int COPY_IMAGE_DONE = 1 << 3;
static const int UPDATE_OBJECT = 1 << 4;
static const int UPDATE_OBJECT_DONE = 1 << 5;
static const int UPDATE_TWINCODE_OUTBOUND = 1 << 6;
static const int UPDATE_TWINCODE_OUTBOUND_DONE = 1 << 7;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 8;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 9;
static const int DELETE_OLD_IMAGE = 1 << 10;
static const int DELETE_OLD_IMAGE_DONE = 1 << 11;

//
// Interface: TLUpdateContactAndIdentityExecutor ()
//

@interface TLUpdateContactAndIdentityExecutor ()

@property (nonatomic, readonly, nonnull) TLContact *contact;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nonnull) TLSpace *oldSpace;
@property (nonatomic, readonly, nonnull) NSString *contactName;
@property (nonatomic, readonly, nullable) NSString *identityName;
@property (nonatomic, readonly, nullable) UIImage *identityAvatar;
@property (nonatomic, readonly, nullable) UIImage *identityLargeAvatar;
@property (nonatomic, readonly) BOOL createImage;
@property (nonatomic, readonly, nullable) NSString *contactDescription;
@property (nonatomic, readonly, nullable) NSString *identityCapabilities;

@property (nonatomic, readonly) BOOL updatePrivateIdentity;
@property (nonatomic) BOOL updateContact;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) TLExportedImageId *identityAvatarId;
@property (nonatomic, nullable) TLImageId *oldIdentityAvatarId;
@property (nonatomic, nullable) TLImageId *identityToCopyAvatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLUpdateContactAndIdentityExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateContactAndIdentityExecutor"

@implementation TLUpdateContactAndIdentityExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact contactName:(nonnull NSString *)contactName description:(nullable NSString *)description {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld contact: %@ contactName:%@ description: %@", LOG_TAG, twinmeContext, requestId, contact, contactName, description);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _contact = contact;
        _contactName = contactName;
        _identityName = nil;
        _identityAvatar = nil;
        _identityLargeAvatar = nil;
        _identityAvatarId = nil;
        _identityToCopyAvatarId = nil;
        _contactDescription = description;
        _oldIdentityAvatarId = contact.identityAvatarId;
        _space = contact.space;
        _oldSpace = _space;
        _peerTwincodeOutbound = contact.peerTwincodeOutbound;
        _twincodeOutbound = contact.twincodeOutbound;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _contactName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        _createImage = NO;
        _updatePrivateIdentity = NO;
        _updateContact = ![_contact.name isEqualToString:_contactName] || ![_contactDescription isEqualToString:contact.objectDescription];

        // Contact identity is not modified, we can start immediately.
        self.needOnline = NO;
    }
    return self;
}

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact identityName:(nonnull NSString *)identityName identityAvatar:(nonnull UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld contact: %@ contactAvatar: %@ identityName:%@ identityAvatar:%@ description: %@ capabilities: %@", LOG_TAG, twinmeContext, requestId, contact, identityName, identityAvatar, identityLargeAvatar, description, capabilities);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _contact = contact;
        _contactName = contact.name;
        _identityName = identityName;
        _identityAvatar = identityAvatar;
        _identityLargeAvatar = identityLargeAvatar;
        _identityAvatarId = nil;
        _contactDescription = description;
        _identityCapabilities = [capabilities attributeValue];
        _oldIdentityAvatarId = contact.identityAvatarId;
        _identityToCopyAvatarId = nil;
        _space = contact.space;
        _oldSpace = _space;
        _peerTwincodeOutbound = contact.peerTwincodeOutbound;
        _twincodeOutbound = contact.twincodeOutbound;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _contactName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);

        _createImage = identityLargeAvatar != nil;

        BOOL updateDescription = ![_contactDescription isEqualToString:contact.identityDescription];
        BOOL updateCapabilities = ![_identityCapabilities isEqualToString:[[contact identityCapabilities] attributeValue]];
        BOOL updateName = ![_identityName isEqualToString:contact.identityName];
        _updatePrivateIdentity = updateName || updateDescription || updateCapabilities || _createImage;
        _updateContact = NO;
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld contact: %@ space:%@", LOG_TAG, twinmeContext, requestId, contact, space);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _contact = contact;
        _oldSpace = contact.space;
        _space = space;
        contact.space = space;
        _contactName = contact.name;
        _identityName = contact.identityName;
        _contactDescription = contact.objectDescription;
        _identityAvatar = nil;
        _identityLargeAvatar = nil;
        _oldIdentityAvatarId = nil;
        _identityToCopyAvatarId = nil;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _contactName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:6], nil);

        _updatePrivateIdentity = NO;
        _updateContact = YES;
        _createImage = NO;

        // We are moving contact to another space, we can start immediately.
        self.needOnline = NO;
    }
    return self;
}

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact identityName:(nullable NSString *)identityName identityAvatarId:(nullable TLImageId *)identityAvatarId identityDescription:(nullable NSString *)identityDescription capabilities:(nullable TLCapabilities*)capabilities timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld contact: %@ identityName:%@ identityAvatarId:%@ identityDescription: %@ capabilities: %@", LOG_TAG, twinmeContext, requestId, contact, identityName, identityAvatarId, identityDescription, capabilities);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:timeout];
    
    if (self) {

        _contact = contact;
        _contactName = contact.name;
        _identityName = identityName;
        _identityAvatar = nil;
        _identityLargeAvatar = nil;
        _identityAvatarId = nil;
        _identityToCopyAvatarId = identityAvatarId;
        _contactDescription = identityDescription;
        _identityCapabilities = [capabilities attributeValue];
        _oldIdentityAvatarId = contact.identityAvatarId;
        _space = contact.space;
        _oldSpace = _space;
        _peerTwincodeOutbound = contact.peerTwincodeOutbound;
        _twincodeOutbound = contact.twincodeOutbound;

        BOOL updateDescription = identityDescription && ![identityDescription isEqualToString:contact.identityDescription];
        BOOL updateCapabilities = ![_identityCapabilities isEqualToString:[[contact identityCapabilities] attributeValue]];
        BOOL updateName = identityName && ![identityName isEqualToString:contact.identityName];
        _updatePrivateIdentity = updateName || updateDescription || updateCapabilities || _identityToCopyAvatarId != nil;
        _updateContact = NO;
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
        if ((self.state & COPY_IMAGE) != 0 && (self.state & COPY_IMAGE_DONE) == 0) {
            self.state &= ~COPY_IMAGE;
        }
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) != 0 && (self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~UPDATE_TWINCODE_OUTBOUND;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) != 0 && (self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~INVOKE_TWINCODE_OUTBOUND;
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
    if (self.identityAvatar && self.createImage) {
        
        if ((self.state & CREATE_IMAGE) == 0) {
            self.state |= CREATE_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService createImageWithImage:self.identityLargeAvatar thumbnail:self.identityAvatar withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 1: a new image must be setup, create it.
    //
    if (self.identityToCopyAvatarId) {
        
        if ((self.state & COPY_IMAGE) == 0) {
            self.state |= COPY_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService copyImageWithImageId:self.identityToCopyAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCopyImage:imageId errorCode:errorCode];
                [self onOperation];
            }];
            return;
        }
        if ((self.state & COPY_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: update the contact object when the space or contact's name is modified.
    //
    
    if (self.updateContact) {
        
        if ((self.state & UPDATE_OBJECT) == 0) {
            self.state |= UPDATE_OBJECT;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:7], nil);
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.contactName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:8], nil);

            //AvatarId?
            self.contact.name = self.contactName;
            self.contact.objectDescription = self.contactDescription;
            
            DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.contact);
            [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.contact localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
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
    
    if (self.updatePrivateIdentity) {
        
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_TWINCODE_OUTBOUND;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:9], nil);

            NSMutableArray *attributes = [NSMutableArray array];
            if (self.identityName && ![self.identityName isEqualToString:self.contact.identityName]) {
                [TLTwinmeAttributes setTwincodeAttributeName:attributes name:self.identityName];
            }
            if (self.identityAvatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:attributes imageId:self.identityAvatarId];
            }
            if (self.contactDescription && ![self.contactDescription isEqualToString:self.contact.identityDescription]) {
                [TLTwinmeAttributes setTwincodeAttributeDescription:attributes description:self.contactDescription];
            }
            if (self.identityCapabilities && ![self.identityCapabilities isEqualToString:[self.contact.identityCapabilities attributeValue]]) {
                [TLTwinmeAttributes setTwincodeAttributeCapabilities:attributes capabilities:self.identityCapabilities];
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
        
        if (self.peerTwincodeOutbound != nil) {

            if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
                self.state |= INVOKE_TWINCODE_OUTBOUND;
                
                DDLogVerbose(@"%@ invokeTwincodeWithTwincodeId: %@", LOG_TAG, self.peerTwincodeOutbound);
                [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeWakeup action:[TLPairProtocol ACTION_PAIR_REFRESH] attributes:nil withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                    [self onInvokeTwincode:invocationId errorCode:errorCode];
                }];
                return;
            }
            if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
                return;
            }
        }
    }
    
    //
    // Step 4: delete the old avatar image..
    //
    if (self.oldIdentityAvatarId && (self.createImage || self.identityToCopyAvatarId)) {
        
        if ((self.state & DELETE_OLD_IMAGE) == 0) {
            self.state |= DELETE_OLD_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.oldIdentityAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
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
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:10], nil);
    if (![self.contact checkInvariants]) {
        [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint CONTACT_INVARIANT], [TLAssertValue initWithSubject:self.contact],  nil];
    }
    
    if (self.space != self.oldSpace) {
        [self.twinmeContext onMoveToSpaceWithRequestId:self.requestId contact:self.contact oldSpace:self.oldSpace];
    } else {
        [self.twinmeContext onUpdateContactWithRequestId:self.requestId contact:self.contact];
    }
    [self stop];
}

- (void)onCreateImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_IMAGE_DONE;
    
    self.identityAvatarId = imageId;
    [self onOperation];
}

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_TWINCODE_OUTBOUND_DONE;
    
    self.contact.twincodeOutbound = twincodeOutbound;
    [self onOperation];
}

- (void)onCopyImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCopyImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:COPY_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= COPY_IMAGE_DONE;
    self.identityAvatarId = imageId;
}

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onInvokeTwincode: %@", LOG_TAG, invocationId);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || invocationId == nil) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
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

- (void)onDeleteImage:(nullable TLImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    // Ignore the error and proceed!!!
    self.state |= DELETE_OLD_IMAGE_DONE;
    [self onOperation];
}

@end
