/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLFilter.h>

#import "TLDeleteSpaceExecutor.h"
#import "TLDeleteProfileExecutor.h"
#import "TLDeleteContactExecutor.h"
#import "TLDeleteGroupExecutor.h"
#import "TLDeleteInvitationExecutor.h"
#import "TLGroup.h"
#import "TLSpace.h"
#import "TLContact.h"
#import "TLProfile.h"
#import "TLInvitation.h"
#import "TLCallReceiver.h"
#import "TLTwinmeContextImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.4
//

static const int GET_CONTACTS = 1 << 0;
static const int GET_CONTACTS_DONE = 1 << 1;
static const int GET_GROUPS = 1 << 2;
static const int GET_GROUPS_DONE = 1 << 3;
static const int DELETE_CONTACT = 1 << 4;
static const int DELETE_CONTACTS_DONE = 1 << 5;
static const int DELETE_GROUP = 1 << 6;
static const int DELETE_GROUPS_DONE = 1 << 7;
static const int GET_INVITATIONS = 1 << 8;
static const int GET_INVITATIONS_DONE = 1 << 9;
static const int DELETE_INVITATION = 1 << 10;
static const int DELETE_INVITATIONS_DONE = 1 << 11;
static const int GET_CALL_RECEIVERS = 1 << 12;
static const int GET_CALL_RECEIVERS_DONE = 1 << 13;
static const int DELETE_CALL_RECEIVER = 1 << 14;
static const int DELETE_CALL_RECEIVERS_DONE = 1 << 15;
static const int DELETE_PROFILE = 1 << 16;
static const int DELETE_PROFILE_DONE = 1 << 17;
static const int DELETE_SPACE_IMAGE = 1 << 18;
static const int DELETE_SPACE_IMAGE_DONE = 1 << 19;
static const int DELETE_SPACE_SETTINGS = 1 << 20;
static const int DELETE_SPACE_SETTINGS_DONE = 1 << 21;
static const int DELETE_SPACE = 1 << 22;
static const int DELETE_SPACE_DONE = 1 << 23;

//
// Interface(): TLDeleteSpaceExecutor
//

@interface TLDeleteSpaceExecutor()

@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nullable) TLSpaceSettings *spaceSettings;
@property (nonatomic, readonly, nullable) NSUUID *spaceAvatarId;
@property (nonatomic, readonly, nonnull) NSMutableArray<NSUUID*> *invitationIds;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSUUID*> *toDeleteContacts;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSUUID*> *toDeleteGroups;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSUUID*> *toDeleteCallReceivers;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSUUID*> *toDeleteInvitations;
@property (nonatomic, readonly, nonnull) TLFilter *filter;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onListContacts:(nullable NSArray<id<TLRepositoryObject>> *)contacts errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onListGroups:(nullable NSArray<id<TLRepositoryObject>> *)groups errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onListInvitations:(nullable NSArray<id<TLRepositoryObject>> *)invitations errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId;

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(nonnull NSUUID *)groupId;

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(nonnull NSUUID *)invitationId;

- (void)onDeleteProfileWithRequestId:(const int64_t)requestId profileId:(nonnull NSUUID *)profileId;

- (void)onDeleteSettingsObject:(nullable NSUUID *)objectId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onDeleteSpaceObject:(nullable NSUUID *)objectId errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter;

@end

//
// Implementation: TLDeleteSpaceExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteSpaceExecutor"

