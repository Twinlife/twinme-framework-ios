/*
 *  Copyright (c) 2020-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

#import <Twinlife/TLConversationService.h>
#import "TLRoomCommand.h"
#import "TLRoomConfig.h"

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
*   {"name":"action", "type":"enum"}
*   {"name":"text", [null, "type":"string"]}
*   {"name":"image", [null, "type":"bitmap"]}
*   {"name":"descriptorId", [null, {
*     {"name":"id", "type":"uuid"},
*     {"name":"sequenceId", "type":"int""}
*   },
*   {"name":"twincodeOutboundId", [null, "type":"UUID"]}
*  ]
* }
*
* </pre>
*/

static NSUUID *TL_ROOM_COMMAND_SCHEMA_ID = nil;
static int TL_ROOM_COMMAND_SCHEMA_VERSION = 1;

#define CONVERSATION_SERVICE_MIN_MAJOR_VERSION 2
#define CONVERSATION_SERVICE_MIN_MINOR_VERSION 11

@interface TLRoomCommand ()

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action text:(nullable NSString *)text image:(nullable UIImage *)image messageId:(nullable TLDescriptorId *)messageId twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId list:(nullable NSArray<NSUUID *> *)list config:(nullable TLRoomConfig *)config;

@end

//
// Implementation: TLRoomCommandSerializer
//

@implementation TLRoomCommandSerializer : TLSerializer

+ (void)initialize {
    
    TL_ROOM_COMMAND_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"110cb974-1abc-4928-a6e6-dccdca0f3ab4"];
}

