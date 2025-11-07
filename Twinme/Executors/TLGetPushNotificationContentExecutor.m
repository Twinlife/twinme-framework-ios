/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <CommonCrypto/CommonCrypto.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLManagementService.h>
#import <Twinlife/TLBinaryDecoder.h>

#import "TLGetPushNotificationContentExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLProfile.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLGroupMember.h"
#import "TLCallReceiver.h"
#import "TLPushNotificationContent.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.2
//

static const int DECRYPT_NOTIFICATION = 1 << 0;
static const int DECRYPT_NOTIFICATION_DONE = 1 << 1;
static const int GET_RECEIVER = 1 << 2;
static const int GET_RECEIVER_DONE = 1 << 3;

//
// Interface(): TLGetPushNotificationContentExecutor
//

@class TLGetPushNotificationContentExecutorTwinmeContextDelegate;

@interface TLGetPushNotificationContentExecutor ()

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, readonly, nonnull) NSDictionary *dictionaryPayload;
@property (nonatomic, nullable) void (^onGetPushNotificationContent) (TLBaseServiceErrorCode status, TLPushNotificationContent *notificationContent);

@property (nonatomic, nullable) TLPushNotificationContent *notificationContent;

@property (nonatomic) int state;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *requestIds;
@property (nonatomic) BOOL restarted;
@property (nonatomic) BOOL stopped;

@property (nonatomic, readonly) TLGetPushNotificationContentExecutorTwinmeContextDelegate *twinmeContextDelegate;

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onOperation;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Interface: TLGetPushNotificationContentExecutorTwinmeContextDelegate
//

@interface TLGetPushNotificationContentExecutorTwinmeContextDelegate:NSObject <TLTwinmeContextDelegate>

@property (nullable) TLGetPushNotificationContentExecutor* executor;

- (instancetype)initWithExecutor:(nonnull TLGetPushNotificationContentExecutor *)executor;

- (void)dispose;

@end

//
// Implementation: TLGetPushNotificationContentExecutorTwinmeContextDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLGetPushNotificationContentExecutorTwinmeContextDelegate"

@implementation TLGetPushNotificationContentExecutorTwinmeContextDelegate

- (instancetype)initWithExecutor:(nonnull TLGetPushNotificationContentExecutor *)executor {
    DDLogVerbose(@"%@ initWithExecutor: %@", LOG_TAG, executor);
    
    self = [super init];
    
    if (self) {
        _executor = executor;
    }
    return self;
}

- (void)dispose {
    DDLogVerbose(@"%@ dispose", LOG_TAG);
    
    self.executor = nil;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeReady];
        [self.executor onOperation];
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeOnline];
        [self.executor onOperation];
    }
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    if (self.executor) {
        [self.executor onTwinlifeOffline];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nonnull NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    if (self.executor) {
        NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
        NSNumber *operationId = self.executor.requestIds[lRequestId];
        if (operationId != nil) {
            [self.executor.requestIds removeObjectForKey:lRequestId];
            [self.executor onErrorWithOperationId:operationId.intValue errorCode:errorCode errorParameter:errorParameter];
            [self.executor onOperation];
        }
    }
}

@end

//
// Implementation: TLGetPushNotificationContentExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGetPushNotificationContentExecutor"

@implementation TLGetPushNotificationContentExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext dictionaryPayload:(nonnull NSDictionary *)dictionaryPayload withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, TLPushNotificationContent * _Nullable notificationContent))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ dictionaryPayload: %@", LOG_TAG, twinmeContext, dictionaryPayload);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
        _dictionaryPayload = dictionaryPayload;
        _onGetPushNotificationContent = block;

        _state = 0;
        _requestIds = [NSMutableDictionary dictionary];
        _stopped = NO;
        
        _twinmeContextDelegate = [[TLGetPushNotificationContentExecutorTwinmeContextDelegate alloc] initWithExecutor:self];
    }
    return self;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    [self.twinmeContext addDelegate:self.twinmeContextDelegate];
}

#pragma mark - Private methods

