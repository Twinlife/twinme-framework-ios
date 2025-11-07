/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteObjectExecutor.h"

//
// Interface: TLDeleteGroupExecutor
//

@class TLTwinmeContext;
@class TLGroup;

@interface TLDeleteGroupExecutor : TLDeleteObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group timeout:(NSTimeInterval)timeout;

@end
