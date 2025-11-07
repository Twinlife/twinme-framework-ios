/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLGroupRegisteredExecutor
//

@class TLTwinmeContext;
@class TLGroup;
@class TLGroupRegisteredInvocation;

@interface TLGroupRegisteredExecutor : NSObject

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId groupRegisteredInvocation:(nonnull TLGroupRegisteredInvocation *)groupRegisteredInvocation group:(nonnull TLGroup *)group;

- (void)start;

@end