- (int64_t)newOperation:(int) operationId {
    DDLogVerbose(@"%@ newOperation: %d", LOG_TAG, operationId);
    
    int64_t requestId = [self.twinmeContext newRequestId];
    self.requestIds[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:operationId];
    return requestId;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;

    }
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    self.restarted = YES;
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: decrypt the notification with the Management service notification key.
    //

    if ((self.state & DECRYPT_NOTIFICATION) == 0) {
        self.state |= DECRYPT_NOTIFICATION;

        NSString *base64EncryptedData = self.dictionaryPayload[@"notification-content"];
        if (!base64EncryptedData) {
            [self onErrorWithOperationId:DECRYPT_NOTIFICATION errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
            return;
        }
        NSData *content = [[NSData alloc] initWithBase64EncodedString:base64EncryptedData options:0];
        NSData *key = [[self.twinmeContext getManagementService] notificationKey];
        if (!content || !key || content.length < 2 * kCCBlockSizeAES128) {
            [self onErrorWithOperationId:DECRYPT_NOTIFICATION errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
            return;
        }
        
        char ivPtr[kCCBlockSizeAES128];
        [content getBytes:ivPtr length:kCCBlockSizeAES128];
        
        NSData *encryptedData = [content subdataWithRange:NSMakeRange(kCCBlockSizeAES128, [content length] - kCCBlockSizeAES128)];
        NSUInteger dataLength = [encryptedData length];
        size_t bufferSize = dataLength + kCCBlockSizeAES128;
        void *buffer = malloc(bufferSize);
        if (!buffer) {
            [self onErrorWithOperationId:DECRYPT_NOTIFICATION errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
            return;
        }
        
        size_t numBytesEncrypted = 0;
        CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                              kCCAlgorithmAES128,
                                              kCCOptionPKCS7Padding,
                                              [key bytes],
                                              kCCKeySizeAES256,
                                              ivPtr,
                                              [encryptedData bytes],
                                              dataLength,
                                              buffer,
                                              bufferSize,
                                              &numBytesEncrypted);
        if (cryptStatus != kCCSuccess) {
            free(buffer);
            [self onErrorWithOperationId:DECRYPT_NOTIFICATION errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
            return;
        }
        
        NSData *decryptedData = [[NSData alloc] initWithBytesNoCopy:buffer length:bufferSize];
        
        TLBinaryDecoder *binaryDecoder = [[TLBinaryDecoder alloc] initWithData:decryptedData];
        NSUUID *schemaId = nil;
        int schemaVersion = -1;
        @try {
            schemaId = [binaryDecoder readUUID];
            if ([TLPushNotificationContent.SCHEMA_ID isEqual:schemaId]) {
                schemaVersion = [binaryDecoder readInt];
                if (TLPushNotificationContent.SCHEMA_VERSION == schemaVersion) {
                    self.notificationContent = (TLPushNotificationContent *)[TLPushNotificationContent.SERIALIZER deserializeWithSerializerFactory:[self.twinmeContext getSerializerFactory] decoder:binaryDecoder];
                }
            }
        } @catch (NSException *ex) {
            [self onErrorWithOperationId:DECRYPT_NOTIFICATION errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
            return;
        }

        self.state |= DECRYPT_NOTIFICATION_DONE;
    }
    if ((self.state & DECRYPT_NOTIFICATION_DONE) == 0) {
        return;
    }

    //
    // Step 2: get the notification receiver from the twincode inbound.
    //
  
    if (self.notificationContent) {

        if ((self.state & GET_RECEIVER) == 0) {
            self.state |= GET_RECEIVER;
            
            DDLogVerbose(@"%@ getReceiverWithTwincodeInboundId: %@", LOG_TAG, self.notificationContent.twincodeInboundId);

            TLFindResult *result = [self.twinmeContext getReceiverWithTwincodeInboundId:self.notificationContent.twincodeInboundId];

            self.state |= GET_RECEIVER_DONE;
            if (result.errorCode == TLBaseServiceErrorCodeSuccess && result.object) {
                if ([result.object isKindOfClass:[TLContact class]]) {
                    self.notificationContent.originator = (TLContact *)result.object;
                } else if ([result.object isKindOfClass:[TLGroup class]]) {
                    self.notificationContent.originator = (TLGroup *)result.object;
                } else if ([result.object isKindOfClass:[TLGroupMember class]]) {
                    self.notificationContent.originator = (TLGroupMember *)result.object;
                } else if ([result.object isKindOfClass:[TLCallReceiver class]]) {
                    self.notificationContent.originator = (TLCallReceiver *)result.object;
                }
            }
                
            [self onOperation];
            return;
        }
        if ((self.state & GET_RECEIVER_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //
    if (self.onGetPushNotificationContent) {
        if (self.notificationContent) {
            DDLogVerbose(@"%@ notificationContent: %@", LOG_TAG, self.notificationContent);

            self.onGetPushNotificationContent(TLBaseServiceErrorCodeSuccess, self.notificationContent);
        } else {
            DDLogVerbose(@"%@ notificationContent invalid", LOG_TAG);

            self.onGetPushNotificationContent(TLBaseServiceErrorCodeBadRequest, nil);
        }
    }
    [self stop];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    if (self.onGetPushNotificationContent) {
        self.onGetPushNotificationContent(errorCode, nil);
    }
    [self stop];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);
    
    self.stopped = YES;
    self.onGetPushNotificationContent = nil;

    [self.twinmeContext removeDelegate:self.twinmeContextDelegate];
    [self.twinmeContextDelegate dispose];
}

@end
