/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLBindAccountMigrationExecutor
//

@class TLTwinmeContext;
@class TLAccountMigration;

@interface TLBindAccountMigrationExecutor : TLAbstractConnectedTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId invocationId:(nonnull NSUUID *)invocationId accountMigration:(nonnull TLAccountMigration *)accountMigration peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId;


- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext accountMigration:(nonnull TLAccountMigration *)accountMigration peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound consumer:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))consumer;
@end
