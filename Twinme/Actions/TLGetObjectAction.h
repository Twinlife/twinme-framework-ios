/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeAction.h"

@protocol TLRepositoryObject;
@protocol TLRepositoryObjectFactory;

@class TLInvitation;
@class TLContact;
@class TLGroup;
@class TLCallReceiver;

@interface TLGetObjectAction : TLTwinmeAction

@property (nonatomic, readonly, nonnull) NSUUID *objectId;
@property (nonatomic, readonly, nonnull) id<TLRepositoryObjectFactory> factory;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext objectId:(nonnull NSUUID *)objectId factory:(nonnull id<TLRepositoryObjectFactory>)factory;

@end

@interface TLGetContactAction : TLGetObjectAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext contactId:(nonnull NSUUID *)contactId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block;

@end

@interface TLGetGroupAction : TLGetObjectAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext groupId:(nonnull NSUUID *)groupId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroup * _Nullable group))block;

@end

@interface TLGetInvitationAction : TLGetObjectAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext invitationId:(nonnull NSUUID *)invitationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvitation * _Nullable invitation))block;

@end

@interface TLGetCallReceiverAction : TLGetObjectAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext callReceiverId:(nonnull NSUUID *)callReceiverId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLCallReceiver * _Nullable callReceiver))block;

@end
