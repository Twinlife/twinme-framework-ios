/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAbstractTwinmeExecutor.h"

@class TLTwinmeContext;
@class TLAccountMigration;

//
// Interface: TLCreateAccountMigrationExecutor
//

@interface TLCreateAccountMigrationExecutor : TLAbstractConnectedTwinmeExecutor

- (nullable instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))block;

@end
