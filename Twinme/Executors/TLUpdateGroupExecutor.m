/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLAttributeNameValue.h>

#import "TLUpdateGroupExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLPairProtocol.h"
#import "TLSpace.h"
#import "TLGroup.h"
#import "TLCapabilities.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the SingleThreadExecutor provided by the twinlife library
// Executor and delegates are reachable (not eligible for garbage collection) between start() and stop() calls
//
// version: 1.6
//

static const int CREATE_GROUP_IMAGE = 1;
static const int CREATE_GROUP_IMAGE_DONE = 1 << 1;
static const int CREATE_MEMBER_IMAGE = 1 << 2;
static const int CREATE_MEMBER_IMAGE_DONE = 1 << 3;
static const int COPY_MEMBER_IMAGE = 1 << 4;
static const int COPY_MEMBER_IMAGE_DONE = 1 << 5;
static const int UPDATE_GROUP_TWINCODE_OUTBOUND = 1 << 6;
static const int UPDATE_GROUP_TWINCODE_OUTBOUND_DONE = 1 << 7;
static const int UPDATE_MEMBER_TWINCODE_OUTBOUND = 1 << 8;
static const int UPDATE_MEMBER_TWINCODE_OUTBOUND_DONE = 1 << 9;
static const int UPDATE_GROUP = 1 << 10;
static const int UPDATE_GROUP_DONE = 1 << 11;
static const int DELETE_OLD_GROUP_IMAGE = 1 << 12;
static const int DELETE_OLD_GROUP_IMAGE_DONE = 1 << 13;
static const int DELETE_OLD_MEMBER_IMAGE = 1 << 14;
static const int DELETE_OLD_MEMBER_IMAGE_DONE = 1 << 15;
static const int INVOKE_TWINCODE_OUTBOUND = 1 << 16;
static const int INVOKE_TWINCODE_OUTBOUND_DONE = 1 << 17;

//
// Interface: TLUpdateGroupExecutor ()
//

@interface TLUpdateGroupExecutor ()

@property (nonatomic, readonly, nonnull) TLGroup *group;
@property (nonatomic, readonly, nonnull) TLSpace *oldSpace;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nullable) NSString *groupName;
@property (nonatomic, readonly, nullable) NSString *groupDescription;
@property (nonatomic, readonly, nullable) UIImage *groupAvatar;
@property (nonatomic, readonly, nullable) UIImage *groupLargeAvatar;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *groupTwincodeOutbound;
@property (nonatomic, readonly, nullable) NSString *profileName;
@property (nonatomic, readonly, nullable) UIImage *profileAvatar;
@property (nonatomic, readonly, nullable) UIImage *profileLargeAvatar;
@property (nonatomic, readonly, nullable) TLImageId *oldGroupAvatarId;
@property (nonatomic, readonly, nullable) TLImageId *oldMemberAvatarId;
@property (nonatomic, readonly, nullable) NSString *groupCapabilities;
@property (nonatomic, readonly) BOOL createGroupImage;
@property (nonatomic, readonly) BOOL createMemberImage;
@property (nonatomic, readonly, nullable) TLImageId *identityToCopyAvatarId;
@property (nonatomic, readonly) BOOL updatePrivateIdentity;
@property (nonatomic, readonly) BOOL updateGroupTwincode;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *memberTwincodeOutbound;

@property (nonatomic, nullable) TLExportedImageId *groupAvatarId;
@property (nonatomic, nullable) TLExportedImageId *memberAvatarId;
@property (nonatomic, nullable) NSMutableArray<TLTwincodeOutbound *> *refreshMembers;
@property (nonatomic, nullable) NSMutableArray<TLAttributeNameValue *> *refreshAttributes;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateGroupTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateMemberTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLUpdateGroupExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateGroupExecutor"

