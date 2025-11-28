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

#import <CocoaLumberjack.h>
#import <CommonCrypto/CommonCrypto.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwinlifeContext.h>
#import <Twinlife/TLTwinlifeContext+Protected.h>
#import <Twinlife/TLManagementService.h>
#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLPeerConnectionService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLTwincodeInboundService.h>
#import <Twinlife/TLAccountMigrationService.h>
#import <Twinlife/TLFilter.h>
#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLNotificationService.h>
#import <Twinlife/TLJobService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLQueue.h>
#import <Twinlife/TLFilter.h>
#import <Twinlife/TLConfigIdentifier.h>

#import "TLTwinmeConfiguration.h"
#import "TLTwinmeApplication.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLNotificationCenter.h"

#import "TLProfile.h"
#import "TLSpace.h"
#import "TLSpaceSettings.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLOriginator.h"
#import "TLGroupMember.h"
#import "TLInvitation.h"
#import "TLInvocation.h"
#import "TLInvitation.h"
#import "TLPairProtocol.h"
#import "TLPairInviteInvocation.h"
#import "TLPairBindInvocation.h"
#import "TLPairUnbindInvocation.h"
#import "TLPairRefreshInvocation.h"
#import "TLGroupRegisteredInvocation.h"
#import "TLPushNotificationContent.h"
#import "TLRoomCommand.h"
#import "TLAccountMigration.h"

#import "TLExecutor.h"
#import "TLCreateProfileExecutor.h"
#import "TLUpdateProfileExecutor.h"
#import "TLChangeProfileTwincodeExecutor.h"
#import "TLChangeCallReceiverTwincodeExecutor.h"
#import "TLDeleteProfileExecutor.h"
#import "TLDeleteAccountExecutor.h"
#import "TLCreateContactPhase1Executor.h"
#import "TLCreateContactPhase2Executor.h"
#import "TLUpdateContactAndIdentityExecutor.h"
#import "TLBindContactExecutor.h"
#import "TLUnbindContactExecutor.h"
#import "TLDeleteContactExecutor.h"
#import "TLVerifyContactExecutor.h"
#import "TLProcessInvocationExecutor.h"
#import "TLGetGroupMemberExecutor.h"
#import "TLGetGroupMemberReceiverExecutor.h"
#import "TLCreateGroupExecutor.h"
#import "TLDeleteGroupExecutor.h"
#import "TLUpdateGroupExecutor.h"
#import "TLReportStatsExecutor.h"
#import "TLRefreshObjectExecutor.h"
#import "TLUpdateStatsExecutor.h"
#import "TLCreateInvitationExecutor.h"
#import "TLDeleteInvitationExecutor.h"
#import "TLGetSpacesExecutor.h"
#import "TLUpdateSpaceExecutor.h"
#import "TLCreateSpaceExecutor.h"
#import "TLGroupRegisteredExecutor.h"
#import "TLDeleteSpaceExecutor.h"
#import "TLGetPushNotificationContentExecutor.h"
#import "TLUpdateSettingsExecutor.h"
#import "TLCreateAccountMigrationExecutor.h"
#import "TLBindAccountMigrationExecutor.h"
#import "TLGetAccountMigrationExecutor.h"
#import "TLDeleteAccountMigrationExecutor.h"
#import "TLRebindContactExecutor.h"
#import "TLListMembersExecutor.h"

#import "TLTwinmeAction.h"
#import "TLCallReceiver.h"
#import "TLCreateCallReceiverExecutor.h"
#import "TLDeleteCallReceiverExecutor.h"
#import "TLUpdateCallReceiverExecutor.h"

#import "TLCreateInvitationCodeExecutor.h"
#import "TLGetInvitationCodeExecutor.h"

#import "TLGetObjectAction.h"

#define TWINME_VERSION @TWINME_FRAMEWORK_VERSION

#define TWINME_CONTEXT_CONTACTS_CONTEXT_NAME @"contacts"
#define TWINME_CONTEXT_PROFILE_CONTEXT_NAME @"profile"
#define TWINME_CONTEXT_LEVELS_CONTEXT_NAME @"levels"

#define TWINME_CONTEXT_CALL_ACTION [NSString stringWithFormat:@"call.%@",[TLTwinlife TWINLIFE_DOMAIN]]
#define TWINME_CONTEXT_INVITE_ACTION [NSString stringWithFormat:@"invite.%@",[TLTwinlife TWINLIFE_DOMAIN]]
#define TWINME_CONTEXT_DATE_CARD_ACTION [NSString stringWithFormat:@"date.card.%@",[TLTwinlife TWINLIFE_DOMAIN]]
#define TWINME_CONTEXT_PRIVILEGE_CARD_ACTION [NSString stringWithFormat:@"privilege.card.%@",[TLTwinlife TWINLIFE_DOMAIN]]

#define SPACE_PREFERENCES @"spaces"
#define DEFAULT_SPACE_ID @"defaultSpaceId"
#define DEFAULT_SETTINGS_ID @"defaultSettingsId"
#define LAST_REPORT_DATE_PREFERENCE @"lastReportDate"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int REPORT_STATS = 3;

#ifdef SKRED
static const BOOL DELETE_CONTACT_ON_UNBIND_CONTACT = YES;
static const BOOL ENABLE_REPORT_LOCATION = YES;
#else
static const BOOL DELETE_CONTACT_ON_UNBIND_CONTACT = NO;
static const BOOL ENABLE_REPORT_LOCATION = NO;
#endif

@class TLVersion;

//
// Interface: TLNotificationRefreshJob ()
//

@interface TLNotificationRefreshHandler : NSObject <TLJob>

@property (weak) TLTwinmeContext *twinmeContext;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext;

- (void)runJob;

@end

//
// Interface: TLTwinmeActionTimeoutHandler ()
//

@interface TLTwinmeActionTimeoutHandler : NSObject <TLJob>

@property (weak) TLTwinmeContext *twinmeContext;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext;

- (void)runJob;

@end

//
// Interface: TLTwinmeContext ()
//

@class TLTwinmeContextConversationServiceDelegate;
@class TLTwinmeContextTwincodeInboundServiceDelegate;
@class TLTwinmeContextTwincodeOutboundServiceDelegate;
@class TLTwinmeContextPeerConnectionServiceDelegate;
@class TLTwinmeContextRepositoryServiceDelegate;
@class TLTwinmeContextNotificationServiceDelegate;

@interface TLTwinmeContext ()<TLJob>

@property (readonly, nonnull) TLTwinmeApplication *twinmeApplication;
@property (readonly, nonnull) TLNotificationRefreshHandler *notificationRefresh;
@property (readonly, nonnull) TLTwinmeActionTimeoutHandler *actionTimeout;
@property volatile BOOL inBackground;
@property NSMutableDictionary<NSUUID *, TLSpace *> *spaces;
@property (readonly, nonnull) NSMutableDictionary<NSString *, TLExecutor*> *executors;
@property TLSpaceSettings *defaultCreateSpaceSettings;
@property NSUUID *defaultSpaceId;
@property NSUUID *defaultSettingsId;
@property BOOL getSpacesDone;
@property BOOL hasProfiles;
@property BOOL hasSpaces;
@property BOOL enableCaches;
@property BOOL enableReports;
@property BOOL enableSpaces;
@property NSTimeInterval refreshBadgeDelay;
@property TLSpace *currentSpace;
@property TLProfile *currentProfile;
@property NSMutableDictionary<NSUUID *, TLGroupMember *> *groupMembers;
@property NSUUID *activeConversationId;
@property TLNotificationServiceNotificationStat *visibleNotificationStats;
@property int64_t reportRequestId;
@property (nonatomic, readonly, nonnull) TLQueue *pendingActions;
@property (nullable) TLJobId *actionTimeoutJob;
@property (nullable) TLTwinmeAction *firstAction;

@property id<TLNotificationCenter> notificationCenter;
@property (nullable) TLJobId *reportJob;
@property (nullable) TLJobId *notificationRefreshJob;

@property (readonly, nonnull) NSMutableDictionary<NSNumber *, NSNumber *> *requestIds;
@property (readonly, nonnull) TLUUIDConfigIdentifier *defaultSpaceConfig;
@property (readonly, nonnull) TLUUIDConfigIdentifier *defaultSettingsConfig;

@property (nonatomic, readonly, nonnull) TLTwinmeContextConversationServiceDelegate *conversationServiceDelegate;
@property (nonatomic, readonly, nonnull) TLTwinmeContextPeerConnectionServiceDelegate *peerConnectionServiceDelegate;
@property (nonatomic, readonly, nonnull) TLTwinmeContextTwincodeOutboundServiceDelegate *twincodeOutboundServiceDelegate;
@property (nonatomic, readonly, nonnull) TLTwinmeContextRepositoryServiceDelegate *repositoryServiceDelegate;
@property (nonatomic, readonly, nonnull) TLTwinmeContextNotificationServiceDelegate *notificationServiceDelegate;

- (void)onProcessInvocation:(nonnull TLInvocation *)invocation;

- (void)onPushDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor;

- (void)onPopDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor;

- (void)onUpdateDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType;

- (void)onUpdateAnnotationWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor annotatingUser:(nonnull TLTwincodeOutbound *)annotatingUser;

- (void)onIncomingPeerConnectionWithPeerConnectionId:(NSUUID *)peerConnectionId peerId:(NSString *)peerId offer:(nonnull TLOffer *)offer;

- (TLBaseServiceErrorCode)onInvokeTwincodeWithInvocation:(nonnull TLTwincodeInvocation *)invocation;

- (void)onRefreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound updatedAttributes:(nonnull NSArray<TLAttributeNameValue *> *)updatedAttributes;

- (void)onLeaveGroupWithGroup:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId;

- (void)onRevokedWithConversation:(nonnull id <TLConversation>)conversation;

- (void)onSignatureInfoWithConversation:(nonnull id<TLConversation>)conversation signedTwincode:(nonnull TLTwincodeOutbound *)signedTwincode;

- (void)refreshNotifications;

- (void)runJobActionTimeout;

@end

//
// Interface: TLTwinmeContextTwinmeContextDelegate
//

@interface TLTwinmeContextTwinmeContextDelegate : NSObject <TLTwinmeContextDelegate>

@property (weak) TLTwinmeContext *twinmeContext;

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext;

@end

//
// Implementation: TLTwinmeAssertPoint ()
//

@implementation TLTwinmeAssertPoint

TL_CREATE_ASSERT_POINT(PROCESS_INVOCATION, 3000)
TL_CREATE_ASSERT_POINT(ON_UPDATE_ANNOTATION, 3001)
TL_CREATE_ASSERT_POINT(ON_UPDATE_DESCRIPTOR, 3002)
TL_CREATE_ASSERT_POINT(ON_POP_DESCRIPTOR, 3003)
TL_CREATE_ASSERT_POINT(INCOMING_PEER_CONNECTION, 3004)

@end

//
// Implementation: TLNotificationRefreshHandler ()
//

#undef LOG_TAG
#define LOG_TAG @"TLNotificationRefreshHandler"

@implementation TLNotificationRefreshHandler

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    [self.twinmeContext refreshNotifications];
}

@end

//
// Implementation: TLTwinmeActionTimeoutHandler ()
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeActionTimeoutHandler"

@implementation TLTwinmeActionTimeoutHandler

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    [self.twinmeContext runJobActionTimeout];
}

@end

#pragma mark - ConversationService delegate

//
// Interface: TLTwinmeContextConversationServiceDelegate
//

@interface TLTwinmeContextConversationServiceDelegate:NSObject <TLConversationServiceDelegate>

@property (weak) TLTwinmeContext *twinmeContext;

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext;

@end

//
// Implementation: TLTwinmeContextConversationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeContextConversationServiceDelegate"

@implementation TLTwinmeContextConversationServiceDelegate

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    [self.twinmeContext onPushDescriptorWithConversation:conversation descriptor:descriptor];
}

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@", LOG_TAG, requestId, conversation, descriptor);
    
    [self.twinmeContext onPopDescriptorWithConversation:conversation descriptor:descriptor];
}

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithRequestId: %lld conversation: %@ objectDescriptor: %@ updateType: %u", LOG_TAG, requestId, conversation, descriptor, updateType);
    
    [self.twinmeContext onUpdateDescriptorWithConversation:conversation descriptor:descriptor updateType:updateType];
}

- (void)onUpdateAnnotationWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor annotatingUser:(nonnull TLTwincodeOutbound *)annotatingUser {
    DDLogVerbose(@"%@ onUpdateAnnotationWithConversation: %@ objectDescriptor: %@ annotatingUser: %@", LOG_TAG, conversation, descriptor, annotatingUser);

    [self.twinmeContext onUpdateAnnotationWithConversation:conversation descriptor:descriptor annotatingUser:annotatingUser];
}

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithRequestId: %lld group: %@ memberId: %@", LOG_TAG, requestId, group, memberId);
    
    [self.twinmeContext onLeaveGroupWithGroup:group memberId:memberId];
}

- (void)onRevokedWithConversation:(id <TLConversation>)conversation {
    DDLogVerbose(@"%@ onRevokedWithConversation: %@", LOG_TAG, conversation);
    
    [self.twinmeContext onRevokedWithConversation:conversation];
}

- (void)onSignatureInfoWithConversation:(nonnull id<TLConversation>)conversation signedTwincode:(nonnull TLTwincodeOutbound *)signedTwincode {
    DDLogVerbose(@"%@ onSignatureInfoWithConversation: %@ signedTwincode: %@", LOG_TAG, conversation, signedTwincode);
    
    [self.twinmeContext onSignatureInfoWithConversation:conversation signedTwincode:signedTwincode];

}

@end

#pragma mark - PeerConnectionService delegate

//
// Interface: TLTwinmeContextPeerConnectionServiceDelegate
//

@interface TLTwinmeContextPeerConnectionServiceDelegate:NSObject <TLPeerConnectionServiceDelegate>

@property (weak) TLTwinmeContext *twinmeContext;

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext;

@end

//
// Implementation: TLTwinmeContextPeerConnectionServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeContextPeerConnectionServiceDelegate"

@implementation TLTwinmeContextPeerConnectionServiceDelegate

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)onIncomingPeerConnectionWithPeerConnectionId:(NSUUID *)peerConnectionId peerId:(NSString *)peerId offer:(nonnull TLOffer *)offer {
    DDLogVerbose(@"%@ onIncomingPeerConnectionWithPeerConnectionId: %@ peerId: %@ offer: %@", LOG_TAG, peerConnectionId, peerId, offer);
    
    [self.twinmeContext onIncomingPeerConnectionWithPeerConnectionId:peerConnectionId peerId:peerId offer:offer];
}

@end

#pragma mark - TwincodeOutboundService delegate

//
// Interface: TLTwinmeContextTwincodeOutboundServiceDelegate
//

@interface TLTwinmeContextTwincodeOutboundServiceDelegate:NSObject <TLTwincodeOutboundServiceDelegate>

@property (weak) TLTwinmeContext *twinmeContext;

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext;

@end

//
// Interface: TLTwinmeContextRepositoryServiceDelegate
//

@interface TLTwinmeContextRepositoryServiceDelegate : NSObject <TLRepositoryServiceDelegate>

@property (weak) TLTwinmeContext *twinmeContext;

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext;

@end

//
// Interface: TLTwinmeContextNotificationServiceDelegate
//

@interface TLTwinmeContextNotificationServiceDelegate : NSObject <TLNotificationServiceDelegate>

@property (weak) TLTwinmeContext *twinmeContext;

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext;

@end

//
// Implementation: TLTwinmeContextTwincodeOutboundServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeContextTwincodeOutboundServiceDelegate"

@implementation TLTwinmeContextTwincodeOutboundServiceDelegate

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)onRefreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound updatedAttributes:(nonnull NSArray<TLAttributeNameValue *> *)updatedAttributes {
    DDLogVerbose(@"%@ onRefreshTwincodeWithTwincode: %@ updatedAttributes: %@", LOG_TAG, twincodeOutbound, updatedAttributes);
    
    [self.twinmeContext onRefreshTwincodeWithTwincode:twincodeOutbound updatedAttributes:updatedAttributes];
}

@end

//
// Implementation: TLTwinmeContextRepositoryServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeContextRepositoryServiceDelegate"

@implementation TLTwinmeContextRepositoryServiceDelegate

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)onInvalidObjectWithObject:(nonnull id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ onInvalidObjectWithObject: %@", LOG_TAG, object);
    
    if ([object isKindOfClass:[TLContact class]]) {
        [self.twinmeContext deleteContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] contact:(TLContact *)object];

    } else if ([object isKindOfClass:[TLGroup class]]) {
        [self.twinmeContext deleteGroupWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:(TLGroup *)object];

    } else if ([object isKindOfClass:[TLCallReceiver class]]) {
        [self.twinmeContext deleteCallReceiverWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] callReceiver:(TLCallReceiver *)object];

    } else if ([object isKindOfClass:[TLInvitation class]]) {
        [self.twinmeContext deleteInvitationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] invitation:(TLInvitation *)object];

    } else if ([object isKindOfClass:[TLSpace class]]) {
        [self.twinmeContext deleteSpaceWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] space:(TLSpace *)object];

    } else if ([object isKindOfClass:[TLProfile class]]) {
        [self.twinmeContext deleteProfileWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] profile:(TLProfile *)object];

    } else {
        TLRepositoryService *repositoryService = [self.twinmeContext getRepositoryService];
        [repositoryService deleteObjectWithObject:object withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *objectId) {
            
        }];
    }
}

@end

//
// Implementation: TLTwinmeContextNotificationServiceDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeContextNotificationServiceDelegate"

@implementation TLTwinmeContextNotificationServiceDelegate

- (instancetype)initWithTwinmeContext:(TLTwinmeContext *)twinmeContext {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@", LOG_TAG, twinmeContext);
    
    self = [super init];
    
    if (self) {
        _twinmeContext = twinmeContext;
    }
    return self;
}

