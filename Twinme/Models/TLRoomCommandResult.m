/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

#import <Twinlife/TLConversationService.h>
#import "TLRoomCommandResult.h"

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

static NSUUID *TL_ROOM_COMMAND_RESULT_SCHEMA_ID = nil;
static int TL_ROOM_COMMAND_RESULT_SCHEMA_VERSION = 1;

#define CONVERSATION_SERVICE_MIN_MAJOR_VERSION 2
#define CONVERSATION_SERVICE_MIN_MINOR_VERSION 11

//
// Implementation: TLRoomCommandResultSerializer
//

@implementation TLRoomCommandResultSerializer : TLSerializer

+ (void)initialize {
    
    TL_ROOM_COMMAND_RESULT_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"c1124181-8360-49a0-8180-0f4802d1dc04"];
}

- (nonnull instancetype)init {
    
    self = [super initWithSchemaId:TL_ROOM_COMMAND_RESULT_SCHEMA_ID schemaVersion:TL_ROOM_COMMAND_RESULT_SCHEMA_VERSION class:[TLRoomCommandResult class]];
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

    int count = [decoder readInt];
    NSMutableArray<NSUUID *> *members = nil;
    
    if (count > 0) {
        members = [[NSMutableArray alloc] initWithCapacity:count];
        
        while (--count >= 0) {
            [members addObject:[decoder readUUID]];
        }
    }
    return [[TLRoomCommandResult alloc] initWithRequestId:requestId status:status memberIds:members];
}

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion {

    return majorVersion == CONVERSATION_SERVICE_MIN_MAJOR_VERSION && minorVersion >= CONVERSATION_SERVICE_MIN_MINOR_VERSION;
}

@end

//
// Implementation: TLRoomCommandResult
//

@implementation TLRoomCommandResult

- (nonnull instancetype)initWithRequestId:(int64_t)requestId status:(TLRoomCommandStatus)status memberIds:(nullable NSArray<NSUUID *> *)memberIds {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _status = status;
        _memberIds = memberIds;
    }
    return self;
}

@end
