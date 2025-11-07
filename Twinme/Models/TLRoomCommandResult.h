/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLSerializer.h>

typedef enum {
    TLRoomCommandStatusSuccess,
    TLRoomCommandStatusError,
    TLRoomCommandStatusBadCommand,
    TLRoomCommandStatusPermissionDenied,
    TLRoomCommandStatusItemNotFound
} TLRoomCommandStatus;

//
// Interface: TLRoomCommandResultSerializer
//

@interface TLRoomCommandResultSerializer : TLSerializer

@end

//
// Interface: TLRoomCommandResult
//

/**
 * Room command result.
 *
 * The `TLRoomCommandResult` object holds the response of a command sent by the Twinroom.
 */
@interface TLRoomCommandResult : NSObject

@property (readonly) int64_t requestId;
@property (readonly) TLRoomCommandStatus status;
@property (readonly, nullable) NSArray<NSUUID *> *memberIds;

- (nonnull instancetype)initWithRequestId:(int64_t)requestId status:(TLRoomCommandStatus)status memberIds:(nullable NSArray<NSUUID *> *)memberIds;

@end