- (void)onCanceledNotificationsWithList:(nonnull NSArray<NSUUID *> *)list {
    DDLogVerbose(@"%@ onCanceledNotificationsWithList: %@", LOG_TAG, list);
    
    for (NSUUID *notificationId in list) {
        [self.twinmeContext.notificationCenter cancelWithNotificationId:notificationId];
    }

    for (id delegate in self.twinmeContext.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteNotificationsWithList:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinmeContext.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteNotificationsWithList:list];
            });
        }
    }
    [self.twinmeContext scheduleRefreshNotifications];
}

@end

//
// Implementation: TLTwinmeContext
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinmeContext"

@implementation TLTwinmeContext

+ (NSString *)VERSION {
    
    return TWINME_VERSION;
}

+ (NSString *)CONTACTS_CONTEXT_NAME {
    
    return TWINME_CONTEXT_CONTACTS_CONTEXT_NAME;
}

+ (NSString *)PROFILE_CONTEXT_NAME {
    
    return TWINME_CONTEXT_PROFILE_CONTEXT_NAME;
}

+ (NSString *)LEVELS_CONTEXT_NAME {
    
    return TWINME_CONTEXT_LEVELS_CONTEXT_NAME;
}

+ (NSString *)CALL_ACTION {
    
    return TWINME_CONTEXT_CALL_ACTION;
}

+ (NSString *)INVITE_ACTION {
    
    return TWINME_CONTEXT_INVITE_ACTION;
}

+ (NSString *)DATE_CARD_ACTION {
    
    return TWINME_CONTEXT_DATE_CARD_ACTION;
}

+ (NSString *)PRIVILEGE_CARD_ACTION {
    
    return TWINME_CONTEXT_PRIVILEGE_CARD_ACTION;
}

+ (BOOL)ENABLE_REPORT_LOCATION {
    
    return ENABLE_REPORT_LOCATION;
}

- (instancetype)initWithTwinmeApplication:(TLTwinmeApplication *)twinmeApplication configuration:(TLTwinmeConfiguration *)configuration {
    DDLogVerbose(@"%@ initWithTwinmeApplication: %@ configuration: %@", LOG_TAG, twinmeApplication, configuration);
    
    self =  [super initWithConfiguration:configuration];
    
    if (self) {
        _twinmeApplication = twinmeApplication;
        _inBackground = YES;
        _notificationRefresh = [[TLNotificationRefreshHandler alloc] initWithTwinmeContext:self];
        _actionTimeout = [[TLTwinmeActionTimeoutHandler alloc] initWithTwinmeContext:self];
        _spaces = [[NSMutableDictionary alloc] init];
        _getSpacesDone = NO;
        _groupMembers = [[NSMutableDictionary alloc] init];
        _notificationCenter = [_twinmeApplication allocNotificationCenterWithTwinmeContext:self];
        _requestIds = [[NSMutableDictionary alloc] init];
        _reportRequestId = [TLBaseService DEFAULT_REQUEST_ID];
        _executors = [[NSMutableDictionary alloc] init];
        _enableCaches = configuration.enableCaches;
        _enableInvocations = configuration.enableInvocations;
        _enableReports = configuration.enableReports;
        _enableSpaces = configuration.enableSpaces;
        _refreshBadgeDelay = configuration.refreshBadgeDelay;
        _defaultSpaceConfig = [TLUUIDConfigIdentifier defineWithName:DEFAULT_SPACE_ID uuid:@"D7E5E971-2813-4418-AD23-D9DE2E1D085F"];
        _defaultSettingsConfig = [TLUUIDConfigIdentifier defineWithName:DEFAULT_SETTINGS_ID uuid:@"f80f7791-15a7-4944-b743-99a84eba6fba"];
        _lastReportDate = [TLIntegerConfigIdentifier defineWithName:LAST_REPORT_DATE_PREFERENCE uuid:@"9D8EB22F-14DE-4BC7-8C39-892F249724BE" defaultValue:0];

        _conversationServiceDelegate = [[TLTwinmeContextConversationServiceDelegate alloc] initWithTwinmeContext:self];
        _peerConnectionServiceDelegate = [[TLTwinmeContextPeerConnectionServiceDelegate alloc] initWithTwinmeContext:self];
        _twincodeOutboundServiceDelegate = [[TLTwinmeContextTwincodeOutboundServiceDelegate alloc] initWithTwinmeContext:self];
        _repositoryServiceDelegate = [[TLTwinmeContextRepositoryServiceDelegate alloc] initWithTwinmeContext:self];
        _notificationServiceDelegate = [[TLTwinmeContextNotificationServiceDelegate alloc] initWithTwinmeContext:self];
        
        _pendingActions = [[TLQueue alloc] initWithComparator:^NSComparisonResult(id<NSObject> obj1, id<NSObject> obj2) {
            TLTwinmeAction *action1 = (TLTwinmeAction *)obj1;
            TLTwinmeAction *action2 = (TLTwinmeAction *)obj2;
            
            return [action1 compareWithAction:action2];
        }];
        
        // Get default space UUID if there is one.
        _defaultSpaceId = _defaultSpaceConfig.uuidValue;
        _defaultSettingsId = _defaultSettingsConfig.uuidValue;
    }
    
    return self;
}

//
// Application Delegate
//

- (void)applicationDidEnterBackground:(id<TLApplication>)application {
    DDLogVerbose(@"%@ applicationDidEnterBackground: %@", LOG_TAG, application);
    
    self.inBackground = YES;
    [self.twinlife applicationDidEnterBackground:application];
    
    // Invalidate the notification stats to force an update at the next refreshNotifications.
    self.visibleNotificationStats = nil;
}

- (void)applicationDidBecomeActive:(id<TLApplication>)application {
    DDLogVerbose(@"%@ applicationDidBecomeActive: %@", LOG_TAG, application);
    
    self.inBackground = NO;
    [self.twinlife applicationDidBecomeActive:application];
}

- (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    DDLogVerbose(@"%@ openURL: %@ options: %@", LOG_TAG, url, options);
    
    [self.twinlife applicationDidOpenURL];

    TLTwincodeOutboundService *service = self.twinlife.getTwincodeOutboundService;

    // Use parseUriWithUri to verify that the URI is handled by the application.
    __block BOOL result = NO;
    [service parseUriWithUri:url withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeURI *twincodeUri) {
        if (errorCode == TLBaseServiceErrorCodeSuccess) {
            for (id delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onOpenURL:)]) {
                    id<TLTwinmeContextDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onOpenURL:url];
                    });
                }
            }
            result = YES;
        }
    }];
    return result;
}

- (BOOL)isDatabaseUpgraded {
    DDLogVerbose(@"%@ isDatabaseUpgraded", LOG_TAG);
    
    // It can be called while Twinlife instance is not yet created.
    TLTwinlife *twinlife = self.twinlife;
    if (twinlife && [twinlife isDatabaseUpgraded]) {
        return YES;
    }
    
    // These flags are updated from onTwinlifeReady() called from another thread.
    @synchronized (self) {
        return self.hasProfiles && !self.hasSpaces;
    }
}

- (void)setPushNotificationWithVariant:(NSString*)variant token:(NSString*)token {
    DDLogVerbose(@"%@ setPushNotificationWithVariant: %@ token: %@", LOG_TAG, variant, token);
    
    [[self getManagementService] setPushNotificationWithVariant:variant token:token];
}

- (void)getPushNotificationContentWithDictionary:(nonnull NSDictionary *)dictionaryPayload withBlock:(nonnull void (^)(TLBaseServiceErrorCode status,  TLPushNotificationContent * _Nullable notificationContent))block {
    DDLogVerbose(@"%@ getPushNotificationContentWithDictionary: %@", LOG_TAG, dictionaryPayload);
    
    TLGetPushNotificationContentExecutor *getPushNotificationContentExecutor = [[TLGetPushNotificationContentExecutor alloc] initWithTwinmeContext:self dictionaryPayload:dictionaryPayload withBlock:block];
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        
        [getPushNotificationContentExecutor start];
    });
}

- (void)didReceiveIncomingPushWithPayload:(nonnull NSDictionary *)dictionaryPayload application:(nullable id<TLApplication>)application completionHandler:(nonnull void (^)(TLBaseServiceErrorCode status, TLPushNotificationContent * _Nullable notificationContent))completionHandler terminateCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))terminateHandler {
    DDLogVerbose(@"%@ didReceiveIncomingPushWithPayload: %@ application: %@", LOG_TAG, dictionaryPayload, application);
    
    [[self.twinlife getJobService] didWakeupWithApplication:application kind:TLWakeupKindPush fetchCompletionHandler:terminateHandler];
    
    [self getPushNotificationContentWithDictionary:dictionaryPayload withBlock:^(TLBaseServiceErrorCode status, TLPushNotificationContent *notificationContent) {
        completionHandler(status, notificationContent);
    }];
}

//
// TwincodeInbound Management
//

- (nonnull TLFindResult *)getReceiverWithTwincodeInboundId:(nonnull NSUUID *)twincodeInboundId {
    DDLogVerbose(@"%@ getReceiverWithTwincodeInboundId: %@", LOG_TAG, twincodeInboundId);
    
    NSArray *factories = [NSArray arrayWithObjects: [TLContact FACTORY], [TLProfile FACTORY], [TLGroup FACTORY], [TLInvitation FACTORY], [TLCallReceiver FACTORY], [TLAccountMigration FACTORY], nil];

    return [[self getRepositoryService] findObjectWithInboundId:YES uuid:twincodeInboundId factories:factories];
}

- (void)getGroupMemberReceiverWithTwincodeInboundId:(NSUUID *)twincodeInboundId memberTwincodeOutboundId:(NSUUID *)memberTwincodeOutboundId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id _Nullable receiver))block {
    DDLogVerbose(@"%@ getGroupMemberReceiverWithTwincodeInboundId: %@ memberTwincodeOutboundId: %@", LOG_TAG, twincodeInboundId, memberTwincodeOutboundId);
    
    TLGroupMember *groupMember;
    @synchronized (self) {
        groupMember = self.groupMembers[memberTwincodeOutboundId];
    }
    
    if (groupMember && [twincodeInboundId isEqual:[groupMember twincodeInboundId]]) {
        block(TLBaseServiceErrorCodeSuccess, groupMember);
    } else {
        TLGetGroupMemberReceiverExecutor *getGroupMemberReceiverExecutor = [[TLGetGroupMemberReceiverExecutor alloc] initWithTwinmeContext:self twincodeInboundId:twincodeInboundId memberTwincodeOutboundId:memberTwincodeOutboundId withBlock:block];
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [getGroupMemberReceiverExecutor start];
        });
    }
}

#pragma mark - Profile management

//
// Profile Management
//

- (BOOL)isCurrentProfile:(TLProfile *)profile {
    DDLogVerbose(@"%@ isCurrentProfile", LOG_TAG);
    
    if (profile == self.currentProfile) {
        return  YES;
    }
    
    if (!profile || !self.currentProfile) {
        return  NO;
    }
    
    return [profile.uuid isEqual:self.currentProfile.uuid];
}

- (BOOL)isSpaceProfile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ isSpaceProfile", LOG_TAG);
    
    return profile.space == self.currentSpace;
}

- (BOOL)isProfileTwincode:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ isProfileTwincode: %@", LOG_TAG, twincodeId);
    
    @synchronized(self) {
        for (TLSpace *space in self.spaces.allValues) {
            TLProfile *profile = space.profile;
            if (profile && [twincodeId isEqual:profile.twincodeOutbound.uuid]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)getProfilesWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLProfile*> * _Nonnull list))block {
    DDLogVerbose(@"%@ getProfilesWithWithBlock", LOG_TAG);
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        TLFilter *filter = [self createSpaceFilter];
        [repositoryService listObjectsWithFactory:[TLProfile FACTORY] filter:filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            NSMutableArray<TLProfile*> *result = [[NSMutableArray alloc] initWithCapacity:list.count];
            for (id<TLRepositoryObject> object in list) {
                [result addObject:(TLProfile *)object];
            }
            block(errorCode, result);
        }];
    });
}

- (void)createProfileWithRequestId:(const int64_t)requestId name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ createProfileWithRequestId: %lld name: %@ avatar: %@ space: %@", LOG_TAG, requestId, name, avatar, space);
    
    if (!name || name.length == 0 || !space || !avatar) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateProfileExecutor *createProfileExecutor = [[TLCreateProfileExecutor alloc] initWithTwinmeContext:self requestId:requestId name:name avatar:avatar largeAvatar:largeAvatar description:description capabilities:capabilities space:space];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createProfileExecutor start];
    });
}

- (void)createProfileWithRequestId:(const int64_t)requestId name:(NSString *)name avatar:(UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities {
    DDLogVerbose(@"%@ createProfileWithRequestId: %lld name: %@ avatar: %@ largeAvatar: %@ description: %@ capabilities: %@", LOG_TAG, requestId, name, avatar, largeAvatar, description, capabilities);
    
    TLCreateProfileExecutor *createProfileExecutor = [[TLCreateProfileExecutor alloc] initWithTwinmeContext:self requestId:requestId name:name avatar:avatar largeAvatar:largeAvatar description:description capabilities:capabilities space:nil];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createProfileExecutor start];
    });
}

- (void)onCreateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onCreateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateProfileWithRequestId:profile:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onCreateProfileWithRequestId:requestId profile:profile];
            });
        }
    }
}

- (void)updateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile updateMode:(TLProfileUpdateMode)updateMode name:(NSString *)name avatar:(UIImage *)avatar largeAvatar:(UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities {
    DDLogVerbose(@"%@ updateProfileWithRequestId: %lld profile: %@ updateMode: %d @name: %@ avatar: %@ largeAvatar: %@ description: %@ capabilities: %@", LOG_TAG, requestId, profile, updateMode, name, avatar, largeAvatar, description, capabilities);
    
    TLUpdateProfileExecutor *updateProfileExecutor = [[TLUpdateProfileExecutor alloc] initWithTwinmeContext:self requestId:requestId profile:profile updateMode:updateMode name:name avatar:avatar largeAvatar:largeAvatar description:description capabilities:capabilities];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateProfileExecutor start];
    });
}

- (void)onUpdateProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onUpdateProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateProfileWithRequestId:profile:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onUpdateProfileWithRequestId:requestId profile:profile];
            });
        }
    }
}

- (void)changeProfileTwincodeWithRequestId:(int64_t)requestId profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ changeProfileTwincodeWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    TLChangeProfileTwincodeExecutor *changeProfileTwincodeExecutor = [[TLChangeProfileTwincodeExecutor alloc] initWithTwinmeContext:self requestId:requestId profile:profile];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [changeProfileTwincodeExecutor start];
    });
}

- (void)onChangeProfileTwincodeWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ onChangeProfileTwincodeWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onChangeProfileTwincodeWithRequestId:profile:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onChangeProfileTwincodeWithRequestId:requestId profile:profile];
            });
        }
    }
}

- (void)deleteProfileWithRequestId:(int64_t)requestId profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ deleteProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
    
    TLDeleteProfileExecutor *deleteProfileExecutor = [[TLDeleteProfileExecutor alloc] initWithTwinmeContext:self requestId:requestId profile:profile timeout:DBL_MAX withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *profileId) {
        [self onDeleteProfileWithRequestId:requestId profileId:profileId];
    }];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [deleteProfileExecutor start];
    });
}

- (void)onDeleteProfileWithRequestId:(int64_t)requestId profileId:(NSUUID *)profileId{
    DDLogVerbose(@"%@ onDeleteProfileWithRequestId: %lld groupId: %@", LOG_TAG, requestId, profileId);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteProfileWithRequestId:profileId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onDeleteProfileWithRequestId:requestId profileId:profileId];
            });
        }
    }
}

- (void)deleteAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ deleteAccountWithRequestId: %lld", LOG_TAG, requestId);
    
    TLDeleteAccountExecutor *deleteAccountExecutor = [[TLDeleteAccountExecutor alloc] initWithTwinmeContext:self requestId:requestId];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [deleteAccountExecutor start];
    });
}

- (void)onDeleteAccountWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ onDeleteProfileWithRequestId: %lld", LOG_TAG, requestId);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteAccountWithRequestId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onDeleteAccountWithRequestId:requestId];
            });
        }
    }
}

#pragma mark - Account migration management

- (void)getAccountMigrationWithAccountMigrationId:(nonnull NSUUID *)accountMigrationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))block{
    DDLogVerbose(@"%@ getAccountMigrationWithAccountMigrationId: %@", LOG_TAG, accountMigrationId.UUIDString);
    
    TLGetAccountMigrationExecutor *executor = [[TLGetAccountMigrationExecutor alloc] initWithTwinmeContext:self deviceMigrationId:accountMigrationId withBlock:block];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [executor start];
    });
}

- (void)createAccountMigrationWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable accountMigration))block{
    DDLogVerbose(@"%@ createAccountMigrationWithBlock", LOG_TAG);
    
    TLCreateAccountMigrationExecutor *createAccountMigrationExecutor = [[TLCreateAccountMigrationExecutor alloc] initWithTwinmeContext:self withBlock:block];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [createAccountMigrationExecutor start];
    });
}

- (void)bindAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration twincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLAccountMigration * _Nullable uuid))block{
    DDLogVerbose(@"%@ bindAccountMigrationWithAccountMigration: %@ peerTwincodeOutbound: %@", LOG_TAG, accountMigration, peerTwincodeOutbound);
    
    TLBindAccountMigrationExecutor *executor = [[TLBindAccountMigrationExecutor alloc] initWithTwinmeContext:self accountMigration:accountMigration peerTwincodeOutbound:peerTwincodeOutbound consumer:block];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [executor start];
    });
}

