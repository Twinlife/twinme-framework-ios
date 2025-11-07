/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOriginator.h"
#import "TLCapabilities.h"
#import "TLTwinmeRepositoryObject.h"

//
// Interface: TLCallReceiver
//

@interface TLCallReceiver : TLTwinmeOriginatorObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (nonnull NSUUID *)DUMMY_PEER_TWINCODE_OUTBOUND_ID;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

- (nullable NSString *)identityDescription;

- (BOOL)isTransfer;

@end
