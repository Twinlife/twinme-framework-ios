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
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLChangeCallReceiverTwincodeExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLCallReceiver.h"
#import "TLPairProtocol.h"

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

static const int CREATE_TWINCODE = 1 << 2;
static const int CREATE_TWINCODE_DONE = 1 << 3;
static const int UPDATE_OBJECT = 1 << 6;
static const int UPDATE_OBJECT_DONE = 1 << 7;
static const int DELETE_TWINCODE = 1 << 8;
static const int DELETE_TWINCODE_DONE = 1 << 9;

//
// Interface: TLChangeCallReceiverTwincodeExecutor ()
//

@interface TLChangeCallReceiverTwincodeExecutor ()

@property (nonatomic, readonly, nonnull) TLCallReceiver *callReceiver;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *oldTwincodeInbound;
@property (nonatomic, nullable) TLImageId *oldAvatarId;
@property (nonatomic, nullable) TLTwincodeOutbound *identityTwincodeOutbound;

@property (nonatomic, nullable) TLExportedImageId *avatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteTwincodeFactory:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLChangeCallReceiverTwincodeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLChangeCallReceiverTwincodeExecutor"

@implementation TLChangeCallReceiverTwincodeExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld callReceiver: %@", LOG_TAG, twinmeContext, requestId, callReceiver);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _callReceiver = callReceiver;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _callReceiver, [TLExecutorAssertPoint PARAMETER], nil);

        if (callReceiver.avatarId) {
            _avatarId = [[twinmeContext getImageService] publicWithImageId:callReceiver.avatarId];
        } else {
            _avatarId = nil;
        }
        _oldTwincodeInbound = callReceiver.twincodeInbound;
        _identityTwincodeOutbound = callReceiver.twincodeOutbound;
        _oldAvatarId = nil;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CREATE_TWINCODE) != 0 && (self.state & CREATE_TWINCODE_DONE) == 0) {
            self.state &= ~CREATE_TWINCODE;
        }
        if ((self.state & DELETE_TWINCODE) != 0 && (self.state & DELETE_TWINCODE_DONE) == 0) {
            self.state &= ~DELETE_TWINCODE;
        }
        if ((self.state & UPDATE_OBJECT) != 0 && (self.state & UPDATE_OBJECT_DONE) == 0)  {
            self.state &= ~UPDATE_OBJECT;
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
    // Step 1: create the public profile twincode.
    //
    
    if ((self.state & CREATE_TWINCODE) == 0) {
        self.state |= CREATE_TWINCODE;

        NSMutableArray *twincodeFactoryAttributes = [NSMutableArray array];
        [TLPairProtocol setTwincodeAttributePair:twincodeFactoryAttributes];
        
        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.callReceiver.identityName];
        
        if (self.avatarId) {
            [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:self.avatarId];
        }

        // Copy a number of twincode attributes from the call receiver identity.
        [self.twinmeContext copySharedTwincodeAttributesWithTwincode:self.callReceiver.twincodeOutbound attributes:twincodeOutboundAttributes];
        

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
    // Step 2: update the profile.
    //
    
    if ((self.state & UPDATE_OBJECT) == 0) {
        self.state |= UPDATE_OBJECT;

        DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.callReceiver);
        [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.callReceiver localOnly:YES withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onUpdateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & UPDATE_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Step 3: delete the twincode.
    //
    if (self.oldTwincodeInbound && self.oldTwincodeInbound.twincodeFactoryId) {
          
        if ((self.state & DELETE_TWINCODE) == 0) {
            self.state |= DELETE_TWINCODE;
              
            DDLogVerbose(@"%@ deleteTwincodeWithFactoryId: %@", LOG_TAG, self.oldTwincodeInbound.twincodeFactoryId);
            [[self.twinmeContext getTwincodeFactoryService] deleteTwincodeWithFactoryId:self.oldTwincodeInbound.twincodeFactoryId withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *factoryId) {
                [self onDeleteTwincodeFactory:factoryId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & DELETE_TWINCODE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //

    [self.twinmeContext onChangeCallReceiverTwincodeWithRequestId:self.requestId callReceiver:self.callReceiver];
    
    [self stop];
}

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateTwincodeFactory: %@", LOG_TAG, twincodeFactory);

    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactory == nil) {
        
        [self onErrorWithOperationId:CREATE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_TWINCODE_DONE;
    [self.callReceiver setTwincodeFactory:twincodeFactory];
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateObject: %@", LOG_TAG, object);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_OBJECT errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_OBJECT_DONE;
    [self onOperation];
}

- (void)onDeleteTwincodeFactory:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteTwincodeFactory: %@", LOG_TAG, twincodeFactoryId);

    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactoryId == nil) {
        
        [self onErrorWithOperationId:DELETE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= DELETE_TWINCODE_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // The delete operation succeeds if we get an item not found error.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case DELETE_TWINCODE:
                self.state |= DELETE_TWINCODE_DONE;
                [self onOperation];
                return;

            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end


