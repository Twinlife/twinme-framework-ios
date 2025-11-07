/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTwinmeRepositoryObject.h"

//
// Interface: TLAccountMigration
//

@interface TLAccountMigration : TLTwinmeObject

@property (nonatomic) BOOL isBound;
@property (nullable, readonly) NSUUID *peerTwincodeOutboundId;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier*)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end
