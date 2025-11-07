/*
 *  Copyright (c) 2020-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLSerializer.h>

@class TLRoomConfig;

// Filters for the ROOM_LIST_MEMBERS command.
#define TL_ROOM_COMMAND_LIST_ROLE_ADMINISTRATOR @"admin"
#define TL_ROOM_COMMAND_LIST_ROLE_MEMBER @"member"
#define TL_ROOM_COMMAND_LIST_ROLE_MODERATOR @"moderator"
#define TL_ROOM_COMMAND_LIST_ROLE_MEMBER_ONLY @"member-only"
#define TL_ROOM_COMMAND_LIST_ALL @"all"

#define TL_ROOM_COMMAND_ROLE_ADMIN @"admin"
#define TL_ROOM_COMMAND_ROLE_MEMBER @"member"
#define TL_ROOM_COMMAND_ROLE_MODERATOR @"moderator"

typedef enum {
    TLRoomCommandActionSetName,
    TLRoomCommandActionSetImage,
    TLRoomCommandActionSetWelcome,
    TLRoomCommandActionDeleteMessage,
    TLRoomCommandActionForwardMessage,
    TLRoomCommandActionBlockSender,
    TLRoomCommandActionDeleteMember,
    TLRoomCommandActionSetAdministrator,
    TLRoomCommandActionSetConfig,
    TLRoomCommandActionSetRoles,
    TLRoomCommandActionListMembers,
    TLRoomCommandActionRenewTwincode,
    TLRoomCommandActionGetConfig,
    TLRoomCommandActionSignalMember
} TLRoomCommandAction;

//
// Interface: TLRoomCommandSerializer
//

@interface TLRoomCommandSerializer : TLSerializer

@end

//
// Interface: TLRoomCommand
//

/**
 * Room command.
 *
 * The `TLRoomCommand` object holds a command that is sent to the Twinroom.  The command to execute is described by
 * the `TLRoomCommandAction` enum and it may have some optional parameters. The command is associated with a requestId
 * which is used for the commands where we expect the room to send back some result. When the requestId is 0, the room
 * will not send any response.
 *
 * A Room command is sent through the ConversationService with the `pushCommandWithRequestId` operation.
 * The onPushDescriptor() callback is called at that time with a TLTransientDescriptor object that contains the command.
 *
 * As soon as the command is executed and we receive the acknowledgment of its execution by the Twinroom, the
 * onUpdateDescriptor() callback is called with the TLTransientDescriptor object. The descriptor contains the timestamps
 * when the command was sent and received.
 */
@interface TLRoomCommand : NSObject

@property (readonly) int64_t requestId;
@property (readonly) TLRoomCommandAction action;
@property (readonly, nullable) NSString *text;
@property (readonly, nullable) UIImage *image;
@property (readonly, nullable) TLDescriptorId *messageId;
@property (readonly, nullable) NSUUID *twincodeOutboundId;
@property (readonly, nullable) NSArray<NSUUID *> *list;
@property (readonly, nullable) TLRoomConfig *roomConfig;

/// Create a command without parameters.  No response is expected from the Twinroom.
- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action;

/// Create a command with a text parameter.  No response is expected from the Twinroom.
- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action text:(nonnull NSString *)text;

/// Create a command with an image parameter.  No response is expected from the Twinroom.
- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action image:(nonnull UIImage *)image;

/// Create a command with a message descriptor Id parameter.  No response is expected from the Twinroom.
- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action messageId:(nonnull TLDescriptorId *)messageId;

/// Create a command with a twincode Id parameter.  No response is expected from the Twinroom.
- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action text:(nonnull NSString *)text list:(nonnull NSArray<NSUUID *> *)list;

- (nonnull instancetype)initWithRequestId:(int64_t)requestId action:(TLRoomCommandAction)action config:(nonnull TLRoomConfig *)config;

@end
