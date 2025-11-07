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
// Implementation: TLInvocation
//

@implementation TLInvocation

- (nonnull instancetype)initWithId:(nonnull NSUUID*)uuid receiver:(nonnull id<TLRepositoryObject>)receiver background:(BOOL)background {
    
    self = [super init];
    if (self) {
        _uuid = uuid;
        _receiver = receiver;
        _background = background;
    }
    return self;
}

@end
