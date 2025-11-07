/*
 *  Copyright (c) 2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>
#import <Twinlife/TLBinaryDecoder.h>

#import "TLPushNotificationContent.h"

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/04/26
 *
 * {
 *  "type":"record",
 *  "name":"NotificationContent",
 *  "namespace":"org.twinlife.schemas.services",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"sessionId", "type":"uuid"}
 *   {"name":"twincodeInboundId", "type":"uuid"}
 *   {"name":"priority", [null, "type":"string"]}
 *   {"name":"operation", [null, "type":"string"]}
 * }
 *
 * </pre>
 */
static NSUUID *TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_ID = nil;
static int TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_VERSION = 1;
static TLSerializer *TL_PUSH_NOTIFICATION_CONTENT_SERIALIZER = nil;

//
// Implementation: TLPushNotificationContentSerializer
//

@implementation TLPushNotificationContentSerializer : TLSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_ID schemaVersion:TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_VERSION class:[TLNotificationContent class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];

    TLPushNotificationContent *notificationContent = (TLPushNotificationContent *)object;
    [encoder writeUUID:notificationContent.sessionId];
    [encoder writeUUID:notificationContent.twincodeInboundId];
    switch (notificationContent.priority) {
        case TLPeerConnectionServiceNotificationPriorityHigh:
            [encoder writeString:@"high"];
            break;

        case TLPeerConnectionServiceNotificationPriorityLow:
            [encoder writeString:@"low"];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
    switch (notificationContent.operation) {
        case TLPeerConnectionServiceNotificationOperationAudioCall:
            [encoder writeString:@"audio-call"];
            break;

        case TLPeerConnectionServiceNotificationOperationVideoCall:
            [encoder writeString:@"video-call"];
            break;

        case TLPeerConnectionServiceNotificationOperationVideoBell:
            [encoder writeString:@"video-bell"];
            break;

        case TLPeerConnectionServiceNotificationOperationPushMessage:
            [encoder writeString:@"push-message"];
            break;

        case TLPeerConnectionServiceNotificationOperationPushFile:
            [encoder writeString:@"push-file"];
            break;

        case TLPeerConnectionServiceNotificationOperationPushImage:
            [encoder writeString:@"push-image"];
            break;

        case TLPeerConnectionServiceNotificationOperationPushAudio:
            [encoder writeString:@"push-audio"];
            break;

        case TLPeerConnectionServiceNotificationOperationPushVideo:
            [encoder writeString:@"push-video"];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    NSUUID *sessionId = [decoder readUUID];
    NSUUID *twincodeInboundId = [decoder readUUID];
    NSString *value = [decoder readString];

    TLPeerConnectionServiceNotificationPriority priority;

    if ([@"high" isEqualToString:value]) {
        priority = TLPeerConnectionServiceNotificationPriorityHigh;
    } else if ([@"low" isEqualToString:value]) {
        priority = TLPeerConnectionServiceNotificationPriorityLow;
    } else {
        priority = TLPeerConnectionServiceNotificationPriorityNotDefined;
    }

    value = [decoder readString];
    TLPeerConnectionServiceNotificationOperation operation;

    if ([@"audio-call" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationAudioCall;
    } else if ([@"video-call" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationVideoCall;
    } else if ([@"video-bell" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationVideoBell;
    } else if ([@"push-message" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationPushMessage;
    } else if ([@"push-file" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationPushFile;
    } else if ([@"push-image" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationPushImage;
    } else if ([@"push-audio" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationPushAudio;
    } else if ([@"push-video" isEqualToString:value]) {
        operation = TLPeerConnectionServiceNotificationOperationPushVideo;
    } else {
        operation = TLPeerConnectionServiceNotificationOperationNotDefined;
    }

    return [[TLPushNotificationContent alloc] initWithSessionId:sessionId twincodeInboundId:twincodeInboundId priority:priority operation:operation];
}

@end

//
// Implementation: TLPushNotificationContent
//

@implementation TLPushNotificationContent

+ (void)initialize {
    
    TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"946fb7cd-f8d2-46a8-a1d2-6d9f3aa0accd"];
    TL_PUSH_NOTIFICATION_CONTENT_SERIALIZER = [[TLPushNotificationContentSerializer alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_ID;
}

+ (int )SCHEMA_VERSION {
    
    return TL_PUSH_NOTIFICATION_CONTENT_SCHEMA_VERSION;
}

+ (nonnull TLSerializer *)SERIALIZER {
    
    return TL_PUSH_NOTIFICATION_CONTENT_SERIALIZER;
}

- (nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId priority:(TLPeerConnectionServiceNotificationPriority)priority operation:(TLPeerConnectionServiceNotificationOperation)operation {

    self = [super init];
    if (self) {
        _sessionId = sessionId;
        _twincodeInboundId = twincodeInboundId;
        _priority = priority;
        _operation = operation;
    }
    return self;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"\nPushNotificationContent\n"];
    [string appendFormat:@" sessionId:         %@\n", [self.sessionId UUIDString]];
    [string appendFormat:@" twincodeInboundId: %@\n", [self.twincodeInboundId UUIDString]];
    [string appendFormat:@" priority:          %d\n", self.priority];
    [string appendFormat:@" operation:         %d\n", self.operation];
    return string;
}

@end
