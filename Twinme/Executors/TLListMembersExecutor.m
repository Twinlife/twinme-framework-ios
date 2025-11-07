/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLTwincodeOutboundService.h>
#import <Twinlife/TLConversationService.h>

#import "TLListMembersExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLGroup.h"
#import "TLGroupMember.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.1
//

static const int LIST_MEMBERS = 1 << 0;
static const int FETCH_MEMBERS = 1 << 1;
static const int GET_GROUP_MEMBER = 1 << 2;
static const int GET_GROUP_MEMBER_DONE = 1 << 3;

//
// Interface(): TLListMembersExecutor
//

@interface TLListMembersExecutor ()

@property (nonatomic, readonly, nonnull) id<TLOriginator> subject;
@property (nonatomic, readonly) TLGroupMemberFilterType filter;
@property (nonatomic, readonly, nonnull) NSMutableArray<TLGroupMember *> *members;
@property (nonatomic, readonly, nonnull) NSMutableArray<NSUUID *> *unknownMembers;
@property (nonatomic, readonly, nonnull) NSMutableArray<NSUUID *> *memberTwincodes;
@property (nonatomic, readonly, nonnull) void (^onListGroupMember) (TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *groupMember);

- (void)onOperation;

- (void)onGetGroupMember:(nullable TLGroupMember *)groupMember errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Implementation: TLListMembersExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLListMembersExecutor"

@implementation TLListMembersExecutor

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext group:(nonnull TLGroup *)group filter:(TLGroupMemberFilterType)filter withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ group: %@ filter: %d", LOG_TAG, twinmeContext, group, filter);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:0];
    
    if (self) {
        _subject = group;
        _filter = filter;
        _onListGroupMember = block;
        _members = [[NSMutableArray alloc] init];
        _unknownMembers = [[NSMutableArray alloc] init];
        _memberTwincodes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext owner:(nonnull id<TLOriginator>)owner memberTwincodeList:(nonnull NSMutableArray *)memberTwincodeList withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> * _Nullable list))block {
    DDLogVerbose(@"%@ initWithTwinmeContext: %@ owner: %@ memberTwincodeList: %@", LOG_TAG, twinmeContext, owner, memberTwincodeList);
    
    self = [super initWithTwinmeContext:twinmeContext requestId:0];
    
    if (self) {
        _subject = owner;
        _memberTwincodes = memberTwincodeList;
        _onListGroupMember = block;
        _members = [[NSMutableArray alloc] init];
        _unknownMembers = [[NSMutableArray alloc] init];
        self.state = LIST_MEMBERS;
    }
    return self;
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Step 1: get the list of group member conversations.
    //
    if ((self.state & LIST_MEMBERS) == 0) {
        self.state |= LIST_MEMBERS;

        id<TLConversation> conversation = [[self.twinmeContext getConversationService] getConversationWithSubject:self.subject];
        if (!conversation) {
            self.onListGroupMember(TLBaseServiceErrorCodeItemNotFound, nil);
            [self stop];
            return;
        }

        NSMutableArray<id<TLGroupMemberConversation>> *memberConversations = [((id<TLGroupConversation>)conversation) groupMembersWithFilter:self.filter];
        for (id<TLGroupMemberConversation> memberConversation in memberConversations) {
            [self.memberTwincodes addObject:[memberConversation peerTwincodeOutboundId]];
        }
    }
    
    //
    // Step 2: look in the twinme context cache to get the members associated with the list of twincodes.
    // Fill up the group members which are already known and get a list of unknown members.
    //
    if ((self.state & FETCH_MEMBERS) == 0) {
        self.state |= FETCH_MEMBERS;

        [self.twinmeContext fetchExistingMembersWithOwner:self.subject members:self.memberTwincodes knownMembers:self.members unknownMembers:self.unknownMembers];
    }

    //
    // Step 3: get the group member for the first unknown member until the list becomes empty.
    //
    if (self.unknownMembers.count > 0) {
        if ((self.state & GET_GROUP_MEMBER) == 0) {
            self.state |= GET_GROUP_MEMBER;

            [self.twinmeContext getGroupMemberWithOwner:self.subject memberTwincodeId:[self.unknownMembers objectAtIndex:0] withBlock:^(TLBaseServiceErrorCode errorCode, TLGroupMember *groupMember) {
                [self onGetGroupMember:groupMember errorCode:errorCode];
            }];
            return;
        }
        if ((self.state & GET_GROUP_MEMBER_DONE) == 0) {
            return;
        }
    }

    //
    // Last Step
    //
    self.onListGroupMember(TLBaseServiceErrorCodeSuccess, self.members);

    [self stop];
}

- (void)onGetGroupMember:(nullable TLGroupMember *)groupMember errorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogVerbose(@"%@ onGetGroupMember: %@ errorCode: %d", LOG_TAG, groupMember, errorCode);
    
    if (errorCode == TLBaseServiceErrorCodeSuccess && groupMember) {
        [self.members addObject:groupMember];
    }

    if (self.unknownMembers.count > 0) {
        [self.unknownMembers removeObjectAtIndex:0];
        self.state &= ~GET_GROUP_MEMBER;
    } else {
        self.state |= GET_GROUP_MEMBER_DONE;
    }
    
    [self onOperation];
}

@end
