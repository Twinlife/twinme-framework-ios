/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSpaceSettings.h"
#import "TLTwinmeRepositoryObject.h"

typedef enum {
    TLSpacePermissionTypeShareSpaceCard = 0,
    TLSpacePermissionTypeCreateContact,
    TLSpacePermissionTypeMoveContact,
    TLSpacePermissionTypeCreateGroup,
    TLSpacePermissionTypeMoveGroup,
    TLSpacePermissionTypeCopyAllowed,
    TLSpacePermissionTypeUpdateIdentity
} TLSpacePermissionType;

//
// Interface: TLSpace
//

@class TLRepositoryService;
@class TLTwincodeOutbound;
@class TLProfile;
@protocol TLOriginator;

@interface TLSpace : TLTwinmeObject

/// The space settings.
@property (nullable) TLSpaceSettings *settings;

/// The user's profile within the space.
@property (nullable) TLProfile *profile;

/// The user's profile ID within the space.
@property (nullable) NSUUID *profileId;

/// The optional space twincode found using the space twincode Id.
@property (nullable) TLTwincodeOutbound *spaceTwincode;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

/// The optional space avatar image (configured by the user).
- (nullable NSUUID *)avatarId;

/// Returns true if the originator belongs to the space.
- (BOOL)isOwner:(nonnull id<TLOriginator>)originator;

/// Returns true if the space is managed.
- (BOOL)isManagedSpace;

/// Check if the permission is granted on the space for the user.
- (BOOL)hasPermission:(TLSpacePermissionType)permission;

@end
