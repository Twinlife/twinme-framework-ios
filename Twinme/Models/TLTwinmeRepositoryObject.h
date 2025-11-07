/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLRepositoryService.h>
#import "TLOriginator.h"

@class TLDatabaseIdentifier;
@class TLTwincodeInbound;
@class TLTwincodeOutbound;
@class TLTwincodeFactory;
@class TLSpace;
@class TLAttributeNameValue;
@class TLImageId;

/**
 * Factory used by the RepositoryService to create Twinme objects.
 */
@interface TLTwinmeObjectFactory : NSObject

@property (readonly, nonnull) NSUUID *schemaId;
@property (readonly) int schemaVersion;
@property (readonly, nullable) id<TLRepositoryObjectFactory> ownerFactory;
@property (readonly) int twincodeUsage;

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion ownerFactory:(nullable id<TLRepositoryObjectFactory>)ownerFactory twincodeUsage:(int)twincodeUsage;

- (BOOL)isImmutable;

- (BOOL)isLocal;

@end

//
// Interface: TLTwinmeObject
//

@interface TLTwinmeObject : NSObject <TLRepositoryObject>

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property (readonly, nonnull) NSUUID *uuid;
@property (readonly) int64_t creationDate;
@property int64_t modificationDate;
@property (nullable) TLTwincodeInbound *twincodeInbound;
@property (nullable) TLTwincodeOutbound *twincodeOutbound;  // Profile, Contact, Group, CallReceiver identity
@property (nullable) NSUUID *twincodeFactoryId;             // Factory Id for twincodeInbound+twincodeOutbound

@property (nonatomic, nonnull) NSString *name;              // Contact, Group local name
@property (nonatomic, nonnull) NSString *objectDescription; // Contact, Group local description

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID*)uuid creationDate:(int64_t)creationDate modificationDate:(int64_t)modificationDate;

- (void)exportAttributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes name:(nullable NSString *)name description:(nullable NSString *)description twincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId space:(nullable TLSpace *)space;

- (void)setTwincodeFactory:(nonnull TLTwincodeFactory *)twincodeFactory;

- (nullable TLImageId *)avatarId;

- (nullable NSString *)identityName;

- (nullable NSString *)identityDescription;

- (nullable TLImageId *)identityAvatarId;

@end

//
// Interface: TLTwinmeOriginatorObject
//

@interface TLTwinmeOriginatorObject : TLTwinmeObject <TLOriginator>

@property double usageScore;
@property int64_t lastMessageDate;
@property (nullable) TLSpace *space;

@end
