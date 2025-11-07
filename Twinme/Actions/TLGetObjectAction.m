/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLConversationService.h>

#import "TLGetObjectAction.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLInvitation.h"
#import "TLCallReceiver.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int GET_OBJECT = 1 << 0;
static const int GET_OBJECT_DONE = 1 << 1;

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.1
//

//
// Interface(): TLGetObjectAction
//

@interface TLGetObjectAction ()

@property (nonatomic) int state;

- (void)onTwinlifeReady;

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onGetObjectWithObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Interface(): TLGetContactAction
//

@interface TLGetContactAction ()

@property (nonatomic, nullable) void (^onGetContactAction) (TLBaseServiceErrorCode errorCode, TLContact *contact);

@end

//
// Interface(): TLGetGroupAction
//

@interface TLGetGroupAction ()

@property (nonatomic, nullable) void (^onGetGroupAction) (TLBaseServiceErrorCode errorCode, TLGroup *group);

@end

//
// Interface(): TLGetInvitationAction
//

@interface TLGetInvitationAction ()

@property (nonatomic, nullable) void (^onGetInvitationAction) (TLBaseServiceErrorCode errorCode, TLInvitation *invitation);

@end

//
// Interface(): TLGetInvitationAction
//

@interface TLGetCallReceiverAction ()

@property (nonatomic, nullable) void (^onGetCallReceiverAction) (TLBaseServiceErrorCode errorCode, TLCallReceiver *invitation);

@end

//
// Implementation: TLGetObjectAction
//

#undef LOG_TAG
#define LOG_TAG @"TLGetObjectAction"

@implementation TLGetObjectAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext objectId:(nonnull NSUUID *)objectId factory:(nonnull id<TLRepositoryObjectFactory>)factory {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ objectId: %@", LOG_TAG, twinmeContext, objectId);
    
    self = [super initWithTwinmeContext:twinmeContext timeLimit:10.0];
    
    if (self) {
        _objectId = objectId;
        _factory = factory;
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);

    [self onOperation];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    // Get the twincode information.
    if ((self.state & GET_OBJECT) == 0) {
        self.state |= GET_OBJECT;

        DDLogVerbose(@"%@ getObjectWithFactory: %@", LOG_TAG, self.objectId);
        [[self.twinmeContext getRepositoryService] getObjectWithFactory:self.factory objectId:self.objectId  withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            self.state |= GET_OBJECT_DONE;

            if (errorCode != TLBaseServiceErrorCodeSuccess) {
                [self fireErrorWithErrorCode:errorCode];
                return;
            }

            [self onGetObjectWithObject:object errorCode:errorCode];
            [self onFinish];
        }];
        return;
    }
    if ((self.state & GET_OBJECT_DONE) == 0) {
        return;
    }

    [self onFinish];
}

- (void)fireErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ fireErrorWithErrorCode %d", LOG_TAG, errorCode);

    [self onGetObjectWithObject:nil errorCode:errorCode];
    [self onFinish];
}

- (void)onGetObjectWithObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    
}

@end

//
// Implementation: TLGetContactAction
//

#undef LOG_TAG
#define LOG_TAG @"TLGetContactAction"

@implementation TLGetContactAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext contactId:(nonnull NSUUID *)contactId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ contactId: %@", LOG_TAG, twinmeContext, contactId);
    
    self = [super initWithTwinmeContext:twinmeContext objectId:contactId factory:[TLContact FACTORY]];
    if (self) {
        _onGetContactAction = block;
    }
    return self;
}

- (void)onGetObjectWithErrorCode:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onGetObjectWithErrorCode: %d object: %@", LOG_TAG, errorCode, object);

    if (self.onGetContactAction) {
        self.onGetContactAction(errorCode, (TLContact *)object);
        self.onGetContactAction = nil;
    }
}

@end

//
// Implementation: TLGetGroupAction
//

#undef LOG_TAG
#define LOG_TAG @"TLGetGroupAction"

@implementation TLGetGroupAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext groupId:(nonnull NSUUID *)groupId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroup * _Nullable group))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ contactId: %@", LOG_TAG, twinmeContext, groupId);
    
    self = [super initWithTwinmeContext:twinmeContext objectId:groupId factory:[TLGroup FACTORY]];
    if (self) {
        _onGetGroupAction = block;
    }
    return self;
}

- (void)onGetObjectWithErrorCode:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onGetObjectWithErrorCode: %d object: %@", LOG_TAG, errorCode, object);

    if (object) {
        TLGroup *group = (TLGroup *)object;

        id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:object];
        if (!conversation) {
            int64_t requestId = [TLBaseService DEFAULT_REQUEST_ID];

            DDLogVerbose(@"%@ deleteGroupWithRequestId: %lld contact: %@", LOG_TAG, requestId, self.objectId);
            [self.twinmeContext deleteGroupWithRequestId:requestId group:group];
            
            // And report an ItemNotFound error with the contact ID.
            errorCode = TLBaseServiceErrorCodeItemNotFound;
            object = nil;
        }
    }

    if (self.onGetGroupAction) {
        self.onGetGroupAction(errorCode, (TLGroup *)object);
        self.onGetGroupAction = nil;
    }
}

@end

//
// Implementation: TLGetInvitationAction
//

#undef LOG_TAG
#define LOG_TAG @"TLGetInvitationAction"

@implementation TLGetInvitationAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invitationId:(nonnull NSUUID *)invitationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvitation * _Nullable invitation))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ contactId: %@", LOG_TAG, twinmeContext, invitationId);
    
    self = [super initWithTwinmeContext:twinmeContext objectId:invitationId factory:[TLInvitation FACTORY]];
    if (self) {
        _onGetInvitationAction = block;
    }
    return self;
}

- (void)onGetObjectWithErrorCode:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onGetObjectWithErrorCode: %d object: %@", LOG_TAG, errorCode, object);

    if (self.onGetInvitationAction) {
        self.onGetInvitationAction(errorCode, (TLInvitation *)object);
        self.onGetInvitationAction = nil;
    }
}

@end

//
// Implementation: TLGetCallReceiverAction
//

#undef LOG_TAG
#define LOG_TAG @"TLGetCallReceiverAction"

@implementation TLGetCallReceiverAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext callReceiverId:(nonnull NSUUID *)callReceiverId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLCallReceiver * _Nullable callReceiver))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ contactId: %@", LOG_TAG, twinmeContext, callReceiverId);
    
    self = [super initWithTwinmeContext:twinmeContext objectId:callReceiverId factory:[TLCallReceiver FACTORY]];
    if (self) {
        _onGetCallReceiverAction = block;
    }
    return self;
}

- (void)onGetObjectWithErrorCode:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onGetObjectWithErrorCode: %d object: %@", LOG_TAG, errorCode, object);

    if (self.onGetCallReceiverAction) {
        self.onGetCallReceiverAction(errorCode, (TLCallReceiver *)object);
        self.onGetCallReceiverAction = nil;
    }
}

@end
