/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupRegisteredInvocation.h"

//
// Implementation: TLGroupRegisteredInvocation
//

@implementation TLGroupRegisteredInvocation

- (nonnull instancetype)initWithId:(nonnull NSUUID *)uuid receiver:(nonnull id<TLRepositoryObject>)receiver adminMemberTwincode:(nonnull TLTwincodeOutbound *)adminMemberTwincode adminPermissions:(long)adminPermissions memberPermissions:(long)memberPermissions {

    self = [super initWithId:uuid receiver:receiver background:true];
    if (self) {
        _adminMemberTwincode = adminMemberTwincode;
        _adminPermissions = adminPermissions;
        _memberPermissions = memberPermissions;
    }
    return self;
}

@end
