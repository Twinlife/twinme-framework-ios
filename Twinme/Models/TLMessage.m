/*
 *  Copyright (c) 2015-2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

#import "TLMessage.h"

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "type":"record",
 *  "name":"Message",
 *  "namespace":"org.twinlife.twinme.schemas",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"content", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */

static NSUUID *TL_MESSAGE_SCHEMA_ID = nil;
static int TL_MESSAGE_SCHEMA_VERSION = 1;

//
// Implementation: TLMessageSerializer
//

@implementation TLMessageSerializer : TLSerializer

+ (void)initialize {
    
    TL_MESSAGE_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"c1ba9e82-43a7-413a-ab9f-b743859e7595"];
}

- (instancetype)init {
    
    self = [super initWithSchemaId:TL_MESSAGE_SCHEMA_ID schemaVersion:TL_MESSAGE_SCHEMA_VERSION class:[TLMessage class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    TLMessage *message = (TLMessage *)object;
    [encoder writeString:message.content];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    NSString *content = [decoder readString];
    
    return [[TLMessage alloc] initWithContent:content];
}

@end

//
// Implementation: TLMessage
//

@implementation TLMessage

- (instancetype)initWithContent:(NSString *)content {
    
    self = [super init];
    if (self) {
        _content = content;
    }
    return self;
}

@end
