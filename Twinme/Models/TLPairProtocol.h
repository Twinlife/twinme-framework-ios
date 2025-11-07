/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

//
// Interface: TLPairProtocol
//

#define PAIR_PROTOCOL_PARAM_TWINCODE_OUTBOUND_ID @"twincodeOutboundId"

@class TLTwincode;

@interface TLPairProtocol : NSObject

+ (void)setTwincodeAttributeMetaPair:(NSMutableArray *)attributes;

+ (void)setTwincodeAttributePair:(NSMutableArray *)attributes;

+ (NSUUID *)getMetaPairTwincodeOutboundId:(TLTwincode *)twincode;

+ (NSUUID *)getPairTwincodeOutboundId:(TLTwincode *)twincode;

+ (void)setTwincodeAttributePairTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId;

+ (void)setTwincodeAttributeMetaPairTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId;

+ (NSString *)ACTION_PAIR_BIND;

+ (void)setInvokeTwincodeActionPairBindAttributeTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId;

+ (NSString *)invokeTwincodeActionPairBindAttributeTwincodeId;

+ (NSString *)ACTION_PAIR_INVITE;

+ (void)setInvokeTwincodeActionPairInviteAttributeTwincodeId:(NSMutableArray *)attributes twincodeId:(NSUUID *)twincodeId;

+ (NSString *)invokeTwincodeActionPairInviteAttributeTwincodeId;

+ (NSString *)ACTION_PAIR_UNBIND;

+ (NSString *)ACTION_PAIR_REFRESH;

@end
