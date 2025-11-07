/*
 *  Copyright (c) 2019-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLExecutor.h"

//
// Interface: TLGetSpacesExecutor
//

@class TLTwinmeContext;

@interface TLGetSpacesExecutor : TLExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId enableSpaces:(BOOL)enableSpaces;

- (void)start;

@end
