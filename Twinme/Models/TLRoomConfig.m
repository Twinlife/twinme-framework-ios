/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLDecoder.h>
#import <Twinlife/TLEncoder.h>

#import "TLRoomConfig.h"

//
// Implementation: TLRoomConfig
//

@implementation TLRoomConfig

- (nullable instancetype)init {
    
    self = [super init];
    if (self) {
        _welcome = nil;
        _invitationTwincodeId = nil;
        _chatMode = TLChatModePublic;
        _callMode = TLCallModeVideo;
        _notificationMode = TLNotificationModeNoisy;
        _invitationMode = TLInvitationModePublic;
    }

    return self;
}

+ (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder config:(nonnull TLRoomConfig *)config {
    
    switch (config.chatMode) {
        case TLChatModePublic:
            [encoder writeEnum:0];
            break;

        case TLChatModeChannel:
            [encoder writeEnum:1];
            break;
            
        case TLChatModeFeedback:
            [encoder writeEnum:2];
            break;
    }

    switch (config.callMode) {
        case TLCallModeDisabled:
            [encoder writeEnum:0];
            break;

        case TLCallModeAudio:
            [encoder writeEnum:1];
            break;

        case TLCallModeVideo:
            [encoder writeEnum:2];
            break;
    }

    switch (config.notificationMode) {
        case TLNotificationModeQuiet:
            [encoder writeEnum:0];
            break;
            
        case TLNotificationModeInform:
            [encoder writeEnum:1];
            break;
            
        case TLNotificationModeNoisy:
            [encoder writeEnum:2];
            break;
    }

    switch (config.invitationMode) {
        case TLInvitationModePublic:
            [encoder writeEnum:0];
            break;
            
        case TLInvitationModeAdmin:
            [encoder writeEnum:1];
            break;
    }

    if (config.invitationTwincodeId == nil) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:config.invitationTwincodeId];
    }

    if (config.welcome == nil) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeString:config.welcome];
    }

    // Finish with a 0 so that we can more easily extend the RoomConfig object.
    [encoder writeEnum:0];
}

+ (nullable TLRoomConfig *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder {
    
    TLRoomConfig *config = [[TLRoomConfig alloc] init];

    switch ([decoder readEnum]) {
        case 0:
            config.chatMode = TLChatModePublic;
            break;

        case 1:
            config.chatMode = TLChatModeChannel;
            break;
            
        case 2:
            config.chatMode = TLChatModeFeedback;
            break;
            
        default:
            config.chatMode = TLChatModePublic;
            break;
    }

    switch ([decoder readEnum]) {
        case 0:
            config.callMode = TLCallModeDisabled;
            break;
            
        case 1:
            config.callMode = TLCallModeAudio;
            break;
            
        case 2:
            config.callMode = TLCallModeVideo;
            break;
            
        default:
            config.callMode = TLCallModeVideo;
            break;
    }

    switch ([decoder readEnum]) {
        case 0:
            config.notificationMode = TLNotificationModeQuiet;
            break;
            
        case 1:
            config.notificationMode = TLNotificationModeInform;
            break;
            
        case 2:
            config.notificationMode = TLNotificationModeNoisy;
            break;
            
        default:
            config.notificationMode = TLNotificationModeNoisy;
            break;
    }

    switch ([decoder readEnum]) {
        case 0:
            config.invitationMode = TLInvitationModePublic;
            break;
            
        case 1:
            config.invitationMode = TLInvitationModeAdmin;
            break;
            
        default:
            config.invitationMode = TLInvitationModePublic;
            break;
    }

    if ([decoder readEnum] != 0) {
        config.invitationTwincodeId = [decoder readUUID];
    }

    if ([decoder readEnum] != 0) {
        config.welcome = [decoder readString];
    }

    // If we add information in RoomConfig, we can extract it with.  It is ignored otherwise.
    // if (decoder.readEnum() != 0) {
    //
    // }

    return config;
}

@end
