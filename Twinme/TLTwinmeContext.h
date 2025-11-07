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

#import <UIKit/UIKit.h>
#import <Twinlife/TLTwinlifeContext.h>
#import <Twinlife/TLNotificationService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLInvitationCode.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import "TLProfile.h"

//
// Protocol: TLTwinmeContextDelegate
//

@class TLTwincodeFactory;
@class TLTwincodeInbound;
@class TLTwincodeOutbound;
@class TLContext;
@class TLProfile;
@class TLSpace;
@class TLSpaceSettings;
@class TLContact;
@class TLGroup;
@class TLGroupMember;
@class TLInvocation;
@class TLInvitation;
@class TLDescriptorId;
@class TLRoomConfig;
@class TLCapabilities;
@class TLCallReceiver;
@class TLAccountMigration;
@class TLImageId;
@class TLConversationDescriptorPair;
@protocol TLConversation;
@protocol TLNotificationCenter;
@protocol TLGroupConversation;
@protocol TLOriginator;
@protocol TLApplication;
@class TLNotification;
@class TLNotificationServiceNotificationStat;
@class TLPushNotificationContent;
@class TLTwinmeAction;
@class TLFindResult;
@class TLTwincodeURI;

@protocol TLTwinmeContextDelegate <TLTwinlifeContextDelegate>
@optional

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)onUpdateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)onChangeProfileTwincodeWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)onDeleteProfileWithRequestId:(int64_t)requestId profileId:(nonnull NSUUID *)profileId;

- (void)onDeleteAccountWithRequestId:(int64_t)requestId;

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(nonnull NSUUID *)groupId;

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId;

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)onCreateInvitationWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation;

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(nonnull NSUUID *)invitationId;

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group conversation:(nonnull id<TLGroupConversation>)conversation;

- (void)onDeleteGroupWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId;

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group;

- (void)onUpdateStatsWithRequestId:(int64_t)requestId contacts:(nonnull NSArray<TLContact *>*)contacts groups:(nonnull NSArray<TLGroup *> *)groups;

- (void)onProcessInvocationWithRequestId:(int64_t)requestId invocation:(nonnull TLInvocation *)invocation;

- (void)onDeleteLevelWithRequestId:(int64_t)requestId;

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)onSetCurrentSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)onDeleteSpaceWithRequestId:(int64_t)requestId spaceId:(nonnull NSUUID *)spaceId;

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group oldSpace:(nonnull TLSpace *)oldSpace;

- (void)onAcknowledgeNotificationWithRequestId:(int64_t)requestId notification:(nonnull TLNotification *)notification;

- (void)onAddNotificationWithNotification:(nonnull TLNotification *)notification;

- (void)onDeleteNotificationsWithList:(nonnull NSArray<NSUUID *> *)list;

- (void)onUpdatePendingNotificationsWithRequestId:(int64_t)requestId hasPendingNotifications:(BOOL)hasPendingNotifications;

- (void)onOpenURL:(nonnull NSURL *)url;

- (void)onCreateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onDeleteCallReceiverWithRequestId:(int64_t)requestId callReceiverId:(nonnull NSUUID *)callReceiverId;

- (void)onUpdateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;
- (void)onChangeCallReceiverTwincodeWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)onUpdateAccountMigrationWithRequestId:(int64_t)requestId accountMigration:(nonnull TLAccountMigration *)accountMigration;
- (void)onDeleteAccountMigrationWithRequestId:(int64_t)requestId accountMigrationId:(nonnull NSUUID *)accountMigrationId;

- (void)onCreateInvitationWithCodeWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation;
- (void)onGetInvitationCodeWithRequestId:(int64_t)requestId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound publicKey:(nullable NSString *)publicKey;
@end

//
// Interface: TLTwinmeContext
//

@class TLTwinmeConfiguration;
@class TLTwinmeApplication;

@interface TLTwinmeContext : TLTwinlifeContext
@property BOOL enableInvocations;

+ (nonnull NSString *)CONTACTS_CONTEXT_NAME;

+ (nonnull NSString *)PROFILE_CONTEXT_NAME;

+ (nonnull NSString *)LEVELS_CONTEXT_NAME;

//
// twinme URLs
//
// https://call.twin.me/?twincodeId=...
+ (nonnull NSString *)CALL_ACTION;
// https://invite.twin.me/?twincodeId=...
+ (nonnull NSString *)INVITE_ACTION;
// https://date.card.twin.me/?id=...
+ (nonnull NSString *)DATE_CARD_ACTION;
// https://privilege.card.twin.me/?id=...
+ (nonnull NSString *)PRIVILEGE_CARD_ACTION;

