/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>
#import <Twinlife/TLPeerConnectionService.h>

@class TLTwinmeContext;
@class TLContact;
@class TLAttributeNameValue;
@class TLAccountMigration;
@protocol TLOriginator;

@protocol TLNotificationCenter

- (void)onIncomingCallWithContact:(nonnull id<TLOriginator>)contact peerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer;

- (void)onIncomingMigrationWithAccountMigration:(nonnull TLAccountMigration *)accountMigration peerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onPopDescriptorWithContact:(nonnull id<TLOriginator>)contact conversationId:(nonnull NSUUID *)conversationId descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onJoinGroupWithGroup:(nonnull id<TLOriginator>)group conversationId:(nonnull NSUUID *)conversationId;

- (void)onUpdateDescriptorWithContact:(nonnull id<TLOriginator>)contact conversationId:(nonnull NSUUID *)conversationId descriptor:(nonnull TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType;

- (void)onUpdateAnnotationWithContact:(nonnull id<TLOriginator>)contact conversationId:(nonnull NSUUID *)conversationId descriptor:(nonnull TLDescriptor *)descriptor annotatingUser:(nonnull TLTwincodeOutbound *)annotatingUser;

- (void)onSetActiveConversationWithConversationId:(nonnull NSUUID *)conversationId;

- (void)onNewContactWithContact:(nonnull id<TLOriginator>)contact;

- (void)onUnbindContactWithContact:(nonnull id<TLOriginator>)contact;

- (void)onUpdateContactWithContact:(nonnull id<TLOriginator>)contact updatedAttributes:(nonnull NSArray<TLAttributeNameValue *> *)updatedAttributes;

- (void)updateApplicationBadgeNumber:(NSInteger)applicationBadgeNumber;

- (void)cancelWithNotificationId:(nonnull NSUUID *)notificationId;

@end
