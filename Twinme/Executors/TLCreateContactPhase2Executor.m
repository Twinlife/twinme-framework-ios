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
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLFilter.h>

#import "TLCreateContactPhase2Executor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLProfile.h"
#import "TLContact.h"
#import "TLInvitation.h"
#import "TLPairProtocol.h"
#import "TLPairInviteInvocation.h"
#import "TLNotificationCenter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//

static const int FIND_CONTACT = 1 << 2;
static const int FIND_CONTACT_DONE = 1 << 3;
static const int COPY_IMAGE = 1 << 4;
static const int COPY_IMAGE_DONE = 1 << 5;
static const int CREATE_TWINCODE = 1 << 6;
static const int CREATE_TWINCODE_DONE = 1 << 7;
static const int CREATE_CONTACT_OBJECT = 1 << 10;
static const int CREATE_CONTACT_OBJECT_DONE = 1 << 11;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 12;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 13;
static const int DELETE_INVITATION = 1 << 14;
static const int DELETE_INVITATION_DONE = 1 << 15;
static const int GET_PEER_IMAGE = 1 << 16;
static const int GET_PEER_IMAGE_DONE = 1 << 17;

//
// Interface: TLCreateContactPhase2Executor ()
//

@interface TLCreateContactPhase2Executor ()

@property (nonatomic, readonly, nonnull) NSUUID *invocationId;
@property (nonatomic, readonly, nonnull) NSString *identityName;
@property (nonatomic, readonly, nonnull) TLImageId *identityAvatarId;
@property (nonatomic, readonly, nullable) TLInvitation *invitation;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *peerTwincodeOutbound;

@property (nonatomic, nullable) TLExportedImageId *copiedIdentityAvatarId;
@property (nonatomic, nullable) TLTwincodeFactory *twincodeFactory;
@property (nonatomic, nullable) TLTwincodeOutbound *identityTwincodeOutbound;
@property (nonatomic, nullable) TLContact *contact;
@property (nonatomic) BOOL unbindContact;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onCreateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(nonnull NSUUID *)invitationId;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)stop;

@end

//
// Implementation: TLCreateContactPhase2Executor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateContactPhase2Executor"