- (nonnull instancetype)initWithTwinmeApplication:(nonnull TLTwinmeApplication *)twinmeApplication configuration:(nonnull TLTwinmeConfiguration *)configuration;

//
// TLApplication protocol
//

- (void)applicationDidEnterBackground:(nullable id<TLApplication>)application;

- (void)applicationDidBecomeActive:(nullable id<TLApplication>)application;

- (BOOL)openURL:(nonnull NSURL *)url options:(nullable NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;

- (BOOL)isDatabaseUpgraded;

//
// Set push notification token
//

- (void)setPushNotificationWithVariant:(nonnull NSString*)variant token:(nonnull NSString*)token;

- (void)didReceiveIncomingPushWithPayload:(nonnull NSDictionary *)dictionaryPayload application:(nullable id<TLApplication>)application completionHandler:(nonnull void (^)(TLBaseServiceErrorCode status, TLPushNotificationContent * _Nullable notificationContent))completionHandler terminateCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))terminateHandler;

# pragma mark - Profile management

//
// Profile Management
//

- (BOOL)isCurrentProfile:(nonnull TLProfile *)profile;

- (BOOL)isSpaceProfile:(nonnull TLProfile *)profile;

/// Returns true if the twincode is from one of our profile.
- (BOOL)isProfileTwincode:(nonnull NSUUID *)twincodeId;

- (void)getProfilesWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLProfile*> * _Nonnull list))block;

- (void)createProfileWithRequestId:(const int64_t)requestId name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities;

- (void)createProfileWithRequestId:(const int64_t)requestId name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities space:(nonnull TLSpace *)space;

- (void)updateProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile updateMode:(TLProfileUpdateMode)updateMode name:(nonnull NSString *)name avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities;

- (void)changeProfileTwincodeWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)deleteProfileWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile;

- (void)deleteAccountWithRequestId:(int64_t)requestId;

//
// TwincodeInbound management
//

- (nonnull TLFindResult *)getReceiverWithTwincodeInboundId:(nonnull NSUUID *)twincodeInboundId;

- (void)getGroupMemberReceiverWithTwincodeInboundId:(nonnull NSUUID *)twincodeInboundId memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, id _Nullable receiver))block;

# pragma mark - Contact management

//
// Contact management
//

- (void)findContactsWithFilter:(nonnull TLFilter *)filter withBlock:(nonnull void (^)(NSMutableArray<TLContact*> * _Nonnull list))block;

- (void)getContactWithContactId:(nonnull NSUUID *)contactId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block;

- (void)createContactPhase1WithRequestId:(int64_t)requestId peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound space:(nullable TLSpace *)space profile:(nonnull TLProfile *)profile;

- (void)createContactPhase1WithRequestId:(int64_t)requestId peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound identityName:(nonnull NSString *)identityName identityAvatarId:(nonnull TLImageId *)identityAvatarId;

- (void)updateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact contactName:(nonnull NSString *)contactName description:(nullable NSString *)description;

- (void)updateContactIdentityWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact identityName:(nonnull NSString *)identityName identityAvatar:(nullable UIImage *)identityAvatar identityLargeAvatar:(nullable UIImage *)identityLargeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities;

- (void)verifyContactWithUri:(nonnull TLTwincodeURI *)twincodeURI trustMethod:(TLTrustMethod)trustMethod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block;

- (void)unbindContactWithRequestId:(int64_t)requestId invocationId:(nullable NSUUID *)invocationId contact:(nonnull TLContact *)contact;

- (void)deleteContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

//
// Invitation management
//

- (void)createInvitationWithRequestId:(int64_t)requestId groupMember:(nullable TLGroupMember *)groupMember;

- (void)createInvitationWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact sendTo:(nonnull NSUUID *)sendTo;

- (void)getInvitationWithInvitationId:(nonnull NSUUID *)invitationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvitation * _Nullable invitation))block;

- (void)deleteInvitationWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation;

# pragma mark - Group management

//
// Group management
//

- (void)findGroupsWithFilter:(nonnull TLFilter *)filter withBlock:(nonnull void (^)(NSMutableArray<TLGroup*> * _Nonnull list))block;

- (void)getGroupWithGroupId:(nonnull NSUUID *)groupId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroup * _Nullable group))block;

- (void)createGroupWithRequestId:(int64_t)requestId name:(nonnull NSString *)name description:(nullable NSString *)description avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar;

