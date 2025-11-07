/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLUpdateStatsExecutor
//

@class TLTwinmeContext;

@interface TLUpdateStatsExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId updateScore:(BOOL)updateScore;

@end
