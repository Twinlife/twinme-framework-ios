/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Julien Poumarat (Julien.Poumarat@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTwinmeContext.h"
#import <Twinlife/TLAssertion.h>

@class TLGroupMember;
@class TLObject;
@class TLInvitation;
@protocol TLGroupConversation;
@protocol TLRepositoryObject;
@class TLCallReceiver;
@class TLPairInviteInvocation;
@class TLIntegerConfigIdentifier;

//
// Interface: TLExecutorAssertPoint ()
//

@interface TLTwinmeAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)PROCESS_INVOCATION;
+(nonnull TLAssertPoint *)ON_UPDATE_ANNOTATION;
+(nonnull TLAssertPoint *)ON_UPDATE_DESCRIPTOR;
+(nonnull TLAssertPoint *)ON_POP_DESCRIPTOR;
+(nonnull TLAssertPoint *)INCOMING_PEER_CONNECTION;

@end

//
// Interface: TLTwinmeContext ()
//

@interface TLTwinmeContext ()

+ (nonnull NSString *)VERSION;

@property (readonly, nonnull) TLIntegerConfigIdentifier *lastReportDate;

+ (BOOL)ENABLE_REPORT_LOCATION;

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)onUpdateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)onChangeProfileTwincodeWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)onDeleteProfileWithRequestId:(int64_t)requestId profileId:(nonnull NSUUID *)profileId;

- (void)onDeleteAccountWithRequestId:(int64_t)requestId;

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId;

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)onCreateInvitationWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation;

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(nonnull NSUUID *)invitationId;

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(nonnull NSUUID *)groupId;

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group;

- (void)onGetGroupMemberWithErrorCode:(TLBaseServiceErrorCode)errorCode groupMember:(nullable TLGroupMember *)groupMember withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupMember * _Nullable groupMember))block;

- (void)onUpdateStatsWithRequestId:(int64_t)requestId contacts:(nonnull NSArray<id<TLRepositoryObject>> *)contacts groups:(nonnull NSArray<id<TLRepositoryObject>> *)groups;

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onReportStatsWithRequestId:(int64_t)requestId delay:(NSTimeInterval)delay;

- (void)createProfileWithRequestId:(const int64_t)requestId name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities;

- (void)deleteProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)createSpaceWithRequestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings profile:(nullable TLProfile *)profile;

- (void)createDefaultSpaceWithRequestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings profile:(nonnull TLProfile *)profile;

- (void)updateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space profile:(nonnull TLProfile *)profile;

- (void)onGetSpacesWithRequestId:(int64_t)requestId spaces:(nonnull NSArray<TLSpace*> *)spaces;

- (void)createGroupWithRequestId:(int64_t)requestId invitationTwincode:(nonnull TLTwincodeOutbound *)invitationTwincode space:(nonnull TLSpace *)space;

- (void)fetchExistingMembersWithOwner:(nonnull id<TLOriginator>)owner members:(nonnull NSArray<NSUUID *> *)members knownMembers:(nonnull NSMutableArray<TLGroupMember *> *)knownMembers unknownMembers:(nonnull NSMutableArray<NSUUID *> *)unknownMembers;

- (void)onDeleteSpaceWithRequestId:(int64_t)requestId spaceId:(nonnull NSUUID *)spaceId;

/// Get the set of contactId and groupId which are part of the space.
- (void)getSpaceOriginatorSet:(nonnull TLSpace *)space withBlock:(nonnull void (^)(NSSet<NSUUID *> * _Nonnull originatorSet))block;

/// Copy from the twincode a set of registered attributes to be copied.
- (void)copySharedTwincodeAttributesWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSMutableArray *)attributes;

/// Call Receiver
- (void)onCreateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onDeleteCallReceiverWithRequestId:(int64_t)requestId callReceiverId:(nonnull NSUUID *)callReceiverId;

- (void)onUpdateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onChangeCallReceiverTwincodeWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onDeleteAccountMigrationWithRequestId:(int64_t)requestId accountMigrationId:(nonnull NSUUID *)accountMigrationId;

/// Invitation code
- (void)onCreateInvitationWithCodeWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitationCode;

- (void)onGetInvitationCodeWithRequestId:(int64_t)requestId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound publicKey:(nullable NSString *)publicKey;
@end
