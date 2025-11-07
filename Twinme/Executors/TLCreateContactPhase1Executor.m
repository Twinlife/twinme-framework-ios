/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLCreateContactPhase1Executor.h"
#import "TLDeleteContactExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLPairProtocol.h"
#import "TLProfile.h"
#import "TLContact.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.19
//

static const int CHECK_TWINCODE = 1 << 0;
static const int CHECK_TWINCODE_DONE = 1 << 1;
static const int COPY_IMAGE = 1 << 2;
static const int COPY_IMAGE_DONE = 1 << 3;
static const int CREATE_OBJECT = 1 << 4;
static const int CREATE_OBJECT_DONE = 1 << 5;
static const int CREATE_TWINCODE = 1 << 6;
static const int CREATE_TWINCODE_DONE = 1 << 7;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 8;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 9;

//
// Interface: TLCreateContactPhase1Executor ()
//

@interface TLCreateContactPhase1Executor ()

@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, readonly, nonnull) NSString *identityName;
@property (nonatomic, readonly, nonnull) TLImageId *identityAvatarId;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *identityTwincodeOutbound;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *identityTwincodeInbound;

@property (nonatomic, nullable) TLExportedImageId *copiedIdentityAvatarId;
@property (nonatomic, nullable) TLTwincodeFactory *twincodeFactory;
@property (nonatomic, nullable) TLContact *contact;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateObject:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLCreateContactPhase1Executor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateContactPhase1Executor"

