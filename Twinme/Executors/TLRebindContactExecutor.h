/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLRebindContactExecutor
//

@class TLTwinmeContext;
@class TLPairBindInvocation;

@interface TLRebindContactExecutor : TLAbstractConnectedTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext peerTwincodeId:(nonnull NSUUID *)peerTwincodeId;

@end
