/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLGetPushNotificationContentExecutor
//

@class TLTwinmeContext;
@class TLPushNotificationContent;

@interface TLGetPushNotificationContentExecutor : NSObject

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext dictionaryPayload:(nonnull NSDictionary *)dictionaryPayload withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, TLPushNotificationContent * _Nullable notificationContent))block;

- (void)start;

@end