- (void)bindAccountMigrationWithRequestId:(int64_t)requestId invocationId:(nonnull NSUUID *)invocationId accountMigration:(nonnull TLAccountMigration *)accountMigration peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId {
    DDLogVerbose(@"%@ bindAccountMigrationWithRequestId: %lld invocationId: %@ accountMigration: %@ peerTwincodeOutboundId: %@", LOG_TAG, requestId, invocationId.UUIDString, accountMigration, peerTwincodeOutboundId.UUIDString);
    
    TLBindAccountMigrationExecutor *executor = [[TLBindAccountMigrationExecutor alloc] initWithTwinmeContext:self requestId:requestId invocationId:invocationId accountMigration:accountMigration peerTwincodeOutboundId:peerTwincodeOutboundId];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [executor start];
    });
}

- (void)deleteAccountMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable uuid))block{
    DDLogVerbose(@"%@ deleteAccountMigrationWithAccountMigration: %@", LOG_TAG, accountMigration);
    
    TLDeleteAccountMigrationExecutor *executor = [[TLDeleteAccountMigrationExecutor alloc] initWithTwinmeContext:self accountMigration:accountMigration withBlock:block];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [executor start];
    });
}

- (void)onUpdateAccountMigrationWithRequestId:(int64_t)requestId accountMigration:(nonnull TLAccountMigration *)accountMigration {
    DDLogVerbose(@"%@ onUpdateAccountMigrationWithRequestId: %lld accountMigration: %@", LOG_TAG, requestId, accountMigration);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateAccountMigrationWithRequestId:accountMigration:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateAccountMigrationWithRequestId:requestId accountMigration:accountMigration];
            });
        }
    }
}

- (void)onDeleteAccountMigrationWithRequestId:(int64_t)requestId accountMigrationId:(nonnull NSUUID *)accountMigrationId {
    DDLogVerbose(@"%@ onDeleteAccountMigrationWithRequestId: %lld accountMigration: %@", LOG_TAG, requestId, accountMigrationId.UUIDString);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteAccountMigrationWithRequestId:accountMigrationId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteAccountMigrationWithRequestId:requestId accountMigrationId:accountMigrationId];
            });
        }
    }
}

#pragma mark - Invitation code management

- (void)createInvitationWithCodeWithRequestId:(int64_t)requestId validityPeriod:(int)validityPeriod {
    DDLogVerbose(@"%@ createInvitationCodeWithRequestId: %lld validityPeriod: %d", LOG_TAG, requestId, validityPeriod);
    
    TLCreateInvitationCodeExecutor *executor = [[TLCreateInvitationCodeExecutor alloc] initWithTwinmeContext:self requestId:requestId validityPeriod:validityPeriod];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [executor start];
    });
}


- (void)onCreateInvitationWithCodeWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitation *)invitation {
    DDLogVerbose(@"%@ onCreateInvitationCodeWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateInvitationWithCodeWithRequestId:invitation:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onCreateInvitationWithCodeWithRequestId:requestId invitation:invitation];
            });
        }
    }
}

- (void)getInvitationCodeWithRequestId:(int64_t)requestId code:(nonnull NSString *)code {
    DDLogVerbose(@"%@ getInvitationCodeWithRequestId: %lld code: %@", LOG_TAG, requestId, code);

    TLGetInvitationCodeExecutor *executor = [[TLGetInvitationCodeExecutor alloc] initWithTwinmeContext:self requestId:requestId code:code];
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        [executor start];
    });
}

- (void)onGetInvitationCodeWithRequestId:(int64_t)requestId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound publicKey:(nullable NSString *)publicKey {
    DDLogVerbose(@"%@ onGetInvitationCodeWithRequestId: %lld twincodeOutbound: %@ publicKey: %@", LOG_TAG, requestId, twincodeOutbound, publicKey);

    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onGetInvitationCodeWithRequestId:twincodeOutbound:publicKey:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onGetInvitationCodeWithRequestId:requestId twincodeOutbound:twincodeOutbound publicKey:publicKey];
            });
        }
    }
}

#pragma mark - Contact management

//
// Contact management
//

- (void)findContactsWithFilter:(nonnull TLFilter *)filter withBlock:(nonnull void (^)(NSMutableArray<TLContact*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findContactsWithFilter: %@", LOG_TAG, filter);
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService listObjectsWithFactory:[TLContact FACTORY] filter:filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            NSMutableArray<TLContact*> *result = [[NSMutableArray alloc] initWithCapacity:list.count];
            for (id<TLRepositoryObject> object in list) {
                [result addObject:(TLContact *)object];
            }
            block(result);
        }];
    });
}

- (void)getContactWithContactId:(nonnull NSUUID *)contactId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block {
    DDLogVerbose(@"%@ getContactWithContactId: %@", LOG_TAG, contactId);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService getObjectWithFactory:[TLContact FACTORY] objectId:contactId withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            
            block(errorCode, (TLContact *)object);
        }];
    });
}

- (void)createContactPhase1WithRequestId:(int64_t)requestId peerTwincodeOutbound:(TLTwincodeOutbound *)peerTwincodeOutbound space:(nullable TLSpace *)space profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ createContactPhase1WithRequestId: %lld  peerTwincodeOutbound: %@ space: %@ profile: %@", LOG_TAG, requestId, peerTwincodeOutbound, space, profile);
    
    if (!space) {
        space = self.currentSpace;
    }
    TLCreateContactPhase1Executor *createContactPhase1Executor = [[TLCreateContactPhase1Executor alloc] initWithTwinmeContext:self requestId:requestId peerTwincodeOutbound:peerTwincodeOutbound space:space profile:profile];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createContactPhase1Executor start];
    });
}

- (void)createContactPhase1WithRequestId:(int64_t)requestId peerTwincodeOutbound:(TLTwincodeOutbound *)peerTwincodeOutbound identityName:(NSString *)identityName identityAvatarId:(TLImageId *)identityAvatarId {
    DDLogVerbose(@"%@ createContactPhase1WithRequestId: %lld  peerTwincodeOutbound: %@ identityName: %@ identityAvatarId: %@", LOG_TAG, requestId, peerTwincodeOutbound, identityName, identityAvatarId);
    
    TLCreateContactPhase1Executor *createContactPhase1Executor = [[TLCreateContactPhase1Executor alloc] initWithTwinmeContext:self requestId:requestId peerTwincodeOutbound:peerTwincodeOutbound space:self.currentSpace identityName:identityName identityAvatarId:identityAvatarId];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createContactPhase1Executor start];
    });
}

- (void)createContactPhase2WithInvocation:(nonnull TLPairInviteInvocation *)invocation profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ createContactPhase2WithInvocation: %@ profile: %@", LOG_TAG, invocation, profile);
    
    TLCreateContactPhase2Executor *createContactPhase2Executor = [[TLCreateContactPhase2Executor alloc] initWithTwinmeContext:self invocation:invocation space:profile.space profile:profile];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createContactPhase2Executor start];
    });
}

- (void)createContactPhase2WithInvocation:(nonnull TLPairInviteInvocation *)invocation invitation:(nonnull TLInvitation *)invitation {
    DDLogVerbose(@"%@ createContactPhase2WithInvocation: %@ invitation: %@", LOG_TAG, invocation, invitation);
    
    TLCreateContactPhase2Executor *createContactPhase2Executor = [[TLCreateContactPhase2Executor alloc] initWithTwinmeContext:self invocation:invocation invitation:invitation];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createContactPhase2Executor start];
    });
}

- (void)onCreateContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ onCreateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateContactWithRequestId:contact:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onCreateContactWithRequestId:requestId contact:contact];
            });
        }
    }
}
- (void)updateContactWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact contactName:(nonnull NSString *)contactName description:(nullable NSString *)description {
    DDLogVerbose(@"%@ updateContactWithRequestId: %lld contact: %@ description: %@", LOG_TAG, requestId, contact, description);
    
    TLUpdateContactAndIdentityExecutor *updateContactAndIdentityExecutor = [[TLUpdateContactAndIdentityExecutor alloc] initWithTwinmeContext:self requestId:requestId contact:contact contactName:contactName description:description];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateContactAndIdentityExecutor start];
    });
}

- (void)updateContactIdentityWithRequestId:(int64_t)requestId contact:(TLContact *)contact identityName:(NSString *)identityName identityAvatar:(UIImage *)identityAvatar identityLargeAvatar:(UIImage *)identityLargeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities {
    DDLogVerbose(@"%@ updateContactIdentityWithRequestId: %lld contact: %@ identityName: %@ identityAvatar: %@ identityLargeAvatar: %@ description: %@ capabilities: %@", LOG_TAG, requestId, contact, identityName, identityAvatar, identityLargeAvatar, description, capabilities);
    
    TLUpdateContactAndIdentityExecutor *updateContactAndIdentityExecutor = [[TLUpdateContactAndIdentityExecutor alloc] initWithTwinmeContext:self requestId:requestId contact:contact identityName:identityName identityAvatar:identityAvatar identityLargeAvatar:identityLargeAvatar description:description capabilities:capabilities];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateContactAndIdentityExecutor start];
    });
}

- (void)bindContactWithInvocation:(nonnull TLPairBindInvocation *)invocation contact:(TLContact *)contact {
    DDLogVerbose(@"%@ bindContactWithInvocation: %@ contact: %@", LOG_TAG, invocation, contact);
    
    TLBindContactExecutor *bindContactExecutor = [[TLBindContactExecutor alloc] initWithTwinmeContext:self invocation:invocation contact:contact];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [bindContactExecutor start];
    });
}

- (void)refreshObjectWithInvocation:(nonnull TLPairRefreshInvocation *)invocation subject:(nonnull id<TLOriginator>)subject {
    DDLogVerbose(@"%@ refreshObjectWithInvocation: %@ subject: %@", LOG_TAG, invocation, subject);
    
    TLRefreshObjectExecutor *refreshObjectExecutor = [[TLRefreshObjectExecutor alloc] initWithTwinmeContext:self invocation:invocation subject:subject];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [refreshObjectExecutor start];
    });
}

- (void)verifyContactWithUri:(nonnull TLTwincodeURI *)twincodeURI trustMethod:(TLTrustMethod)trustMethod  withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLContact * _Nullable contact))block {

    TLVerifyContactExecutor *verifyContactExecutor = [[TLVerifyContactExecutor alloc] initWithTwinmeContext:self twincodeURI:twincodeURI trustMethod:trustMethod withBlock:block];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [verifyContactExecutor start];
    });
}

- (void)unbindContactWithRequestId:(int64_t)requestId invocationId:(NSUUID *)invocationId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ unbindContactWithRequestId: %lld invocationId: %@ contact: %@", LOG_TAG, requestId, invocationId, contact);
    
    if (DELETE_CONTACT_ON_UNBIND_CONTACT) {
        TLDeleteContactExecutor *deleteContactExecutor = [[TLDeleteContactExecutor alloc] initWithTwinmeContext:self requestId:requestId contact:contact invocationId:invocationId timeout:DBL_MAX];
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [deleteContactExecutor start];
        });
    } else {
        TLUnbindContactExecutor *unbindContactExecutor = [[TLUnbindContactExecutor alloc] initWithTwinmeContext:self requestId:requestId invocationId:invocationId contact:contact];
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [unbindContactExecutor start];
        });
    }
}

- (void)onUpdateContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateContactWithRequestId:contact:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateContactWithRequestId:requestId contact:contact];
            });
        }
    }
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId contact:(TLContact *)contact oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onMoveToSpaceWithRequestId:contact:oldSpace:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onMoveToSpaceWithRequestId:requestId contact:contact oldSpace:oldSpace];
            });
        }
    }
}

- (void)deleteContactWithRequestId:(int64_t)requestId contact:(TLContact *)contact {
    DDLogVerbose(@"%@ deleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    TLDeleteContactExecutor *deleteContactExecutor = [[TLDeleteContactExecutor alloc] initWithTwinmeContext:self requestId:requestId contact:contact invocationId:nil timeout:DEFAULT_TIMEOUT];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [deleteContactExecutor start];
    });
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contactId);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteContactWithRequestId:contactId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteContactWithRequestId:requestId contactId:contactId];
            });
        }
    }
}

- (void)copySharedTwincodeAttributesWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSMutableArray *)attributes {
    DDLogVerbose(@"%@ copySharedTwincodeAttributesWithTwincode: %@ attributes: %@", LOG_TAG, twincode, attributes);
    
    // The list of attributes to copy is hard-coded on iOS and limited to:
    // - capabilities
    // - description
    
    NSString *capabilities = [twincode capabilities];
    if (capabilities) {
        [TLTwinmeAttributes setTwincodeAttributeCapabilities:attributes capabilities:capabilities];
    }
    
    NSString *description = [twincode twincodeDescription];
    if (description) {
        [TLTwinmeAttributes setTwincodeAttributeDescription:attributes description:description];
    }
}

# pragma mark - Call Receiver management

//
// Call Receiver
//

- (void)createCallReceiverWithRequestId:(const int64_t)requestId name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nullable NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities*)capabilities space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ createCallReceiverWithRequestId: %lld name: %@ avatar: %@ space: %@", LOG_TAG, requestId, name, avatar, space);
    
    if (!name || name.length == 0 || !space) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateCallReceiverExecutor *createCallReceiverExecutor = [[TLCreateCallReceiverExecutor  alloc] initWithTwinmeContext:self requestId:requestId name:name description:description identityName:identityName identityDescription:identityDescription avatar:avatar largeAvatar:largeAvatar capabilities:capabilities space:space];
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createCallReceiverExecutor start];
    });
}

- (void)onCreateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onCreateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateCallReceiverWithRequestId:callReceiver:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onCreateCallReceiverWithRequestId:requestId callReceiver:callReceiver];
            });
        }
    }
}

- (void)getCallReceiverWithCallReceiverId:(nonnull NSUUID *)callReceiverId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLCallReceiver * _Nullable callReceiver))block {
    DDLogVerbose(@"%@ getCallReceiverWithCallReceiverId: %@", LOG_TAG, callReceiverId);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService getObjectWithFactory:[TLCallReceiver FACTORY] objectId:callReceiverId withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            
            block(errorCode, (TLCallReceiver *)object);
        }];
    });
}

- (void)getCallReceiversWithRequestId:(int64_t)requestId withBlock:(void (^)(NSArray<TLCallReceiver *> *))block {
    DDLogVerbose(@"%@ getCallReceiversWithRequestId: %lld", LOG_TAG, requestId);
    
    TLFilter *filter = [TLFilter alloc];
    filter.owner = self.currentSpace;
    [self findCallReceiversWithFilter:filter withBlock:block];
}

- (void)deleteCallReceiverWithRequestId:(int64_t)requestId callReceiver:(TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ deleteCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    TLDeleteCallReceiverExecutor *executor = [[TLDeleteCallReceiverExecutor alloc] initWithTwinmeContext:self requestId:requestId callReceiver:callReceiver timeout:DEFAULT_TIMEOUT];
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [executor start];
    });
}

- (void)onDeleteCallReceiverWithRequestId:(int64_t)requestId callReceiverId:(NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ onDeleteCallReceiverWithRequestId: %lld callReceiverId: %@", LOG_TAG, requestId, callReceiverId);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteCallReceiverWithRequestId:callReceiverId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteCallReceiverWithRequestId:requestId callReceiverId:callReceiverId];
            });
        }
    }
}

- (void)updateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver name:(nonnull NSString *)name description:(nullable NSString *)description identityName:(nonnull NSString *)identityName identityDescription:(nullable NSString *)identityDescription avatar:(nullable UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar capabilities:(nullable TLCapabilities*)capabilities{
    DDLogVerbose(@"%@ updateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    TLUpdateCallReceiverExecutor *executor = [[TLUpdateCallReceiverExecutor alloc] initWithTwinmeContext:self requestId:requestId callReceiver:callReceiver name:name description:description identityName:identityName identityDescription:identityDescription avatar:avatar largeAvatar:largeAvatar capabilities:capabilities];
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [executor start];
    });
}

- (void)onUpdateCallReceiverWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onUpdateCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateCallReceiverWithRequestId:callReceiver:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateCallReceiverWithRequestId:requestId callReceiver:callReceiver];
            });
        }
    }
}

- (void)changeCallReceiverTwincodeWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ changeCallReceiverTwincodeWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    TLChangeCallReceiverTwincodeExecutor *executor = [[TLChangeCallReceiverTwincodeExecutor alloc] initWithTwinmeContext:self requestId:requestId callReceiver:callReceiver];
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [executor start];
    });
}

- (void)onChangeCallReceiverTwincodeWithRequestId:(int64_t)requestId callReceiver:(nonnull TLCallReceiver *)callReceiver {
    DDLogVerbose(@"%@ onChangeCallReceiverTwincodeWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onChangeCallReceiverTwincodeWithRequestId:callReceiver:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onChangeCallReceiverTwincodeWithRequestId:requestId callReceiver:callReceiver];
            });
        }
    }
}

- (void)findCallReceiversWithFilter:(nonnull TLFilter*)filter withBlock:(nonnull void (^)(NSMutableArray<TLCallReceiver*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findCallReceiversWithFilter: %@", LOG_TAG, filter);
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService listObjectsWithFactory:[TLCallReceiver FACTORY] filter:filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            NSMutableArray<TLCallReceiver*> *result = [[NSMutableArray alloc] initWithCapacity:list.count];
            for (id<TLRepositoryObject> object in list) {
                [result addObject:(TLCallReceiver *)object];
            }
            block(result);
        }];
    });
}

- (void)findInvitationsWithFilter:(nonnull TLFilter*)filter withBlock:(nonnull void (^)(NSArray<TLInvitation*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findCallReceiversWithFilter: %@", LOG_TAG, filter);
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService listObjectsWithFactory:[TLInvitation FACTORY] filter:filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            NSMutableArray<TLInvitation*> *result = [[NSMutableArray alloc] initWithCapacity:list.count];
            for (id<TLRepositoryObject> object in list) {
                [result addObject:(TLInvitation *)object];
            }
            block(result);
        }];
    });
}

