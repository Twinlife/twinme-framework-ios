/*
 *  Copyright (c) 2015-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLTwincode.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLVersion.h>

#import "TLTwinmeAttributes.h"

#import "UIImage+Resize.h"
#import "UIImage+ToData.h"

// Twincode Attributes

#define TWINCODE_ATTRIBUTE_NAME @"name"
#define TWINCODE_ATTRIBUTE_AVATAR_ID @"avatarId"
#define TWINCODE_ATTRIBUTE_TWINCODE_OUTBOUND_ID @"twincodeOutboundId"
#define TWINCODE_ATTRIBUTE_CREATED_BY @"created-by"
#define TWINCODE_ATTRIBUTE_INVITED_BY @"invited-by"
#define TWINCODE_ATTRIBUTE_CHANNEL @"channel"
#define TWINCODE_ATTRIBUTE_PERMISSIONS @"permissions"
#define TWINCODE_ATTRIBUTE_TWINROOM @"twinroom"
#define TWINCODE_ATTRIBUTE_ROLE @"role"
#define TWINCODE_ATTRIBUTE_ACCOUNT_MIGRATION @"accountMigration"

@implementation TLAccountMigrationVersion

- (nonnull instancetype)initWithVersion:(nonnull TLVersion *)version hasRelations:(BOOL)hasRelations {
    self = [[TLAccountMigrationVersion alloc] init];
    
    if (self) {
        _version = version;
        _hasRelations = hasRelations;
    }
    
    return self;
}

@end

//
// Implementation: TwinmeAttributes
//

@implementation TLTwinmeAttributes

+ (UIImage *)DEFAULT_AVATAR {
    
    return [UIImage imageNamed:@"anonymous"];
}

+ (UIImage *)DEFAULT_GROUP_AVATAR {
    
    return [UIImage imageNamed:@"anonymous_group_avatar"];
}

+ (void)setTwincodeAttributeName:(NSMutableArray *)attributes name:(NSString*)name {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_NAME stringValue:name]];
}

+ (NSUUID *)getTwincodeOutboundId:(TLTwincode *)twincode {
    
    NSString *value = (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_TWINCODE_OUTBOUND_ID];
    if (value == nil) {
        return nil;
    }
    return [[NSUUID alloc] initWithUUIDString:value];
}

+ (nullable NSUUID *)getChannelIdFromTwincode:(nonnull TLTwincode *)twincode {

    NSString *value = (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_TWINCODE_OUTBOUND_ID];
    if (value == nil) {
        return nil;
    }
    return [[NSUUID alloc] initWithUUIDString:value];
}

+ (void)setTwincodeAttributeImageId:(NSMutableArray *)attributes imageId:(TLExportedImageId*)imageId {
    
    if (imageId) {
        [attributes addObject:[[TLAttributeNameImageIdValue alloc] initWithName:TWINCODE_ATTRIBUTE_AVATAR_ID imageId:imageId]];
    }
}

+ (void)setTwincodeAttributeCreatedBy:(NSMutableArray *)attributes twincodeId:(NSUUID*) twincodeId {
    
    if (twincodeId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_CREATED_BY stringValue:[twincodeId UUIDString]]];
    }
}

+ (nullable NSUUID *)getCreatedByFromTwincode:(nonnull TLTwincode *)twincode {

    NSString *value = (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_CREATED_BY];
    if (value == nil) {
        return nil;
    }
    return [[NSUUID alloc] initWithUUIDString:value];
}

+ (void)setTwincodeAttributeInvitedBy:(nonnull NSMutableArray *)attributes twincodeId:(nonnull NSUUID*) twincodeId {

    if (twincodeId) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_INVITED_BY stringValue:[twincodeId UUIDString]]];
    }
}

+ (nullable NSUUID *)getInvitedByFromTwincode:(nonnull TLTwincode *)twincode {

    NSString *value = (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_INVITED_BY];
    if (value == nil) {
        return nil;
    }
    return [[NSUUID alloc] initWithUUIDString:value];
}

+ (nullable NSString *)getPermissionsFromTwincode:(nonnull TLTwincode *)twincode {

    return (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_PERMISSIONS];
}

+ (void)setTwincodeAttributeDescription:(nonnull NSMutableArray *)attributes description:(nonnull NSString*)description {
    
    if (description) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_DESCRIPTION stringValue:description]];
    }
}

+ (nullable NSString *)getTwinroomFromTwincode:(nonnull TLTwincode *)twincode {
    
    return (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_TWINROOM];
}

+ (nullable NSString *)getRoleFromTwincode:(nonnull TLTwincode *)twincode {
    
    return (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_ROLE];
}

+ (void)setTwincodeAttributeCapabilities:(nonnull NSMutableArray *)attributes capabilities:(nonnull NSString*)capabilities {
    
    if (capabilities) {
        [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_CAPABILITIES stringValue:capabilities]];
    }
}

+ (void)setTwincodeAttributeAccountMigration:(nonnull NSMutableArray *)attributes name:(nonnull NSString*)name hasRelations:(BOOL)hasRelations{
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_ACCOUNT_MIGRATION stringValue:[NSString stringWithFormat:@"%@%@", name, hasRelations ? @":1" : @":0"]]];
}

+ (nonnull TLAccountMigrationVersion *)getTwincodeAttributeAccountMigrationWithTwincode:(nonnull TLTwincodeOutbound *)twincode {
    NSObject *value = [twincode getAttributeWithName:TWINCODE_ATTRIBUTE_ACCOUNT_MIGRATION];
    
    if (![value isKindOfClass:NSString.class]) {
        return [[TLAccountMigrationVersion alloc] initWithVersion:[[TLVersion alloc] initWithVersion:@"0.0.0"] hasRelations:YES];
    }

    NSArray<NSString *> *items = [(NSString *)value componentsSeparatedByString:@":"];
    TLVersion *version = [[TLVersion alloc] initWithVersion:items[0]];
    BOOL hasRelations = YES;
    if (items.count == 2) {
        hasRelations = [@"1" isEqualToString:items[1]];
    }
    
    return [[TLAccountMigrationVersion alloc] initWithVersion:version hasRelations:hasRelations];
}


@end
