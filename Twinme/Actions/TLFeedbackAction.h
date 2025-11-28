/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinmeAction.h"

/**
 * Interface: TLFeedbackAction
 *
 * A Twinme action to send a user feedback (guarded by a timeout).
 *
 */
@interface TLFeedbackAction : TLTwinmeAction

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext email:(nonnull NSString *)email subject:(nonnull NSString *)subject description:(nonnull NSString *)description sendLogReport:(BOOL)sendLogReport withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode))block;

@end