#pragma mark - Invitation management

//
// Invitation management
//

- (void)createInvitationWithRequestId:(int64_t)requestId groupMember:(nullable TLGroupMember *)groupMember {
    DDLogVerbose(@"%@ createInvitationWithRequestId: %lld groupMember: %@", LOG_TAG, requestId, groupMember);
    
    TLCreateInvitationExecutor *createInvitationExecutor = [[TLCreateInvitationExecutor alloc] initWithTwinmeContext:self requestId:requestId space:self.currentSpace groupMember:groupMember];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createInvitationExecutor start];
    });
}

- (void)createInvitationWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact sendTo:(nonnull NSUUID *)sendTo {
    DDLogVerbose(@"%@ createInvitationWithRequestId: %lld contact: %@ sendTo: %@", LOG_TAG, requestId, contact, sendTo);
    
    TLCreateInvitationExecutor *createInvitationExecutor = [[TLCreateInvitationExecutor alloc] initWithTwinmeContext:self requestId:requestId space:self.currentSpace contact:contact sendTo:sendTo];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createInvitationExecutor start];
    });
}

- (void)onCreateInvitationWithRequestId:(int64_t)requestId invitation:(TLInvitation *)invitation {
    DDLogVerbose(@"%@ onCreateInvitationWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateInvitationWithRequestId:invitation:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            [lDelegate onCreateInvitationWithRequestId:requestId invitation:invitation];
        }
    }
}

- (void)getInvitationWithInvitationId:(nonnull NSUUID *)invitationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvitation * _Nullable invitation))block {
    DDLogVerbose(@"%@ getInvitationWithInvitationId: %@", LOG_TAG, invitationId);
    
    TLGetInvitationAction *getInvitationExecutor = [[TLGetInvitationAction alloc] initWithTwinmeContext:self invitationId:invitationId withBlock:block];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [getInvitationExecutor start];
    });
}

- (void)deleteInvitationWithRequestId:(int64_t)requestId invitation:(TLInvitation *)invitation {
    DDLogVerbose(@"%@ deleteInvitationWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);
    
    TLDeleteInvitationExecutor *deleteInvitationExecutor = [[TLDeleteInvitationExecutor alloc] initWithTwinmeContext:self requestId:requestId invitation:invitation timeout:DEFAULT_TIMEOUT];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [deleteInvitationExecutor start];
    });
}

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(NSUUID *)invitationId {
    DDLogVerbose(@"%@ onDeleteInvitationWithRequestId: %lld invitationId: %@", LOG_TAG, requestId, invitationId);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteInvitationWithRequestId:invitationId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteInvitationWithRequestId:requestId invitationId:invitationId];
            });
        }
    }
}

#pragma mark - Group management

//
// Group management
//

- (void)findGroupsWithFilter:(nonnull TLFilter*)filter withBlock:(nonnull void (^)(NSMutableArray<TLGroup*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findGroupsWithFilter: %@", LOG_TAG, filter);
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService listObjectsWithFactory:[TLGroup FACTORY] filter:filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            NSMutableArray<TLGroup*> *result = [[NSMutableArray alloc] initWithCapacity:list.count];
            for (id<TLRepositoryObject> object in list) {
                [result addObject:(TLGroup *)object];
            }
            block(result);
        }];
    });
}

- (void)getGroupWithGroupId:(nonnull NSUUID *)groupId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroup * _Nullable group))block {
    DDLogVerbose(@"%@ getGroupWithGroupId: %@", LOG_TAG, groupId);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLRepositoryService *repositoryService = [self getRepositoryService];
        
        [repositoryService getObjectWithFactory:[TLGroup FACTORY] objectId:groupId withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            
            block(errorCode, (TLGroup *)object);
        }];
    });
}

- (void)createGroupWithRequestId:(int64_t)requestId name:(NSString *)name description:(nullable NSString *)description avatar:(UIImage *)avatar largeAvatar:(UIImage *)largeAvatar {
    DDLogVerbose(@"%@ createGroupWithRequestId: %lld name: %@", LOG_TAG, requestId, name);
    
    TLCreateGroupExecutor *createGroupExecutor = [[TLCreateGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId space:self.currentSpace name:name description:description avatar:avatar largeAvatar:largeAvatar];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createGroupExecutor start];
    });
}

- (void)createGroupWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ createGroupWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);
    
    TLCreateGroupExecutor *createGroupExecutor = [[TLCreateGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId space:self.currentSpace invitation:invitation];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createGroupExecutor start];
    });
}

- (void)createGroupWithRequestId:(int64_t)requestId invitationTwincode:(nonnull TLTwincodeOutbound *)invitationTwincode space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ createGroupWithRequestId: %lld invitationTwincodeId: %@ space: %@", LOG_TAG, requestId, invitationTwincode, space);
    
    TLCreateGroupExecutor *createGroupExecutor = [[TLCreateGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId space:space invitationTwincode:invitationTwincode];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createGroupExecutor start];
    });
}

- (void)onCreateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group conversation:(id<TLGroupConversation>)conversation {
    DDLogVerbose(@"%@ onCreateGroupWithRequestId: %lld group: %@ conversation: %@", LOG_TAG, requestId, group, conversation);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateGroupWithRequestId:group:conversation:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onCreateGroupWithRequestId:requestId group:group conversation:conversation];
            });
        }
    }
}

- (void)updateGroupWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name description:(nullable NSString *)description groupAvatar:(nullable UIImage *)groupAvatar groupLargeAvatar:(nullable UIImage *)groupLargeAvatar capabilities:(nullable TLCapabilities *)capabilities {
    DDLogVerbose(@"%@ updateGroupWithRequestId: %lld group: %@ name: %@ groupAvatar: %@ groupLargeAvatar: %@", LOG_TAG, requestId, group, name, groupAvatar, groupLargeAvatar);
    
    TLUpdateGroupExecutor *updateGroupExecutor = [[TLUpdateGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId group:group name:name groupDescription:description groupAvatar:groupAvatar groupLargeAvatar:groupLargeAvatar groupCapabilities:capabilities];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateGroupExecutor start];
    });
}

- (void)updateGroupProfileWithRequestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name profileAvatar:(nullable UIImage *)profileAvatar profileLargeAvatar:(nullable UIImage *)profileLargeAvatar {
    DDLogVerbose(@"%@ updateGroupWithRequestId: %lld group: %@ name: %@ profileAvatar: %@", LOG_TAG, requestId, group, name, profileAvatar);
    
    TLUpdateGroupExecutor *updateGroupExecutor = [[TLUpdateGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId group:group name:name profileAvatar:profileAvatar profileLargeAvatar:profileLargeAvatar];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateGroupExecutor start];
    });
}

- (void)onUpdateGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateGroupWithRequestId:group:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateGroupWithRequestId:requestId group:group];
            });
        }
    }
}

- (void)onMoveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group oldSpace:(TLSpace *)oldSpace {
    DDLogVerbose(@"%@ onMoveToSpaceWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onMoveToSpaceWithRequestId:group:oldSpace:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onMoveToSpaceWithRequestId:requestId group:group oldSpace:oldSpace];
            });
        }
    }
}

- (void)deleteGroupWithRequestId:(int64_t)requestId group:(TLGroup *)group {
    DDLogVerbose(@"%@ deleteGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    TLDeleteGroupExecutor *deleteGroupExecutor = [[TLDeleteGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId group:group timeout:DEFAULT_TIMEOUT];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [deleteGroupExecutor start];
    });
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld groupId: %@", LOG_TAG, requestId, groupId);
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteGroupWithRequestId:groupId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteGroupWithRequestId:requestId groupId:groupId];
            });
        }
    }
}

- (void)getGroupMemberWithOwner:(id<TLOriginator>)owner memberTwincodeId:(NSUUID *)memberTwincodeId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupMember * _Nullable member))block {
    DDLogVerbose(@"%@ getGroupMemberWithOwner: %@ memberTwincodeId: %@", LOG_TAG, owner, memberTwincodeId);
    
    TLGroupMember *groupMember;
    @synchronized(self) {
        groupMember = self.groupMembers[memberTwincodeId];

        // If the cache contains an old member, remove and ignore it (use pointer equality for the test!).
       if (groupMember && groupMember.group != owner) {
            [self.groupMembers removeObjectForKey:memberTwincodeId];
            groupMember = nil;
        }
    }
    
    if (groupMember) {
        block(TLBaseServiceErrorCodeSuccess, groupMember);
        
    } else {
        TLGetGroupMemberExecutor *getGroupMemberExecutor = [[TLGetGroupMemberExecutor alloc] initWithTwinmeContext:self  owner:owner groupMemberTwincodeId:memberTwincodeId withBlock:block];
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [getGroupMemberExecutor start];
        });
    }
}

- (void)onGetGroupMemberWithErrorCode:(TLBaseServiceErrorCode)errorCode groupMember:(TLGroupMember *)groupMember withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupMember * _Nullable groupMember))block {
    DDLogVerbose(@"%@ onGetGroupMemberWithRequestId: %u groupMember: %@", LOG_TAG, errorCode, groupMember);
    
    if (errorCode == TLBaseServiceErrorCodeSuccess && groupMember) {
        @synchronized(self) {
            self.groupMembers[groupMember.memberTwincodeOutboundId] = groupMember;
        }
    }
    
    block(errorCode, groupMember);
}

- (void)fetchExistingMembersWithOwner:(nonnull id<TLOriginator>)owner members:(nonnull NSArray<NSUUID *> *)members knownMembers:(nonnull NSMutableArray<TLGroupMember *> *)knownMembers unknownMembers:(nonnull NSMutableArray<NSUUID *> *)unknownMembers {
    DDLogVerbose(@"%@ fetchExistingMembersWithOwner: %@ members: %@", LOG_TAG, owner, members);

    @synchronized (self) {
        for (NSUUID *memberTwincodeId in members) {
            TLGroupMember *groupMember = self.groupMembers[memberTwincodeId];

            if (!groupMember) {
                [unknownMembers addObject:memberTwincodeId];
            } else if (groupMember.group != owner) {
                // If the cache contains an old member, remove and ignore it (use pointer equality for the test!).
                [self.groupMembers removeObjectForKey:memberTwincodeId];
                [unknownMembers addObject:memberTwincodeId];
            } else {
                [knownMembers addObject:groupMember];
            }
        }
    }
}

- (void)listGroupMembersWithGroup:(nonnull TLGroup *)group filter:(TLGroupMemberFilterType)filter withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block {
    DDLogVerbose(@"%@ listGroupMembersWithGroup: %@ filter: %u", LOG_TAG, group, filter);

    TLListMembersExecutor *listGroupMemberExecutor = [[TLListMembersExecutor alloc] initWithTwinmeContext:self group:group filter:filter withBlock:block];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [listGroupMemberExecutor start];
    });
}

- (void)listMembersWithOwner:(nonnull id<TLOriginator>)owner memberTwincodeList:(nonnull NSMutableArray *)memberTwincodeList withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block {
    DDLogVerbose(@"%@ listMembersWithOwner: %@ memberTwincodeList: %@", LOG_TAG, owner, memberTwincodeList);

    TLListMembersExecutor *listGroupMemberExecutor = [[TLListMembersExecutor alloc] initWithTwinmeContext:self owner:owner memberTwincodeList:memberTwincodeList withBlock:block];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [listGroupMemberExecutor start];
    });
}

- (void)getSpaceOriginatorSet:(nonnull TLSpace *)space withBlock:(nonnull void (^)(NSSet<NSUUID *> * _Nonnull originatorSet))block {
    
    NSMutableSet<NSUUID *> *result = [[NSMutableSet alloc] init];
    TLFilter *filter = [TLFilter alloc];
    filter.owner = self.currentSpace;
    [self findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *list) {
        for (TLContact *contact in list) {
            [result addObject:contact.uuid];
        }
        [self findGroupsWithFilter:filter withBlock:^(NSMutableArray<TLGroup *> *list) {
            for (TLGroup *group in list) {
                [result addObject:group.uuid];
            }
            block(result);
        }];
    }];
}

- (void)updateStatsWithRequestId:(int64_t)requestId  updateScore:(BOOL)updateScore {
    DDLogVerbose(@"%@ updateStatsWithRequestId: %lld updateScore: %d", LOG_TAG, requestId, updateScore);
    
    TLUpdateStatsExecutor *updateStatsExecutor = [[TLUpdateStatsExecutor alloc] initWithTwinmeContext:self requestId:requestId updateScore:updateScore];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateStatsExecutor start];
    });
}

- (void)onUpdateStatsWithRequestId:(int64_t)requestId contacts:(NSArray<id<TLRepositoryObject>> *)contacts groups:(NSArray<id<TLRepositoryObject>> *)groups {
    DDLogVerbose(@"%@ onUpdateStatsWithRequestId: %lld contacts: %@ groups: %@", LOG_TAG, requestId, contacts, groups);
#if 0
    NSMutableArray<TLContact *> *updatedContacts = [[NSMutableArray alloc] init];
    @synchronized (self) {
        for (id<TLRepositoryObject> object in contacts) {
            TLContact *contact = self.contacts[object.uuid];
            if (contact) {
                if ([contact updateStatsWithObject:object] && [self isCurrentSpace:contact]) {
                    [updatedContacts addObject:contact];
                }
            }
        }
    }
    
    NSMutableArray<TLGroup *> *updatedGroups = [[NSMutableArray alloc] init];
    @synchronized (self) {
        for (TLObject *object in groups) {
            TLGroup *group = self.groups[object.uuid];
            if (group) {
                if ([group updateStatsWithObject:object] && [self isCurrentSpace:group]) {
                    [updatedGroups addObject:group];
                }
            }
        }
    }
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateStatsWithRequestId:contacts:groups:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateStatsWithRequestId:requestId contacts:updatedContacts groups:updatedGroups];
            });
        }
    }
#endif
}

#pragma mark - Invocations

//
// Invocation management
//

- (void)acknowledgeInvocationWithInvocationId:(NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ acknowledgeInvocationWithInvocationId: %@ errorCode: %d", LOG_TAG, invocationId, errorCode);

    // TBD check result of asynchronous operation
    [[self getTwincodeInboundService] acknowledgeInvocationWithInvocationId:invocationId errorCode:errorCode];
}

- (BOOL)hasPendingInvocations {
    DDLogVerbose(@"%@ hasPendingInvocations", LOG_TAG);
    
    return [[self getTwincodeInboundService] hasPendingInvocations];
}

#pragma mark - Level management

//
// Level management
//

- (void)setLevelWithRequestId:(int64_t)requestId name:(NSString *)name {
    DDLogVerbose(@"%@ setLevelWithRequestId: %lld name: %@", LOG_TAG, requestId, name);
    
    // Map the setLevel("0") to the selection of the default space.
    if (!name || name.length == 0 || [@"0" isEqual:name]) {
        [self getDefaultSpaceWithBlock:^(TLBaseServiceErrorCode errorCode, TLSpace *space) {
            [self setCurrentSpaceWithRequestId:requestId space:space];
        }];
        return;
    }
    
    // Step #1: find the space with the given name.
    [self findSpacesWithPredicate:^(TLSpace *space) {
        return [name isEqualToString:space.settings.name];
    } withBlock:^(NSMutableArray<TLSpace *> * list) {
        if (list.count > 0) {
            // Step #2a: set the current space.
            [self setCurrentSpaceWithRequestId:requestId space:list[0]];
        } else {
            [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeItemNotFound errorParameter:name];
        }
    }];
}

- (void)createLevelWithRequestId:(int64_t)requestId name:(NSString *)name {
    DDLogVerbose(@"%@ createLevelWithRequestId: %lld name: %@", LOG_TAG, requestId, name);
    
    if (!name || name.length == 0 || [@"0" isEqual:name]) {
        [self setLevelWithRequestId:requestId name:@"0"];
        return;
    }
    
    // Step #1: find the space with the given name.
    [self findSpacesWithPredicate:^(TLSpace *space) {
        return [name isEqualToString:space.settings.name];
    } withBlock:^(NSMutableArray<TLSpace *> * list) {
        if (list.count > 0) {
            // Step #2a: set the current space.
            [self setCurrentSpaceWithRequestId:requestId space:list[0]];
        } else {
            TLSpaceSettings *settings = [[TLSpaceSettings alloc] initWithName:name settings:self.defaultSpaceSettings];
            settings.isSecret = YES;
            [self createSpaceWithRequestId:requestId settings:settings profile:nil];
        }
    }];
}

- (void)deleteLevelWithRequestId:(int64_t)requestId name:(NSString *)name {
    DDLogVerbose(@"%@ deleteLevelWithRequestId: %lld name: %@", LOG_TAG, requestId, name);
    
    if (!name || name.length == 0 || [@"0" isEqual:name]) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    [self findSpacesWithPredicate:^(TLSpace *space) {
        return [name isEqualToString:space.settings.name];
    } withBlock:^(NSMutableArray<TLSpace *> * list) {
        if (list.count > 0) {
            [self deleteSpaceWithRequestId:requestId space:list[0]];
        }
    }];
}

#pragma mark - Space management

//
// Space management
//

- (nonnull TLFilter *)createSpaceFilter {
    DDLogVerbose(@"%@ createSpaceFilter", LOG_TAG);
    
    TLFilter *filter = [TLFilter alloc];
    filter.owner = self.currentSpace;
    return filter;
}

- (void)getSpaceWithSpaceId:(nonnull NSUUID *)spaceId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpace *space))block {
    DDLogVerbose(@"%@ getSpaceWithSpaceId: %@", LOG_TAG, spaceId);
    
    if (self.getSpacesDone) {
        TLSpace *lSpace;
        
        @synchronized(self) {
            lSpace = self.spaces[spaceId];
        }
        block(lSpace ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeItemNotFound, lSpace);
    } else {
        [self findSpacesWithPredicate:^BOOL(TLSpace *space) {
            return false;
        } withBlock:^(NSMutableArray<TLSpace *> *list) {
            TLSpace *lSpace;
            @synchronized(self) {
                lSpace = self.spaces[spaceId];
            }
            
            block(lSpace ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeItemNotFound, lSpace);
        }];
    }
}

