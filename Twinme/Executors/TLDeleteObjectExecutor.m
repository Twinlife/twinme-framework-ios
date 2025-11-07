/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLNotificationService.h>
#import <Twinlife/TLConversationService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLDeleteObjectExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLPairProtocol.h"
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
// version: 1.18
//

static const int UNBIND_TWINCODE_INBOUND = 1 << 0;
static const int UNBIND_TWINCODE_INBOUND_DONE = 1 << 1;
static const int DELETE_TWINCODE = 1 << 4;
static const int DELETE_TWINCODE_DONE = 1 << 5;
static const int DELETE_IDENTITY_IMAGE = 1 << 6;
static const int DELETE_IDENTITY_IMAGE_DONE = 1 << 7;
static const int DELETE_OBJECT = 1 << 12;
static const int DELETE_OBJECT_DONE = 1 << 13;

//
// Interface(): TLDeleteObjectExecutor
//

@interface TLDeleteObjectExecutor()

@property (nonatomic, readonly, nonnull) TLTwinmeObject *object;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *twincodeInbound;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property (nonatomic, readonly, nullable) TLImageId *identityAvatarId;
@property (nonatomic, nullable) NSUUID *invocationId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onDeleteTwincode:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteObject:(nullable NSUUID *)objectId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUnbindTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLDeleteObjectExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteObjectExecutor"

@implementation TLDeleteObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId object:(nonnull TLTwinmeObject *)object invocationId:(nullable NSUUID *)invocationId timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld object: %@ invocationId: %@ timeout: %f", LOG_TAG, twinmeContext, requestId, object, invocationId, timeout);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:timeout];
    
    if (self) {
        _object = object;
        _invocationId = invocationId;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _object, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

        _peerTwincodeOutbound = object.peerTwincodeOutbound;
        _twincodeInbound = object.twincodeInbound;
        
        _identityAvatarId = object.identityAvatarId;
    }
    return self;
}

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object {
    DDLogVerbose(@"%@ onFinishDeleteWithObject: %@", LOG_TAG, object);

}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & UNBIND_TWINCODE_INBOUND) != 0 && (self.state & UNBIND_TWINCODE_INBOUND_DONE) == 0) {
            self.state &= ~UNBIND_TWINCODE_INBOUND;
        }
        if ((self.state & DELETE_TWINCODE) != 0 && (self.state & DELETE_TWINCODE_DONE) == 0) {
            self.state &= ~DELETE_TWINCODE;
        }
        if ((self.state & DELETE_IDENTITY_IMAGE) != 0 && (self.state & DELETE_IDENTITY_IMAGE_DONE) == 0) {
            self.state &= ~DELETE_IDENTITY_IMAGE;
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
    // Step 1: unbind the inbound twincode.
    //
    
    if (self.twincodeInbound) {
        
        if ((self.state & UNBIND_TWINCODE_INBOUND) == 0) {
            self.state |= UNBIND_TWINCODE_INBOUND;
            
            DDLogVerbose(@"%@ unbindTwincodeWithTwincode: %@", LOG_TAG, self.twincodeInbound);
            [[self.twinmeContext getTwincodeInboundService] unbindTwincodeWithTwincode:self.twincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *twincodeInbound) {
                [self onUnbindTwincodeInbound:twincodeInbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UNBIND_TWINCODE_INBOUND_DONE) == 0) {
            return;
        }

        //
        // Step 2: delete the twincode.
        //
    
        if (self.twincodeInbound.twincodeFactoryId) {
            
            if ((self.state & DELETE_TWINCODE) == 0) {
                self.state |= DELETE_TWINCODE;
                
                DDLogVerbose(@"%@ deleteTwincodeWithFactoryId: %@", LOG_TAG, self.twincodeInbound.twincodeFactoryId);
                [[self.twinmeContext getTwincodeFactoryService] deleteTwincodeWithFactoryId:self.twincodeInbound.twincodeFactoryId withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *factoryId) {
                    [self onDeleteTwincode:factoryId errorCode:errorCode];
                }];
                return;
            }
            if ((self.state & DELETE_TWINCODE_DONE) == 0) {
                return;
            }
        }
    }
    
    //
    // Step 3: delete the identity avatar image.
    //
    if (self.identityAvatarId) {
        
        if ((self.state & DELETE_IDENTITY_IMAGE) == 0) {
            self.state |= DELETE_IDENTITY_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.identityAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                self.state |= DELETE_IDENTITY_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & DELETE_IDENTITY_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 4: delete the repository object.
    //
    if ((self.state & DELETE_OBJECT) == 0) {
        self.state |= DELETE_OBJECT;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.object, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

        DDLogVerbose(@"%@ deleteObjectWithObject: %@", LOG_TAG, self.object);
        [[self.twinmeContext getRepositoryService] deleteObjectWithObject:self.object withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *objectId) {
            [self onDeleteObject:objectId errorCode:errorCode];
        }];

        //
        // remove the peer twincode and image from the cache.
        //
        if (self.peerTwincodeOutbound) {
            [[self.twinmeContext getTwincodeOutboundService] evictWithTwincode:self.peerTwincodeOutbound];
        }

        return;
    }
    if ((self.state & DELETE_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.object, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

    [self onFinishDeleteWithObject:self.object];
    [self stop];
}

- (void)onDeleteTwincode:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteTwincode: %@", LOG_TAG, twincodeFactoryId);

    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactoryId == nil) {
        
        [self onErrorWithOperationId:DELETE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= DELETE_TWINCODE_DONE;
    [self onOperation];
}

- (void)onUnbindTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUnbindTwincodeInbound: %@", LOG_TAG, twincodeInbound);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeInbound == nil) {
        
        [self onErrorWithOperationId:UNBIND_TWINCODE_INBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UNBIND_TWINCODE_INBOUND_DONE;
    [self onOperation];
}

- (void)onDeleteObject:(nullable NSUUID *)objectId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteObject: %@ errorCode: %d", LOG_TAG, objectId, errorCode);

    self.state |= DELETE_OBJECT_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case UNBIND_TWINCODE_INBOUND:
                self.state |= UNBIND_TWINCODE_INBOUND_DONE;
                [self onOperation];
                return;

            case DELETE_TWINCODE:
                self.state |= DELETE_TWINCODE_DONE;
                [self onOperation];
                return;

            case DELETE_OBJECT:
                self.state |= DELETE_OBJECT_DONE;
                [self onOperation];
                return;
                
            default:
                break;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    if (self.invocationId) {
        [self.twinmeContext acknowledgeInvocationWithInvocationId:self.invocationId errorCode:TLBaseServiceErrorCodeSuccess];
    }

    [super stop];
}

@end

