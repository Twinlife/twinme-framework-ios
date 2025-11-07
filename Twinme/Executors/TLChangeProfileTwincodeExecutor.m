/*
 *  Copyright (c) 2020-2025 twinlife SA.
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
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLChangeProfileTwincodeExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLProfile.h"
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
// version: 1.6
//

static const int CREATE_TWINCODE = 1 << 2;
static const int CREATE_TWINCODE_DONE = 1 << 3;
static const int UPDATE_OBJECT = 1 << 6;
static const int UPDATE_OBJECT_DONE = 1 << 7;
static const int UNBIND_TWINCODE_INBOUND = 1 << 8;
static const int UNBIND_TWINCODE_INBOUND_DONE = 1 << 9;
static const int DELETE_TWINCODE = 1 << 10;
static const int DELETE_TWINCODE_DONE = 1 << 11;

//
// Interface: TLChangeProfileTwincodeExecutor ()
//

@interface TLChangeProfileTwincodeExecutor ()

@property (nonatomic, readonly, nonnull) TLProfile *profile;
@property (nonatomic, readonly, nullable) TLTwincodeInbound *oldTwincodeInbound;
@property (nonatomic, readonly, nullable) NSUUID *oldTwincodeFactoryId;
@property (nonatomic, readonly, nullable) TLImageId *avatarId;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *identityTwincodeOutbound;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteTwincodeFactory:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUnbindTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLChangeProfileTwincodeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLChangeProfileTwincodeExecutor"

@implementation TLChangeProfileTwincodeExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld profile: %@", LOG_TAG, twinmeContext, requestId, profile);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _profile = profile;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _profile, [TLExecutorAssertPoint PARAMETER], nil);

        _avatarId = profile.avatarId;
        _oldTwincodeInbound = profile.twincodeInbound;
        _oldTwincodeFactoryId = profile.twincodeFactoryId;
        _identityTwincodeOutbound = profile.twincodeOutbound;
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
        if ((self.state & UNBIND_TWINCODE_INBOUND) != 0 && (self.state & UNBIND_TWINCODE_INBOUND_DONE) == 0) {
            self.state &= ~UNBIND_TWINCODE_INBOUND;
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
        [TLPairProtocol setTwincodeAttributeMetaPair:twincodeFactoryAttributes];
        
        NSMutableArray *twincodeOutboundAttributes = [NSMutableArray array];
        [TLTwinmeAttributes setTwincodeAttributeName:twincodeOutboundAttributes name:self.profile.name];

        if (self.avatarId) {
            TLExportedImageId *avatarId = [[self.twinmeContext getImageService] publicWithImageId:self.avatarId];
            if (avatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:twincodeOutboundAttributes imageId:avatarId];
            }
        }

        // Copy a number of twincode attributes from the profile identity.
        if (self.identityTwincodeOutbound) {
            [self.twinmeContext copySharedTwincodeAttributesWithTwincode:self.identityTwincodeOutbound attributes:twincodeOutboundAttributes];
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
    // Step 2: update the profile.
    //
    
    if ((self.state & UPDATE_OBJECT) == 0) {
        self.state |= UPDATE_OBJECT;

        DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.profile);
        [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.profile localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onUpdateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & UPDATE_OBJECT_DONE) == 0) {
        return;
    }

    //
    // Step 3: unbind the old twincode.
    //
    if (self.oldTwincodeInbound) {
          
        if ((self.state & UNBIND_TWINCODE_INBOUND) == 0) {
            self.state |= UNBIND_TWINCODE_INBOUND;
              
            DDLogVerbose(@"%@ unbindTwincodeWithTwincode: %@", LOG_TAG, self.oldTwincodeInbound);
            [[self.twinmeContext getTwincodeInboundService] unbindTwincodeWithTwincode:self.oldTwincodeInbound withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *twincodeInbound) {
                [self onUnbindTwincodeInbound:twincodeInbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UNBIND_TWINCODE_INBOUND_DONE) == 0) {
            return;
        }
    }

    //
    // Step 4: delete the old twincode.
    //
    if (self.oldTwincodeFactoryId) {
          
        if ((self.state & DELETE_TWINCODE) == 0) {
            self.state |= DELETE_TWINCODE;
              
            DDLogVerbose(@"%@ deleteTwincodeWithFactoryId: %@", LOG_TAG, self.oldTwincodeFactoryId);
            [[self.twinmeContext getTwincodeFactoryService] deleteTwincodeWithFactoryId:self.oldTwincodeFactoryId withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *factoryId) {
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

    [self.twinmeContext onChangeProfileTwincodeWithRequestId:self.requestId profile:self.profile];
    
    [self stop];
}

- (void)onCreateTwincodeFactory:(nullable TLTwincodeFactory *)twincodeFactory errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateTwincodeFactory: %@", LOG_TAG, twincodeFactory);

    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactory == nil) {
        
        [self onErrorWithOperationId:CREATE_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= CREATE_TWINCODE_DONE;
    
    [self.profile setTwincodeFactory:twincodeFactory];
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

- (void)onDeleteTwincodeFactory:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteTwincodeFactory: %@", LOG_TAG, twincodeFactoryId);

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

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // The delete operation succeeds if we get an item not found error.
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

            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end