- (void)findSpacesWithPredicate:(nonnull BOOL (^)(TLSpace * _Nonnull space))predicate withBlock:(nonnull void (^)(NSMutableArray<TLSpace*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findSpacesWithPredicate", LOG_TAG);
    
    if (self.getSpacesDone || (!self.hasSpaces && !self.hasProfiles)) {
        dispatch_async(self.twinlife.twinlifeQueue, ^{
            [self resolveFindSpacesWithPredicate:predicate withBlock:block];
        });
    } else {
        TLExecutor *getSpacesExecutor;
        BOOL created;
        
        @synchronized(self) {
            getSpacesExecutor = self.executors[@"TLGetSpacesExecutor"];
            created = getSpacesExecutor ? NO : YES;
            if (created) {
                getSpacesExecutor = (TLExecutor *)[[TLGetSpacesExecutor alloc] initWithTwinmeContext:self requestId:0 enableSpaces:self.enableSpaces];
                self.executors[@"TLGetSpacesExecutor"] = getSpacesExecutor;
            }
        }
        [getSpacesExecutor execute:^{
            [self resolveFindSpacesWithPredicate:predicate withBlock:block];
        }];
        
        if (created) {
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [getSpacesExecutor start];
            });
        }
    }
}

- (void)onGetSpacesWithRequestId:(int64_t)requestId spaces:(nonnull NSArray<TLSpace*> *)spaces {
    
    for (TLSpace *space in spaces) {
        [self putSpace:space];
    }
    
    // Make sure we know a current/default space.
    TLSpace *setDefaultSpace = nil;
    @synchronized(self) {
        if (!self.currentSpace && self.defaultSpaceId && spaces.count > 0) {
            setDefaultSpace = spaces[0];
        }
    }
    if (setDefaultSpace) {
        [self setDefaultSpace:setDefaultSpace];
        [self setCurrentSpaceWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] space:setDefaultSpace];
    }
    
    self.getSpacesDone = YES;
    
    @synchronized(self) {
        [self.executors removeObjectForKey:@"TLGetSpacesExecutor"];
    }
}

- (void)resolveFindSpacesWithPredicate:(nonnull BOOL (^)(TLSpace * _Nonnull space))predicate withBlock:(nonnull void (^)(NSMutableArray<TLSpace*> * _Nonnull list))block {
    DDLogVerbose(@"%@ resolveFindSpacesWithPredicate", LOG_TAG);
    
    NSMutableArray<TLSpace*> *result;
    @synchronized(self) {
        result = [[NSMutableArray alloc] initWithCapacity:self.spaces.count];
        for (NSUUID *spaceId in self.spaces) {
            TLSpace *space = self.spaces[spaceId];
            if (predicate(space)) {
                [result addObject:space];
            }
        }
    }
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        block(result);
    });
}

- (void)getDefaultSpaceWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpace *space))block {
    DDLogVerbose(@"%@ getDefaultSpaceWithBlock", LOG_TAG);
    
    [self findSpacesWithPredicate:^(TLSpace * space) {
        return [self isDefaultSpace:space];
    } withBlock:^(NSMutableArray<TLSpace*> *list) {
        if (list.count == 1) {
            if (!self.currentSpace) {
                [self setCurrentSpace:list[0]];
            }
            block(TLBaseServiceErrorCodeSuccess, list[0]);
        } else {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
        }
    }];
}

- (void)getCurrentSpaceWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpace *space))block {
    DDLogVerbose(@"%@ getCurrentSpaceWithBlock", LOG_TAG);
    
    TLSpace *space;
    @synchronized(self) {
        space = self.currentSpace;
    }
    if (space) {
        block(TLBaseServiceErrorCodeSuccess, space);
    } else {
        [self findSpacesWithPredicate:^BOOL (TLSpace * space) {
            return !space.settings.isSecret;
        } withBlock:^(NSMutableArray<TLSpace*> *list) {
            block(self.currentSpace ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeItemNotFound, self.currentSpace);
        }];
    }
}

- (void)setCurrentSpaceWithRequestId:(int64_t)requestId name:(NSString *)name {
    DDLogVerbose(@"%@ setCurrentSpaceWithRequestId: %lld name: %@", LOG_TAG, requestId, name);
    
    [self findSpacesWithPredicate:^BOOL (TLSpace * space) {
        return [name isEqualToString:space.settings.name];
    } withBlock:^(NSMutableArray<TLSpace*> *list) {
        if (list.count == 1) {
            [self setCurrentSpaceWithRequestId:requestId space:list[0]];
        }
    }];
}

- (void)setCurrentSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ setCurrentSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    @synchronized(self) {
        self.currentSpace = space;
        self.currentProfile = space.profile;
    }
    
    [self.twinmeApplication setDefaultProfileWithProfile:space.profile];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onSetCurrentSpaceWithRequestId:space:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async(self.twinlife.twinlifeQueue, ^{
                [lDelegate onSetCurrentSpaceWithRequestId:requestId space:space];
            });
        }
    }
}

- (BOOL)isDefaultSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ isDefaultSpace: %@", LOG_TAG, space);
    
    @synchronized(self) {
        return self.defaultSpaceId && [space.uuid isEqual:self.defaultSpaceId];
    }
}

- (nullable TLSpace *)getCurrentSpace {
    DDLogVerbose(@"%@ getCurrentSpace", LOG_TAG);
    
    @synchronized(self) {
        return self.currentSpace;
    }
}

- (void)setDefaultSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ setDefaultSpace: %@", LOG_TAG, space);
    
    @synchronized(self) {
        if (!self.defaultSpaceId || ![space.uuid isEqual:self.defaultSpaceId]) {
            self.defaultSpaceId = space.uuid;
            
            self.defaultSettingsConfig.uuidValue = self.defaultSpaceConfig.uuid;
        }
    }
}

- (void)setDefaultSpaceSettings:(TLSpaceSettings *)settings oldDefaultName:(nonnull NSString *)oldDefaultName {
    DDLogVerbose(@"%@ setDefaultSpaceSettings: %@ oldDefaultName: %@", LOG_TAG, settings, oldDefaultName);
    
    [TLSpaceSettings setDefaultSpaceSettingsWithSettings:settings oldDefaultName:oldDefaultName];
    self.defaultCreateSpaceSettings = settings;
}

- (void)saveDefaultSpaceSettings:(nonnull TLSpaceSettings *)settings withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSpaceSettings * _Nullable settings))block {
    
    TLUpdateSettingsExecutor *updateSettingsExecutor = [[TLUpdateSettingsExecutor alloc] initWithTwinmeContext:self settings:settings spaceAvatar:nil spaceLargeAvatar:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLSpaceSettings *settings) {
        
        if (errorCode == TLBaseServiceErrorCodeSuccess) {
            NSUUID* saveId = nil;
            @synchronized (self) {
                if (!self.defaultSettingsId) {
                    self.defaultSettingsId = settings.uuid;
                    saveId = settings.uuid;
                }
                self.defaultCreateSpaceSettings = settings;
            }
            
            if (saveId) {
                self.defaultSettingsConfig.uuidValue = saveId;
            }
        }
        block(errorCode, settings);
    }];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateSettingsExecutor start];
    });
}

- (TLSpaceSettings *)defaultSpaceSettings {
    
    return [[TLSpaceSettings alloc] initWithSettings:self.defaultCreateSpaceSettings];
}

- (void)createSpaceWithRequestId:(int64_t)requestId settings:(TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar {
    DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ spaceAvatar: %@ spaceLargeAvatar: %@", LOG_TAG, requestId, settings, spaceAvatar, spaceLargeAvatar);
    
    if (!settings) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateSpaceExecutor *createSpaceExecutor = [[TLCreateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId settings:settings spaceAvatar:spaceAvatar spaceLargeAvatar:spaceLargeAvatar name:nil avatar:nil largeAvatar:nil isDefault:NO];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createSpaceExecutor start];
    });
}

- (void)createSpaceWithRequestId:(int64_t)requestId settings:(TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar name:(NSString *)name avatar:(UIImage *)avatar largeAvatar:(UIImage *)largeAvatar {
    DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ name: %@", LOG_TAG, requestId, settings, name);
    
    if (!settings || !name) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateSpaceExecutor *createSpaceExecutor = [[TLCreateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId settings:settings spaceAvatar:spaceAvatar spaceLargeAvatar:spaceLargeAvatar name:name avatar:avatar largeAvatar:largeAvatar isDefault:NO];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createSpaceExecutor start];
    });
}

- (void)createSpaceWithRequestId:(int64_t)requestId settings:(TLSpaceSettings *)settings profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ profile: %@", LOG_TAG, requestId, settings, profile);
    
    if (!settings) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateSpaceExecutor *createSpaceExecutor = [[TLCreateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId settings:settings profile:profile isDefault:NO];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createSpaceExecutor start];
    });
}

- (void)createDefaultSpaceWithRequestId:(int64_t)requestId settings:(TLSpaceSettings *)settings profile:(TLProfile *)profile {
    DDLogVerbose(@"%@ createSpaceWithRequestId: %lld settings: %@ profile: %@", LOG_TAG, requestId, settings, profile);
    
    if (!settings || !profile) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateSpaceExecutor *createSpaceExecutor = [[TLCreateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId settings:settings profile:profile isDefault:YES];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createSpaceExecutor start];
    });
}

- (void)createDefaultSpaceWithRequestId:(int64_t)requestId settings:(TLSpaceSettings *)settings name:(NSString *)name avatar:(UIImage *)avatar largeAvatar:(UIImage *)largeAvatar {
    DDLogVerbose(@"%@ createDefaultSpaceWithRequestId: %lld settings: %@ name: %@", LOG_TAG, requestId, settings, name);
    
    if (!settings || !name) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLCreateSpaceExecutor *createSpaceExecutor = [[TLCreateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId settings:settings spaceAvatar:nil spaceLargeAvatar:nil name:name avatar:avatar largeAvatar:largeAvatar isDefault:YES];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [createSpaceExecutor start];
    });
}

- (void)onCreateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onCreateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    TLSpace *lSpace = [self putSpace:space];
    
    // Creation of the first space, setup the default and current space.
    if (!self.currentSpace) {
        [self setDefaultSpace:lSpace];
        [self setCurrentSpaceWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] space:lSpace];
    }
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCreateSpaceWithRequestId:space:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onCreateSpaceWithRequestId:requestId space:lSpace];
            });
        }
    }
}

- (void)deleteSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ deleteSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    if (!space) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    if ([self isDefaultSpace:space]) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:space.uuid.UUIDString];
        
    } else {
        TLDeleteSpaceExecutor *deleteSpaceExecutor = [[TLDeleteSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId space:space];
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [deleteSpaceExecutor start];
        });
    }
}

- (void)onDeleteSpaceWithRequestId:(int64_t)requestId spaceId:(nonnull NSUUID *)spaceId {
    DDLogVerbose(@"%@ onDeleteSpaceWithRequestId: %lld spaceId: %@", LOG_TAG, requestId, spaceId);
    
    [self removeSpace:spaceId];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteSpaceWithRequestId:spaceId:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteSpaceWithRequestId:requestId spaceId:spaceId];
            });
        }
    }
}

- (BOOL)isVisible:(nullable id<TLOriginator>)originator {
    
    if (!originator) {
        
        return NO;
    }
    
    TLSpace *space = [originator space];
    return self.currentSpace == space || (space && !space.settings.isSecret);
}

- (BOOL)isCurrentSpace:(nullable id<TLOriginator>)originator {
    
    if (!originator) {
        
        return NO;
    }
    
    TLSpace *space = [originator space];
    return self.currentSpace == space;
}

- (void)moveToSpaceWithRequestId:(int64_t)requestId contact:(TLContact *)contact space:(TLSpace *)space {
    DDLogVerbose(@"%@ moveToSpaceWithRequestId: %lld contact: %@ space: %@", LOG_TAG, requestId, contact, space);
    
    if (!contact || !space) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLUpdateContactAndIdentityExecutor *updateContactExecutor = [[TLUpdateContactAndIdentityExecutor alloc] initWithTwinmeContext:self requestId:requestId contact:contact space:space];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateContactExecutor start];
    });
}

- (void)moveToSpaceWithRequestId:(int64_t)requestId group:(TLGroup *)group space:(TLSpace *)space {
    DDLogVerbose(@"%@ moveToSpaceWithRequestId: %lld group: %@ space: %@", LOG_TAG, requestId, group, space);
    
    if (!group || !space) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLUpdateGroupExecutor *updateGroupExecutor = [[TLUpdateGroupExecutor alloc] initWithTwinmeContext:self requestId:requestId group:group space:space];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateGroupExecutor start];
    });
}

- (void)updateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space profile:(nonnull TLProfile *)profile {
    DDLogVerbose(@"%@ updateSpaceWithRequestId: %lld space: %@ profile: %@", LOG_TAG, requestId, space, profile);
    
    if (!space || !profile) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLUpdateSpaceExecutor *updateSpaceExecutor = [[TLUpdateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId space:space profile:profile settings:nil spaceAvatar:nil spaceLargeAvatar:nil];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateSpaceExecutor start];
    });
}

- (void)updateSpaceWithRequestId:(int64_t)requestId space:(nonnull TLSpace *)space settings:(nonnull TLSpaceSettings *)settings spaceAvatar:(nullable UIImage *)spaceAvatar spaceLargeAvatar:(nullable UIImage *)spaceLargeAvatar {
    DDLogVerbose(@"%@ updateSpaceWithRequestId: %lld space: %@ settings: %@", LOG_TAG, requestId, space, settings);
    
    if (!space || !settings) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    TLUpdateSpaceExecutor *updateSpaceExecutor = [[TLUpdateSpaceExecutor alloc] initWithTwinmeContext:self requestId:requestId space:space profile:nil settings:settings spaceAvatar:spaceAvatar spaceLargeAvatar:spaceLargeAvatar];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [updateSpaceExecutor start];
    });
}

- (void)onUpdateSpaceWithRequestId:(int64_t)requestId space:(TLSpace *)space {
    DDLogVerbose(@"%@ onUpdateSpaceWithRequestId: %lld space: %@", LOG_TAG, requestId, space);
    
    TLSpace *lSpace = [self putSpace:space];
    
    // Detect if the profile associated with the space was changed.
    TLProfile *updatedProfile = nil;
    @synchronized(self) {
        if (lSpace == self.currentSpace && lSpace.profile != self.currentProfile) {
            self.currentProfile = lSpace.profile;
            updatedProfile = self.currentProfile;
        }
    }
    if (updatedProfile) {
        [self.twinmeApplication setDefaultProfileWithProfile:updatedProfile];
    }
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateSpaceWithRequestId:space:)]) {
            id<TLTwinmeContextDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateSpaceWithRequestId:requestId space:lSpace];
            });
        }
    }
}

#pragma mark - Conversation management

//
// Conversation management
//

- (void)findConversationsWithPredicate:(nonnull BOOL (^)(id<TLOriginator> _Nonnull originator))predicate withBlock:(nonnull void (^)(NSMutableArray<id<TLConversation>> * _Nonnull list))block {
    DDLogVerbose(@"%@ findConversationsWithPredicate", LOG_TAG);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        NSMutableArray<id<TLConversation>> *list = [[self getConversationService] listConversationsWithFilter:nil];
        block(list);
    });
}

- (void)setActiveConversationWithConversation:(nonnull id<TLConversation>)conversation {
    DDLogVerbose(@"%@ setActiveConversationWithConversation: %@", LOG_TAG, conversation);
    
    @synchronized(self) {
        self.activeConversationId = conversation.uuid;
    }
    
    NSMutableArray<TLNotification *> *notifications = [[self.twinlife getNotificationService] getPendingNotificationsWithSubject:conversation.subject];
    
    for (TLNotification *notif in notifications) {
        TLNotification *notification = (TLNotification *)notif;
        
        if (!notification.acknowledged && (notification.notificationType == TLNotificationTypeNewTextMessage || notification.notificationType == TLNotificationTypeNewImageMessage || notification.notificationType == TLNotificationTypeNewAudioMessage || notification.notificationType == TLNotificationTypeNewVideoMessage || notification.notificationType == TLNotificationTypeNewFileMessage || notification.notificationType == TLNotificationTypeNewGroupInvitation || notification.notificationType == TLNotificationTypeNewGroupJoined || notification.notificationType == TLNotificationTypeNewGeolocation || notification.notificationType == TLNotificationTypeResetConversation || notification.notificationType == TLNotificationTypeUpdatedAnnotation)) {
            
            [self acknowledgeNotificationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] notification:notification];
        }
    }
    
    [self.notificationCenter onSetActiveConversationWithConversationId:conversation.uuid];
}

- (void)resetActiveConversationWithConversation:(nonnull id<TLConversation>)conversation {
    
    @synchronized(self) {
        if ([self.activeConversationId isEqual:conversation.uuid]) {
            self.activeConversationId = nil;
        }
    }
}

- (void)findConversationDescriptorsWithFilter:(nonnull TLFilter *)filter callsMode:(TLDisplayCallsMode)callsMode withBlock:(nonnull void (^)(NSArray<TLConversationDescriptorPair*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findConversationDescriptorsWithFilter: %@", LOG_TAG, filter);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        NSArray<TLConversationDescriptorPair *> *list = [[self getConversationService] getLastConversationDescriptorsWithFilter:filter callsMode:callsMode];
        block(list);
    });
}

- (void)pushObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] pushObjectWithRequestId:requestId conversation:conversation sendTo:sendTo replyTo:replyTo message:message copyAllowed:copyAllowed expireTimeout:expireTimeout];
    });
}

