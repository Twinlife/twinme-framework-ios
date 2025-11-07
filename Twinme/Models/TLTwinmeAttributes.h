/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#define TWINCODE_ATTRIBUTE_DESCRIPTION @"description"
#define TWINCODE_ATTRIBUTE_CAPABILITIES @"capabilities"

//
// Interface: TLTwinmeAttributes
//

@class TLTwincode;
@class TLTwincodeOutbound;
@class TLExportedImageId;
@class TLVersion;

@interface TLAccountMigrationVersion : NSObject

@property (nonatomic, readonly, nonnull) TLVersion *version;
@property (nonatomic, readonly) BOOL hasRelations;

- (nonnull instancetype)initWithVersion:(nonnull TLVersion *)version hasRelations:(BOOL)hasRelations;

@end

@interface TLTwinmeAttributes : NSObject

+ (nullable UIImage *)DEFAULT_AVATAR;

+ (nullable UIImage *)DEFAULT_GROUP_AVATAR;

+ (void)setTwincodeAttributeName:(nonnull NSMutableArray *)attributes name:(nonnull NSString*) name;

+ (nullable NSUUID *)getTwincodeOutboundId:(nonnull TLTwincode *)twincode;

+ (nullable NSUUID *)getChannelIdFromTwincode:(nonnull TLTwincode *)twincode;

+ (void)setTwincodeAttributeImageId:(nonnull NSMutableArray *)attributes imageId:(nullable TLExportedImageId*)imageId;

+ (void)setTwincodeAttributeCreatedBy:(nonnull NSMutableArray *)attributes twincodeId:(nonnull NSUUID*) twincodeId;

+ (nullable NSUUID *)getCreatedByFromTwincode:(nonnull TLTwincode *)twincode;

+ (void)setTwincodeAttributeInvitedBy:(nonnull NSMutableArray *)attributes twincodeId:(nonnull NSUUID*) twincodeId;

+ (nullable NSUUID *)getInvitedByFromTwincode:(nonnull TLTwincode *)twincode;

+ (nullable NSString *)getPermissionsFromTwincode:(nonnull TLTwincode *)twincode;

+ (void)setTwincodeAttributeDescription:(nonnull NSMutableArray *)attributes description:(nonnull NSString*)description;

+ (nullable NSString *)getTwinroomFromTwincode:(nonnull TLTwincode *)twincode;

+ (nullable NSString *)getRoleFromTwincode:(nonnull TLTwincode *)twincode;

+ (void)setTwincodeAttributeCapabilities:(nonnull NSMutableArray *)attributes capabilities:(nonnull NSString*)capabilities;

+ (void)setTwincodeAttributeAccountMigration:(nonnull NSMutableArray *)attributes name:(nonnull NSString*)name hasRelations:(BOOL)hasRelations;

+ (nonnull TLAccountMigrationVersion *)getTwincodeAttributeAccountMigrationWithTwincode:(nonnull TLTwincodeOutbound *)twincode;
@end
