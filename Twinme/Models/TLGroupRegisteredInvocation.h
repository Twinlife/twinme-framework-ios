/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLInvocation.h"

@class TLTwincodeOutbound;

//
// Interface: TLGroupRegisteredInvocation
//

@interface TLGroupRegisteredInvocation : TLInvocation

@property (readonly, nonnull) TLTwincodeOutbound *adminMemberTwincode;
@property (readonly) long adminPermissions;
@property (readonly) long memberPermissions;

- (nonnull instancetype)initWithId:(nonnull NSUUID *)uuid receiver:(nonnull id<TLRepositoryObject>)receiver adminMemberTwincode:(nonnull TLTwincodeOutbound *)adminMemberTwincode adminPermissions:(long)adminPermissions memberPermissions:(long)memberPermissions;

@end