- (void)pushFileWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(nonnull NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] pushFileWithRequestId:requestId conversation:conversation sendTo:sendTo replyTo:replyTo path:path type:type toBeDeleted:toBeDeleted copyAllowed:copyAllowed expireTimeout:expireTimeout];
    });
}

- (void)pushTransientObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation object:(nonnull NSObject *)object {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] pushTransientObjectWithRequestId:requestId conversation:conversation object:object];
    });
}

- (void)pushGeolocationWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta localMapPath:(nullable NSString *)localMapPath expireTimeout:(int64_t)expireTimeout {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] pushGeolocationWithRequestId:requestId conversation:conversation sendTo:sendTo replyTo:replyTo longitude:longitude latitude:latitude altitude:altitude mapLongitudeDelta:mapLongitudeDelta mapLatitudeDelta:mapLatitudeDelta localMapPath:localMapPath expireTimeout:expireTimeout];
    });
}

- (void)saveGeolocationMapWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId path:(nonnull NSString *)path {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] saveGeolocationMapWithRequestId:requestId conversation:conversation descriptorId:descriptorId path:path];
    });
}

- (void)forwardDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo descriptorId:(nonnull TLDescriptorId *)descriptorId copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] forwardDescriptorWithRequestId:requestId conversation:conversation sendTo:sendTo descriptorId:descriptorId copyAllowed:copyAllowed expireTimeout:expireTimeout];
    });
}

- (void)deleteDescriptorWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] deleteDescriptorWithRequestId:requestId descriptorId:descriptorId];
    });
}

- (void)markDescriptorReadWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] markDescriptorReadWithRequestId:requestId descriptorId:descriptorId];
    });
}

- (void)markDescriptorDeletedWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] markDescriptorDeletedWithRequestId:requestId descriptorId:descriptorId];
    });
}

- (void)toggleAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value {
    DDLogVerbose(@"%@ toggleAnnotationWithDescriptorId: %@ type: %u value: %d", LOG_TAG, descriptorId, type, value);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [[self getConversationService] toggleAnnotationWithDescriptorId:descriptorId type:type value:value];
    });
}

- (void)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> * _Nonnull list))block {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair*> *annotations = [[self getConversationService] listAnnotationsWithDescriptorId:descriptorId];
        block(annotations);
    });
}

- (void)getDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId withBlock:(nonnull void (^)(TLDescriptor * _Nullable descriptor))block {
    DDLogVerbose(@"%@ getDescriptorWithDescriptorId: %@", LOG_TAG, descriptorId.toString);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLDescriptor *descriptor = [[self getConversationService] getDescriptorWithDescriptorId:descriptorId];
        block(descriptor);
    });
}


#pragma mark - Room management

//
// Room management
//

- (void)roomSetNameWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact name:(nonnull NSString *)name {
    DDLogVerbose(@"%@ roomSetNameWithRequestId: %lld contact: %@ name: %@", LOG_TAG, requestId, contact, name);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionSetName text:name];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomSetWelcomeWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact message:(nonnull NSString *)message {
    DDLogVerbose(@"%@ roomSetWelcomeWithRequestId: %lld contact: %@ message: %@", LOG_TAG, requestId, contact, message);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionSetWelcome text:message];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomSetImageWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact image:(nonnull UIImage *)image {
    DDLogVerbose(@"%@ roomSetImageWithRequestId: %lld contact: %@ image: %@", LOG_TAG, requestId, contact, image);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionSetImage image:image];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomSetConfigWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact config:(nonnull TLRoomConfig *)config {
    DDLogVerbose(@"%@ roomSetConfigWithRequestId: %lld contact: %@ config: %@", LOG_TAG, requestId, contact, config);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionSetConfig config:config];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomGetConfigWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ roomGetConfigWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionGetConfig];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomChangeTwincodeWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ roomChangeTwincodeWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionRenewTwincode];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomDeleteMessageWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact messageId:(nonnull TLDescriptorId *)messageId {
    DDLogVerbose(@"%@ roomDeleteMessageWithRequestId: %lld contact: %@ messageId: %@", LOG_TAG, requestId, contact, messageId);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionDeleteMessage messageId:messageId];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomForwardMessageWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact messageId:(nonnull TLDescriptorId *)messageId {
    DDLogVerbose(@"%@ roomForwardMessageWithRequestId: %lld contact: %@ messageId: %@", LOG_TAG, requestId, contact, messageId);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionForwardMessage messageId:messageId];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomBlockSenderWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact messageId:(nonnull TLDescriptorId *)messageId {
    DDLogVerbose(@"%@ roomBlockMemberWithRequestId: %lld contact: %@ messageId: %@", LOG_TAG, requestId, contact, messageId);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionBlockSender messageId:messageId];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomSignalMemberWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId {
    DDLogVerbose(@"%@ roomSignalMemberWithRequestId: %lld contact: %@ memberTwincodeOutboundId: %@", LOG_TAG, requestId, contact, memberTwincodeOutboundId);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionSignalMember twincodeOutboundId:memberTwincodeOutboundId];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomDeleteMemberWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId {
    DDLogVerbose(@"%@ roomDeleteMemberWithRequestId: %lld contact: %@ memberTwincodeOutboundId: %@", LOG_TAG, requestId, contact, memberTwincodeOutboundId);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionDeleteMember twincodeOutboundId:memberTwincodeOutboundId];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomSetRolesWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact role:(nonnull NSString *)role members:(nonnull NSArray<NSUUID *> *)members {
    DDLogVerbose(@"%@ roomSetRolesWithRequestId: %lld contact: %@ role: %@ members: %@", LOG_TAG, requestId, contact, role, members);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionSetRoles text:role list:members];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomListMembersWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact filter:(nonnull NSString *)filter {
    DDLogVerbose(@"%@ roomListMembersWithRequestId: %lld contact: %@ filter: %@", LOG_TAG, requestId, contact, filter);
    
    TLRoomCommand *command = [[TLRoomCommand alloc] initWithRequestId:requestId action:TLRoomCommandActionListMembers text:filter];
    
    [self roomCommandWithRequestId:requestId contact:contact command:command];
}

- (void)roomCommandWithRequestId:(int64_t)requestId contact:(nonnull TLContact *)contact command:(nonnull TLRoomCommand *)command {
    DDLogVerbose(@"%@ roomCommandWithRequestId: %lld contact: %@ command: %@", LOG_TAG, requestId, contact, command);
    
    if (![contact isTwinroom] || ![contact hasPrivatePeer]) {
        [self fireOnErrorWithRequestId:requestId errorCode:TLBaseServiceErrorCodeBadRequest errorParameter:nil];
        return;
    }
    
    id<TLConversation> conversation = [[self getConversationService] getOrCreateConversationWithSubject:contact create:YES];
    if (conversation) {
        [[self getConversationService] pushCommandWithRequestId:requestId conversation:conversation object:command];
    }
}

#pragma mark - Notification management

//
// Notification management
//

- (void)getNotificationWithNotificationId:(nonnull NSUUID *)notificationId withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, TLNotification *notification))block {
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLNotificationService *notificationService = [self getNotificationService];
        TLNotification *notification = [notificationService getNotificationWithNotificationId:notificationId];
        if (notification) {
            block(TLBaseServiceErrorCodeSuccess, notification);
        } else {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
        }
    });
}

- (void)findNotificationsWithFilter:(nonnull TLFilter *)filter maxDescriptors:(int)maxDescriptors withBlock:(nonnull void (^)(NSMutableArray<TLNotification*> * _Nonnull list))block {
    DDLogVerbose(@"%@ findNotificationsWithFilter: %@ maxDescriptor: %d", LOG_TAG, filter, maxDescriptors);
    
    dispatch_async(self.twinlife.twinlifeQueue, ^{
        TLNotificationService *notificationService = [self getNotificationService];
        NSMutableArray<TLNotification*> *notifications = [notificationService listNotificationsWithFilter:filter maxDescriptors:maxDescriptors];
        block(notifications);
    });
}

- (nullable TLNotification *)createNotificationWithType:(TLNotificationType)type notificationId:(nullable NSUUID *)notificationId subject:(nonnull id<TLRepositoryObject>)subject descriptorId:(nullable TLDescriptorId *)descriptorId annotatingUser:(nullable TLTwincodeOutbound *)annotatingUser {
    DDLogVerbose(@"%@ createNotificationWithType: %d notificationId: %@ subject: %@ descriptorId: %@ annotatingUser: %@", LOG_TAG, type, notificationId, subject, descriptorId, annotatingUser);
    
    TLNotificationService *notificationService = [self getNotificationService];
    if (!notificationService) {
        return nil;
    }
    
    TLNotification *notification = [notificationService createNotificationWithType:type notificationId:notificationId subject:subject descriptorId:descriptorId annotatingUser:annotatingUser];
    if (notification) {
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onAddNotificationWithNotification:)]) {
                id<TLTwinmeContextDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onAddNotificationWithNotification:notification];
                });
            }
        }
        
        [self scheduleRefreshNotifications];
    }
    return notification;
}

- (void)acknowledgeNotificationWithRequestId:(int64_t)requestId notification:(TLNotification *)notification {
    DDLogVerbose(@"%@ acknowledgeNotificationsWithRequestId: %lld notification: %@", LOG_TAG, requestId, notification);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLNotificationService *notificationService = [self getNotificationService];
        [notificationService acknowledgeWithNotification:notification];
        [self scheduleRefreshNotifications];
    });
}

- (void)deleteWithNotification:(nonnull TLNotification *)notification {
    DDLogVerbose(@"%@ deleteWithNotification: %@", LOG_TAG, notification);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        TLNotificationService *notificationService = [self getNotificationService];
        [notificationService deleteWithNotification:notification];
        
        NSArray<NSUUID *> *list = [[NSArray alloc] initWithObjects:notification.uuid, nil];
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onDeleteNotificationsWithList:)]) {
                id<TLTwinmeContextDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onDeleteNotificationsWithList:list];
                });
            }
        }
        
        [self scheduleRefreshNotifications];
    });
}

- (void)getSpaceNotificationStatsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLNotificationServiceNotificationStat *stats))block {
    DDLogVerbose(@"%@ getSpaceNotificationStatsWithBlock", LOG_TAG);

    dispatch_async([self.twinlife twinlifeQueue], ^{
        NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *stats = [[self.twinlife getNotificationService] getNotificationStats];
        long pendingCount = 0;
        long acknowledgedCount = 0;
        @synchronized (self) {
            if (self.currentSpace) {
                TLNotificationServiceNotificationStat* stat = stats[self.currentSpace.uuid];
                if (stat) {
                    pendingCount = stat.pendingCount;
                    acknowledgedCount = stat.acknowledgedCount;
                }
            }
        }
        block(TLBaseServiceErrorCodeSuccess, [[TLNotificationServiceNotificationStat alloc] initWithPendingCount:pendingCount acknowledgedCount:acknowledgedCount]);
        
        [self refreshNotificationsWithStats:stats];
    });
}

- (void)getNotificationStatsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSDictionary<NSUUID *, TLNotificationServiceNotificationStat *>* _Nonnull stats))block {
    DDLogVerbose(@"%@ getNotificationStatsWithBlock", LOG_TAG);
    
    dispatch_async([self.twinlife twinlifeQueue], ^{
        NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *>* stats = [[self.twinlife getNotificationService] getNotificationStats];
        block(TLBaseServiceErrorCodeSuccess, stats);
    });
}

- (void)scheduleRefreshNotifications {
    DDLogVerbose(@"%@ scheduleRefreshNotifications", LOG_TAG);
    
    // When the delay is < 0, the refresh of notification is disabled
    // (used by NotificationServiceExtension because spaces are not loaded and computed badge is wrong).
    if (self.refreshBadgeDelay <= 0.0) {
        return;
    }
    @synchronized (self) {
        if (self.notificationRefreshJob) {
            return;
        }
        self.notificationRefreshJob = [[self.twinlife getJobService] scheduleWithJob:self.notificationRefresh delay:self.refreshBadgeDelay priority:TLJobPriorityMessage];
    }
}

- (void)refreshNotifications {
    DDLogVerbose(@"%@ refreshNotifications", LOG_TAG);
    
    @synchronized (self) {
        self.notificationRefreshJob = nil;
    }
    
    [self refreshNotificationsWithStats:[[self.twinlife getNotificationService] getNotificationStats]];
}

- (void)refreshNotificationsWithStats:(nonnull NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *)stats {
    DDLogVerbose(@"%@ refreshNotificationsWithStats: %@", LOG_TAG, stats);
    
    long pendingCount = 0;
    long spacePendingCount = 0;
    long acknowledgedCount = 0;
    BOOL modified;
    @synchronized (self) {
        for (NSUUID *spaceId in stats) {
            TLNotificationServiceNotificationStat *stat = stats[spaceId];
            TLSpace *space = self.spaces[spaceId];
            
            if (stat && space) {
                if (space == self.currentSpace || ![space.settings isSecret]) {
                    pendingCount += stat.pendingCount;
                    acknowledgedCount += stat.acknowledgedCount;
                }
                if (space == self.currentSpace) {
                    spacePendingCount += stat.pendingCount;
                }
            }
        }
        
        modified = !self.visibleNotificationStats || self.visibleNotificationStats.pendingCount != pendingCount;
        if (modified) {
            self.visibleNotificationStats = [[TLNotificationServiceNotificationStat alloc] initWithPendingCount:pendingCount acknowledgedCount:acknowledgedCount];
        }
    }
    
    if (modified) {
        BOOL hasPendingNotifications = spacePendingCount > 0;
        for (id delegate in self.delegates) {
            if ([delegate respondsToSelector:@selector(onUpdatePendingNotificationsWithRequestId:hasPendingNotifications:)]) {
                id<TLTwinmeContextDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onUpdatePendingNotificationsWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] hasPendingNotifications:hasPendingNotifications];
                });
            }
        }
        
        [self.notificationCenter updateApplicationBadgeNumber:pendingCount];
    }
}

#pragma mark - Timeout based actions

- (void)startActionWithAction:(nonnull TLTwinmeAction *)action {
    DDLogVerbose(@"%@ startActionWithAction: %@", LOG_TAG, action);
    
    @synchronized (self) {
        [self.pendingActions addObject:action allowDuplicate:YES];
        
        TLTwinmeAction *firstAction = (TLTwinmeAction *)[self.pendingActions firstObject];
        if (self.firstAction != firstAction) {
            if (self.actionTimeoutJob) {
                [self.actionTimeoutJob cancel];
            }
            self.firstAction = firstAction;
            self.actionTimeoutJob = [[self.twinlife getJobService] scheduleWithJob:self.actionTimeout deadline:firstAction.deadlineTime priority:TLJobPriorityMessage];
        }
    }
    
    [self addDelegate:action];
}

- (void)finishActionWithAction:(nonnull TLTwinmeAction *)action {
    DDLogVerbose(@"%@ finishActionWithAction: %@", LOG_TAG, action);
    
    @synchronized (self) {
        [self.pendingActions removeObject:action];
        
        TLTwinmeAction *firstAction = (TLTwinmeAction *)[self.pendingActions firstObject];
        if (!firstAction) {
            self.firstAction = nil;
            if (self.actionTimeoutJob) {
                [self.actionTimeoutJob cancel];
                self.actionTimeoutJob = nil;
            }
        } else if (firstAction != self.firstAction) {
            if (self.actionTimeoutJob) {
                [self.actionTimeoutJob cancel];
            }
            self.firstAction = firstAction;
            self.actionTimeoutJob = [[self.twinlife getJobService] scheduleWithJob:self.actionTimeout deadline:firstAction.deadlineTime priority:TLJobPriorityMessage];
        }
    }
    
    [self removeDelegate:action];
}

- (void)runJobActionTimeout {
    DDLogVerbose(@"%@ runJobActionTimeout", LOG_TAG);
    
    NSMutableArray<TLTwinmeAction *> *expiredList = nil;
    
    @synchronized (self) {
        unsigned long count = self.pendingActions.count;
        if (count > 0) {
            NSDate *now = [[NSDate alloc] initWithTimeIntervalSinceNow:0.0];
            
            for (unsigned long i = 0; i < count; i++) {
                TLTwinmeAction *action = (TLTwinmeAction *)self.pendingActions.queue[i];
                
                if ([action.deadlineTime compare:now] == NSOrderedDescending) {
                    break;
                }
                
                if (!expiredList) {
                    expiredList = [[NSMutableArray alloc] init];
                }
                [expiredList addObject:action];
            }
        }
    }
    if (expiredList) {
        for (TLTwinmeAction *action in expiredList) {
            [action fireTimeout];
        }
    }
}

#pragma mark - Report methods

- (void)reportStatsWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ reportStatsWithRequestId: %lld", LOG_TAG, requestId);
    
    TLReportStatsExecutor *reportStatsExecutor = [[TLReportStatsExecutor alloc] initWithTwinmeContext:self requestId:requestId];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [reportStatsExecutor start];
    });
}

- (void)onReportStatsWithRequestId:(int64_t)requestId delay:(NSTimeInterval)delay {
    DDLogVerbose(@"%@ onReportStatsWithRequestId: %lld", LOG_TAG, requestId);
    
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self) {
        NSNumber *operationId = self.requestIds[lRequestId];
        if (operationId != nil) {
            [self.requestIds removeObjectForKey:lRequestId];
            if (requestId == self.reportRequestId) {
                self.reportRequestId = [TLBaseService DEFAULT_REQUEST_ID];
            }
        }
        if (self.reportJob) {
            [self.reportJob cancel];
        }
        self.reportJob = [[self.twinlife getJobService] scheduleWithJob:self delay:delay priority:TLJobPriorityReport];
    }
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    int64_t requestId = [TLBaseService DEFAULT_REQUEST_ID];
    @synchronized (self) {
        self.reportJob = nil;
        
        // Forbid to create a new report if one is already running.
        if (self.reportRequestId == [TLBaseService DEFAULT_REQUEST_ID]) {
            self.reportRequestId = [self newOperation:REPORT_STATS];
            requestId = self.reportRequestId;
        }
    }
    if (requestId != [TLBaseService DEFAULT_REQUEST_ID]) {
        [self reportStatsWithRequestId:requestId];
    }
}

