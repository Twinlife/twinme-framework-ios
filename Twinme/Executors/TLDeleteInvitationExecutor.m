/*
 *  Copyright (c) 2019-2023 twinlife SA.
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
#import <Twinlife/TLConversationService.h>

#import "TLDeleteInvitationExecutor.h"
#import "TLInvitation.h"
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
// version: 1.8
//

static const int DELETE_INVITATION_DESCRIPTOR = 1 << (TL_DELETE_OBJECT_LAST_STATE_BIT + 1);
static const int DELETE_INVITATION_DESCRIPTOR_DONE = 1 << (TL_DELETE_OBJECT_LAST_STATE_BIT + 2);

//
// Interface(): TLDeleteInvitationExecutor
//

@class TLDeleteInvitationExecutorConversationServiceDelegate;

@interface TLDeleteInvitationExecutor()

@property (nonatomic, readonly, nonnull) TLInvitation *invitation;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, readonly, nonnull) TLTwincodeInbound *twincodeInbound;
@property (nonatomic, readonly, nonnull) TLImageId *invitationAvatarId;
@property (nonatomic, readonly, nonnull) TLDescriptorId *descriptorId;

@property (nonatomic, readonly, nonnull) TLDeleteInvitationExecutorConversationServiceDelegate *conversationServiceDelegate;

- (void)onTwinlifeReady;

- (void)onOperation;

- (void)onMarkDescriptorDeleted:(nonnull TLDescriptor *)descriptor;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

@end

//
// Interface: TLDeleteInvitationExecutorConversationServiceDelegate
//

@interface TLDeleteInvitationExecutorConversationServiceDelegate : NSObject <TLConversationServiceDelegate>

@property (weak) TLDeleteInvitationExecutor* executor;

- (instancetype)initWithExecutor:(nonnull TLDeleteInvitationExecutor *)executor;

@end

//
// Implementation: TLDeleteInvitationExecutorConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteInvitationExecutorConversationServiceDelegate"

@implementation TLDeleteInvitationExecutorConversationServiceDelegate

- (instancetype)initWithExecutor:(nonnull TLDeleteInvitationExecutor *)executor {
    DDLogVerbose(@"%@ initWithExecutor: %@", LOG_TAG, executor);
    
    self = [super init];
    
    if (self) {
        _executor = executor;
    }
    return self;
}

- (void)onMarkDescriptorDeletedWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeletedWithRequestId: %lld conversation: %@ descriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    int operationId = [self.executor getOperationWithRequestId:requestId];
    if (operationId) {
        [self.executor onMarkDescriptorDeleted:descriptor];
    }
}

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithRequestId: %lld errorCode: %d errorParameter: %@", LOG_TAG, requestId, errorCode, errorParameter);
    
    int operationId = [self.executor getOperationWithRequestId:requestId];
    if (operationId) {
        [self.executor onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
        [self.executor onOperation];
    }
}

@end

//
// Implementation: TLDeleteInvitationExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteInvitationExecutor"

@implementation TLDeleteInvitationExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld invitation: %@", LOG_TAG, twinmeContext, requestId, invitation);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId object:invitation invocationId:nil timeout:timeout];
    
    if (self) {
        _invitation = invitation;
        _twincodeInbound = [invitation twincodeInbound];
        _twincodeOutbound = [invitation twincodeOutbound];
        _invitationAvatarId = [invitation avatarId];
        _descriptorId = [invitation descriptorId];

        _conversationServiceDelegate = [[TLDeleteInvitationExecutorConversationServiceDelegate alloc] initWithExecutor:self];
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinmeContext getConversationService] addDelegate:self.conversationServiceDelegate];
    [super onTwinlifeReady];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 3: delete the invitation descriptor.
    //

    if (self.descriptorId) {
    
        if ((self.state & DELETE_INVITATION_DESCRIPTOR) == 0) {
            self.state |= DELETE_INVITATION_DESCRIPTOR;

            int64_t requestId = [self newOperation:DELETE_INVITATION_DESCRIPTOR];
            DDLogVerbose(@"%@ markDescriptorDeletedWithRequestId: %lld descriptorId: %@", LOG_TAG, requestId, self.descriptorId);
            [[self.twinmeContext getConversationService] markDescriptorDeletedWithRequestId:requestId descriptorId:self.descriptorId];
            return;
        }
        if ((self.state & DELETE_INVITATION_DESCRIPTOR_DONE) == 0) {
            return;
        }
    }

    [super onOperation];
}

- (void)onMarkDescriptorDeleted:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onMarkDescriptorDeleted: %@", LOG_TAG, descriptor);

    self.state |= DELETE_INVITATION_DESCRIPTOR_DONE;
    [self onOperation];
}

- (void)onFinishDeleteWithObject:(nonnull TLTwinmeObject *)object {
    DDLogVerbose(@"%@ onFinishDeleteWithObject: %@", LOG_TAG, object);

    [self.twinmeContext onDeleteInvitationWithRequestId:self.requestId invitationId:self.invitation.uuid];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // The delete operation succeeds if we get an item not found error.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {

            case DELETE_INVITATION_DESCRIPTOR:
                self.state |= DELETE_INVITATION_DESCRIPTOR_DONE;
                return;

            default:
                break;
        }
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

- (void)stop {
    DDLogVerbose(@"%@ stop", LOG_TAG);

    [[self.twinmeContext getConversationService] removeDelegate:self.conversationServiceDelegate];

    [super stop];
}

@end

