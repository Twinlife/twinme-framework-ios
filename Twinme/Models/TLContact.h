/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOriginator.h"
#import "TLCapabilities.h"
#import "TLTwinmeRepositoryObject.h"

typedef enum {
    TLCertificationLevel0, // Relation does not use public and private keys
    TLCertificationLevel1, // Relation uses public and private keys, no side is trusted
    TLCertificationLevel2, // Relation uses public/private keys, the peer trust our public key and identity twincode.
    TLCertificationLevel3, // Relation uses public/private keys, we trust the peer public key and identity twincode.
    TLCertificationLevel4  // Relation uses public/private keys, both side trust each other's public key and twincode.
} TLCertificationLevel;

//
// Interface: TLContact
//

@class TLRepositoryService;
@class TLTwincodeInbound;
@class TLTwincodeOutbound;
@class TLTwincodeFactory;

@interface TLContact : TLTwinmeOriginatorObject

@property (nullable) NSUUID *publicPeerTwincodeOutboundId;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (nonnull NSString *)ANONYMOUS_NAME;

+ (nonnull UIImage *)ANONYMOUS_AVATAR;

+ (nonnull id<TLRepositoryObjectFactory>)FACTORY;

- (BOOL)updatePeerName:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound oldName:(nonnull NSString *)oldName;

// - (BOOL)updateStatsWithObject:(nonnull TLObject *)object;

- (void)setPublicPeerTwincodeOutbound:(nullable TLTwincodeOutbound *)publicPeerTwincodeOutbound;

/// Update the peer twincode outbound, return YES if it was modified.
- (BOOL)updatePeerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound;

- (BOOL)hasPrivateIdentity;

- (BOOL)hasPeer;

- (BOOL)hasPrivatePeer;

- (BOOL)isTwinroom;

/// Get the peer's capabilities describing the operations we can do on this relation.
- (nonnull TLCapabilities *)capabilities;

/// Get the our own capabilities describing the operations we allow from the peer.
- (nonnull TLCapabilities *)identityCapabilities;

- (nonnull NSString *)peerTwincodeName;

- (TLCertificationLevel)certificationLevel;

- (BOOL)checkInvariants;

@end
