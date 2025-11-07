/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInvocation.h"

//
// Interface: TLPairUnbindInvocation
//

//
// version: 1.2
//

@interface TLPairUnbindInvocation : TLInvocation

- (nonnull instancetype)initWithId:(nonnull NSUUID*)uuid receiver:(nonnull id<TLRepositoryObject>)receiver;

@end
