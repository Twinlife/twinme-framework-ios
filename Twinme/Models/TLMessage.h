/*
 *  Copyright (c) 2015-2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLSerializer.h>

//
// Interface: TLMessageSerializer
//

@interface TLMessageSerializer : TLSerializer

@end

//
// Interface: TLMessage
//

@interface TLMessage : NSObject

@property (readonly) NSString *content;
@property BOOL isPeer;

- (instancetype)initWithContent:(NSString *)content;

@end
