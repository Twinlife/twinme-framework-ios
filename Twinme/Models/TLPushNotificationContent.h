/*
 *  Copyright (c) 2019-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLSerializer.h>

@protocol TLOriginator;

//
// Interface: TLPushNotificationContentSerializer
//

@interface TLPushNotificationContentSerializer : TLSerializer

@end

//
// Interface: TLPushNotificationContent
//

/**
 * Notification content
 *
 * Describes an incoming notification that is received either from PushKit or APNS.
 */
@interface TLPushNotificationContent : NSObject

@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly, nonnull) NSUUID *twincodeInboundId;
@property (readonly) TLPeerConnectionServiceNotificationPriority priority;
@property (readonly) TLPeerConnectionServiceNotificationOperation operation;
@property (nullable) id<TLOriginator> originator;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (nonnull TLSerializer *)SERIALIZER;

- (nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId priority:(TLPeerConnectionServiceNotificationPriority)priority operation:(TLPeerConnectionServiceNotificationOperation)operation;

@end
