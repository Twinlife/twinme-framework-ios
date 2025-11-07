/*
 *  Copyright (c) 2015-2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <Twinlife/TLTwincode.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLPairProtocol.h"

/**
 * <pre>
 * 
 * Pair Protocol
 * 
 *                                                                                             
 * 
 * pair::invite -- pair::bind
 * 
 * 
 *         Peer1                                                      Peer2                                         
 * 
 *    profileA
 *    publicIdentityId = identityIdA
 * 
 *   identityA
 *    id = identityIdA
 *    twincodeFactoryId = twincodeFactoryIdA
 *    twincodeInboundId = twincodeInboundIdA
 *    twincodeOutboundId = twincodeOutboundIdA
 *    twincodeSwitchId = twincodeSwitchIdA
 * 
 *   twincodeFactoryA
 *    id = twincodeFactoryIdA
 *    twincodeInboundId = twincodeInboundIdA
 *    twincodeOutboundId = twincodeOutboundIdA
 *    twincodeSwitchId = twincodeSwitchIdA
 *    attributes:
 *     meta::pair::
 * 
 *   twincodeInboundA
 *    id = twincodeInboundIdA
 *    attributes:
 *     meta::pair::
 * 
 *   twincodeOutboundA
 *    id = twincodeOutboundIdA
 *    attributes:
 *     meta::pair::
 * 
 *   twincodeSwitchA
 *    id = twincodeSwitchIdA
 *    twincodeInboundId = twincodeInboundIdA
 *    twincodeOutboundId = twincodeOutboundIdA
 *    attributes:
 *     meta::pair::
 * 
 *                                                                                                                   
 *                                                                    Peer2 (Anonymous)                              
 *                                                                                                                   
 * 
 * 
 *                                                    ImportInvitationActivity (Anonymous)
 *                                                     => CreateContactPhase1Executor
 * 
 *                                                      contactB
 *                                                       id = contactIdB
 *                                                       publicPeerTwincodeOutboundId = twincodeOutboundIdA
 *                                                       privatePeerTwincodeOutboundId = null
 *                                                       privateIdentityId = null
 * 
 * 
 *                                                                                                                   
 *                                                                    Peer2 (name)                                   
 *                                                                                                                   
 * 
 *                                                    ImportInvitationActivity (name)
 *                                                     => CreateContactPhase1Executor
 * 
 *                                                      contactB
 *                                                       id = contactIdB
 *                                                       publicPeerTwincodeOutboundId = twincodeOutboundIdA
 *                                                       privatePeerTwincodeOutboundId = null
 *                                                       privateIdentityId = privateIdentityIdB
 * 
 *                                                      privateIdentityB
 *                                                       id = privateIdentityIdB
 *                                                       twincodeFactoryId = twincodeFactoryIdB
 *                                                       twincodeInboundId = twincodeInboundIdB
 *                                                       twincodeOutboundId = twincodeOutboundIdB
 *                                                       twincodeSwitchId = twincodeSwitchIdB
 * 
 *                                                      twincodeFactoryB
 *                                                       id = twincodeFactoryIdB
 *                                                       twincodeInboundId = twincodeInboundIdB
 *                                                       twincodeOutboundId = twincodeOutboundIdB
 *                                                       twincodeSwitchId = twincodeSwitchIdB
 *                                                       attributes:
 *                                                        pair::
 * 
 *                                                      twincodeInboundB
 *                                                       id = twincodeInboundIdB
 *                                                       attributes:
 *                                                        pair::
 * 
 *                                                      twincodeOutboundB
 *                                                       id = twincodeOutboundIdB
 *                                                       attributes:
 *                                                        pair::
 * 
 *                                                      twincodeSwitchB
 *                                                       id = twincodeSwitchIdB
 *                                                       twincodeInboundId = twincodeInboundIdB
 *                                                       twincodeOutboundId = twincodeOutboundIdB
 *                                                       attributes:
 *                                                        pair::
 * 
 *                                                    invoke
 *                                                     id = twincodeOutboundIdA
 *                                                     action = pair::invite
 *                                                     attributes:
 *                                                      twincodeOutboundId = twincodeOutboundIdB
 * 
 * onInvoke
 *  twincodeInboundId = twincodeInboundIdA
 *  action = pair::invite
 *  attributes:
 *   twincodeOutboundId = twincodeOutboundIdB
 * 
 *                                                                                                                   
 *         Peer1 (name)                                                                                             
 *                                                                                                                   
 * 
 *  => CreateContactPhase2Executor
 * 
 *  contactC
 *   id = contactIdB
 *   publicPeerTwincodeOutboundId = null
 *   privatePeerTwincodeOutboundId = twincodeOutboundIdB
 *   privateIdentityId = privateIdentityIdC
 * 
 *  privateIdentityC
 *   id = privateIdentityIdC
 *   twincodeFactoryId = twincodeFactoryIdC
 *   twincodeInboundId = twincodeInboundIdC
 *   twincodeOutboundId = twincodeOutboundIdC
 *   twincodeSwitchId = twincodeSwitchIdC
 * 
 *  twincodeFactoryC
 *   id = twincodeFactoryIdC
 *   twincodeInboundId = twincodeInboundIdC
 *   twincodeOutboundId = twincodeOutboundIdC
 *   twincodeSwitchId = twincodeSwitchIdC
 *   attributes:
 *    pair::
 * 
 *  twincodeInboundC
 *   id = twincodeInboundIdC
 *   attributes:
 *    pair::
 *    pair::twincodeOutboundId = twincodeOutboundIdB
 * 
 *  twincodeOutboundC
 *   id = twincodeOutboundIdC
 *   attributes:
 *    pair::
 * 
 *  twincodeSwitchC
 *   id = twincodeSwitchIdC
 *   twincodeInboundId = twincodeInboundIdC
 *   twincodeOutboundId = twincodeOutboundIdC
 *   attributes:
 *    pair::
 * 
 * invoke
 *  id = twincodeOutboundIdB
 *  action = pair::bind
 *  attributes:
 *   twincodeOutboundId = twincodeOutboundIdC
 * 
 *                                                    onInvoke
 *                                                     twincodeInboundId = twincodeInboundIdB
 *                                                     action = pair::bind
 *                                                     attributes:
 *                                                      twincodeOutboundId = twincodeOutboundIdC
 * 
 *                                                     => BindContactExecutor
 * 
 *                                                      contactB
 *                                                       id = contactIdB
 *                                                       publicPeerTwincodeOutboundId = twincodeOutboundIdA
 *                                                       privatePeerTwincodeOutboundId = twincodeOutboundIdC
 *                                                       privateIdentityId = privateIdentityIdB
 * 
 *                                                      privateIdentityB
 *                                                       id = privateIdentityIdB
 *                                                       twincodeFactoryId = twincodeFactoryIdB
 *                                                       twincodeInboundId = twincodeInboundIdB
 *                                                       twincodeOutboundId = twincodeOutboundIdB
 *                                                       twincodeSwitchId = twincodeSwitchIdB
 * 
 *                                                      twincodeFactoryB
 *                                                       id = twincodeFactoryIdB
 *                                                       twincodeInboundId = twincodeInboundIdB
 *                                                       twincodeOutboundId = twincodeOutboundIdB
 *                                                       twincodeSwitchId = twincodeSwitchIdB
 *                                                       attributes:
 *                                                        pair::
 * 
 *                                                      twincodeInboundB
 *                                                       id = twincodeInboundIdB
 *                                                       attributes:
 *                                                        pair::
 *                                                        pair::twincodeOutboundId = twincodeOutboundIdC
 * 
 *                                                      twincodeOutboundB
 *                                                       attributes:
 *                                                        pair::
 * 
 *                                                      twincodeSwitchB
 *                                                       twincodeInboundId = twincodeInboundIdB
 *                                                       twincodeOutboundId = twincodeOutboundIdB
 *                                                       attributes:
 *                                                        pair::
 * 
 * 
 * 
 * pair::unbind
 * 
 * invoke
 *  id = twincodeOutboundIdB
 *  action = pair::unbind
 *  attributes:
 * 
 *                                                    onInvoke
 *                                                     twincodeInboundId = twincodeInboundIdB
 *                                                     action = pair::unbind
 *                                                     attributes:
 * 
 * 
 * 
 * pair::refresh
 * 
 * invoke
 *  id = twincodeOutboundIdB
 *  action = pair::refresh
 *  attributes:
 * 
 *                                                    onInvoke
 *                                                     twincodeInboundId = twincodeInboundIdB
 *                                                     action = pair::refresh
 *                                                     attributes:
 * 
 * 
 * </pre>
 **/