@implementation TLCreateContactPhase1Executor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound space:(nonnull TLSpace *)space profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld peerTwincodeOutbound:%@ space:%@ profile:%@", LOG_TAG, twinmeContext, requestId, peerTwincodeOutbound, space, profile);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _peerTwincodeOutbound = peerTwincodeOutbound;
        _identityName = profile.name;
        _identityAvatarId = profile.avatarId;
        _identityTwincodeOutbound = profile.twincodeOutbound;
        _identityTwincodeInbound = profile.twincodeInbound;
        _space = space;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, profile, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);
    }
    return self;
}

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound space:(nonnull TLSpace *)space identityName:(nonnull NSString *)identityName identityAvatarId:(nonnull TLImageId *)identityAvatarId {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld peerTwincodeOutbound:%@ identityName:%@ identityAvatarId:%@", LOG_TAG, twinmeContext, requestId, peerTwincodeOutbound, identityName, identityAvatarId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _peerTwincodeOutbound = peerTwincodeOutbound;
        _identityName = identityName;
        _identityAvatarId = identityAvatarId;
        _identityTwincodeInbound = nil;
        _space = space;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CHECK_TWINCODE) != 0 && (self.state & CHECK_TWINCODE_DONE) == 0) {
            self.state &= ~CHECK_TWINCODE;
        }
        if ((self.state & COPY_IMAGE) != 0 && (self.state & COPY_IMAGE_DONE) == 0) {
            self.state &= ~COPY_IMAGE;
        }
        if ((self.state & CREATE_TWINCODE) != 0 && (self.state & CREATE_TWINCODE_DONE) == 0) {
            self.state &= ~CREATE_TWINCODE;
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
    // Step 0: verify that the peer twincode is not one of our profile twincode, raises the BAD_REQUEST error if this occurs.
    // At the same time, verify that our identity twincode has a public/private key.
    // By updating the attributes, the TwincodeOutboundService will create the public/private key and sign the attributes.
    //
    if ((self.state & CHECK_TWINCODE) == 0) {
        self.state |= CHECK_TWINCODE;
        
        if ([self.twinmeContext isProfileTwincode:self.peerTwincodeOutbound.uuid]) {
            [self onErrorWithOperationId:CHECK_TWINCODE errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:[self.peerTwincodeOutbound.uuid UUIDString]];
            return;
        }
        
        if (![self.identityTwincodeOutbound isTrusted] && self.identityTwincodeInbound) {
            [[self.twinmeContext getTwincodeOutboundService] createPrivateKeyWithTwincode:self.identityTwincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onUpdateProfile:errorCode twincodeOutbound:twincodeOutbound];
            }];
            return;
        } else {
            self.state |= CHECK_TWINCODE_DONE;
        }
    }
    if ((self.state & CHECK_TWINCODE_DONE) == 0) {
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
    // Step 1: create the private identity twincode.
    //
    
    if ((self.state & CREATE_TWINCODE) == 0) {
        self.state |= CREATE_TWINCODE;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.identityName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);

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
        
        DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, nil,
                     twincodeOutboundAttributes, nil);
        [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:nil outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLContact SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
            [self onCreateTwincodeFactory:twincodeFactory errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & CREATE_TWINCODE_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: create the Contact object.
    //
    
    if ((self.state & CREATE_OBJECT) == 0) {
        self.state |= CREATE_OBJECT;
        
        NSString *peerTwincodeName = [self.peerTwincodeOutbound name];
        if (!peerTwincodeName) {
            [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint INVALID_TWINCODE], [TLAssertValue initWithTwincodeOutbound:self.peerTwincodeOutbound], nil];
            
            peerTwincodeName = NSLocalizedString(@"anonymous", nil);
        }
        
        [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLContact FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
            TLContact *contact = (TLContact *)object;
            contact.space = self.space;
            contact.name = peerTwincodeName;
            [contact setPublicPeerTwincodeOutbound:self.peerTwincodeOutbound];
            [contact setTwincodeFactory:self.twincodeFactory];
        } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onCreateObject:errorCode object:object];
        }];
        return;
    }
    if ((self.state & CREATE_OBJECT_DONE) == 0) {
        return;
    }
    
    //
    // Step 4: invoke the peer twincode to create the contact on the other side (CreateContactPhase2 on the peer device).
    //
    
    if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
        self.state |= INVOKE_TWINCODE_OUTBOUND;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeFactory, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);

        NSMutableArray *attributes = [NSMutableArray array];
        [TLPairProtocol setInvokeTwincodeActionPairInviteAttributeTwincodeId:attributes twincodeId:self.twincodeFactory.twincodeOutbound.uuid];
        DDLogVerbose(@"%@ invokeTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.peerTwincodeOutbound, attributes);

        if ([self.peerTwincodeOutbound isSigned]) {
            [[self.twinmeContext getTwincodeOutboundService] secureInvokeTwincodeWithTwincode:self.twincodeFactory.twincodeOutbound senderTwincode:self.twincodeFactory.twincodeOutbound receiverTwincode:self.peerTwincodeOutbound options:(TLInvokeTwincodeUrgent | TLInvokeTwincodeCreateSecret) action:[TLPairProtocol ACTION_PAIR_INVITE] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
        } else {
            [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeUrgent action:[TLPairProtocol ACTION_PAIR_INVITE] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
        }
        return;
    }
    if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
        return;
    }
    
    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:6], nil);
    if (!self.contact.checkInvariants) {
        [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint CONTACT_INVARIANT], [TLAssertValue initWithSubject:self.contact], nil];
    }
    
    [self.twinmeContext onCreateContactWithRequestId:self.requestId contact:self.contact];
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

- (void)onUpdateProfile:(TLBaseServiceErrorCode)errorCode twincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ onUpdateProfile: %d twincodeOutbound: %@", LOG_TAG, errorCode, twincodeOutbound);

    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        [self onErrorWithOperationId:CHECK_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CHECK_TWINCODE_DONE;
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

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onInvokeTwincode: %@", LOG_TAG, invocationId);

    if (errorCode != TLBaseServiceErrorCodeSuccess || invocationId == nil) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
    [self onOperation];
}

- (void)onCreateObject:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onCreateObject: %d object: %@", LOG_TAG, errorCode, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:CREATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_OBJECT_DONE;
    self.contact = (TLContact *)object;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    
    if (operationId == INVOKE_TWINCODE_OUTBOUND || operationId == CREATE_OBJECT) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {

            // The peer twincode is invalid, delete the contact without waiting (do not timeout on this delete).
            TLDeleteContactExecutor *deleteContactExecutor = [[TLDeleteContactExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:[self.twinmeContext newRequestId] contact:self.contact invocationId:nil timeout:0];
            [deleteContactExecutor start];

            // And return the ITEM_NOT_FOUND error: there is nothing we can do.
        }
    }
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