- (nonnull instancetype)init {
    
    self = [super initWithSchemaId:TL_ROOM_COMMAND_SCHEMA_ID schemaVersion:TL_ROOM_COMMAND_SCHEMA_VERSION class:[TLRoomCommand class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    TLRoomCommand *command = (TLRoomCommand *)object;

    [encoder writeLong:command.requestId];
    switch (command.action) {
        case TLRoomCommandActionSetName:
            [encoder writeEnum:0];
            break;

        case TLRoomCommandActionSetImage:
            [encoder writeEnum:1];
            break;

        case TLRoomCommandActionSetWelcome:
            [encoder writeEnum:2];
            break;

        case TLRoomCommandActionDeleteMessage:
            [encoder writeEnum:3];
            break;

        case TLRoomCommandActionForwardMessage:
            [encoder writeEnum:4];
            break;

        case TLRoomCommandActionBlockSender:
            [encoder writeEnum:5];
            break;

        case TLRoomCommandActionDeleteMember:
            [encoder writeEnum:6];
            break;

        case TLRoomCommandActionSetAdministrator:
            [encoder writeEnum:7];
            break;

        case TLRoomCommandActionSetConfig:
            [encoder writeEnum:8];
            break;

        case TLRoomCommandActionListMembers:
            [encoder writeEnum:9];
            break;

        case TLRoomCommandActionSetRoles:
            [encoder writeEnum:10];
            break;

        case TLRoomCommandActionRenewTwincode:
            [encoder writeEnum:12];
            break;

        case TLRoomCommandActionGetConfig:
            [encoder writeEnum:13];
            break;

        case TLRoomCommandActionSignalMember:
            [encoder writeEnum:14];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
    if (!command.text) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeString:command.text];
    }
    if (!command.messageId) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:command.messageId.twincodeOutboundId];
        [encoder writeLong:command.messageId.sequenceId];
    }
    if (!command.image) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        NSData *data = UIImagePNGRepresentation(command.image);
        [encoder writeData:data];
    }
    if (!command.twincodeOutboundId) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:command.twincodeOutboundId];
    }

    if (command.action == TLRoomCommandActionSetRoles) {
        if (!command.list) {
            [encoder writeLong:0];
        } else {
            [encoder writeLong:command.list.count];
            for (NSUUID *memberId in command.list) {
                [encoder writeUUID:memberId];
            }
        }
    } else if (command.action == TLRoomCommandActionSetConfig) {
        if (!command.roomConfig) {
            [encoder writeEnum:0];
        } else {
            [encoder writeEnum:1];
            [TLRoomConfig serializeWithEncoder:encoder config:command.roomConfig];
        }
    }

}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    TLRoomCommandAction action;
    int64_t requestId = [decoder readLong];
    int value = [decoder readEnum];
    switch (value) {
        case 0:
            action = TLRoomCommandActionSetName;
            break;
        
        case 1:
            action = TLRoomCommandActionSetImage;
            break;
        
        case 2:
            action = TLRoomCommandActionSetWelcome;
            break;
        
        case 3:
            action = TLRoomCommandActionDeleteMessage;
            break;
        
        case 4:
            action = TLRoomCommandActionForwardMessage;
            break;
        
        case 5:
            action = TLRoomCommandActionBlockSender;
            break;

        case 6:
            action = TLRoomCommandActionDeleteMember;
            break;

        case 7:
            action = TLRoomCommandActionSetAdministrator;
            break;

        case 8:
            action = TLRoomCommandActionSetConfig;
            break;

        case 9:
            action = TLRoomCommandActionListMembers;
            break;

        case 10:
            action = TLRoomCommandActionSetRoles;
            break;

        case 12:
            action = TLRoomCommandActionRenewTwincode;
            break;

        case 13:
            action = TLRoomCommandActionGetConfig;
            break;

        case 14:
            action = TLRoomCommandActionSignalMember;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }

    NSString* text;
    if ([decoder readEnum] == 1) {
        text = [decoder readString];
    } else {
        text = nil;
    }
    UIImage *image;
    if ([decoder readEnum] == 1) {
        NSData *data = [decoder readData];
        image = [UIImage imageWithData:data];
    } else {
        image = nil;
    }
    TLDescriptorId *messageId;
    if ([decoder readEnum] == 1) {
        NSUUID *twincodeOutboundId = [decoder readUUID];
        int64_t sequenceId = [decoder readLong];
        messageId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
    } else {
        messageId = nil;
    }
    NSUUID *twincodeOutboundId;
    if ([decoder readEnum] == 1) {
        twincodeOutboundId = [decoder readUUID];
    } else {
        twincodeOutboundId = nil;
    }
    NSMutableArray<NSUUID *> *list = nil;
    if (action == TLRoomCommandActionSetRoles) {
        int64_t count = [decoder readLong];
        if (count > 0) {
            list = [[NSMutableArray alloc] initWithCapacity:(int)count];
            while (count > 0) {
                [list addObject:[decoder readUUID]];
                count--;
            }
        }
    }
    TLRoomConfig *roomConfig = nil;
    if (action == TLRoomCommandActionSetConfig) {
        if ([decoder readEnum] != 0) {
            roomConfig = [TLRoomConfig deserializeWithDecoder:decoder];
        }
    }
    return [[TLRoomCommand alloc] initWithRequestId:requestId action:action text:text image:image messageId:messageId twincodeOutboundId:twincodeOutboundId list:list config:roomConfig];
}

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion {

    return majorVersion == CONVERSATION_SERVICE_MIN_MAJOR_VERSION && minorVersion >= CONVERSATION_SERVICE_MIN_MINOR_VERSION;
}

@end

//
// Implementation: TLRoomCommand
//

@implementation TLRoomCommand

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action text:(nonnull NSString *)text {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _text = text;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action image:(nonnull UIImage *)image {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _image = image;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action messageId:(nonnull TLDescriptorId *)messageId {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _messageId = messageId;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _twincodeOutboundId = twincodeOutboundId;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action text:(nullable NSString *)text image:(nullable UIImage *)image messageId:(nullable TLDescriptorId *)messageId twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId list:(nullable NSArray<NSUUID *> *)list config:(nullable TLRoomConfig *)config {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _text = text;
        _image = image;
        _messageId = messageId;
        _twincodeOutboundId = twincodeOutboundId;
        _list = list;
        _roomConfig = config;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action text:(nonnull NSString *)text list:(nonnull NSArray<NSUUID *> *)list {

    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _text = text;
        _list = list;
    }
    return self;
}

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action config:(nonnull TLRoomConfig *)config {
    
    self = [super init];
    if (self) {
        _requestId = requestId;
        _action = action;
        _roomConfig = config;
    }
    return self;
}

@end
