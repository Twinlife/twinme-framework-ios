/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Julien Poumarat (Julien.Poumarat@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLRepositoryService.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLImageService.h>
#import <Twinlife/TLFilter.h>

#import "TLAbstractTwinmeExecutor.h"
#import "TLUpdateProfileExecutor.h"
#import "TLUpdateContactAndIdentityExecutor.h"
#import "TLUpdateGroupExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLTwinmeAttributes.h"
#import "TLProfile.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLSpace.h"
#import "TLCapabilities.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.12
//

static const int CREATE_IMAGE = 1 << 0;
static const int CREATE_IMAGE_DONE = 1 << 1;
static const int UPDATE_TWINCODE_OUTBOUND = 1 << 2;
static const int UPDATE_TWINCODE_OUTBOUND_DONE = 1 << 3;
static const int GET_CONTACTS = 1 << 4;
static const int GET_CONTACTS_DONE = 1 << 5;
static const int GET_GROUPS = 1 << 6;
static const int GET_GROUPS_DONE = 1 << 7;
static const int UPDATE_CONTACT = 1 << 8;
static const int UPDATE_CONTACT_DONE = 1 << 9;
static const int UPDATE_GROUP = 1 << 10;
static const int UPDATE_GROUP_DONE = 1 << 11;
static const int DELETE_OLD_IMAGE = 1 << 12;
static const int DELETE_OLD_IMAGE_DONE = 1 << 13;

//
// Interface: TLUpdateProfileExecutor ()
//

@interface TLUpdateProfileExecutor ()

@property (nonatomic, readonly, nonnull) TLProfile *profile;
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly, nonnull) UIImage *avatar;
@property (nonatomic, readonly, nullable) UIImage *largeAvatar;
@property (nonatomic, readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (nonatomic, readonly) BOOL updateIdentity;
@property (nonatomic, readonly) BOOL updateDescription;
@property (nonatomic, readonly) BOOL updateName;
@property (nonatomic, readonly) BOOL createImage;
@property (nonatomic, readonly, nullable) NSString *profileDescription;
@property (nonatomic, readonly, nullable) NSString *capabilities;
@property (nonatomic, readonly, nonnull) NSString *oldName;
@property (nonatomic, readonly, nonnull) NSString *oldDescription;
@property (nonatomic, readonly) TLProfileUpdateMode updateMode;
@property (nonatomic, readonly, nonnull) TLSpace *space;
@property (nonatomic, readonly, nullable) TLImageId *oldAvatarId;

@property (nonatomic, nullable) TLExportedImageId *avatarId;
@property (nonatomic, nullable) NSMutableArray<TLContact *> *contacts;
@property (nonatomic, nullable) NSMutableArray<TLGroup *> *groups;
@property (nonatomic, nullable) NSMutableDictionary<TLImageId *, TLImageId *> *imageMap;

- (void)onTwinlifeOnline;

- (void)onOperation;

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onUpdateContactWithRequestId:(const int64_t)requestId contact:(nonnull TLContact *)contact;

- (void)onUpdateGroupWithRequestId:(const int64_t)requestId group:(nonnull TLGroup *)group;

@end

//
// Implementation: TLUpdateProfileExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLUpdateProfileExecutor"

@implementation TLUpdateProfileExecutor

- (instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext requestId:(int64_t)requestId profile:(nonnull TLProfile *)profile updateMode:(TLProfileUpdateMode)updateMode name:(nonnull NSString *)name avatar:(nonnull UIImage *)avatar largeAvatar:(nullable UIImage *)largeAvatar description:(nullable NSString *)description capabilities:(nullable TLCapabilities*)capabilities {
    
    self = [super initWithTwinmeContext:twinmeContext requestId:requestId timeout:DEFAULT_TIMEOUT];
    
    if (self) {
        _profile = profile;
        _space = profile.space;
        _oldName = profile.name;
        _oldDescription = profile.objectDescription ? profile.objectDescription : @"";
        _updateMode = updateMode;
        _avatar = avatar;
        _largeAvatar = largeAvatar;
        _oldAvatarId = profile.avatarId;
        _twincodeOutbound = profile.twincodeOutbound;
        _createImage = largeAvatar != nil;
        
        TL_ASSERT_NOT_NULL(twinmeContext, _profile, [TLExecutorAssertPoint PARAMETER], nil);

        NSString *capValue = [capabilities attributeValue];
        _updateDescription = ![description isEqual:_oldDescription];
        BOOL updateCapabilities = ![capValue isEqual:[profile.identityCapabilities attributeValue]];
        _updateName = ![name isEqual:_oldName];
        _updateIdentity = _updateName || _updateDescription || updateCapabilities || _createImage;
        
        _name = _updateName ? name : nil;
        _profileDescription = _updateDescription ? description : nil;
        _capabilities = updateCapabilities ? capValue : nil;
        if (updateMode == TLProfileUpdateModeNone) {
            self.state |= GET_CONTACTS | GET_CONTACTS_DONE | GET_GROUPS | GET_GROUPS_DONE
            | UPDATE_CONTACT | UPDATE_CONTACT_DONE | UPDATE_GROUP | UPDATE_GROUP_DONE;
        }
    }
    return self;
}

#pragma mark - Private methods

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    if (self.restarted) {
        if ((self.state & CREATE_IMAGE) != 0 && (self.state & CREATE_IMAGE_DONE) == 0) {
            self.state &= ~CREATE_IMAGE;
        }
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) != 0 && (self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            self.state &= ~UPDATE_TWINCODE_OUTBOUND;
        }
        if ((self.state & DELETE_OLD_IMAGE) != 0 && (self.state & DELETE_OLD_IMAGE_DONE) == 0) {
            self.state &= ~DELETE_OLD_IMAGE;
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
    // Step 1: a new image must be setup, create it.
    //
    if (self.avatar && self.createImage) {
        
        if ((self.state & CREATE_IMAGE) == 0) {
            self.state |= CREATE_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService createImageWithImage:self.largeAvatar thumbnail:self.avatar withBlock:^(TLBaseServiceErrorCode errorCode, TLExportedImageId *imageId) {
                [self onCreateImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & CREATE_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Step 2: update the name and avatar.
    //
    if (self.updateIdentity) {
        
        if ((self.state & UPDATE_TWINCODE_OUTBOUND) == 0) {
            self.state |= UPDATE_TWINCODE_OUTBOUND;
            
            TL_ASSERT_NOT_NULL(self.twinmeContext, self.twincodeOutbound, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);

            NSMutableArray *attributes = [NSMutableArray array];
            if (self.name) {
                [TLTwinmeAttributes setTwincodeAttributeName:attributes name:self.name];
            }
            if (self.avatarId) {
                [TLTwinmeAttributes setTwincodeAttributeImageId:attributes imageId:self.avatarId];
            }
            if (self.profileDescription) {
                [TLTwinmeAttributes setTwincodeAttributeDescription:attributes description:self.profileDescription];
            }
            if (self.capabilities) {
                [TLTwinmeAttributes setTwincodeAttributeCapabilities:attributes capabilities:self.capabilities];
            }
            
            DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ attributes: %@", LOG_TAG, self.twincodeOutbound, attributes);
            [[self.twinmeContext getTwincodeOutboundService] updateTwincodeWithTwincode:self.twincodeOutbound attributes:attributes deleteAttributeNames:nil withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
                [self onUpdateTwincodeOutbound:twincodeOutbound errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & UPDATE_TWINCODE_OUTBOUND_DONE) == 0) {
            return;
        }
        
        // Get the list of contacts for which we must propagate the identity change.
        if ((self.state & GET_CONTACTS) == 0) {
            self.state |= GET_CONTACTS;
            
            self.imageMap = [[self.twinmeContext getImageService] listCopiedImages];
            TLFilter *contactFilter = [self.twinmeContext createSpaceFilter];
            contactFilter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLContact *contact = (TLContact *)object;
                
                // Don't update revoked contacts.
                if (![contact hasPeer]) {
                    return false;
                }
                if (self.updateMode == TLProfileUpdateModeAll) {
                    return true;
                }
                // Don't update if name or description are different.
                if (self.updateName && ![self.oldName isEqual:contact.identityName]) {
                    return false;
                }
                if (self.updateDescription && ![self.oldDescription isEqual:contact.identityDescription]) {
                    return false;
                }
                TLImageId *contactIdentityAvatarId = contact.identityAvatarId;
                if (!self.avatarId || !contactIdentityAvatarId || !self.imageMap) {
                    // Profile image is not changed but name and description must be propagated.
                    return true;
                }
                // Update if contact avatar matches current profile avatar or previous profile avatar if it was changed.
                contactIdentityAvatarId = self.imageMap[contactIdentityAvatarId];
                return [self.avatarId isEqual:contactIdentityAvatarId] || (self.oldAvatarId && [self.oldAvatarId isEqual:contactIdentityAvatarId]);
            };
            [self.twinmeContext findContactsWithFilter:contactFilter withBlock:^(NSMutableArray<TLContact *> *contacts) {
                [self onListWithContacts:contacts];
            }];
            // Continue to get the groups.
        }
        if ((self.state & GET_GROUPS) == 0) {
            self.state |= GET_GROUPS;
            
            TLFilter *groupFilter = [self.twinmeContext createSpaceFilter];
            groupFilter.acceptWithObject = ^BOOL(id<TLDatabaseObject> object) {
                TLGroup *group = (TLGroup *)object;
                
                // Don't update a group if we are leaving or it is being deleted.
                if ([group isLeaving] || [group isDeleted]) {
                    return false;
                }
                if (self.updateMode == TLProfileUpdateModeAll) {
                    return true;
                }
                // Don't update if name or description are different.
                if (self.updateName && ![self.oldName isEqual:group.identityName]) {
                    return false;
                }
                TLImageId *groupIdentityAvatarId = group.identityAvatarId;
                if (!self.avatarId || !groupIdentityAvatarId || !self.imageMap) {
                    // Profile image is not changed but name and description must be propagated.
                    return true;
                }
                groupIdentityAvatarId = self.imageMap[groupIdentityAvatarId];
                // Update if contact avatar matches current profile avatar or previous profile avatar if it was changed.
                return [self.avatarId isEqual:groupIdentityAvatarId] || (self.oldAvatarId && [self.oldAvatarId isEqual:groupIdentityAvatarId]);
            };
            [self.twinmeContext findGroupsWithFilter:groupFilter withBlock:^(NSMutableArray<TLGroup *> *groups) {
                [self onListWithGroups:groups];
            }];
            return;
        }
        if ((self.state & GET_CONTACTS_DONE) == 0) {
            return;
        }
        if ((self.state & GET_GROUPS_DONE) == 0) {
            return;
        }
        
        // Propagate the name, description and image if it was created on the contact's identity.
        if (self.contacts) {
            if ((self.state & UPDATE_CONTACT) == 0) {
                self.state |= UPDATE_CONTACT;
                
                // If the contact's image does not match the profile, update it from the profile avatar id.
                TLContact *contact = self.contacts[0];
                TLImageId *contactIdentityAvatarId = contact.identityAvatarId;
                TLImageId *updateAvatarId;
                if (!contactIdentityAvatarId || !self.imageMap
                    || (self.avatarId && ![self.avatarId isEqual:self.imageMap[contactIdentityAvatarId]])) {
                    updateAvatarId = self.avatarId;
                } else {
                    updateAvatarId = nil;
                }
                
                int64_t requestId = [self newOperation:UPDATE_CONTACT];
                TLUpdateContactAndIdentityExecutor *updateContactAndIdentityExecutor = [[TLUpdateContactAndIdentityExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:requestId contact:contact identityName:self.updateName ? self.name : contact.identityName identityAvatarId:updateAvatarId identityDescription:self.updateDescription ? self.profileDescription : contact.identityDescription capabilities:[contact identityCapabilities] timeout:DBL_MAX];
                [updateContactAndIdentityExecutor start];
                return;
            }
            if ((self.state & UPDATE_CONTACT_DONE) == 0) {
                return;
            }
        }
        if (self.groups) {
            if ((self.state & UPDATE_GROUP) == 0) {
                self.state |= UPDATE_GROUP;
                
                // If the contact's image does not match the profile, update it from the profile avatar id.
                TLGroup *group = self.groups[0];
                TLImageId *groupIdentityAvatarId = group.identityAvatarId;
                TLImageId *updateAvatarId;
                if (!groupIdentityAvatarId || !self.imageMap
                    || (self.avatarId && ![self.avatarId isEqual:self.imageMap[groupIdentityAvatarId]])) {
                    updateAvatarId = self.avatarId;
                } else {
                    updateAvatarId = nil;
                }
                
                int64_t requestId = [self newOperation:UPDATE_GROUP];
                TLUpdateGroupExecutor *updateGroupExecutor = [[TLUpdateGroupExecutor alloc] initWithTwinmeContext:self.twinmeContext requestId:requestId group:group identityName:self.updateName ? self.name : group.identityName identityAvatarId:updateAvatarId identityDescription:self.profileDescription timeout:DBL_MAX];
                [updateGroupExecutor start];
                return;
            }
            if ((self.state & UPDATE_CONTACT_DONE) == 0) {
                return;
            }
        }
    }
    
    //
    // Step 3: delete the old avatar image..
    //
    if (self.oldAvatarId && self.createImage) {
        
        if ((self.state & DELETE_OLD_IMAGE) == 0) {
            self.state |= DELETE_OLD_IMAGE;
            
            TLImageService *imageService = [self.twinmeContext getImageService];
            [imageService deleteImageWithImageId:self.oldAvatarId withBlock:^(TLBaseServiceErrorCode errorCode, TLImageId *imageId) {
                [self onDeleteImage:imageId errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & DELETE_OLD_IMAGE_DONE) == 0) {
            return;
        }
    }
    
    //
    // Last Step
    //
    
    TL_ASSERT_NOT_NULL(self.twinmeContext, self.profile, [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:2], nil);

    [self.twinmeContext onUpdateProfileWithRequestId:self.requestId profile:self.profile];
    [self stop];
}

- (void)onCreateImage:(nullable TLExportedImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onCreateImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !imageId) {
        [self onErrorWithOperationId:CREATE_IMAGE errorCode:errorCode errorParameter:nil];
        return;
    }
    self.state |= CREATE_IMAGE_DONE;
    
    self.avatarId = imageId;
    [self onOperation];
}

- (void)onUpdateTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onUpdateTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);
    
    if (errorCode != TLBaseServiceErrorCodeSuccess || !twincodeOutbound) {
        [self onErrorWithOperationId:UPDATE_TWINCODE_OUTBOUND errorCode:errorCode errorParameter:nil];
        return;
    }
    
    self.state |= UPDATE_TWINCODE_OUTBOUND_DONE;
    self.profile.twincodeOutbound = twincodeOutbound;
    [self onOperation];
}

- (void)onListWithContacts:(nonnull NSMutableArray<TLContact *> *)list {
    DDLogVerbose(@"%@ onListWithContacts: %@", LOG_TAG, list);
    
    self.state |= GET_CONTACTS_DONE;
    if (list.count > 0) {
        self.contacts = list;
    } else {
        self.state |= UPDATE_CONTACT | UPDATE_CONTACT_DONE;
    }
    [self onOperation];
}

- (void)onListWithGroups:(nonnull NSMutableArray<TLGroup *> *)list {
    DDLogVerbose(@"%@ onListWithGroups: %@", LOG_TAG, list);
    
    self.state |= GET_GROUPS_DONE;
    if (list.count > 0) {
        self.groups = list;
    } else {
        self.state |= UPDATE_GROUP | UPDATE_GROUP_DONE;
    }
    [self onOperation];
}

- (void)onUpdateContactWithRequestId:(const int64_t)requestId contact:(nonnull TLContact *)contact {
    DDLogVerbose(@"%@ onUpdateContactWithRequestId: %lld contact: %@", LOG_TAG, requestId, contact);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        self.state |= UPDATE_CONTACT_DONE;
        [self.contacts removeObject:contact];
        if (self.contacts.count > 0) {
            self.state &= ~(UPDATE_CONTACT | UPDATE_CONTACT_DONE);
        }
        [self onOperation];
    }
}

- (void)onUpdateGroupWithRequestId:(const int64_t)requestId group:(nonnull TLGroup *)group {
    DDLogVerbose(@"%@ onUpdateGroupWithRequestId: %lld group: %@", LOG_TAG, requestId, group);
    
    int operationId = [self getOperationWithRequestId:requestId];
    if (operationId) {
        self.state |= UPDATE_GROUP_DONE;
        [self.groups removeObject:group];
        if (self.groups.count > 0) {
            self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
        }
        [self onOperation];
    }
}

- (void)onDeleteImage:(nullable TLImageId *)imageId errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onDeleteImage: %@ errorCode: %d", LOG_TAG, imageId, errorCode);
    
    // Ignore the error and proceed!!!
    self.state |= DELETE_OLD_IMAGE_DONE;
    [self onOperation];
}

- (void)onErrorWithOperationId:(int)operationId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter {
    DDLogVerbose(@"%@ onErrorWithOperationId: %d errorCode: %d", LOG_TAG, operationId, errorCode);

    if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
        switch (operationId) {
            case UPDATE_CONTACT:
                self.state |= UPDATE_CONTACT_DONE;
                if (self.contacts) {
                    [self.contacts removeObjectAtIndex:0];
                    if (self.contacts.count > 0) {
                        self.state &= ~(UPDATE_CONTACT | UPDATE_CONTACT_DONE);
                    }
                }
                [self onOperation];
                return;

            case UPDATE_GROUP:
                self.state |= UPDATE_GROUP_DONE;
                if (self.groups) {
                    [self.groups removeObjectAtIndex:0];
                    if (self.groups.count > 0) {
                        self.state &= ~(UPDATE_GROUP | UPDATE_GROUP_DONE);
                    }
                }
                [self onOperation];
                return;

            default:
                break;
        }
    }
    [super onErrorWithOperationId:operationId errorCode:errorCode errorParameter:errorParameter];
}

@end
