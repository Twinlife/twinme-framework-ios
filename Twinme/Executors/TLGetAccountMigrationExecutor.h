/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLGetAccountMigrationExecutor
//

@class TLTwinmeContext;
@class TLAccountMigration;

@interface TLGetAccountMigrationExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext deviceMigrationId:(nonnull NSUUID *)deviceMigrationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))block;

@end
