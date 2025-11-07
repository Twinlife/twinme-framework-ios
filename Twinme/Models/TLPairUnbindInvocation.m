/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLPairUnbindInvocation.h"

//
// Implementation: TLPairUnbindInvocation
//

@implementation TLPairUnbindInvocation

- (nonnull instancetype)initWithId:(nonnull NSUUID*)uuid receiver:(nonnull id<TLRepositoryObject>)receiver {
    
    self = [super initWithId:uuid receiver:receiver background:true];
    return self;
}

@end