//
// Twincode Attributes
//

#define TWINCODE_ATTRIBUTE_META_PAIR @"meta::pair::"
#define TWINCODE_ATTRIBUTE_META_PAIR_TWINCODE_OUTBOUND_ID @"meta::pair::twincodeOutboundId"

#define TWINCODE_ATTRIBUTE_PAIR @"pair::"
#define TWINCODE_ATTRIBUTE_PAIR_TWINCODE_OUTBOUND_ID @"pair::twincodeOutboundId"

//
// Invoke Actions & Attributes
//

#define INVOKE_TWINCODE_ACTION_PAIR_BIND @"pair::bind"
#define INVOKE_TWINCODE_ACTION_PAIR_BIND_ATTRIBUTE_TWINCODE_OUTBOUND_ID @"twincodeOutboundId"
#define INVOKE_TWINCODE_ACTION_PAIR_INVITE @"pair::invite"
#define INVOKE_TWINCODE_ACTION_PAIR_INVITE_ATTRIBUTE_TWINCODE_OUTBOUND_ID @"twincodeOutboundId"
#define INVOKE_TWINCODE_ACTION_PAIR_UNBIND @"pair::unbind"
#define INVOKE_TWINCODE_ACTION_PAIR_REFRESH @"pair::refresh"

//
// Implementation: TLPairProtocol
//

