/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLNotificationService.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLDeleteGroupExecutor.h"
#import "TLGroup.h"
#import "TLTwinmeContextImpl.h"
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

static const int DELETE_GROUP_TWINCODE = 1 << (TL_DELETE_OBJECT_LAST_STATE_BIT + 1);
static const int DELETE_GROUP_TWINCODE_DONE = 1 << (TL_DELETE_OBJECT_LAST_STATE_BIT + 2);

//
// Interface(): TLDeleteGroupExecutor
//

@interface TLDeleteGroupExecutor()

@property (nonatomic, readonly, nonnull) NSUUID *groupTwincodeFactoryId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onDeleteGroupTwincode:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Implementation: TLDeleteGroupExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteGroupExecutor"

@implementation TLDeleteGroupExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld group: %@", LOG_TAG, twinmeContext, requestId, group);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId object:group invocationId:nil timeout:timeout];
    if (self) {
        _groupTwincodeFactoryId = group.groupTwincodeFactoryId;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & DELETE_GROUP_TWINCODE) != 0 && (self.state & DELETE_GROUP_TWINCODE_DONE) == 0) {
            self.state &= ~DELETE_GROUP_TWINCODE;
        }
    }
    [super onTwinlifeOnline];
}

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object {
    DDLogVerbose(@"%@ onFinishDeleteWithObject: %@", LOG_TAG, object);

    [self.twinmeContext onDeleteGroupWithRequestId:self.requestId groupId:object.uuid];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: delete the group twincode if we are the owner.
    //
    if (self.groupTwincodeFactoryId) {
        if ((self.state & DELETE_GROUP_TWINCODE) == 0) {
            self.state |= DELETE_GROUP_TWINCODE;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.groupTwincodeFactoryId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

            DDLogVerbose(@"%@ deleteTwincodeWithFactoryId: %@", LOG_TAG, self.groupTwincodeFactoryId);
            [[self.twinmeContext getTwincodeFactoryService] deleteTwincodeWithFactoryId:self.groupTwincodeFactoryId withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *factoryId) {
                [self onDeleteGroupTwincode:factoryId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & DELETE_GROUP_TWINCODE_DONE) == 0) {
            return;
        }
    }

    [super onOperation];
}

- (void)onDeleteGroupTwincode:(nullable NSUUID *)twincodeFactoryId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteGroupTwincode: %@", LOG_TAG, twincodeFactoryId);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeFactoryId == nil) {
        
        [self onErrorWithOperationId:DELETE_GROUP_TWINCODE errorCode:errorCode errorParameter:nil];
        return;
    }

    TL_ASSERT_EQUAL(self.twinmeContext, twincodeFactoryId, self.groupTwincodeFactoryId, [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterFactoryId, [TLAssertValue initWithNumber:23], nil);

    self.state |= DELETE_GROUP_TWINCODE_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // The delete operation succeeds if we get an item not found error.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {

            case DELETE_GROUP_TWINCODE:
                self.state |= DELETE_GROUP_TWINCODE_DONE;
                [self onOperation];
                return;

            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end