#pragma mark - Protected methods

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self getConversationService] addDelegate:self.conversationServiceDelegate];
    [[self getPeerConnectionService] addDelegate:self.peerConnectionServiceDelegate];
    [[self getTwincodeOutboundService] addDelegate:self.twincodeOutboundServiceDelegate];
    [[self getNotificationService] addDelegate:self.notificationServiceDelegate];
    
    TLTwincodeInvocationListener invocationListener = ^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [self onInvokeTwincodeWithInvocation:invocation];
    };
    TLTwincodeInboundService *twincodeInboundService = [self getTwincodeInboundService];
    [twincodeInboundService addListenerWithAction:[TLPairProtocol ACTION_PAIR_INVITE] listener:invocationListener];
    [twincodeInboundService addListenerWithAction:[TLPairProtocol ACTION_PAIR_BIND] listener:invocationListener];
    [twincodeInboundService addListenerWithAction:[TLPairProtocol ACTION_PAIR_UNBIND] listener:invocationListener];
    [twincodeInboundService addListenerWithAction:[TLPairProtocol ACTION_PAIR_REFRESH] listener:invocationListener];

    [[self getConversationService] acceptPushTwincodeWithSchemaId:[TLInvitation SCHEMA_ID]];
    TLRepositoryService* repositoryService = [self getRepositoryService];
    [repositoryService addDelegate:self.repositoryServiceDelegate];
    //[repositoryService addLocalSchemaWithSchemaId:[TLSpaceSettings SCHEMA_ID]];
    //[repositoryService addLocalSchemaWithSchemaId:[TLCallReceiver SCHEMA_ID]];
    
    BOOL hasProfiles = [repositoryService hasObjectsWithSchemaId:[TLProfile SCHEMA_ID]];
    BOOL hasSpaces = [repositoryService hasObjectsWithSchemaId:[TLSpace SCHEMA_ID]];
    
    // Update the status at the same time.
    @synchronized (self) {
        self.hasProfiles = hasProfiles;
        self.hasSpaces = hasSpaces;
    }
    
    // Load the default settings from the local database only.
    if (self.defaultSettingsId) {
        [repositoryService getObjectWithFactory:[TLSpaceSettings FACTORY] objectId:self.defaultSettingsId withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            if (errorCode == TLBaseServiceErrorCodeSuccess && object && [object isKindOfClass:[TLSettings class]]) {
                self.defaultCreateSpaceSettings = (TLSpaceSettings *)object;
            } else {
                self.defaultSettingsId = nil;
            }
        }];
    }
    
    // Trigger the onTwinlifeReady on registered services at the end after knowing if we have spaces and profiles.
    [super onTwinlifeReady];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    [super onTwinlifeOnline];
    
    if (self.enableInvocations) {
        [[self getTwincodeInboundService] triggerPendingInvocationsWithFilters:nil withBlock:^() {
            [[self getPeerConnectionService] triggerSessionPing];
        }];
    } else {
        NSMutableArray *filters = [[NSMutableArray alloc] initWithCapacity:1];
        [filters addObject:@"twinlife::conversation::synchronize"];
        [[self getTwincodeInboundService] triggerPendingInvocationsWithFilters:filters withBlock:^() {
            [[self getPeerConnectionService] triggerSessionPing];
        }];
    }
    
    if (self.enableReports) {
        // Setup the job to send the report periodically.
        TLReportStatsExecutor *reportStatsExecutor = [[TLReportStatsExecutor alloc] initWithTwinmeContext:self requestId:[TLBaseService DEFAULT_REQUEST_ID] ];
        NSTimeInterval delay = [reportStatsExecutor nextDelay];
        [self onReportStatsWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] delay:delay];
    }
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [super onSignOut];
    
    @synchronized(self) {
        self.currentProfile = nil;
        self.hasProfiles = false;
        self.hasSpaces = false;
        [self.spaces removeAllObjects];
        [self.groupMembers removeAllObjects];
        self.getSpacesDone = false;
        
        // Cancel any job report.
        if (self.reportJob) {
            [self.reportJob cancel];
            self.reportJob = nil;
        }
        if (self.notificationRefreshJob) {
            [self.notificationRefreshJob cancel];
            self.notificationRefreshJob = nil;
        }
    }
    
    // Clear the notification badge.
    [self.notificationCenter updateApplicationBadgeNumber:0];
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
    // Cleanup to force a fetch when one of these objects are required.
    // For the NotificationServiceExtension, we only load one object at a time
    // except for the spaces.  The application can keep the profile and spaces since they
    // are never modified by the extension.  For both, we must cleanup the contacts and groups.
    @synchronized (self) {
        if (!self.enableCaches) {
            [self.spaces removeAllObjects];
            self.currentSpace = nil;
            self.currentProfile = nil;
            self.getSpacesDone = NO;
            [self.groupMembers removeAllObjects];
        }
        
        // Make sure we reload the groups, contacts, conversations at the next resume.
        self.visibleNotificationStats = nil;
    }
}

#pragma mark - Private methods

- (TLSpace *)putSpace:(TLSpace *)space {
    DDLogVerbose(@"%@ putSpace: %@", LOG_TAG, space);
    
    TLSpace *setCurrent = nil;
    @synchronized(self) {
        self.spaces[space.uuid] = space;
        
        // Check the default space validity.
        if (!self.defaultSpaceId) {
            [self setDefaultSpace:space];
        }
        
        // Make sure we know a current space.
        if (!self.currentSpace && [self.defaultSpaceId isEqual:space.uuid]) {
            setCurrent = space;
        }
        
        self.hasSpaces = YES;
    }
    if (setCurrent) {
        [self setCurrentSpaceWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] space:setCurrent];
    }
    
    return space;
}

- (void)removeSpace:(NSUUID *)spaceId {
    DDLogVerbose(@"%@ removeSpace: %@", LOG_TAG, spaceId);
    
    TLSpace *setCurrent;
    @synchronized(self) {
        [self.spaces removeObjectForKey:spaceId];
        
        // If the current space was deleted, invalidate and switch to the default space if there is one.
        if (self.currentSpace && [self.currentSpace.uuid isEqual:spaceId]) {
            self.currentSpace = nil;
            self.currentProfile = nil;
            if (self.defaultSpaceId) {
                setCurrent = self.spaces[self.defaultSpaceId];
            }
        }
    }
    
    if (setCurrent) {
        [self setCurrentSpaceWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] space:setCurrent];
    }
}

- (void)onLeaveGroupWithGroup:(id <TLGroupConversation>)group memberId:(NSUUID *)memberId {
    DDLogVerbose(@"%@ onLeaveGroupWithGroup: %@ memberId: %@", LOG_TAG, group, memberId);
    
    // Remove the member's twincode from our local database.
    [[self getTwincodeOutboundService] evictTwincode:memberId];
    
    // And make sure the group member cache is also cleared (in case we are re-invited in the same group).
    @synchronized (self) {
        [self.groupMembers removeObjectForKey:memberId];
    }
}

- (void)onRevokedWithConversation:(id<TLConversation>)conversation {
    DDLogVerbose(@"%@ onRevokedWithConversation: %@", LOG_TAG, conversation);
    
    id<TLRepositoryObject> subject = conversation.subject;
    if ([subject isKindOfClass:[TLContact class]]) {
        [self unbindContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] invocationId:nil contact:(TLContact *)subject];
    }
}

- (void)onSignatureInfoWithConversation:(nonnull id<TLConversation>)conversation signedTwincode:(nonnull TLTwincodeOutbound *)signedTwincode {
    DDLogVerbose(@"%@ onSignatureInfoWithConversation: %@ signedTwincode: %@", LOG_TAG, conversation, signedTwincode);
    
    id<TLRepositoryObject> subject = conversation.subject;
    if ([subject isKindOfClass:[TLContact class]]) {
        TLContact *contact = (TLContact *)subject;
        
        if (![contact.peerTwincodeOutboundId isEqual:signedTwincode.uuid] || !signedTwincode.isSigned) {
            return;
        }
        
        TLCapabilities *caps = [[TLCapabilities alloc] initWithCapabilities:contact.identityCapabilities.attributeValue];
        
        [caps setTrustedWithValue:signedTwincode.uuid];
        
        [self updateContactIdentityWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] contact:contact identityName:contact.identityName identityAvatar:nil identityLargeAvatar:nil description:contact.objectDescription capabilities:caps];
    }
}

- (void)onProcessInvocation:(nonnull TLInvocation *)invocation {
    DDLogVerbose(@"%@ onProcessInvocation: %@", LOG_TAG, invocation);

    id<TLRepositoryObject> receiver = invocation.receiver;
    if (invocation.background) {
        if ([receiver class] == [TLProfile class]) {
            if ([invocation class] == [TLPairInviteInvocation class]) {
                [self createContactPhase2WithInvocation:(TLPairInviteInvocation *)invocation profile:(TLProfile *)receiver];
            } else {
                [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];
                
                [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
            }
        } else if ([receiver class] == [TLInvitation class]) {
            if ([invocation class] == [TLPairInviteInvocation class]) {
                [self createContactPhase2WithInvocation:(TLPairInviteInvocation *)invocation invitation:(TLInvitation *)receiver];
            } else {
                [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];

                [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
            }
        } else if ([receiver class] == [TLContact class]) {
            TLContact *contact = (TLContact *)receiver;
            if ([invocation class] == [TLPairBindInvocation class]) {
                [self bindContactWithInvocation:(TLPairBindInvocation *)invocation contact:contact];
            } else if ([invocation class] == [TLPairUnbindInvocation class]) {
                TLPairUnbindInvocation *pairUnbindInvocation = (TLPairUnbindInvocation *)invocation;
                [self unbindContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] invocationId:pairUnbindInvocation.uuid contact:contact];
            } else if ([invocation class] == [TLPairRefreshInvocation class]) {
                [self refreshObjectWithInvocation:(TLPairRefreshInvocation *)invocation subject:contact];
            } else {
                [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];
                
                [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
            }
        } else if ([receiver class] == [TLGroup class]) {
            TLGroup *group = (TLGroup *)receiver;
            if ([invocation class] == [TLGroupRegisteredInvocation class]) {
                TLGroupRegisteredInvocation *groupRegisteredInvocation = (TLGroupRegisteredInvocation *)invocation;
                TLGroupRegisteredExecutor *groupRegisteredExecutor = [[TLGroupRegisteredExecutor alloc] initWithTwinmeContext:self requestId:[TLBaseService DEFAULT_REQUEST_ID] groupRegisteredInvocation:groupRegisteredInvocation group:group];
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [groupRegisteredExecutor start];
                });
            } else if ([invocation class] == [TLPairRefreshInvocation class]) {
                [self refreshObjectWithInvocation:(TLPairRefreshInvocation *)invocation subject:group];

            } else {
                [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];
                
                [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
            }
        } else if ([receiver class] == [TLAccountMigration class]) {
            TLAccountMigration *accountMigration = (TLAccountMigration *)receiver;
            
            if ([invocation class] == [TLPairInviteInvocation class]) {
                TLPairInviteInvocation *pairBindInvocation = (TLPairInviteInvocation *)invocation;
                [self bindAccountMigrationWithRequestId:TLBaseService.DEFAULT_REQUEST_ID invocationId:pairBindInvocation.uuid accountMigration:accountMigration peerTwincodeOutboundId:pairBindInvocation.twincodeOutbound.uuid];
            } else if ([invocation class] == [TLPairUnbindInvocation class]) {
                [self deleteAccountMigrationWithAccountMigration:accountMigration withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID * _Nullable uuid) {
                    [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeSuccess];
                }];
            } else {
                [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];

                [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
            }
        } else {
            [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];

            [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
        }
    } else {
        if ([receiver class] == [TLProfile class]) {
            
            [self onUpdateProfileWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] profile:(TLProfile *)receiver];
        } else if ([receiver class] == [TLContact class]) {
            
            [self onUpdateContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] contact:(TLContact *)receiver];
        } else {
            [self assertionWithAssertPoint:[TLTwinmeAssertPoint PROCESS_INVOCATION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithInvocationId:invocation.uuid], nil];
            
            [self acknowledgeInvocationWithInvocationId:invocation.uuid errorCode:TLBaseServiceErrorCodeBadRequest];
        }
    }
}

- (void)onIncomingPeerConnectionWithPeerConnectionId:(NSUUID *)peerConnectionId peerId:(NSString *)peerId offer:(nonnull TLOffer *)offer {
    DDLogVerbose(@"%@ onIncomingPeerConnectionWithPeerConnectionId: %@ peerId: %@ offer: %@", LOG_TAG, peerConnectionId, peerId, offer);
    
    NSArray<NSString *> *items = [peerId componentsSeparatedByString:@"@"];
    if (items.count != 2 || ![items[1] hasPrefix:@"inbound.twincode.twinlife"]) {
        
        return;
    }
    
    NSUUID *twincodeInboundId = [[NSUUID alloc] initWithUUIDString:items[0]];
    if (!twincodeInboundId) {
        [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGeneralError];
        return;
    }
    NSUUID *callingUserTwincodeId;
        
    NSArray<NSString *> *domainAndResource = [items[1] componentsSeparatedByString:@"/"];
    if (domainAndResource.count == 2) {
        callingUserTwincodeId = [[NSUUID alloc] initWithUUIDString:domainAndResource[1]];
    }

    TLFindResult *result = [self getReceiverWithTwincodeInboundId:twincodeInboundId];
    if (result.errorCode != TLBaseServiceErrorCodeSuccess || [result.object class] != [TLGroup class]) {
        [self onIncomingPeerConnectionWithPeerConnectionId:peerConnectionId errorCode:result.errorCode receiver:result.object callingUserTwincodeId:callingUserTwincodeId offer:offer];
    } else {
        if (callingUserTwincodeId) {
            [self getGroupMemberWithOwner:(id<TLOriginator>)result.object memberTwincodeId:callingUserTwincodeId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
                    [self onIncomingPeerConnectionWithPeerConnectionId:peerConnectionId errorCode:errorCode receiver:groupMember callingUserTwincodeId:callingUserTwincodeId offer:offer];
            }];
        } else {
            // There is no resource part in the peerId, this is not an error but an old
            // twinme version is trying to send us something in a group.
            [self onIncomingPeerConnectionWithPeerConnectionId:peerConnectionId errorCode:result.errorCode receiver:result.object callingUserTwincodeId:callingUserTwincodeId offer:offer];
        }
    }
}

- (void)onIncomingPeerConnectionWithPeerConnectionId:(NSUUID *)peerConnectionId errorCode:(TLBaseServiceErrorCode)errorCode receiver:(id)receiver callingUserTwincodeId:(nullable NSUUID *)callingUserTwincodeId offer:(nonnull TLOffer *)offer {
    DDLogVerbose(@"%@ onIncomingPeerConnectionWithPeerConnectionId: %@ errorCode: %d receiver: %@ offer: %@", LOG_TAG, peerConnectionId, errorCode, receiver, offer);
    
    // Contact or group was not found, send a terminate to close the P2P connection.
    if (errorCode != TLBaseServiceErrorCodeSuccess || !receiver) {
        [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGone];
        return;
    }
    
    id<TLOriginator> originator = nil;
    
    TLGroup *group = nil;
    NSUUID *twincodeInboundId = nil;
    NSUUID *twincodeOutboundId = nil;
    if ([receiver class] == [TLContact class] || [receiver class] == [TLCallReceiver class]) {
        originator = (id<TLOriginator>)receiver;
        twincodeInboundId = originator.twincodeInboundId;
        twincodeOutboundId = originator.twincodeOutboundId;
        
    } else if ([receiver class] == [TLGroupMember class]) {
        TLGroupMember *groupMember = (TLGroupMember *)receiver;
        originator = groupMember;
        group = (TLGroup *)groupMember.owner;
        
        twincodeInboundId = group.twincodeInboundId;
        twincodeOutboundId = group.twincodeOutboundId;
        
    } else if ([receiver class] == [TLGroup class]) {
        group = (TLGroup *)receiver;
        originator = group;
        twincodeInboundId = group.twincodeInboundId;
        twincodeOutboundId = group.twincodeOutboundId;
        
    } else if ([receiver class] == [TLAccountMigration class]) {
        [self.notificationCenter onIncomingMigrationWithAccountMigration:(TLAccountMigration *)receiver peerConnectionId:peerConnectionId];
        return;
        
    } else if ([receiver class] == [TLProfile class] && callingUserTwincodeId) {
        // The peer is doing a P2P invocation on our Profile which is not allowed but occurs due to
        // a bug on the caller's side: its contact is not configured correctly (the `pair::bind` invocation
        // was not saved correctly).  We look at the contact with the twincode ID used by the caller and try
        // to see a contact which such twincode ID:
        // - if we find it, it means the `pair::bind` was lost, missed or not saved correctly on its side.
        //   we can issue a second `pair:bind` with the same information.
        // - if we don't find such contact, there is nothing to do.
        // In both cases, the incoming P2P is terminated immediately.
        // There is no security issue in doing this because we have validated that contact when it was created.
        TLRebindContactExecutor *rebindContactExecutor = [[TLRebindContactExecutor alloc] initWithTwinmeContext:self peerTwincodeId:callingUserTwincodeId];
        [rebindContactExecutor start];
        [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGeneralError];
        return;

    } else {
        [self assertionWithAssertPoint:[TLTwinmeAssertPoint INCOMING_PEER_CONNECTION], [TLAssertValue initWithSubject:receiver], [TLAssertValue initWithPeerConnectionId:peerConnectionId], nil];
    }
    
    if (!twincodeInboundId) {
        [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGeneralError];
        return;
    }
    
    if (offer.data && !(offer.video || offer.audio)) {
        // For the incoming data P2P, we have to wait that every incoming invocation for
        // the twincode are processed so that we have a chance to handle the `pair::bind`
        // before accepting the session (if we accept the session earlier, we won't have
        // the peer secret keys to decrypt the SDPs).
        [[self getTwincodeInboundService] waitInvocationsForTwincode:twincodeInboundId withBlock:^{

            // Now, we can verify that incoming P2P are accepted for the given calling twincode.
            // It could be rejected also due to a `pair::bind` that was not handled.
            BOOL acceptP2P = [originator canAcceptP2PWithTwincodeId:callingUserTwincodeId];
            if (!group && twincodeOutboundId && acceptP2P) {
                [[self getConversationService] incomingPeerConnectionWithPeerConnectionId:peerConnectionId subject:originator create:true peerTwincodeOutbound:originator.peerTwincodeOutbound];

            } else if (group && group.groupTwincodeOutboundId) {
                [[self getConversationService] incomingPeerConnectionWithPeerConnectionId:peerConnectionId subject:group create:false peerTwincodeOutbound:originator.peerTwincodeOutbound];
            } else {
                // If the receiver does not accept P2P connection, terminate with NotAuthorized.
                [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:acceptP2P ? TLPeerConnectionServiceTerminateReasonGeneralError : TLPeerConnectionServiceTerminateReasonNotAuthorized];
            }
        }];

    } else if (originator && (offer.audio || offer.video)) {
        if ([self isVisible:originator]) {
            [self.notificationCenter onIncomingCallWithContact:originator peerConnectionId:peerConnectionId offer:offer];
        } else {
            [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonBusy];
            TLNotificationType notificationType = offer.video ? TLNotificationTypeMissedVideoCall : TLNotificationTypeMissedAudioCall;
            [self createNotificationWithType:notificationType notificationId:[NSUUID alloc] subject:originator descriptorId:nil annotatingUser:nil];
        }
        
    } else {
        [[self getPeerConnectionService] terminatePeerConnectionWithPeerConnectionId:peerConnectionId terminateReason:TLPeerConnectionServiceTerminateReasonGeneralError];
    }
}

