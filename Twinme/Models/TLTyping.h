/*
 *  Copyright (c) 2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLSerializer.h>

typedef enum {
    TLTypingActionStart,
    TLTypingActionStop
} TLTypingAction;

//
// Interface: TLTypingSerializer
//

@interface TLTypingSerializer : TLSerializer

@end

//
// Interface: TLTyping
//

/**
 * Transient user typing action.
 *
 * The `Typing` object is intended to be sent through the pushTransientObject() operation to notify the peer
 * that the user starts or stops typing some text.
 */
@interface TLTyping : NSObject

@property TLTypingAction action;

- (instancetype)initWithAction:(TLTypingAction)action;

@end
