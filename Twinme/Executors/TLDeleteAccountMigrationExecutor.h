/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLDeleteAccountMigrationExecutor
//

@class TLTwinmeContext;
@class TLAccountMigration;

@interface TLDeleteAccountMigrationExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext accountMigration:(nonnull TLAccountMigration *)accountMigration withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable accountMigrationId))block;

@end
