/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeAction.h"

@protocol TLRepositoryObject;

/**
 * Interface: TLGetTwincodeAction
 *
 * A Twinme action to get a twincode name and avatar (guarded by a timeout).
 *
 */
@interface TLGetTwincodeAction : TLTwinmeAction

@property (nonatomic, readonly, nonnull) NSUUID *twincodeOutboundId;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSString * _Nullable name, UIImage * _Nullable avatar))block;


@end

@interface TLGetObjectAction : TLTwinmeAction

@property (nonatomic, readonly, nonnull) NSUUID *objectId;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext contactId:(nonnull NSUUID *)contactId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block;

@end

@interface TLGetContactAction : TLGetObjectAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext contactId:(nonnull NSUUID *)contactId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block;


@end
