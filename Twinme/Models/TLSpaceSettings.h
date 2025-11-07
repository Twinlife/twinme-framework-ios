/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageId.h>
#import "TLSettings.h"

//
// Interface: TLSpaceSettings
//

@interface TLSpaceSettings : TLSettings <TLRepositoryObject>

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property (readonly, nonnull) NSUUID *uuid;
@property (readonly) int64_t creationDate;
@property int64_t modificationDate;
@property (nullable) TLTwincodeInbound *twincodeInbound;
@property (nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nullable) NSUUID *twincodeFactoryId;

/// The space name.
@property (nonnull) NSString *name;

/// The space style.
@property (nullable) NSString *style;

/// True to allow messages to be copied.
@property BOOL messageCopyAllowed;

/// True to allow files and images to be copied.
@property BOOL fileCopyAllowed;

/// True when the space is a secret space.
@property BOOL isSecret;

/// The space avatar configured by the user.
@property (nullable) NSUUID *avatarId;

- (nullable instancetype)initWithName:(nonnull NSString *)name settings:(nullable TLSpaceSettings *)settings;

- (nullable instancetype)initWithSettings:(nonnull TLSpaceSettings *)settings;

- (void)copyWithSettings:(nonnull TLSpaceSettings *)settings;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

/// Internal method to check if the Space name must be changed to use a new application default (ie, "Default" -> "General").
- (BOOL)fixSpaceSettingName;

+ (nonnull NSUUID *)SCHEMA_ID;

/// Set the default space settings (used for migrating SpaceSettings V1 to SpaceSettings V2).
+ (void)setDefaultSpaceSettingsWithSettings:(nonnull TLSpaceSettings *)settings oldDefaultName:(nonnull NSString *)oldDefaultName;

@end
