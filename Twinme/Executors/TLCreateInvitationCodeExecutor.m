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
#import "TLCreateInvitationCodeExecutor.h"
#import "TLInvitation.h"

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

static const int CREATE_INVITATION = 1 << 0;
static const int CREATE_INVITATION_DONE = 1 << 1;
static const int CREATE_INVITATION_CODE = 1 << 2;
static const int CREATE_INVITATION_CODE_DONE = 1 << 3;
static const int UPDATE_INVITATION = 1 << 4;
static const int UPDATE_INVITATION_DONE = 1 << 5;


//
// Interface: TLCreateInvitationCodeExecutor ()
//

@interface TLCreateInvitationCodeExecutor ()

@property (readonly) int validityPeriod;
@property (nonatomic, nullable) TLInvitationCode* invitationCode;
@property (nonatomic, nullable) TLInvitation* invitation;

- (void)onTwinlifeOnline;

- (void)onOperation;

@end

//
// Implementation: TLCreateInvitationCodeExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateInvitationCodeExecutor"

@implementation TLCreateInvitationCodeExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId validityPeriod:(int)validityPeriod {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld validityPeriod: %d", LOG_TAG, twinmeContext, requestId, validityPeriod);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _validityPeriod = validityPeriod;
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
    // Step 1: Create the invitation
    //
    
    if ((self.state & CREATE_INVITATION) == 0) {
        self.state |= CREATE_INVITATION;
        
        int64_t requestId = [self newOperation:CREATE_INVITATION];
        
        [self.twinmeContext createInvitationWithRequestId:requestId groupMember:nil];
        
        return;
    }
    
    if ((self.state & CREATE_INVITATION_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: Create the invitation code
    //
    
    if ((self.state & CREATE_INVITATION_CODE) == 0) {
        self.state |= CREATE_INVITATION_CODE;
        
        if (!self.invitation.twincodeOutbound) {
            [self.twinmeContext assertionWithAssertPoint:[TLExecutorAssertPoint INVALID_TWINCODE], [TLAssertValue initWithSubject:self.invitation], nil];
            return;
        }
        
        [self.twinmeContext.getTwincodeOutboundService createInvitationCodeWithTwincodeOutbound:self.invitation.twincodeOutbound validityPeriod:self.validityPeriod withBlock:^(TLBaseServiceErrorCode errorCode, TLInvitationCode * _Nullable invitationCode) {
            if (errorCode != TLBaseServiceErrorCodeSuccess || !invitationCode) {
                [self onErrorWithOperationId:CREATE_INVITATION_CODE errorCode:errorCode errorParameter:nil];
                return;
            }
            
            self.state |= CREATE_INVITATION_CODE_DONE;
            self.invitationCode = invitationCode;
            self.invitation.invitationCode = invitationCode;
            
            [self onOperation];
        }];
        
        return;
    }
    
    if ((self.state & CREATE_INVITATION_CODE_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: Update the invitation to persist the code
    //

    if ((self.state & UPDATE_INVITATION) == 0) {
        self.state |= UPDATE_INVITATION;

        TL_ASSERT_NOT_NULL(self.twinmeContext, self.invitation, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:10], nil);

        [self.twinmeContext.getRepositoryService updateObjectWithObject:self.invitation localOnly:YES withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject>  _Nullable object) {
            self.state |= UPDATE_INVITATION_DONE;

            if ([object isKindOfClass:TLInvitation.class]) {
                self.invitation = object;
            } else {
                self.invitation = nil;
            }
            
            [self onOperation];
        }];
        
        return;
    }
    
    if ((self.state & UPDATE_INVITATION_DONE) == 0) {
        return;
    }

    
    //
    // Last Step
    //
   
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.invitation, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

    [self.twinmeContext onCreateInvitationWithCodeWithRequestId:self.requestId invitation:self.invitation];
    
    [self stop];
}

- (void)onCreateInvitationWithRequestId:(int64_t)requestId invitation:(TLInvitation *)invitation {
    DDLogVerbose(@"%@ onCreateInvitationWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId > 0) {
        self.state |= CREATE_INVITATION_DONE;
        self.invitation = invitation;
    }
    
    [self onOperation];
}



@end
