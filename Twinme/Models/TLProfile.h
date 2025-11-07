/*
 *  Copyright (c) 2016-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeRepositoryObject.h"

//
// Interface: TLProfile
//

@class TLCapabilities;

typedef enum {
    // Do not update contact's identity when profile is changed
    TLProfileUpdateModeNone,

    // Update contact's identity that are synchronized with the profile.
    TLProfileUpdateModeDefault,

    // Update every contact's identity of the space associated with the profile.
    TLProfileUpdateModeAll
} TLProfileUpdateMode;

@interface TLProfile : TLTwinmeObject

@property int64_t priority;
@property (weak, nullable) TLSpace *space;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

- (BOOL)hasPublicIdentity;

- (BOOL)checkInvariants;

/// Get the our own capabilities describing the operations we allow from the peer.
- (nonnull TLCapabilities *)identityCapabilities;

@end
