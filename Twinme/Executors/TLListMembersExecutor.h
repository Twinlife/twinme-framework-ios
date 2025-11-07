/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"
#import <Twinlife/TLConversationService.h>

//
// Interface: TLListMembersExecutor
//

@class TLTwinmeContext;
@class TLGroup;
@class TLGroupMember;
@protocol TLOriginator;

@interface TLListMembersExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext group:(nonnull TLGroup *)group filter:(TLGroupMemberFilterType)filter withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext owner:(nonnull id<TLOriginator>)owner memberTwincodeList:(nonnull NSMutableArray *)memberTwincodeList withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block;

@end