@implementation TLCreateContactPhase2Executor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairInviteInvocation *)invocation space:(nonnull TLSpace *)space profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ invocation:%@ profile: %@", LOG_TAG, twinmeContext, invocation, profile);

    self = [super initWithTwinmeContext:twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID]];
    
    if (self) {
        _invocationId = invocation.uuid;
        _peerTwincodeOutbound = invocation.twincodeOutbound;
        _space = space;
        _identityName = profile.name;
        _identityAvatarId = profile.avatarId;
        _identityTwincodeOutbound = profile.twincodeOutbound;
        _unbindContact = NO;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _invocationId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);
    }
    return self;
}

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invocation:(nonnull TLPairInviteInvocation *)invocation invitation:(nonnull TLInvitation *)invitation {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ invocation:%@ invitation: %@", LOG_TAG, twinmeContext, invocation, invitation);

    self = [super initWithTwinmeContext:twinmeContext requestId:[TLBaseService DEFAULT_REQUEST_ID]];

    if (self) {
        _invocationId = invocation.uuid;
        _invitation = invitation;
        _space = invitation.space;
        _identityName = invitation.name;
        _identityAvatarId = invitation.avatarId;
        _identityTwincodeOutbound = invitation.twincodeOutbound;
        _peerTwincodeOutbound = invocation.twincodeOutbound;
        _unbindContact = NO;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _invocationId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    if (self.stopped) {
        [self.twinmeContext fireOnErrorWithRequestId:self.requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        
        [self stop];
    } else {
        [super start];
    }
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & COPY_IMAGE) != 0 && (self.state & COPY_IMAGE_DONE) == 0) {
            self.state &= ~COPY_IMAGE;
        }
        if ((self.state & CREATE_TWINCODE) != 0 && (self.state & CREATE_TWINCODE_DONE) == 0) {
            self.state &= ~CREATE_TWINCODE;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) != 0 && (self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~INVOKE_TWINCODE_OUTBOUND;
        }
        if ((self.state & GET_PEER_IMAGE) != 0 && (self.state & GET_PEER_IMAGE_DONE) == 0) {
            self.state &= ~GET_PEER_IMAGE;
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
    // Step 2: check if a contact has not been created previously with the same peerTwincodeOutboundId
    //
    if ((self.state & FIND_CONTACT) == 0) {
        self.state |= FIND_CONTACT;
        
        TLFilter *filter = [TLFilter alloc];
        filter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
            TLContact *contact = (TLContact *)object;

            return [self.peerTwincodeOutbound.uuid isEqual:contact.peerTwincodeOutboundId];
        };

        DDLogVerbose(@"%@ findContactsWithFilter: %@ contact.peerTwincodeOutbound: %@", LOG_TAG, filter, self.peerTwincodeOutbound);
        [self.twinmeContext findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *contacts) {
            if (contacts && contacts.count > 0) {
                //
                // A contact with the same peerTwincodeOutboundId has been created in a previous call to CreateContactPhase2Executor
                //  that has been stopped prematurely, reuse it in order to avoid to have two different contacts bounded to the same peer
                //  contact
                //
                self.contact = contacts[0];
                self.contact.space = self.space;
            }
            
            self.state |= FIND_CONTACT_DONE;
            [self onOperation];
        }];
        return;
    }
    
    if ((self.state & FIND_CONTACT_DONE) == 0) {
        return;
    }
    
    if (!self.contact) {
        //
        // Step 3: create a copy of the identity image if there is one (privacy constraint).
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
        // Step 4: create the private identity twincode.
        //
        
        if ((self.state & CREATE_TWINCODE) == 0) {
            self.state |= CREATE_TWINCODE;

            TL_ASSERT_NOT_NULL(self.twinmeContext, self.peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.identityName, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:6], nil);

            NSMutableArray *twincodeFactoryAttributes = [[NSMutableArray alloc] init];
            [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];
            
            NSMutableArray *twincodeInboundAttributes = [[NSMutableArray alloc] init];
            [TLPairProtocol setTwincodeAttributePairTwincodeId:twincodeInboundAttributes twincodeId:self.peerTwincodeOutbound.uuid];
            
            NSMutableArray *twincodeOutboundAttributes = [[NSMutableArray alloc] init];
            [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.identityName];
            
            if (self.copiedIdentityAvatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.copiedIdentityAvatarId];
            }
            
            // Copy a number of twincode attributes from the profile identity.
            if (self.identityTwincodeOutbound) {
                [self.twinmeContext copySharedTwincodeAttributesWithTwincode:self.identityTwincodeOutbound attributes:twincodeOutboundAttributes];
            }

            DDLogVerbose(@"%@ createTwincodeWithFactoryAttributes: %@ twincodeInboundAttributes: %@ twincodeOutboundAttributes: %@ twincodeSwitchAttributes: %@", LOG_TAG, twincodeFactoryAttributes, twincodeInboundAttributes, twincodeOutboundAttributes, nil);
            [[self.twinmeContext getTwincodeFactoryService] createTwincodeWithFactoryAttributes:twincodeFactoryAttributes inboundAttributes:twincodeInboundAttributes outboundAttributes:twincodeOutboundAttributes switchAttributes:nil twincodeSchemaId:[TLContact SCHEMA_ID] withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *twincodeFactory) {
                [self onCreateTwincodeFactory:twincodeFactory errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_TWINCODE_DONE) == 0) {
            return;
        }

        //
        // Step 6: create the contact object.
        //
        
        if ((self.state & CREATE_CONTACT_OBJECT) == 0) {
            self.state |= CREATE_CONTACT_OBJECT;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:7], nil);
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeFactory, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:8], nil);

            NSString *peerTwincodeName = [self.peerTwincodeOutbound name];
            if (!peerTwincodeName) {
                [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint INVALID_TWINCODE], [TLAssertValue initWithTwincodeOutbound:self.peerTwincodeOutbound], nil];
                
                peerTwincodeName = NSLocalizedString(@"anonymous", nil);
            }
            
            [[self.twinmeContext getRepositoryService] createObjectWithFactory:[TLContact FACTORY] accessRights:TLRepositoryServiceAccessRightsPrivate withInitializer:^(id<TLRepositoryObject> object) {
                TLContact *contact = (TLContact *)object;
                contact.space = self.space;
                contact.name = peerTwincodeName;
                contact.peerTwincodeOutbound = self.peerTwincodeOutbound;
                [contact setTwincodeFactory:self.twincodeFactory];
            } withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
                [self onCreateObject:object errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_CONTACT_OBJECT_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 7: invoke the peer twincode to send our private identity twincode.
    //
    
    if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
        self.state |= INVOKE_TWINCODE_OUTBOUND;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact.twincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:9], nil);
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.peerTwincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:10], nil);

        NSMutableArray *attributes = [NSMutableArray array];
        [TLPairProtocol setInvokeTwincodeActionPairInviteAttributeTwincodeId:attributes twincodeId:self.contact.twincodeOutbound.uuid];
        DDLogVerbose(@"%@ invokeTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.peerTwincodeOutbound, attributes);
        
        if ([self.peerTwincodeOutbound isSigned]) {
            // The cipher twincode must be our public identity because we must authenticate and encrypt with a public
            // key that is trusted by the receiver (that public key is trusted in the process by CreateContactPhase1).
            // But, we must send information about our contact twincode to give our public key.
            [[self.twinmeContext getTwincodeOutboundService] secureInvokeTwincodeWithTwincode:self.identityTwincodeOutbound senderTwincode:self.twincodeFactory.twincodeOutbound receiverTwincode:self.peerTwincodeOutbound options:(TLInvokeTwincodeUrgent | TLInvokeTwincodeCreateSecret) action:[TLPairProtocol ACTION_PAIR_BIND] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
        } else {
            [[self.twinmeContext getTwincodeOutboundService] invokeTwincodeWithTwincode:self.peerTwincodeOutbound options:TLInvokeTwincodeUrgent action:[TLPairProtocol ACTION_PAIR_BIND] attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
        }
        return;
    }
    if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
        return;
    }
    
    //
    // Step 8: delete the invitation object because we don't need it anymore.
    //
    
    if (self.invitation) {
        if ((self.state & DELETE_INVITATION) == 0) {
            self.state |= DELETE_INVITATION;
            
            int64_t requestId = [self newOperation:DELETE_INVITATION];
            DDLogVerbose(@"%@ deleteInvitationWithRequestId: %lld invitation: %@", LOG_TAG, requestId, self.invitation);
            
            [self.twinmeContext deleteInvitationWithRequestId:requestId invitation:self.invitation];
            return;
        }
        if ((self.state & DELETE_INVITATION_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 9: get the peer thumbnail image so that we have it in our local cache before displaying the notification.
    //
    
    if (self.contact && self.contact.avatarId && !self.unbindContact) {
        if ((self.state & GET_PEER_IMAGE) == 0) {
            self.state |= GET_PEER_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.contact.avatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_PEER_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_PEER_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.contact, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:11], nil);
    if (!self.contact.checkInvariants) {
        [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint CONTACT_INVARIANT], [TLAssertValue initWithSubject:self.contact], [TLAssertValue initWithInvocationId:self.invocationId], nil];
    }

    if (self.unbindContact) {
        [self.twinmeContext unbindContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] invocationId:nil contact:self.contact];
    } else {
        // Post a notification for the new contact (contactPhase2 received asynchronously).
        if ([self.twinmeContext isVisible:self.contact]) {
            [self.twinmeContext.notificationCenter onNewContactWithContact:self.contact];
        }
        [self.twinmeContext onCreateContactWithRequestId:self.requestId contact:self.contact];
    }
    
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

- (void)onCreateObject:(id <TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || object == nil) {
        
        [self onErrorWithOperationId:CREATE_CONTACT_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_CONTACT_OBJECT_DONE;
    self.contact = (TLContact *)object;
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

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(nonnull NSUUID *)invitationId {
    DDLogVerbose(@"%@ onDeleteInvitationWithRequestId:: %lld invitationId: %@", LOG_TAG, requestId, invitationId);

    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        self.state |= DELETE_INVITATION_DONE;
        [self onOperation];
    }
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (operationId == INVOKE_TWINCODE_OUTBOUND) {
        if (errorCode == TLBaseServiceErrorCodeItemNotFound || errorCode == TLBaseServiceErrorCodeNoPrivateKey || errorCode == TLBaseServiceErrorCodeInvalidPublicKey || errorCode == TLBaseServiceErrorCodeInvalidPrivateKey) {
            self.state |= INVOKE_TWINCODE_OUTBOUND_DONE;
            self.unbindContact = YES;
            [self onOperation];
            return;
        }

    } else if (operationId == DELETE_INVITATION && errorCode == TLBaseServiceErrorCodeItemNotFound) {
        self.state |= DELETE_INVITATION_DONE;
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];

    [super stop];
}

@end