@implementation TLPairProtocol

+ (void)setTwincodeAttributeMetaPair:(NSMutableArray *)attributes {
    
    [attributes addObject:[[TLAttributeNameVoidValue alloc] initWithName:TWINCODE_ATTRIBUTE_META_PAIR]];
    
}

+ (void)setTwincodeAttributePair:(NSMutableArray *)attributes {
    
    [attributes addObject:[[TLAttributeNameVoidValue alloc] initWithName:TWINCODE_ATTRIBUTE_PAIR]];
}

+ (NSUUID *)getMetaPairTwincodeOutboundId:(TLTwincode *)twincode {
    
    NSString *value = (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_META_PAIR_TWINCODE_OUTBOUND_ID];
    if (value) {
        return [[NSUUID alloc] initWithUUIDString:value];
    }
    return nil;
}

+ (NSUUID *)getPairTwincodeOutboundId:(TLTwincode *)twincode {
    
    NSString *value = (NSString *)[twincode getAttributeWithName:TWINCODE_ATTRIBUTE_PAIR_TWINCODE_OUTBOUND_ID];
    if (value) {
        return [[NSUUID alloc] initWithUUIDString:value];
    }
    return nil;
}

+ (void)setTwincodeAttributePairTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_PAIR_TWINCODE_OUTBOUND_ID stringValue:twincodeId.UUIDString]];
}

+ (void)setTwincodeAttributeMetaPairTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TWINCODE_ATTRIBUTE_META_PAIR_TWINCODE_OUTBOUND_ID stringValue:twincodeId.UUIDString]];
}

+ (NSString *)ACTION_PAIR_BIND {
    
    return INVOKE_TWINCODE_ACTION_PAIR_BIND;
}

+ (void)setInvokeTwincodeActionPairBindAttributeTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:INVOKE_TWINCODE_ACTION_PAIR_BIND_ATTRIBUTE_TWINCODE_OUTBOUND_ID stringValue:twincodeId.UUIDString]];
}

+ (NSString *)invokeTwincodeActionPairBindAttributeTwincodeId {
    
    return INVOKE_TWINCODE_ACTION_PAIR_BIND_ATTRIBUTE_TWINCODE_OUTBOUND_ID;
}

+ (NSString *)ACTION_PAIR_INVITE {
    
    return INVOKE_TWINCODE_ACTION_PAIR_INVITE;
}

+ (void)setInvokeTwincodeActionPairInviteAttributeTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:INVOKE_TWINCODE_ACTION_PAIR_INVITE_ATTRIBUTE_TWINCODE_OUTBOUND_ID stringValue:twincodeId.UUIDString]];
}

+ (NSString *)invokeTwincodeActionPairInviteAttributeTwincodeId {
    
    return INVOKE_TWINCODE_ACTION_PAIR_INVITE_ATTRIBUTE_TWINCODE_OUTBOUND_ID;
}

+ (NSString *)ACTION_PAIR_UNBIND {
    
    return INVOKE_TWINCODE_ACTION_PAIR_UNBIND;
}

+ (NSString *)ACTION_PAIR_REFRESH {
    
    return INVOKE_TWINCODE_ACTION_PAIR_REFRESH;
}

@end
