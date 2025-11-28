/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLManagementService.h>

#import "TLFeedbackAction.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int SEND_FEEDBACK = 1 << 0;
static const int SEND_FEEDBACK_DONE = 1 << 1;

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.1
//

//
// Interface(): TLFeedbackAction
//

@interface TLFeedbackAction ()

@property (nonatomic, nullable) void (^onFeedbackAction) (TLBaseServiceErrorCode errorCode);
@property (nonatomic) int state;
@property (nonatomic, nonnull, readonly) NSString *email;
@property (nonatomic, nonnull, readonly) NSString *subject;
@property (nonatomic, nonnull, readonly) NSString *feedbackDescription;
@property (nonatomic, readonly) BOOL sendLogReport;

- (void)onOperation;

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLFeedbackAction
//

#undef LOG_TAG
#define LOG_TAG @"TLFeedbackAction"

@implementation TLFeedbackAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext email:(nonnull NSString *)email subject:(nonnull NSString *)subject description:(nonnull NSString *)description sendLogReport:(BOOL)sendLogReport withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ email: %@", LOG_TAG, twinmeContext, email);
    
    self = [super initWithTwinmeContext:twinmeContext timeLimit:10.0];
    
    if (self) {
        _email = email;
        _subject = subject;
        _feedbackDescription = description;
        _sendLogReport = sendLogReport;
        _onFeedbackAction = block;
    }
    return self;
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (!self.isOnline) {
        return;

    }

    if ((self.state & SEND_FEEDBACK) == 0) {
        self.state |= SEND_FEEDBACK;
        
        TLManagementService *managementService = [self.twinmeContext getManagementService];
        NSString *logReport = self.sendLogReport ? [managementService buildLogReport] : nil;

        [managementService sendFeedbackWithDescription:self.feedbackDescription email:self.email subject:self.subject logReport:logReport withBlock:^(TLBaseServiceErrorCode errorCode) {

            self.state |= SEND_FEEDBACK_DONE;
            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                [self fireErrorWithErrorCode:errorCode];
                return;
            }
            if (self.onFeedbackAction) {
                self.onFeedbackAction(errorCode);
                self.onFeedbackAction = nil;
            }
            [self onFinish];
        }];
        return;
    }
        
    if ((self.state & SEND_FEEDBACK_DONE) == 0) {
        return;
    }

    [self onFinish];
}

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ fireErrorWithErrorCode %d", LOG_TAG, errorCode);

    if (self.onFeedbackAction) {
        self.onFeedbackAction(errorCode);
        self.onFeedbackAction = nil;
    }

    [self onFinish];
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    self.onFeedbackAction = nil;
    [self onFinish];
}

@end
