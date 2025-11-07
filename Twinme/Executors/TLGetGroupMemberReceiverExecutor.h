/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLGetGroupMemberReceiverExecutor
//

@class TLTwinmeContext;

@interface TLGetGroupMemberReceiverExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext twincodeInboundId:(nonnull NSUUID *)twincodeInboundId memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id _Nullable receiver))block;

@end