@implementation TLDeleteSpaceExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId space:(nonnull TLSpace *)space {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ requestId: %lld space: %@", LOG_TAG, twinmeContext, requestId, space);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _space = space;
        _spaceSettings = space.settings;
        if (_spaceSettings) {
            _spaceAvatarId = _spaceSettings.avatarId;
        } else {
            _spaceAvatarId = nil;
        }
        _invitationIds = [[NSMutableArray alloc] init];
        _toDeleteContacts = [[NSMutableSet alloc] init];
        _toDeleteGroups = [[NSMutableSet alloc] init];
        _toDeleteInvitations = [[NSMutableSet alloc] init];
        _toDeleteCallReceivers = [[NSMutableSet alloc] init];
        _filter = [TLFilter alloc];
        _filter.owner = space;
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    self.state = 0;
    [super onTwinlifeOnline];
}

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: get the contacts from the space.
    //
    
    if ((self.state & GET_CONTACTS) == 0) {
        self.state |= GET_CONTACTS;

        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLContact SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLContact FACTORY] filter:self.filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListContacts:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_CONTACTS_DONE) == 0) {
        return;
    }
    
    //
    // Step 2: get the groups from the space.
    //
    
    if ((self.state & GET_GROUPS) == 0) {
        self.state |= GET_GROUPS;
        
        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLGroup SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLGroup FACTORY] filter:self.filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListGroups:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_GROUPS_DONE) == 0) {
        return;
    }
    
    //
    // Step 3: get all invitation ids from the repository (we don't want TwinmeContext filter on the level).
    //
    
    if ((self.state & GET_INVITATIONS) == 0) {
        self.state |= GET_INVITATIONS;

        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLInvitation SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLInvitation FACTORY] filter:self.filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListInvitations:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_INVITATIONS_DONE) == 0) {
        return;
    }
    
    //
    // Step 4: get all invitation ids from the repository (we don't want TwinmeContext filter on the level).
    //
    
    if ((self.state & GET_CALL_RECEIVERS) == 0) {
        self.state |= GET_CALL_RECEIVERS;

        DDLogVerbose(@"%@ listObjectsWithFactory: %@", LOG_TAG, [TLCallReceiver SCHEMA_ID]);
        [[self.twinmeContext getRepositoryService] listObjectsWithFactory:[TLCallReceiver FACTORY] filter:self.filter withBlock:^(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *list) {
            [self onListCallReceivers:list errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & GET_CALL_RECEIVERS_DONE) == 0) {
        return;
    }

    //
    // Step 5: wait fo all contacts and groups to be deleted.
    //
    if (self.toDeleteContacts.count > 0) {
        return;
    }
    if (self.toDeleteGroups.count > 0) {
        return;
    }
    if (self.toDeleteInvitations.count > 0) {
        return;
    }
    if (self.toDeleteCallReceivers.count > 0) {
        return;
    }

    //
    // Step 6: delete the profile
    //
    TLProfile *profile = self.space.profile;
    if (profile) {
    
        if ((self.state & DELETE_PROFILE) == 0) {
            self.state |= DELETE_PROFILE;
        
            int64_t requestId = [self newOperation:DELETE_PROFILE];
            DDLogVerbose(@"%@ deleteProfileWithRequestId: %lld profile: %@", LOG_TAG, requestId, profile);
            [self.twinmeContext deleteProfileWithRequestId:requestId profile:profile];
            return;
        }
        if ((self.state & DELETE_PROFILE_DONE) == 0) {
            return;
        }
    }

    //
    // Step 7: delete the space settings object.
    //
    if (self.spaceSettings) {
        
        //
        // Step 7a: delete the old space image when it was replaced by a new one.
        //
        if (self.spaceAvatarId) {
        
            if ((self.state & DELETE_SPACE_IMAGE) == 0) {
                self.state |= DELETE_SPACE_IMAGE;

                TLImageService *imageService = [self.twinmeContext getImageService];
                TLExportedImageId *exportedImageId = [imageService imageWithPublicId:self.spaceAvatarId];
                if (exportedImageId) {
                    [imageService deleteImageWithImageId:exportedImageId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                        self.state |= DELETE_SPACE_IMAGE_DONE;
                        [self onOperation];
                    }];
                    return;
                }
                self.state |= DELETE_SPACE_IMAGE_DONE;
            }
            if ((self.state & DELETE_SPACE_IMAGE_DONE) == 0) {
                return;
            }
        }

        if ((self.state & DELETE_SPACE_SETTINGS) == 0) {
            self.state |= DELETE_SPACE_SETTINGS;
        
            DDLogVerbose(@"%@ deleteObjectWithObject: %@ schemaId: %@", LOG_TAG, self.space.settings.uuid, [TLSpaceSettings SCHEMA_ID]);
            [[self.twinmeContext getRepositoryService] deleteObjectWithObject:self.spaceSettings withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *objectId) {
                [self onDeleteSettingsObject:objectId errorCode:errorCode];
            }];
            return;
        }
    }
    
    //
    // Step 8: delete the space object.
    //
    if ((self.state & DELETE_SPACE) == 0) {
        self.state |= DELETE_SPACE;
        
        DDLogVerbose(@"%@ deleteObjectWithObject: %@", LOG_TAG, self.space.uuid);
        [[self.twinmeContext getRepositoryService] deleteObjectWithObject:self.space withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *objectId) {
            [self onDeleteSpaceObject:objectId errorCode:errorCode];
        }];
        return;
    }
    if ((self.state & DELETE_SPACE_DONE) == 0) {
        return;
    }

    //
    // Last Step
    //
    
    [self.twinmeContext onDeleteSpaceWithRequestId:self.requestId spaceId:self.space.uuid];
    [self stop];
}

