/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeFactoryService.h>
#import <Twinlife/TLImageService.h>


#import "TLDeleteCallReceiverExecutor.h"
#import "TLTwinmeContextImpl.h"
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
// version: 1.0
//

//
// Interface(): TLDeleteCallReceiverExecutor
//

@interface TLDeleteCallReceiverExecutor ()

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object;

@end

//
// Implementation: TLDeleteCallReceiverExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteCallReceiverExecutor"


@implementation TLDeleteCallReceiverExecutor
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld callReceiver: %@", LOG_TAG, twinmeContext, requestId, callReceiver);

    return [super initWithTwinmeContext:twinmeContext requestId:requestId object:callReceiver invocationId:nil timeout:timeout];
}

#pragma mark - Private methods

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object {
    DDLogVerbose(@"%@ onFinishDeleteWithObject: %@", LOG_TAG, object);

    [self.twinmeContext onDeleteCallReceiverWithRequestId:self.requestId callReceiverId:object.uuid];
}

@end
