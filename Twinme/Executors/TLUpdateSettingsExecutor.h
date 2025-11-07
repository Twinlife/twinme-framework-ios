/*
 *  Copyright (c) 2022-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAbstractTwinmeExecutor.h"

//
// Interface: TLUpdateSettingsExecutor
//

@class TLTwinmeContext;
@class TLSpaceSettings;

@interface TLUpdateSettingsExecutor : TLAbstractTwinmeExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpaceSettings * _Nullable settings))block;

@end
