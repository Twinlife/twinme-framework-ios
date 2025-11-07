/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>

#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLAbstractTwinmeExecutor.h"
#import "TLGetInvitationCodeExecutor.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.8
//

static const int GET_INVITATION_CODE = 1 << 0;
static const int GET_INVITATION_CODE_DONE = 1 << 1;

//
// Interface: TLGetInvitationCodeExecutor ()
//

@interface TLGetInvitationCodeExecutor ()

@property (readonly, nonnull) NSString *code;
@property (nonatomic, nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, nullable) NSString *publicKey;

- (void)onTwinlifeOnline;

- (void)onOperation;

@end

//
// Implementation: TLGetInvitationCodeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGetInvitationCodeExecutor"

@implementation TLGetInvitationCodeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId code:(nonnull NSString *)code {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld code: %@", LOG_TAG, twinmeContext, requestId, code);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _code = code;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
        self.state = 0;
    }
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 1: Get the invitation code
    //
    
    if ((self.state & GET_INVITATION_CODE) == 0) {
        self.state |= GET_INVITATION_CODE;
        
        [self.twinmeContext.getTwincodeOutboundService getInvitationCodeWithCode:self.code withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound * _Nullable twincodeOutbound, NSString * _Nullable publicKey) {
            
            if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
                [self onErrorWithOperationId:GET_INVITATION_CODE errorCode:errorCode errorParameter:nil];
                return;
            }
            
            self.state |= GET_INVITATION_CODE_DONE;
            self.twincodeOutbound = twincodeOutbound;
            self.publicKey = publicKey;
            
            [self onOperation];
        }];
    }
    
    if ((self.state & GET_INVITATION_CODE_DONE) == 0) {
        return;
    }
    
    //
    // Last Step
    //
   
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

    [self.twinmeContext onGetInvitationCodeWithRequestId:self.requestId twincodeOutbound:self.twincodeOutbound publicKey:self.publicKey];
    
    [self stop];
}


@end