- (void)createGroupWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitationDescriptor *)invitation;

- (void)updateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description groupAvatar:(nullable UIImage *)groupAvatar groupLargeAvatar:(nullable UIImage *)groupLargeAvatar capabilities:(nullable TLCapabilities *)capabilities;

- (void)updateGroupProfileWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name profileAvatar:(nullable UIImage *)profileAvatar profileLargeAvatar:(nullable UIImage *)profileLargeAvatar;

- (void)deleteGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group;

- (void)getGroupMemberWithOwner:(nonnull id<TLOriginator>)owner memberTwincodeId:(nonnull NSUUID *)memberTwincodeId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupMember * _Nullable member))block;

- (void)listGroupMembersWithGroup:(nonnull TLGroup *)group filter:(TLGroupMemberFilterType)filter withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block;

- (void)listMembersWithOwner:(nonnull id<TLOriginator>)owner memberTwincodeList:(nonnull NSMutableArray *)memberTwincodeList withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block;

- (void)updateStatsWithRequestId:(int64_t)requestId updateScore:(BOOL)updateScore;

# pragma mark - Space management

//
// Level management
//

- (void)setLevelWithRequestId:(int64_t)requestId name:(nonnull NSString *)name;

- (void)createLevelWithRequestId:(int64_t)requestId name:(nonnull NSString *)name;

- (void)deleteLevelWithRequestId:(int64_t)requestId name:(nonnull NSString *)name;

//
// Space management
//

- (nonnull TLFilter *)createSpaceFilter;

- (void)getSpaceWithSpaceId:(nonnull NSUUID *)spaceId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpace * _Nullable space))block;

- (void)getCurrentSpaceWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpace * _Nullable space))block;

- (void)setCurrentSpaceWithRequestId:(int64_t)requestId name:(nonnull NSString *)name;

- (void)setCurrentSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (BOOL)isDefaultSpace:(nonnull TLSpace *)space;

- (nullable TLSpace *)getCurrentSpace;

- (void)getDefaultSpaceWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpace * _Nullable space))block;

- (void)setDefaultSpace:(nonnull TLSpace *)space;

- (void)setDefaultSpaceSettings:(nonnull TLSpaceSettings *)settings oldDefaultName:(nonnull NSString *)oldDefaultName;

- (void)saveDefaultSpaceSettings:(nonnull TLSpaceSettings *)settings withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpaceSettings * _Nullable settings))block;

- (nullable TLSpaceSettings *)defaultSpaceSettings;

- (void)createSpaceWithRequestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar;

- (void)createSpaceWithRequestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nonnull UIImage *)largeAvatar;

- (void)createDefaultSpaceWithRequestId:(int64_t)requestId settings:(nonnull TLSpaceSettings *)settings name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar;

- (void)deleteSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space;

- (void)findSpacesWithPredicate:(nonnull BOOL (^)(TLSpace * _Nonnull space))predicate withBlock:(nonnull void (^)(NSMutableArray<TLSpace*> * _Nonnull list))block;

- (void)moveToSpaceWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact space:(nonnull TLSpace *)space;

- (void)moveToSpaceWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group space:(nonnull TLSpace *)space;

- (void)updateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space profile:(nonnull TLProfile *)profile;

- (void)updateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar;

- (BOOL)isVisible:(nullable id<TLOriginator>)originator;

- (BOOL)isCurrentSpace:(nullable id<TLOriginator>)originator;

//
// Invocation management
//

/// Check if we have some pending invocations being processed.
- (BOOL)hasPendingInvocations;

# pragma mark - Conversation management

//
// Conversation management
//

- (void)findConversationsWithPredicate:(nonnull BOOL (^)(id<TLOriginator> _Nonnull originator))predicate withBlock:(nonnull void (^)(NSMutableArray<id<TLConversation>> * _Nonnull list))block;

- (void)setActiveConversationWithConversation:(nonnull id<TLConversation>)conversation;

- (void)resetActiveConversationWithConversation:(nonnull id<TLConversation>)conversation;

- (void)findConversationDescriptorsWithFilter:(nonnull TLFilter *)filter callsMode:(TLDisplayCallsMode)callsMode withBlock:(nonnull void (^)(NSArray<TLConversationDescriptorPair*> * _Nonnull list))block;

- (void)pushObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)pushFileWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(nonnull NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)pushGeolocationWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta localMapPath:(nullable NSString *)localMapPath expireTimeout:(int64_t)expireTimeout;

