/*
 *  Copyright (c) 2021-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

@class TLSchedule;
@class TLAttributeNameValue;

typedef enum {
    /// The twincode is an invitation
    TLTwincodeKindInvitation,

    /// The twincode is a simple contact relation.
    TLTwincodeKindContact,

    /// The twincode is a group twincode.
    TLTwincodeKindGroup,

    /// The twincode is a group member.
    TLTwincodeKindGroupMember,

    /// The twincode is a twinroom with specific capabilities.
    TLTwincodeKindTwinroom,

    /// The twincode is used for account migration.
    TLTwincodeKindAccountMigration,

    /// The twincode describes a managed space.
    TLTwincodeKindSpace,
    
    /// The twincode describes a managed space.
    TLTwincodeKindCallReceiver
} TLTwincodeKind;

typedef NS_OPTIONS(NSInteger, TLVideoZoomable) {
    /// Control of the camera by the peer is never allowed (we must not ask).
    TLVideoZoomableNever,
    /// Control of the camera is allowed after a request and confirmation process.
    TLVideoZoomableAsk,
    /// Control of the camera is always allowed (no need to request).
    TLVideoZoomableAllow
};

//
// Interface: TLCapabilities
//
// The Capabilities describes the features which are supported by a twincode.  The UI can use it to know
// which operations are supported so that it hides the operations not available.  Capabilities are also
// enforced either on the Openfire server or on the receiving side (ie, the twincode owner).
//
// The Capabilities comes within the `capabilities` twincode attributes in the form of a multi-line string.
// Each line describes a single capability.
//
@interface TLCapabilities : NSObject

@property (nonatomic, nullable) TLSchedule *schedule;

- (nullable instancetype)init;

- (nullable instancetype)initWithCapabilities:(nonnull NSString *)capabilities;

- (nullable instancetype)initWithTwincodeKind:(TLTwincodeKind)kind admin:(BOOL)admin;

- (TLTwincodeKind)kind;

/// Returns true if the owner is Twinroom owner.
- (BOOL)hasOwner;

/// Returns true if the owner is admin
- (BOOL)hasAdmin;

/// Returns true if the owner can moderate a Twinroom.
- (BOOL)hasModerate;

/// Returns true if an audio call is possible.
- (BOOL)hasAudio;

/// Returns true if the target can receive audio stream.
- (BOOL)hasAudioReceiver;

/// Returns true if a video call is possible.
- (BOOL)hasVideo;

/// Returns true if the target can receive video stream.
- (BOOL)hasVideoReceiver;

/// Returns true if opening data channel is possible.
- (BOOL)hasData;

/// Returns true if the owner is visible (in twinroom list members by non-admin).
- (BOOL)hasVisibility;

/// Returns true if the owner accepts contact invitations.
- (BOOL)hasAcceptInvitation;

/// Returns true if transferring calls to the owner is allowed.
- (BOOL)hasTransfer;

/// Returns true if group calls are allowed (CallReceiver only).
- (BOOL)hasGroupCall;

- (BOOL)hasDiscreet;

- (TLVideoZoomable)zoomable;

/// Set or clear the admin capability.
- (void)setCapAdminWithValue:(BOOL)value;

/// Set or clear the moderate capability.
- (void)setCapModerateWithValue:(BOOL)value;

/// Set or clear the audio capability.
- (void)setCapAudioWithValue:(BOOL)value;

/// Set or clear the video capability.
- (void)setCapVideoWithValue:(BOOL)value;

/// Set or clear the data capability.
- (void)setCapDataWithValue:(BOOL)value;

/// Set or clear the visibility capability.
- (void)setCapVisibilityWithValue:(BOOL)value;

/// Set or clear the accept invitation capability.
- (void)setCapAcceptInvitationWithValue:(BOOL)value;

/// Set or clear the transfer capability.
- (void)setCapTransferWithValue:(BOOL)value;

/// Set or clear the group call capability.
- (void)setCapGroupCallWithValue:(BOOL)value;

- (void)setCapDiscreetWithValue:(BOOL)value;

/// Set the new twincode class.
- (void)setKindWithValue:(TLTwincodeKind)value;

- (void)setZoomableWithValue:(TLVideoZoomable)value;

- (void)setTrustedWithValue:(nullable NSUUID *)value;

- (BOOL)isTrustedWithTwincodeId:(nonnull NSUUID*)twincodeId;

/// Get the twincode attribute value describing the capabilities.
- (nullable NSString *)attributeValue;

@end
