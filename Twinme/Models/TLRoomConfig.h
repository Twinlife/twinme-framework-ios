/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLSerializer.h>

typedef enum {
    /// Room is public, anybody can write and messages are dispatched to members
    TLChatModePublic,

    /// Room is a channel, only administrators can write messages, users can post feedbacks to admin
    TLChatModeFeedback,

    /// Room is a channel where only administrators can write messages.
    TLChatModeChannel
} TLChatMode;

typedef enum {
    /// Audio and video calls are disabled.
    TLCallModeDisabled,

    /// Only the audio call is allowed.
    TLCallModeAudio,

    /// Audio and video calls are allowed.
    TLCallModeVideo
} TLCallMode;

typedef enum {
    /// The room is quiet when a member joins an audio/video call.
    TLNotificationModeQuiet,

    /// Post a notification when the conference starts (first person join) and stops (last person leaves).
    TLNotificationModeInform,

    /// The room send a message each time a member joins or leaves the call.
    TLNotificationModeNoisy
} TLNotificationMode;

typedef enum {
    /// The room Twincode is public and anybody can join the twinroom.
    TLInvitationModePublic,

    /// The room Twincode is visible only to admin users.
    TLInvitationModeAdmin
} TLInvitationMode;

//
// Interface: TLRoomConfig
//
@interface TLRoomConfig : NSObject

@property (nullable) NSString *welcome;
@property TLChatMode chatMode;
@property TLCallMode callMode;
@property TLNotificationMode notificationMode;
@property TLInvitationMode invitationMode;
@property (nullable) NSUUID *invitationTwincodeId;

- (nullable instancetype)init;

+ (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder config:(nonnull TLRoomConfig *)config;

+ (nullable TLRoomConfig *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder;

@end