- (void)saveGeolocationMapWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId path:(nonnull NSString *)path;

- (void)forwardDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo descriptorId:(nonnull TLDescriptorId *)descriptorId copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)pushTransientObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation object:(nonnull NSObject *)object;

- (void)markDescriptorReadWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)markDescriptorDeletedWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)deleteDescriptorWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)toggleAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value;

- (void)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> * _Nonnull list))block;

- (void)getDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(TLDescriptor * _Nonnull descriptor))block;

# pragma mark - Room management

//
// Room management
//
- (void)roomSetNameWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact name:(nonnull NSString *)name;

- (void)roomSetWelcomeWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact message:(nonnull NSString *)message;

- (void)roomSetImageWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact image:(nonnull UIImage *)image;

- (void)roomSetConfigWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact config:(nonnull TLRoomConfig *)config;

- (void)roomGetConfigWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)roomChangeTwincodeWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)roomDeleteMessageWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact messageId:(nonnull TLDescriptorId *)messageId;

- (void)roomForwardMessageWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact messageId:(nonnull TLDescriptorId *)messageId;

- (void)roomBlockSenderWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact messageId:(nonnull TLDescriptorId *)messageId;

- (void)roomSignalMemberWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId;

- (void)roomDeleteMemberWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId;

- (void)roomSetRolesWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact role:(nonnull NSString *)role members:(nonnull NSArray<NSUUID *> *)members;

- (void)roomListMembersWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact filter:(nonnull NSString *)filter;

# pragma mark - Notification management

//
// Notification management
//

- (nonnull id<TLNotificationCenter>)notificationCenter;

- (void)findNotificationsWithFilter:(nonnull TLFilter *)filter maxDescriptors:(int)maxDescriptors withBlock:(nonnull void (^)(NSMutableArray<TLNotification*> * _Nonnull list))block;

- (void)getNotificationWithNotificationId:(nonnull NSUUID *)notificationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, TLNotification * _Nullable notification))block;

- (nullable TLNotification *)createNotificationWithType:(TLNotificationType)type notificationId:(nullable NSUUID *)notificationId subject:(nonnull id<TLRepositoryObject>)subject descriptorId:(nullable TLDescriptorId *)descriptorId annotatingUser:(nullable TLTwincodeOutbound *)annotatingUser;

- (void)acknowledgeNotificationWithRequestId:(int64_t)requestId notification:(nonnull TLNotification *)notification;

- (void)deleteWithNotification:(nonnull TLNotification *)notification;

- (void)getSpaceNotificationStatsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLNotificationServiceNotificationStat * _Nonnull stats))block;

- (void)getNotificationStatsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSDictionary<NSUUID *, TLNotificationServiceNotificationStat *>* _Nonnull stats))block;

- (void)scheduleRefreshNotifications;

# pragma mark - Call receiver management

//
// Call Receiver
//

- (void)createCallReceiverWithRequestId:(const int64_t)requestId name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nullable NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities*)capabilities space:(nonnull TLSpace *)space;

- (void)getCallReceiverWithCallReceiverId:(nonnull NSUUID *)callReceiverId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLCallReceiver * _Nullable callReceiver))block;

- (void)deleteCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)updateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities*)capabilities;

- (void)changeCallReceiverTwincodeWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver;

- (void)findCallReceiversWithFilter:(nonnull TLFilter *)filter withBlock:(nonnull void (^)(NSMutableArray<TLCallReceiver*> * _Nonnull list))block;

- (void)findInvitationsWithFilter:(nonnull TLFilter*)filter withBlock:(nonnull void (^)(NSArray<TLInvitation*> * _Nonnull list))block;

#pragma mark - Account migration management

- (void)createAccountMigrationWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))block;

- (void)bindAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration twincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable uuid))block;

- (void)deleteAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable uuid))block;

/// Account Migration
- (void)acknowledgeInvocationWithInvocationId:(nonnull NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateAccountMigrationWithRequestId:(int64_t)requestId accountMigration:(nonnull TLAccountMigration *)accountMigration;

- (void)getAccountMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))block;

#pragma mark - Invitation code management

- (void)createInvitationWithCodeWithRequestId:(int64_t)requestId validityPeriod:(int)validityPeriod;

- (void)getInvitationCodeWithRequestId:(int64_t)requestId code:(nonnull NSString *)code;

//
// Timeout based actions
//

- (void)startActionWithAction:(nonnull TLTwinmeAction *)action;

- (void)finishActionWithAction:(nonnull TLTwinmeAction *)action;
@end