- (void)onListContacts:(nullable NSArray<id<TLRepositoryObject>> *)contacts errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListContacts: %@", LOG_TAG, contacts);

    self.state |= GET_CONTACTS_DONE;

    for (id<TLRepositoryObject> object in contacts) {
        TLContact *contact = (TLContact *)object;
        if ([self.space isOwner:contact]) {
            int64_t requestId = [self newOperation:DELETE_CONTACT];
            [self.toDeleteContacts addObject:contact.uuid];
            
            DDLogVerbose(@"%@ deleteContact: %lld contact: %@", LOG_TAG, requestId, contact);
            TLDeleteContactExecutor *deleteContactExecutor = [[TLDeleteContactExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:requestId contact:contact invocationId:nil timeout:DBL_MAX];
            [deleteContactExecutor start];
        }
    }
    [self onOperation];
}

- (void)onDeleteContactWithRequestId:(int64_t)requestId contactId:(nonnull NSUUID *)contactId {
    DDLogVerbose(@"%@ onDeleteContactWithRequestId: %lld contactId: %@", LOG_TAG, requestId, contactId);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self.toDeleteContacts removeObject:contactId];
        if (self.toDeleteContacts.count == 0) {
            self.state |= DELETE_CONTACTS_DONE;
        }
        [self onOperation];
    }
}

- (void)onListGroups:(nullable NSArray<id<TLRepositoryObject>> *)groups errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListGroups %@ errorCode: %d", LOG_TAG, groups, errorCode);

    self.state |= GET_GROUPS_DONE;
    
    for (id<TLRepositoryObject> object in groups) {
        TLGroup *group = (TLGroup *)object;
        if ([self.space isOwner:group]) {
            int64_t requestId = [self newOperation:DELETE_GROUP];
            [self.toDeleteGroups addObject:group.uuid];
            
            DDLogVerbose(@"%@ deleteGroup: %lld group: %@", LOG_TAG, requestId, group);
            TLDeleteGroupExecutor *deleteGroupExecutor = [[TLDeleteGroupExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:requestId group:group timeout:DBL_MAX];
            [deleteGroupExecutor start];
        }
    }
    [self onOperation];
}

- (void)onDeleteGroupWithRequestId:(int64_t)requestId groupId:(nonnull NSUUID *)groupId {
    DDLogVerbose(@"%@ onDeleteGroupWithRequestId: %lld groupId: %@", LOG_TAG, requestId, groupId);

    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self.toDeleteGroups removeObject:groupId];
        if (self.toDeleteGroups.count == 0) {
            self.state |= DELETE_GROUPS_DONE;
        }
        [self onOperation];
    }
}

- (void)onListInvitations:(nullable NSArray<id<TLRepositoryObject>> *)objects errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListInvitations %@ errorCode: %d", LOG_TAG, objects, errorCode);

    self.state |= GET_INVITATIONS_DONE;
    
    for (id<TLRepositoryObject> object in objects) {
        TLInvitation *invitation = (TLInvitation *)object;
        if (self.space == invitation.space) {
            int64_t requestId = [self newOperation:DELETE_INVITATION];
            [self.toDeleteInvitations addObject:invitation.uuid];
            
            DDLogVerbose(@"%@ deleteInvitationWithRequestId: %lld invitation: %@", LOG_TAG, requestId, invitation);
            TLDeleteInvitationExecutor *deleteInvitationExecutor = [[TLDeleteInvitationExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:requestId invitation:invitation timeout:DBL_MAX];
            [deleteInvitationExecutor start];
        }
    }
    [self onOperation];
}

- (void)onDeleteInvitationWithRequestId:(int64_t)requestId invitationId:(nonnull NSUUID *)invitationId {
    DDLogVerbose(@"%@ onDeleteInvitationWithRequestId: %lld invitationId: %@", LOG_TAG, requestId, invitationId);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self.toDeleteInvitations removeObject:invitationId];
        if (self.toDeleteInvitations.count == 0) {
            self.state |= DELETE_INVITATIONS_DONE;
        }
        [self onOperation];
    }
}