- (TLBaseServiceErrorCode)onInvokeTwincodeWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@ onInvokeTwincodeWithInvocation: %@", LOG_TAG, invocation);
    
    // Invocations can be disabled for the NotificationServiceExtension, ignore them if we get one.
    // (it could happen if an invocation is made while the extension is connected to the server).
    if (!self.enableInvocations) {
        DDLogInfo(@"%@ ignore invocation: %@", LOG_TAG, invocation);
        return TLBaseServiceErrorCodeQueued;
    }

    TLProcessInvocationExecutor *processInvocationExecutor = [[TLProcessInvocationExecutor alloc] initWithTwinmeContext:self invocation:invocation withBlock:^(TLBaseServiceErrorCode errorCode, TLInvocation *newInvocation) {
        if (errorCode != TLBaseServiceErrorCodeSuccess || !newInvocation) {
            [self acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:errorCode];
        } else {
            [self onProcessInvocation:newInvocation];
        }
    }];
    dispatch_async([self.twinlife twinlifeQueue], ^{
        [processInvocationExecutor start];
    });
    return TLBaseServiceErrorCodeQueued;
}

- (void)onRefreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound updatedAttributes:(nonnull NSArray<TLAttributeNameValue *> *)updatedAttributes {
    DDLogVerbose(@"%@ onRefreshTwincodeWithTwincode: %@ updatedAttributes: %@", LOG_TAG, twincodeOutbound, updatedAttributes);
    
    TLImageId *oldAvatarId;
    TLImageId *newAvatarId;
    
    TLAttributeNameValue *attr = [TLAttributeNameValue getAttributeWithName:TL_TWINCODE_AVATAR_ID list:updatedAttributes];
    if (attr) {
        oldAvatarId = (TLImageId *)attr.value;
    }
    
    TLFilter *filter = [[TLFilter alloc] init];
    filter.twincodeOutbound = twincodeOutbound;
    [self findContactsWithFilter:filter withBlock:^(NSMutableArray<TLContact *> *list) {
        for (TLContact *contact in list) {
            [self onUpdateContactWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] contact:contact];
        }
    }];
    [self findGroupsWithFilter:filter withBlock:^(NSMutableArray<TLGroup *> *list) {
        for (TLGroup *group in list) {
            [self onUpdateGroupWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:group];
        }
    }];
    
    // Detect a change of the avatar to cleanup our database and get the new image.
    if ((!oldAvatarId && newAvatarId) || (oldAvatarId && ![oldAvatarId isEqual:newAvatarId])) {
        TLImageService *imageService = [self.twinlife getImageService];
        if (oldAvatarId) {
            [imageService evictImageWithImageId:oldAvatarId];
        }
        if (newAvatarId) {
            [imageService getImageWithImageId:newAvatarId kind:TLImageServiceKindThumbnail withBlock:^(TLBaseServiceErrorCode status, UIImage *image) {
            }];
        }
    }
}

- (void)onPushDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPushDescriptorWithConversation: %@ descriptor: %@", LOG_TAG, conversation, descriptor);
    
    switch ([descriptor getType]) {
        case TLDescriptorTypeObjectDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbMessageSent];
            break;
            
        case TLDescriptorTypeFileDescriptor:
        case TLDescriptorTypeNamedFileDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbFileSent];
            break;
            
        case TLDescriptorTypeAudioDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbAudioSent];
            break;
            
        case TLDescriptorTypeImageDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbImageSent];
            break;
            
        case TLDescriptorTypeVideoDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbVideoSent];
            break;
            
        case TLDescriptorTypeGeolocationDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbGeolocationSent];
            if (ENABLE_REPORT_LOCATION) {
                [TLLocationReport recordGeolocationWithDescriptor:(TLGeolocationDescriptor *)descriptor];
            }
            break;
            
        case TLDescriptorTypeTwincodeDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbTwincodeSent];
            break;
            
        case TLDescriptorTypeCallDescriptor: {
            TLCallDescriptor *callDescriptor = (TLCallDescriptor *)descriptor;
            
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:[callDescriptor isVideo] ? TLRepositoryServiceStatTypeNbVideoCallSent : TLRepositoryServiceStatTypeNbAudioCallSent];
            break;
        }
            
        default:
            break;
    }
}

- (void)onPopDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ onPopDescriptorWithConversation: %@ descriptor: %@", LOG_TAG, conversation, descriptor);
    
    switch ([descriptor getType]) {
        case TLDescriptorTypeObjectDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbMessageReceived];
            break;
            
        case TLDescriptorTypeFileDescriptor:
        case TLDescriptorTypeNamedFileDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbFileReceived];
            break;
            
        case TLDescriptorTypeAudioDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbAudioReceived];
            break;
            
        case TLDescriptorTypeImageDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbImageReceived];
            break;
            
        case TLDescriptorTypeVideoDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbVideoReceived];
            break;
            
        case TLDescriptorTypeGeolocationDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbGeolocationReceived];
            break;
            
        case TLDescriptorTypeTwincodeDescriptor:
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:TLRepositoryServiceStatTypeNbTwincodeReceived];
            break;
            
        case TLDescriptorTypeCallDescriptor: {
            TLCallDescriptor *callDescriptor = (TLCallDescriptor *)descriptor;
            
            [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:[callDescriptor isVideo] ? TLRepositoryServiceStatTypeNbVideoCallReceived : TLRepositoryServiceStatTypeNbAudioCallReceived];
            
            // When an incoming audio/video call is received, we don't need to proceed since it is handled specifically.
            return;
        }
            
        default:
            break;
    }
    if (!self.inBackground) {
        @synchronized(self) {
            if ([conversation isConversationWithUUID:self.activeConversationId]) {
                return;
            }
        }
    }
    
    id<TLRepositoryObject> subject = conversation.subject;
    TLDescriptorId *descriptorId = descriptor.descriptorId;
    if ([conversation isGroup] || ![descriptorId.twincodeOutboundId isEqual:conversation.peerTwincodeOutboundId]) {
        [self getGroupMemberWithOwner:(id<TLOriginator>)subject memberTwincodeId:descriptorId.twincodeOutboundId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
            [self onPopDescriptorWithConversation:conversation descriptor:descriptor errorCode:errorCode receiver:groupMember];
        }];
    } else {
        [self onPopDescriptorWithConversation:conversation descriptor:descriptor errorCode:TLBaseServiceErrorCodeSuccess receiver:subject];
    }
}

- (void)onPopDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor errorCode:(TLBaseServiceErrorCode)errorCode receiver:(id)receiver {
    DDLogVerbose(@"%@ onPopDescriptorWithConversation: %@ descriptor: %@ errorCode: %d receiver: %@", LOG_TAG, conversation, descriptor, errorCode, receiver);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !receiver) {
        
        return;
    }
    
    id<TLOriginator> originator;
    if ([receiver class] == [TLContact class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else if ([receiver class] == [TLGroup class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else if ([receiver class] == [TLGroupMember class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else {
        [self assertionWithAssertPoint:[TLTwinmeAssertPoint ON_POP_DESCRIPTOR], [TLAssertValue initWithSubject:receiver], nil];
        return;
    }
    
    if ([self isVisible:originator]) {
        [self.notificationCenter onPopDescriptorWithContact:originator conversationId:[conversation uuid] descriptor:descriptor];
    } else {
        BOOL addNotification = NO;
        TLNotificationType notificationType = TLNotificationTypeNewTextMessage;
        switch ([descriptor getType]) {
            case TLDescriptorTypeObjectDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewTextMessage;
                break;
                
            case TLDescriptorTypeImageDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewImageMessage;
                break;
                
            case TLDescriptorTypeAudioDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewAudioMessage;
                break;
                
            case TLDescriptorTypeVideoDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewVideoMessage;
                break;
                
            case TLDescriptorTypeFileDescriptor:
            case TLDescriptorTypeNamedFileDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewFileMessage;
                break;
                
            case TLDescriptorTypeInvitationDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewGroupInvitation;
                break;
                
            case TLDescriptorTypeGeolocationDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewGeolocation;
                break;
                
            case TLDescriptorTypeTwincodeDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewContactInvitation;
                break;
                
            case TLDescriptorTypeClearDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeResetConversation;
                break;
                
            default:
                break;
        }
        if (addNotification) {
            [self createNotificationWithType:notificationType notificationId:[NSUUID alloc] subject:originator descriptorId:descriptor.descriptorId annotatingUser:nil];
        }
    }
}

- (void)onUpdateDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType {
    DDLogVerbose(@"%@ onUpdateDescriptorWithConversation: %@ descriptor: %@ updateType: %u", LOG_TAG, conversation, descriptor, updateType);
    
    switch ([descriptor getType]) {
        case TLDescriptorTypeTwincodeDescriptor:
            break;
            
        case TLDescriptorTypeCallDescriptor:
            if (updateType == TLConversationServiceUpdateTypeContent) {
                TLCallDescriptor *callDescriptor = (TLCallDescriptor *)descriptor;
                
                TLRepositoryServiceStatType kind;
                if ([callDescriptor isVideo]) {
                    kind = [callDescriptor isIncoming] ? TLRepositoryServiceStatTypeVideoCallReceivedDuration : TLRepositoryServiceStatTypeVideoCallSentDuration;
                } else {
                    kind = [callDescriptor isIncoming] ? TLRepositoryServiceStatTypeAudioCallReceivedDuration : TLRepositoryServiceStatTypeAudioCallSentDuration;
                }
                if ([callDescriptor duration] > 0) {
                    [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:kind value:[callDescriptor duration]];
                } else if ([callDescriptor isIncoming] && [callDescriptor terminateReason] == TLPeerConnectionServiceTerminateReasonTimeout) {
                    [[self getRepositoryService] incrementStatWithObject:conversation.subject statType:[callDescriptor isVideo] ? TLRepositoryServiceStatTypeNbVideoCallMissed : TLRepositoryServiceStatTypeNbAudioCallMissed];
                }
            }
            
            // When an incoming audio/video call is updated or terminated, we don't need to proceed since it is handled specifically.
            return;
            
        default:
            break;
    }
    
    if (!self.inBackground) {
        @synchronized(self) {
            if ([conversation isConversationWithUUID:self.activeConversationId]) {
                return;
            }
        }
    }
    
    id<TLRepositoryObject> subject = conversation.subject;
    TLDescriptorId *descriptorId = descriptor.descriptorId;
    if ([conversation isGroup] || ![descriptorId.twincodeOutboundId isEqual:conversation.peerTwincodeOutboundId]) {
        [self getGroupMemberWithOwner:(id<TLOriginator>)subject memberTwincodeId:descriptorId.twincodeOutboundId withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
            [self onUpdateDescriptorWithConversation:conversation descriptor:descriptor updateType:updateType errorCode:errorCode receiver:groupMember];
        }];
    } else {
        [self onUpdateDescriptorWithConversation:conversation descriptor:descriptor updateType:updateType errorCode:TLBaseServiceErrorCodeSuccess receiver:subject];
    }
}

- (void)onUpdateDescriptorWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType errorCode:(TLBaseServiceErrorCode)errorCode receiver:(id)receiver {
    DDLogVerbose(@"%@ onUpdateDescriptorWithConversation: %@ descriptor: %@ updateType: %u errorCode: %d receiver: %@", LOG_TAG, conversation, descriptor, updateType, errorCode, receiver);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !receiver) {
        return;
    }
    
    id<TLOriginator> originator;
    if ([receiver class] == [TLContact class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else if ([receiver class] == [TLGroup class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else if ([receiver class] == [TLGroupMember class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else {
        [self assertionWithAssertPoint:[TLTwinmeAssertPoint ON_UPDATE_DESCRIPTOR], [TLAssertValue initWithSubject:receiver], nil];
        return;
    }
    
    if ([self isVisible:originator]) {
        [self.notificationCenter onUpdateDescriptorWithContact:originator conversationId:[conversation uuid] descriptor:descriptor updateType:updateType];
    } else {
        BOOL addNotification = NO;
        TLNotificationType notificationType = TLNotificationTypeNewTextMessage;
        switch ([descriptor getType]) {
            case TLDescriptorTypeImageDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewImageMessage;
                break;
                
            case TLDescriptorTypeAudioDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewAudioMessage;
                break;
                
            case TLDescriptorTypeVideoDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewVideoMessage;
                break;
                
            case TLDescriptorTypeFileDescriptor:
            case TLDescriptorTypeNamedFileDescriptor:
                addNotification = YES;
                notificationType = TLNotificationTypeNewFileMessage;
                break;
                
            default:
                break;
        }
        if (addNotification) {
            [self createNotificationWithType:notificationType notificationId:[NSUUID alloc] subject:originator descriptorId:descriptor.descriptorId annotatingUser:nil];
        }
    }
}

- (void)onUpdateAnnotationWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor annotatingUser:(nonnull TLTwincodeOutbound *)annotatingUser {
    DDLogVerbose(@"%@ onUpdateAnnotationWithConversation: %@ descriptor: %@ annotatingUser: %@", LOG_TAG, conversation, descriptor, annotatingUser);
    
    if (!self.inBackground) {
        @synchronized(self) {
            if ([conversation isConversationWithUUID:self.activeConversationId]) {
                return;
            }
        }
    }
    
    id<TLRepositoryObject> subject = conversation.subject;
    if ([conversation isGroup] || ![annotatingUser.uuid isEqual:conversation.peerTwincodeOutboundId]) {
        [self getGroupMemberWithOwner:(id<TLOriginator>)subject memberTwincodeId:annotatingUser.uuid withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
            [self onUpdateAnnotationWithConversation:conversation descriptor:descriptor annotatingUser:annotatingUser errorCode:errorCode receiver:groupMember];
        }];
    } else {
        [self onUpdateAnnotationWithConversation:conversation descriptor:descriptor annotatingUser:annotatingUser errorCode:TLBaseServiceErrorCodeSuccess receiver:subject];
    }
}

- (void)onUpdateAnnotationWithConversation:(id <TLConversation>)conversation descriptor:(TLDescriptor *)descriptor annotatingUser:(nonnull TLTwincodeOutbound *)annotatingUser errorCode:(TLBaseServiceErrorCode)errorCode receiver:(id)receiver {
    DDLogVerbose(@"%@ onUpdateAnnotationWithConversation: %@ descriptor: %@ annotatingUser: %@ errorCode: %d receiver: %@", LOG_TAG, conversation, descriptor, annotatingUser, errorCode, receiver);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !receiver) {
        return;
    }
    
    id<TLOriginator> originator;
    if ([receiver class] == [TLContact class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else if ([receiver class] == [TLGroup class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else if ([receiver class] == [TLGroupMember class]) {
        originator = (id<TLOriginator>)receiver;
        
    } else {
        [self assertionWithAssertPoint:[TLTwinmeAssertPoint ON_UPDATE_ANNOTATION], [TLAssertValue initWithSubject:receiver], nil];
        return;
    }
    
    if ([self isVisible:originator]) {
        [self.notificationCenter onUpdateAnnotationWithContact:originator conversationId:[conversation uuid] descriptor:descriptor annotatingUser:annotatingUser];
    } else {
        [self createNotificationWithType:TLNotificationTypeUpdatedAnnotation notificationId:[NSUUID alloc] subject:originator descriptorId:descriptor.descriptorId annotatingUser:annotatingUser];
    }
}

- (int64_t)newOperation:(int) operationId {
    DDLogVerbose(@"%@ newOperation: %d", LOG_TAG, operationId);
    
    int64_t requestId = [self newRequestId];
    @synchronized(self) {
        self.requestIds[[NSNumber numberWithLongLong:requestId]] = [NSNumber numberWithInt:operationId];
    }
    return requestId;
}

@end
