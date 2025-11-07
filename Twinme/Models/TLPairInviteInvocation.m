/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPairInviteInvocation.h"

//
// Implementation: TLPairInviteInvocation
//

@implementation TLPairInviteInvocation

- (nonnull instancetype)initWithId:(nonnull NSUUID*)uuid receiver:(nonnull id<TLRepositoryObject>)receiver twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    
    self = [super initWithId:uuid receiver:receiver background:true];
    if (self) {
        _twincodeOutbound = twincodeOutbound;
    }
    return self;
}

@end

