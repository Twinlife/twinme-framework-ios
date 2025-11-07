/*
 *  Copyright (c) 2018-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLGetGroupMemberExecutor
//

@class TLTwinmeContext;
@class TLGroup;
@class TLGroupMember;
@protocol TLOriginator;

@interface TLGetGroupMemberExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext owner:(nonnull id<TLOriginator>)owner groupMemberTwincodeId:(nonnull NSUUID *)groupMemberTwincodeId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupMember * _Nullable groupMember))block;

@end
