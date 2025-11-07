/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLBinaryDecoder.h>

#import "TLTwinmeAction.h"
#import "TLTwinmeContextImpl.h"

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

//
// Interface(): TLTwinmeAction
//

@interface TLTwinmeAction ()

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

@end

//
// Implementation: TLTwinmeAction
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeAction"

@implementation TLTwinmeAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext timeLimit:(NSTimeInterval)timeLimit {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ timeLimit: %f", LOG_TAG, twinmeContext, timeLimit);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;

        _requestId = [twinmeContext newRequestId];
        _isOnline = NO;
        _deadlineTime = [[NSDate alloc] initWithTimeIntervalSinceNow:timeLimit];
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId timeLimit:(NSTimeInterval)timeLimit {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld timeLimit: %f", LOG_TAG, twinmeContext, requestId, timeLimit);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;

        _requestId = requestId;
        _isOnline = NO;
        _deadlineTime = [[NSDate alloc] initWithTimeIntervalSinceNow:timeLimit];
    }
    return self;
}

- (NSComparisonResult)compareWithAction:(nonnull TLTwinmeAction *)action {

    NSComparisonResult result = [self.deadlineTime compare:action.deadlineTime];
    if (result != NSOrderedSame) {
        return result;
    }

    return self.requestId < action.requestId ? NSOrderedAscending : NSOrderedDescending;
}

- (void)start {
    DDLogVerbose(@"%@ start", LOG_TAG);
    
    [self.twinmeContext startActionWithAction:self];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);

}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    self.isOnline = YES;
    [self onOperation];
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);
    
    self.isOnline = NO;
}

- (void)onFinish {
    DDLogVerbose(@"%@ onFinish", LOG_TAG);

    [self.twinmeContext finishActionWithAction:self];
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    [self onFinish];
}

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ fireErrorWithErrorCode %d", LOG_TAG, errorCode);

    [self onFinish];
}

- (void)fireTimeout {
    DDLogVerbose(@"%@ fireTimeout", LOG_TAG);

    [self fireErrorWithErrorCode:TLBaseServiceErrorCodeTimeoutError];
}

@end
