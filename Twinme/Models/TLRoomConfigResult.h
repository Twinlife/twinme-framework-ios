/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLSerializer.h>
#import "TLRoomConfig.h"
#import "TLRoomCommandResult.h"

//
// Interface: TLRoomConfigResultSerializer
//

@interface TLRoomConfigResultSerializer : TLSerializer

@end

//
// Interface: TLRoomConfig
//
@interface TLRoomConfigResult : TLRoomCommandResult

@property (nullable) TLRoomConfig *roomConfig;

- (nonnull instancetype)initWithRequestId:(int64_t)requestId status:(TLRoomCommandStatus)status config:(nullable TLRoomConfig *)config;

@end
