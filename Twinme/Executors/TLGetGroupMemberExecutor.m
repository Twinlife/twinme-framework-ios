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
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLImageService.h>

#import "TLGetGroupMemberExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLGroup.h"
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
// version: 1.4
//

static const int GET_MEMBER_TWINCODE_OUTBOUND = 1 << 0;
static const int GET_MEMBER_TWINCODE_OUTBOUND_DONE = 1 << 1;
static const int GET_MEMBER_IMAGE = 1 << 2;
static const int GET_MEMBER_IMAGE_DONE = 1 << 3;

//
// Interface(): TLGetGroupMemberExecutor
//

@interface TLGetGroupMemberExecutor ()

@property (nonatomic, readonly) NSUUID *memberTwincodeOutboundId;
@property (nonatomic, readonly) id<TLOriginator> owner;
@property (nonatomic, readonly, nonnull) void (^onGetGroupMember) (TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember);

@property (nonatomic) TLGroupMember *groupMember;
@property (nonatomic) TLImageId *memberAvatarId;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onGetTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Implementation: TLGetGroupMemberExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLGetGroupMemberExecutor"

@implementation TLGetGroupMemberExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext owner:(nonnull id<TLOriginator>)owner groupMemberTwincodeId:(nonnull NSUUID *)groupMemberTwincodeId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupMember * _Nullable groupMember))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ owner: %@ groupMemberTwincodeId: %@", LOG_TAG, twinmeContext, owner, groupMemberTwincodeId);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:0];
    
    if (self) {
        _owner = owner;
        _memberTwincodeOutboundId = groupMemberTwincodeId;
        _onGetGroupMember = block;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
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
    // Step 1: get the twincode that corresponds to the group member.
    //
    
    if ((self.state & GET_MEMBER_TWINCODE_OUTBOUND) == 0) {
        self.state |= GET_MEMBER_TWINCODE_OUTBOUND;

        [[self.twinmeContext getTwincodeOutboundService] getTwincodeWithTwincodeId:self.memberTwincodeOutboundId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
            [self onGetTwincodeOutbound:twincodeOutbound errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_MEMBER_TWINCODE_OUTBOUND_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: get the group member image so that we have it in the cache when we are done.
    //
    if (self.memberAvatarId) {
    
        if ((self.state & GET_MEMBER_IMAGE) == 0) {
            self.state |= GET_MEMBER_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService getImageWithImageId:self.memberAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode errorCode, UIImage *image) {
                self.state |= GET_MEMBER_IMAGE_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_MEMBER_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //

    [self.twinmeContext onGetGroupMemberWithErrorCode:TLBaseServiceErrorCodeSuccess groupMember:self.groupMember withBlock:self.onGetGroupMember];
    [self stop];
}

- (void)onGetTwincodeOutbound:(TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || twincodeOutbound == nil) {
        
        [self onErrorWithOperationId:GET_MEMBER_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:self.memberTwincodeOutboundId.UUIDString];
        return;
    }

    self.state |= GET_MEMBER_TWINCODE_OUTBOUND_DONE;
    
    self.groupMember = [[TLGroupMember alloc] initWithOwner:self.owner twincodeOutbound:twincodeOutbound];
    self.memberAvatarId = self.groupMember.memberAvatarId;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (operationId == GET_MEMBER_TWINCODE_OUTBOUND && errorCode == TLBaseServiceErrorCodeItemNotFound) {
            
        self.state |= GET_MEMBER_TWINCODE_OUTBOUND_DONE;

        if ([self.owner isGroup]) {
            TLGroup *group = (TLGroup *)self.owner;
            NSUUID *groupTwincodeOutboundId = group.groupTwincodeOutboundId;
            if (groupTwincodeOutboundId) {
                // The member twincode is invalid, remove the member from the group.
                [[self.twinmeContext getConversationService] leaveGroupWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:group memberTwincodeId:self.memberTwincodeOutboundId];
            }
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