- (void)onListCallReceivers:(nullable NSArray<id<TLRepositoryObject>> *)callReceivers errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onListCallReceivers %@ errorCode: %d", LOG_TAG, callReceivers, errorCode);

    self.state |= GET_CALL_RECEIVERS_DONE;
    
    for (id<TLRepositoryObject> object in callReceivers) {
        TLCallReceiver *callReceiver = (TLCallReceiver *)object;
        if ([self.space isOwner:callReceiver]) {
            int64_t requestId = [self newOperation:DELETE_CALL_RECEIVER];
            [self.toDeleteCallReceivers addObject:callReceiver.uuid];
            
            DDLogVerbose(@"%@ deleteCallReceiverWithRequestId: %lld callReceiver: %@", LOG_TAG, requestId, callReceiver);
            [self.twinmeContext deleteCallReceiverWithRequestId:requestId callReceiver:callReceiver];
        }
    }
    [self onOperation];
}

- (void)onDeleteCallReceiverWithRequestId:(int64_t)requestId callReceiverId:(nonnull NSUUID *)callReceiverId {
    DDLogVerbose(@"%@ onDeleteCallReceiverWithRequestId: %lld callReceiverId: %@", LOG_TAG, requestId, callReceiverId);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        [self.toDeleteCallReceivers removeObject:callReceiverId];
        if (self.toDeleteCallReceivers.count == 0) {
            self.state |= DELETE_CALL_RECEIVERS_DONE;
        }
        [self onOperation];
    }
}

- (void)onDeleteProfileWithRequestId:(const int64_t)requestId profileId:(nonnull NSUUID *)profileId {
    DDLogVerbose(@"%@ onDeleteProfileWithRequestId: %lld profileId: %@", LOG_TAG, requestId, profileId);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        self.state |= DELETE_PROFILE_DONE;
        self.space.profile = nil;
        [self onOperation];
    }
}

- (void)onDeleteSettingsObject:(nullable NSUUID *)objectId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteSettingsObject %@ objectId", LOG_TAG, objectId);
    
    self.state |= DELETE_SPACE_SETTINGS_DONE;
    [self onOperation];
}

- (void)onDeleteSpaceObject:(nullable NSUUID *)objectId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteObject %@ objectId", LOG_TAG, objectId);
    
    self.state |= DELETE_SPACE_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d errorParameter: %@", LOG_TAG, operationId, errorCode, errorParameter);

    // The delete operation succeeds if we get an item not found error.
    if (errorCode == TLBaseServiceErrorCodeItemNotFound && errorParameter) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:errorParameter];
        
        switch (operationId) {
            case DELETE_CONTACT:
                if (uuid) {
                    [self.toDeleteContacts removeObject:uuid];
                    if (self.toDeleteContacts.count == 0) {
                        self.state |= DELETE_CONTACTS_DONE;
                    }
                }
                return;
                
            case DELETE_GROUP:
                if (uuid) {
                    [self.toDeleteGroups removeObject:uuid];
                    if (self.toDeleteGroups.count == 0) {
                        self.state |= DELETE_GROUPS_DONE;
                    }
                }
                return;
                
            case DELETE_INVITATION:
                if (uuid) {
                    [self.toDeleteInvitations removeObject:uuid];
                    if (self.toDeleteInvitations.count == 0) {
                        self.state |= DELETE_INVITATIONS_DONE;
                    }
                }
                return;
                
            case DELETE_CALL_RECEIVER:
                if (uuid) {
                    [self.toDeleteCallReceivers removeObject:uuid];
                    if (self.toDeleteCallReceivers.count == 0) {
                        self.state |= DELETE_CALL_RECEIVERS_DONE;
                    }
                }
                return;

            case DELETE_PROFILE:
                if (uuid) {
                    self.state |= DELETE_PROFILE_DONE;
                    self.space.profile = nil;
                }
                return;

            case DELETE_SPACE_SETTINGS:
                if (uuid) {
                    self.state |= DELETE_SPACE_SETTINGS_DONE;
                }
                return;

            case DELETE_SPACE:
                if (uuid) {
                    self.state |= DELETE_SPACE_DONE;
                }
                return;

            default:
                break;
        }
    }
    
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end