@implementation TLUpdateGroupExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name groupDescription:(nullable NSString *)groupDescription groupAvatar:(nullable UIImage *)groupAvatar groupLargeAvatar:(nullable UIImage *)groupLargeAvatar groupCapabilities:(nullable TLCapabilities *)groupCapabilities {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld group: %@ name: %@ groupAvatar: %@ groupLargeAvatar: %@", LOG_TAG, twinmeContext, requestId, group, name, groupAvatar, groupLargeAvatar);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _group = group;
        _groupName = name;
        
        _groupAvatar = groupAvatar;
        _groupDescription = groupDescription;
        _groupCapabilities = groupCapabilities ? groupCapabilities.attributeValue : nil;
        _groupLargeAvatar = groupLargeAvatar;
        _oldGroupAvatarId = group.groupAvatarId;
        _space = group.space;
        _oldSpace = _space;
        _identityToCopyAvatarId = nil;
        
        BOOL updateAvatar = groupAvatar != nil;
        BOOL updateGroupName = group.isOwner && name && ![name isEqualToString:group.groupPublicName];
        BOOL updateGroupDescription = ![groupDescription isEqualToString:group.objectDescription];
        BOOL updateGroupCapabilities = _groupCapabilities && ![_groupCapabilities isEqualToString:group.capabilities.attributeValue];

        _memberTwincodeOutbound = group.twincodeOutbound;
        _groupTwincodeOutbound = group.groupTwincodeOutbound;

        if ([group isOwner]) {
            _updateGroupTwincode = updateAvatar | updateGroupName | updateGroupDescription | updateGroupCapabilities;
        } else {
            group.objectDescription = groupDescription;
            group.name = name;
            _updateGroupTwincode = NO;
        }
        
        _createGroupImage = groupLargeAvatar != nil;
        _createMemberImage = NO;
        _updatePrivateIdentity = NO;
    }
    return self;
}
- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group name:(nonnull NSString *)name profileAvatar:(nullable UIImage *)profileAvatar profileLargeAvatar:(nullable UIImage *)profileLargeAvatar {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld group: %@ name: %@ profileAvatar: %@ profileLargeAvatar: %@", LOG_TAG, twinmeContext, requestId, group, name, profileAvatar, profileLargeAvatar);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _group = group;
        _profileAvatar = profileAvatar;
        _profileLargeAvatar = profileLargeAvatar;
        _memberAvatarId = nil;
        _oldMemberAvatarId = group.identityAvatarId;
        _space = group.space;
        _oldSpace = _space;
        _memberTwincodeOutbound = group.twincodeOutbound;
        _groupTwincodeOutbound = group.groupTwincodeOutbound;
        _identityToCopyAvatarId = nil;

        BOOL updateName = name && ![name isEqualToString:group.identityName];
        if (updateName) {
            _profileName = name;
        } else {
            _profileName = nil;
        }
        _createMemberImage = profileLargeAvatar != nil;
        _createGroupImage = NO;
        _updatePrivateIdentity = _createMemberImage || updateName;
        _updateGroupTwincode = NO;
    }
    return self;
}

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld group: %@ space: %@", LOG_TAG, twinmeContext, requestId, group, space);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];

    if (self) {
        _group = group;
        _oldSpace = group.space;
        _space = space;
        group.space = space;
        _groupName = group.name;
        _oldGroupAvatarId = nil;
        _groupTwincodeOutbound = nil;
        _createGroupImage = false;
        _createMemberImage = false;
        _identityToCopyAvatarId = nil;
        _updatePrivateIdentity = NO;
        _updateGroupTwincode = NO;
        // We are moving group to another space, we can start immediately.
        self.needOnline = NO;
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId group:(nonnull TLGroup *)group identityName:(nonnull NSString *)identityName identityAvatarId:(nullable TLImageId *)identityAvatarId identityDescription:(nullable NSString *)identityDescription timeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ requestId: %lld group: %@ identityName: %@ identityAvatarId: %@ identityDescription: %@", LOG_TAG, twinmeContext, requestId, group, identityName, identityAvatarId, identityDescription);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:timeout];

    if (self) {
        _group = group;
        _profileAvatar = nil;
        _profileLargeAvatar = nil;
        _memberAvatarId = nil;
        _oldMemberAvatarId = group.identityAvatarId;
        _space = group.space;
        _oldSpace = _space;
        _memberTwincodeOutbound = group.twincodeOutbound;
        _groupTwincodeOutbound = group.groupTwincodeOutbound;
        _identityToCopyAvatarId = identityAvatarId;

        _createMemberImage = identityAvatarId != nil;
        _createGroupImage = NO;

        BOOL updateName = identityName && ![identityName isEqualToString:group.identityName];
        if (updateName) {
            _profileName = identityName;
        } else {
            _profileName = nil;
        }
        _updatePrivateIdentity = _createMemberImage || updateName;
        _updateGroupTwincode = NO;
        // No need to update the group object
        self.state = UPDATE_GROUP | UPDATE_GROUP_DONE;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CREATE_GROUP_IMAGE) != 0 && (self.state & CREATE_GROUP_IMAGE_DONE) == 0) {
            self.state &= ~CREATE_GROUP_IMAGE;
        }
        if ((self.state & CREATE_MEMBER_IMAGE) != 0 && (self.state & CREATE_MEMBER_IMAGE_DONE) == 0) {
            self.state &= ~CREATE_MEMBER_IMAGE;
        }
        if ((self.state & COPY_MEMBER_IMAGE) != 0 && (self.state & COPY_MEMBER_IMAGE_DONE) == 0) {
            self.state &= ~COPY_MEMBER_IMAGE;
        }
        if ((self.state & UPDATE_GROUP_TWINCODE_OUTBOUND) != 0 && (self.state & UPDATE_GROUP_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~UPDATE_GROUP_TWINCODE_OUTBOUND;
        }
        if ((self.state & UPDATE_MEMBER_TWINCODE_OUTBOUND) != 0 && (self.state & UPDATE_MEMBER_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~UPDATE_MEMBER_TWINCODE_OUTBOUND;
        }
        if ((self.state & DELETE_OLD_GROUP_IMAGE) != 0 && (self.state & DELETE_OLD_GROUP_IMAGE_DONE) == 0) {
            self.state &= ~DELETE_OLD_GROUP_IMAGE;
        }
        if ((self.state & DELETE_OLD_MEMBER_IMAGE) != 0 && (self.state & DELETE_OLD_MEMBER_IMAGE_DONE) == 0) {
            self.state &= ~DELETE_OLD_MEMBER_IMAGE;
        }
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) != 0 && (self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~INVOKE_TWINCODE_OUTBOUND;
        }
    }
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }

    //
    // Step 1: a new group image must be setup, create it.
    //
    if (self.groupAvatar && self.createGroupImage) {
    
        if ((self.state & CREATE_GROUP_IMAGE) == 0) {
            self.state |= CREATE_GROUP_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService createImageWithImage:self.groupLargeAvatar thumbnail:self.groupAvatar withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateGroupImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_GROUP_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 1: a new group image must be setup, create it.
    //
    if (self.profileAvatar && self.createMemberImage) {
    
        if ((self.state & CREATE_MEMBER_IMAGE) == 0) {
            self.state |= CREATE_MEMBER_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService createImageWithImage:self.profileLargeAvatar thumbnail:self.profileAvatar withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateMemberImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_MEMBER_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 1: a new image must be setup, create it.
    //
    if (self.identityToCopyAvatarId && self.createMemberImage) {
    
        if ((self.state & COPY_MEMBER_IMAGE) == 0) {
            self.state |= COPY_MEMBER_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService copyImageWithImageId:self.identityToCopyAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCopyMemberImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & COPY_MEMBER_IMAGE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 1: update the group name and avatar if we are the group owner.
    //
    if (self.groupTwincodeOutbound && self.updateGroupTwincode) {
    
        if ((self.state & UPDATE_GROUP_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_GROUP_TWINCODE_OUTBOUND;

            NSMutableArray *attributes = [NSMutableArray array];
            NSMutableArray *deleteAttributes = [NSMutableArray array];
            if (self.groupName && ![self.groupName isEqualToString:self.group.groupPublicName]) {
                [TLTwinmeAttributes setTwincodeAttributeName:attributes name:self.groupName];
            }
            if (self.groupAvatarId && self.groupAvatarId != self.group.groupAvatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:attributes imageId:self.groupAvatarId];
            }
            if (![self.groupDescription isEqualToString:self.group.objectDescription]) {
                if (self.groupDescription) {
                    [TLTwinmeAttributes setTwincodeAttributeDescription:attributes description:self.groupDescription];
                } else {
                    [deleteAttributes addObject:TWINCODE_ATTRIBUTE_DESCRIPTION];
                }
            }
            if (self.groupCapabilities && ![self.groupCapabilities isEqualToString:self.group.capabilities.attributeValue]){
                [TLTwinmeAttributes setTwincodeAttributeCapabilities:attributes capabilities:self.groupCapabilities];
            }
            DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.groupTwincodeOutbound, attributes);
            [[self.twinmeContext getTwincodeOutboundService] updateTwincodeWithTwincode:self.groupTwincodeOutbound attributes:attributes deleteAttributeNames:deleteAttributes withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onUpdateGroupTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_GROUP_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }

    //
    // Step 2: update the member's profile name and avatar.
    //
    if (self.updatePrivateIdentity) {
    
        if ((self.state & UPDATE_MEMBER_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_MEMBER_TWINCODE_OUTBOUND;

            NSMutableArray *attributes = [NSMutableArray array];
            if (self.profileName) {
                [TLTwinmeAttributes setTwincodeAttributeName:attributes name:self.profileName];
            }
            if (self.memberAvatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:attributes imageId:self.memberAvatarId];
            }
            DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.memberTwincodeOutbound, attributes);
            [[self.twinmeContext getTwincodeOutboundService] updateTwincodeWithTwincode:self.memberTwincodeOutbound attributes:attributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onUpdateMemberTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_MEMBER_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 3: update the group object in the repository.
    //
    
    if ((self.state & UPDATE_GROUP) == 0) {
        self.state |= UPDATE_GROUP;

        DDLogVerbose(@"%@ updateObjectWithObject: %@", LOG_TAG, self.group);
        [[self.twinmeContext getRepositoryService] updateObjectWithObject:self.group localOnly:NO withBlock:^(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> object) {
            [self onUpdateObject:object errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & UPDATE_GROUP_DONE) == 0) {
        return;
    }

    //
    // Invoke the group members to notify them about the change.
    //
    if (self.refreshMembers && self.refreshAttributes && self.memberTwincodeOutbound && self.refreshMembers.count > 0) {
        if ((self.state & INVOKE_TWINCODE_OUTBOUND) == 0) {
            self.state |= INVOKE_TWINCODE_OUTBOUND;
            
            TLTwincodeOutbound *peerTwincode = self.refreshMembers[0];
            [[self.twinmeContext getTwincodeOutboundService] secureInvokeTwincodeWithTwincode:self.memberTwincodeOutbound senderTwincode:self.memberTwincodeOutbound receiverTwincode:peerTwincode options:TLInvokeTwincodeWakeup action:[TLPairProtocol ACTION_PAIR_REFRESH] attributes:self.refreshAttributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
                [self onInvokeTwincode:invocationId errorCode:errorCode];
            }];
            return;
        }

        if ((self.state & INVOKE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
    }

    //
    // Step 4: delete the old avatar image..
    //
    if (self.oldGroupAvatarId && self.createGroupImage) {
    
        if ((self.state & DELETE_OLD_GROUP_IMAGE) == 0) {
            self.state |= DELETE_OLD_GROUP_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.oldGroupAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                [self onDeleteGroupImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & DELETE_OLD_GROUP_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 4: delete the old avatar image..
    //
    if (self.oldMemberAvatarId && self.createMemberImage) {
    
        if ((self.state & DELETE_OLD_MEMBER_IMAGE) == 0) {
            self.state |= DELETE_OLD_MEMBER_IMAGE;

            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.oldMemberAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                [self onDeleteMemberImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & DELETE_OLD_MEMBER_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    if (self.space != self.oldSpace) {
        [self.twinmeContext onMoveToSpaceWithRequestId:self.requestId group:self.group oldSpace:self.oldSpace];
    } else {
        [self.twinmeContext onUpdateGroupWithRequestId:self.requestId group:self.group];
    }
    [self stop];
}

- (void)onCreateGroupImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateGroupImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_GROUP_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_GROUP_IMAGE_DONE;
    
    self.groupAvatarId = imageId;
    [self onOperation];
}

- (void)onCreateMemberImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateMemberImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_MEMBER_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_MEMBER_IMAGE_DONE;
    
    self.memberAvatarId = imageId;
    [self onOperation];
}

- (void)onUpdateObject:(nullable id<TLRepositoryObject>)object errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateObject: %@ errorCode: %d", LOG_TAG, object, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !object) {
        [self onErrorWithOperationId:UPDATE_GROUP errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_GROUP_DONE;
    [self onOperation];
}

- (void)onCopyMemberImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCopyMemberImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:COPY_MEMBER_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= COPY_MEMBER_IMAGE_DONE;
    
    self.memberAvatarId = imageId;
    [self onOperation];
}

- (void)onUpdateGroupTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateGroupTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_GROUP_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_GROUP_TWINCODE_OUTBOUND_DONE;
    
    [self.group setPeerTwincodeOutbound:twincodeOutbound];
    if (self.groupName) {
        self.group.name = self.groupName;
    }
    [self refreshMembersWithTwincode:twincodeOutbound];
    [self onOperation];
}

- (void)onUpdateMemberTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateMemberTwincodeOutbound: %@ errorCode: %d", LOG_TAG, twincodeOutbound, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_GROUP_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state |= UPDATE_MEMBER_TWINCODE_OUTBOUND_DONE;
    [self.group setTwincodeOutbound:twincodeOutbound];
    [self refreshMembersWithTwincode:twincodeOutbound];
    [self onOperation];
}

- (void)refreshMembersWithTwincode:(nonnull TLTwincodeOutbound *)updatedTwincode {
    DDLogVerbose(@"%@ refreshMembersWithTwincode: %@", LOG_TAG, updatedTwincode);
    
    if (!self.groupTwincodeOutbound) {
        return;
    }

    id<TLGroupConversation> groupConversation = [[self.twinmeContext getConversationService] getGroupConversationWithGroupTwincodeId:self.groupTwincodeOutbound.uuid];
    if (!groupConversation) {
        return;
    }
    if (!self.refreshMembers) {
        self.refreshMembers = [[NSMutableArray alloc] init];
    }
    if (!self.refreshAttributes) {
        self.refreshAttributes = [[NSMutableArray alloc] init];
    }
    [self.refreshAttributes addObject:[[TLAttributeNameStringValue alloc] initWithName:PAIR_PROTOCOL_PARAM_TWINCODE_OUTBOUND_ID stringValue:[updatedTwincode.uuid UUIDString]]];
    NSArray<id<TLGroupMemberConversation>> *members = [groupConversation groupMembersWithFilter:TLGroupMemberFilterTypeJoinedMembers];
    for (id<TLGroupMemberConversation> groupMember in members) {
        TLTwincodeOutbound *peerTwincodeOutbound = groupMember.peerTwincodeOutbound;
        if (peerTwincodeOutbound && [peerTwincodeOutbound isSigned]) {
            [self.refreshMembers addObject:peerTwincodeOutbound];
        }
    }
}

- (void)onInvokeTwincode:(nullable NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onInvokeTwincode: %@ errorCode: %d", LOG_TAG, invocationId, errorCode);

    if (errorCode != TLBaseServiceErrorCodeSuccess || !invocationId) {
        [self onErrorWithOperationId:INVOKE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }

    self.state &= ~(INVOKE_TWINCODE_OUTBOUND | INVOKE_TWINCODE_OUTBOUND_DONE);
    
    if (self.refreshMembers.count > 0) {
        [self.refreshMembers removeObjectAtIndex:0];
    }
    [self onOperation];
}

- (void)onDeleteGroupImage:(nullable TLImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteGroupImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);

    // Ignore the error and proceed!!!
    self.state |= DELETE_OLD_GROUP_IMAGE_DONE;
    [self onOperation];
}

- (void)onDeleteMemberImage:(nullable TLImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteMemberImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);

    // Ignore the error and proceed!!!
    self.state |= DELETE_OLD_MEMBER_IMAGE_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound && operationId == INVOKE_TWINCODE_OUTBOUND) {
        if (self.refreshMembers.count > 0) {
            [self.refreshMembers removeObjectAtIndex:0];
        }
        self.state &= ~(INVOKE_TWINCODE_OUTBOUND | INVOKE_TWINCODE_OUTBOUND_DONE);
        [self onOperation];
        return;
    }

    // Wait for reconnection
    if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
        self.restarted = YES;
        return;
    }

    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
