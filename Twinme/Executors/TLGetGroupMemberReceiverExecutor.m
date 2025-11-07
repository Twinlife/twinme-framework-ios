/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLConversationProtocol.h>

#import "TLGetGroupMemberReceiverExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLGroup.h"
#import "TLContact.h"
#import "TLGroupMember.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.3
//

static const int GET_RECEIVER = 1 << 0;
static const int GET_RECEIVER_DONE = 1 << 1;
static const int GET_GROUP_MEMBER = 1 << 2;
static const int GET_GROUP_MEMBER_DONE = 1 << 3;

//
// Interface: TLGetGroupMemberReceiverExecutor ()
//

@interface TLGetGroupMemberReceiverExecutor ()

@property (nonatomic, readonly, nonnull) NSUUID *twincodeInboundId;
@property (nonatomic, readonly, nonnull) NSUUID *memberTwincodeOutboundId;
@property (nonatomic, readonly, nonnull) void (^onGetReceiver) (TLBaseServiceErrorCode errorCode, TLGroupMember *receiver);

@property (nonatomic) id<TLOriginator> owner;
@property (nonatomic) TLGroupMember *groupMember;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onGetGroupMember:(TLBaseServiceErrorCode)errorCode member:(TLGroupMember *)member;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Implementation: TLGetGroupMemberReceiverExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGetGroupMemberReceiverExecutor"

@implementation TLGetGroupMemberReceiverExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twincodeInboundId:(nonnull NSUUID *)twincodeInboundId memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, id _Nullable receiver))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ twincodeInboundId: %@ memberTwincodeOutboundId: %@", LOG_TAG, twinmeContext, twincodeInboundId, memberTwincodeOutboundId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:0];
    
    if (self) {
        _twincodeInboundId = twincodeInboundId;
        _memberTwincodeOutboundId = memberTwincodeOutboundId;
        _onGetReceiver = block;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _memberTwincodeOutboundId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
        TL_ASSERT_NOT_NULL(twinmeContext, _twincodeInboundId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        self.restarted = NO;
    }
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 1: get the group associated with the twincode inbound.
    //

    if ((self.state & GET_RECEIVER) == 0) {
        self.state |= GET_RECEIVER;
            
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeInboundId, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:3], nil);

        DDLogVerbose(@"%@ getReceiverWithTwincodeInboundId: %@", LOG_TAG, self.twincodeInboundId);
        TLFindResult *result = [self.twinmeContext getReceiverWithTwincodeInboundId:self.twincodeInboundId];
        
        if (result.errorCode != TLBaseServiceErrorCodeSuccess || !result.object) {
            [self onErrorWithOperationId:GET_RECEIVER errorCode:result.errorCode errorParameter:self.twincodeInboundId.UUIDString];
            return;
        }

        self.state |= GET_RECEIVER_DONE;
        
        if ([result.object isKindOfClass:[TLGroup class]]) {
            self.owner = (TLGroup *)result.object;
        } else if ([result.object isKindOfClass:[TLContact class]]) {
            self.owner = (TLContact *)result.object;
        }
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.owner, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:4], nil);
        [self onOperation];
        return;
    }
    if ((self.state & GET_RECEIVER_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: get the group member.
    //
    
    if ((self.state & GET_GROUP_MEMBER) == 0) {
        self.state |= GET_GROUP_MEMBER;
        
        TL_ASSERT_NOT_NULL(self.twinmeContext, self.owner, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:5], nil);

        DDLogVerbose(@"%@ getGroupMemberWithOwner: %@ memberTwincodeOutboundId: %@", LOG_TAG, self.owner, self.memberTwincodeOutboundId);
        [self.twinmeContext getGroupMemberWithOwner:self.owner memberTwincodeId:self.memberTwincodeOutboundId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *member) {
            [self onGetGroupMember:errorCode member:member];
        }];
        return;
    }
    if ((self.state & GET_GROUP_MEMBER_DONE) == 0) {
        return;
    }

    self.onGetReceiver(TLBaseServiceErrorCodeSuccess, self.groupMember);

    [self stop];
}

- (void)onGetGroupMember:(TLBaseServiceErrorCode)errorCode member:(TLGroupMember *)member {
    DDLogVerbose(@"%@ onGetGroupMember: %d member: %@", LOG_TAG, errorCode, member);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !member) {

        [self onErrorWithOperationId:GET_GROUP_MEMBER errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= GET_GROUP_MEMBER_DONE;
    
    self.groupMember = member;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);
    
    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    self.onGetReceiver(errorCode, nil);

    [self stop];
}

@end
