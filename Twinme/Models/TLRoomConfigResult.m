/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

#import <Twinlife/TLConversationService.h>
#import "TLRoomConfigResult.h"

/*
* <pre>
*
* Schema version 1
*
* {
*  "type":"record",
*  "name":"RoomCommand",
*  "namespace":"org.twinlife.twinme.schemas",
*  "fields":
*  [
*   {"name":"schemaId", "type":"uuid"},
*   {"name":"schemaVersion", "type":"int"}
*   {"name":"requestId", "type":"long"}
*   {"name":"status", "type":"enum"}
*  ]
* }
*
* </pre>
*/

static NSUUID *TL_ROOM_CONFIG_RESULT_SCHEMA_ID = nil;
static int TL_ROOM_CONFIG_RESULT_SCHEMA_VERSION = 1;

#define CONVERSATION_SERVICE_MIN_MAJOR_VERSION 2
#define CONVERSATION_SERVICE_MIN_MINOR_VERSION 11

//
// Implementation: TLRoomConfigResultSerializer
//

@implementation TLRoomConfigResultSerializer : TLSerializer

+ (void)initialize {
    
    TL_ROOM_CONFIG_RESULT_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"a9a2a78b-b224-4aab-b61b-1a8ed17b80a7"];
}

- (nonnull instancetype)init {
    
    self = [super initWithSchemaId:TL_ROOM_CONFIG_RESULT_SCHEMA_ID schemaVersion:TL_ROOM_CONFIG_RESULT_SCHEMA_VERSION class:[TLRoomConfigResult class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    TLRoomCommandStatus status;
    int64_t requestId = [decoder readLong];
    int value = [decoder readEnum];
    switch (value) {
        case 0:
            status = TLRoomCommandStatusSuccess;
            break;
        
        case 1:
            status = TLRoomCommandStatusError;
            break;
        
        case 2:
            status = TLRoomCommandStatusBadCommand;
            break;
        
        case 3:
            status = TLRoomCommandStatusPermissionDenied;
            break;

        case 4:
            status = TLRoomCommandStatusItemNotFound;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }

    TLRoomConfig* roomConfig = nil;
    if ([decoder readEnum]) {
        roomConfig = [TLRoomConfig deserializeWithDecoder:decoder];
    }

    return [[TLRoomConfigResult alloc] initWithRequestId:requestId status:status config:roomConfig];
}

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion {

    return majorVersion == CONVERSATION_SERVICE_MIN_MAJOR_VERSION && minorVersion >= CONVERSATION_SERVICE_MIN_MINOR_VERSION;
}

@end

//
// Implementation: TLRoomConfigResult
//

@implementation TLRoomConfigResult

- (nonnull instancetype)initWithRequestId:(int64_t)requestId status:(TLRoomCommandStatus)status config:(nullable TLRoomConfig *)config {
    
    self = [super initWithRequestId:requestId status:status memberIds:nil];
    if (self) {
        _roomConfig = config;
    }
    return self;
}

@end
