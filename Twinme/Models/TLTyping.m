/*
 *  Copyright (c) 2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

#import "TLTyping.h"

/*
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "type":"record",
 *  "name":"Typing",
 *  "namespace":"org.twinlife.twinme.schemas",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"action", "type":"enum"}
 *  ]
 * }
 *
 * </pre>
 */
static NSUUID *TL_TYPING_SCHEMA_ID = nil;
static int TL_TYPING_SCHEMA_VERSION = 1;

#define CONVERSATION_SERVICE_MIN_MAJOR_VERSION 2
#define CONVERSATION_SERVICE_MIN_MINOR_VERSION 9

//
// Implementation: TLTypingSerializer
//

@implementation TLTypingSerializer : TLSerializer

+ (void)initialize {
    
    TL_TYPING_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"4d23a645-233b-4d8f-a9aa-2b15b37e2ba3"];
}

- (instancetype)init {
    
    self = [super initWithSchemaId:TL_TYPING_SCHEMA_ID schemaVersion:TL_TYPING_SCHEMA_VERSION class:[TLTyping class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    TLTyping *typing = (TLTyping *)object;
    switch (typing.action) {
        case TLTypingActionStop:
            [encoder writeEnum:0];
            break;

        case TLTypingActionStart:
            [encoder writeEnum:1];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLTypingAction action;
    int value = [decoder readEnum];
    switch (value) {
        case 0:
            action = TLTypingActionStop;
            break;
            
        case 1:
            action = TLTypingActionStart;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }

    return [[TLTyping alloc] initWithAction:action];
}

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion {

    return majorVersion == CONVERSATION_SERVICE_MIN_MAJOR_VERSION && minorVersion >= CONVERSATION_SERVICE_MIN_MINOR_VERSION;
}

@end

//
// Implementation: TLTyping
//

@implementation TLTyping

- (instancetype)initWithAction:(TLTypingAction)action {
    
    self = [super init];
    if (self) {
        _action = action;
    }
    return self;
}

@end
