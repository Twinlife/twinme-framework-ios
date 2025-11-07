/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDeleteObjectExecutor.h"

//
// Interface: TLDeleteContactExecutor
//

@class TLTwinmeContext;
@class TLContact;

@interface TLDeleteContactExecutor : TLDeleteObjectExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId contact:(nonnull TLContact *)contact invocationId:(nullable NSUUID *)invocationId timeout:(NSTimeInterval)timeout;

@end
