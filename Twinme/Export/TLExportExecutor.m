/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <Twinlife/TLTwinlife.h>
#import <Twinlife/TLFilter.h>

#import "TLExportExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLGroupMember.h"
#import "TLSpace.h"
#import "TLExporter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Executor and delegates are running in the twinlife serial queue provided by the twinlife library
// Executor and delegates are retained between start() and stop() calls
//
// version: 1.2
//

static const int GET_SPACES = 1 << 0;
static const int GET_SPACES_DONE = 1 << 1;
static const int GET_CONVERSATIONS = 1 << 2;
static const int GET_CONTACTS = 1 << 3;
static const int GET_CONTACTS_DONE = 1 << 4;
static const int GET_GROUPS = 1 << 5;
static const int GET_GROUPS_DONE = 1 << 6;
static const int LIST_GROUP_MEMBER = 1 << 7;
static const int LIST_GROUP_MEMBER_DONE = 1 << 8;
static const int GET_GROUP_MEMBER = 1 << 9;
static const int GET_GROUP_MEMBER_DONE = 1 << 10;
static const int EXPORT_PHASE_1 = 1 << 11;
static const int EXPORT_PHASE_1_DONE = 1 << 12;
static const int EXPORT_PHASE_2 = 1 << 13;
static const int EXPORT_PHASE_2_DONE = 1 << 14;

//
// Interface: TLExportExecutorGroupMemberQuery ()
//

@interface TLExportExecutorGroupMemberQuery : NSObject

@property (nonatomic, readonly, nonnull) id<TLOriginator> group;
@property (nonatomic, readonly, nonnull) NSUUID *memberTwincodeOutboundId;

- (nonnull instancetype) initWithGroup:(nonnull id<TLOriginator>)group memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId;

@end

//
// Interface: TLExportExecutor ()
//

@interface TLExportExecutor ()

@property (nonatomic, readonly, nonnull) TLTwinmeContext *twinmeContext;
@property (nonatomic, weak, nullable) id<TLExportDelegate> delegate;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, NSMutableDictionary<NSUUID *, NSString *> *> *groupMembers;
@property (nonatomic, readonly, nonnull) NSMutableArray<TLExportExecutorGroupMemberQuery *> *groupMemberList;
@property (nonatomic, readonly) BOOL statAllDescriptors;

@property (nonatomic) int state;
@property (nonatomic) int work;
@property (nonatomic, readonly, nonnull) NSMutableDictionary *requestIds;
@property (nonatomic) BOOL restarted;
@property (nonatomic) BOOL stopped;
@property (nonatomic) BOOL addSpacePrefix;
@property (nonatomic, nullable) TLExporter *exporter;
@property (nonatomic, nullable) TLSpace *space;
@property (nonatomic, nullable) NSArray<TLContact *> *contacts;
@property (nonatomic, nullable) NSArray<TLGroup *> *groups;
@property (nonatomic, nullable) NSMutableArray<TLSpace *> *spaces;
@property (nonatomic, nullable) TLExportExecutorGroupMemberQuery *currentGroupMember;
@property (nonatomic) int groupIndex;
@property (nonatomic, nullable) NSString *path;
@property (nonatomic, nullable) NSString *password;
@property (nonatomic, nullable) TLFilter *filter;
@property (nonatomic) dispatch_queue_t exportQueue;

- (void)onOperation;

- (void)listGroupMembers;

@end

//
// Implementation: TLExportStats
//

#undef LOG_TAG
#define LOG_TAG @"TLExportStats"

@implementation TLExportStats

- (NSString *)description {
    
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];

    [result appendFormat:@"Stats:{conversationCount:%lld, ", self.conversationCount];
    [result appendFormat:@", totSize: %lld, msgCount: %lld", self.totalSize, self.msgCount];
    if (self.fileCount > 0) {
        [result appendFormat:@", fileCount: %lld, fileSize: %lld", self.fileCount, self.fileSize];
    }
    if (self.imageCount > 0) {
        [result appendFormat:@", imageCount: %lld, imageSize: %lld", self.imageCount, self.imageSize];
    }
    if (self.audioCount > 0) {
        [result appendFormat:@", audioCount: %lld, audioSize: %lld", self.audioCount, self.audioSize];
    }
    if (self.videoCount > 0) {
        [result appendFormat:@", videoCount: %lld, videoSize: %lld", self.videoCount, self.videoSize];
    }
    [result appendFormat:@"}"];
    return result;
}

@end

//
// Implementation: TLExportExecutorGroupMemberQuery
//

#undef LOG_TAG
#define LOG_TAG @"TLExportExecutorGroupMemberQuery"

@implementation TLExportExecutorGroupMemberQuery

- (nonnull instancetype) initWithGroup:(nonnull id<TLOriginator>)group memberTwincodeOutboundId:(nonnull NSUUID *)memberTwincodeOutboundId {
    DDLogVerbose(@"%@ initWithGroup: %@ memberTwincodeOutboundId: %@", LOG_TAG, group, memberTwincodeOutboundId);
    
    self = [super init];
    if (self) {
        _group = group;
        _memberTwincodeOutboundId = memberTwincodeOutboundId;
    }
    return self;
}

@end

//
// Implementation: TLExportExecutor
//

#undef LOG_TAG
#define LOG_TAG @"TLExportExecutor"

@implementation TLExportExecutor

+ (nonnull NSString *)exportWithName:(nonnull NSString *)name {

    return [name stringByReplacingOccurrencesOfString:@"[|\\\\?*<\":>/']" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, name.length)];
}

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<TLExportDelegate>)delegate statAllDescriptors:(BOOL)statAllDescriptors needConversations:(BOOL)needConversations {
    DDLogVerbose(@"%@ initWithTwinmeContext:%@ needConversations: %d", LOG_TAG, twinmeContext, needConversations);
    
    self = [super init];
    if (self) {
        _twinmeContext = twinmeContext;
        _delegate = delegate;

        const char *exportQueueName = "exportQueue";
        _exportQueue = dispatch_queue_create(exportQueueName, DISPATCH_QUEUE_SERIAL);
        _state = 0;
        _requestIds = [NSMutableDictionary dictionary];
        _restarted = NO;
        _stopped = NO;
        _addSpacePrefix = NO;
        _statAllDescriptors = statAllDescriptors;
        _dateFilter = LONG_MAX;
        _groupIndex = 0;
        _typeFilter = @[@(TLDescriptorTypeObjectDescriptor), @(TLDescriptorTypeImageDescriptor), @(TLDescriptorTypeAudioDescriptor), @(TLDescriptorTypeVideoDescriptor), @(TLDescriptorTypeNamedFileDescriptor)];
        _groupMemberList = [[NSMutableArray alloc] init];
        _groupMembers = [[NSMutableDictionary alloc] init];
        if (needConversations) {
            _work |= GET_CONVERSATIONS;
            _state |= GET_CONVERSATIONS;
            _conversations = [[NSMutableArray alloc] init];
        } else {
            _conversations = nil;
        }
    }
    return self;
}

- (void)prepareWithContacts:(nonnull NSArray<TLContact *> *)contacts {
    DDLogVerbose(@"%@ prepareWithContacts: %@", LOG_TAG, contacts);

    self.contacts = contacts;
    self.work |= LIST_GROUP_MEMBER | EXPORT_PHASE_1;
    self.state &= ~(EXPORT_PHASE_1 | EXPORT_PHASE_1_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE);
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        [self onOperation];
    });
}

- (void)prepareWithGroups:(nonnull NSArray<TLGroup *> *)groups {
    DDLogVerbose(@"%@ prepareWithGroups: %@", LOG_TAG, groups);

    self.groups = groups;
    self.work |= LIST_GROUP_MEMBER | EXPORT_PHASE_1;
    self.state &= ~(EXPORT_PHASE_1 | EXPORT_PHASE_1_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE);
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        [self onOperation];
    });
}

- (void)prepareWithSpace:(nonnull TLSpace *)space reset:(BOOL)reset {
    DDLogVerbose(@"%@ prepareWithSpace: %@ reset: %d", LOG_TAG, space, reset);

    self.space = space;
    self.filter = [TLFilter alloc];
    self.filter.owner = space;
    self.work |= GET_CONTACTS | GET_GROUPS | LIST_GROUP_MEMBER | EXPORT_PHASE_1;
    self.state &= ~(GET_CONVERSATIONS | GET_CONTACTS | GET_CONTACTS_DONE | GET_GROUPS | GET_GROUPS_DONE | LIST_GROUP_MEMBER | LIST_GROUP_MEMBER_DONE | GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE | EXPORT_PHASE_1 | EXPORT_PHASE_1_DONE);
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        if (reset) {
            self.contacts = nil;
            self.groups = nil;
            [self.conversations removeAllObjects];
        }
        [self onOperation];
    });
}

- (void)prepareAll {
    DDLogVerbose(@"%@ prepareAll", LOG_TAG);

    self.work |= GET_SPACES | EXPORT_PHASE_1;
    self.state &= ~(GET_CONVERSATIONS | GET_SPACES | GET_SPACES_DONE | GET_CONVERSATIONS | EXPORT_PHASE_1 | EXPORT_PHASE_1_DONE);
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        self.contacts = nil;
        self.groups = nil;
        self.spaces = nil;
        self.space = nil;
        self.filter = nil;
        [self.conversations removeAllObjects];
        [self onOperation];
    });
}

- (void)runExportWithPath:(nonnull NSString *)path password:(nullable NSString *)password {
    DDLogVerbose(@"%@ runExportWithPath: %@", LOG_TAG, path);

    self.path = path;
    self.password = password;
    self.work |= EXPORT_PHASE_2;
    self.state &= ~(EXPORT_PHASE_2 | EXPORT_PHASE_2_DONE);
    dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
        [self onOperation];
    });
}

- (void)dispose {

    self.delegate = nil;
}

#pragma mark - Private methods

- (void)onOperation {
    DDLogVerbose(@"%@ onOperation", LOG_TAG);
    
    if (self.stopped) {
        return;
    }
    
    //
    // Get the group members (each of them, one by one until we are done).
    //
    if (self.groups && self.groups.count > self.groupIndex) {
        if ((self.state & GET_GROUP_MEMBER) == 0) {
            self.state |= GET_GROUP_MEMBER;
            
            [self.twinmeContext listGroupMembersWithGroup:self.groups[self.groupIndex] filter:TLGroupMemberFilterTypeJoinedMembers withBlock:^(TLBaseServiceErrorCode errorCode, NSMutableArray<TLGroupMember *> *members) {
                TLGroup *group = self.groups[self.groupIndex];
                if (errorCode == TLBaseServiceErrorCodeSuccess && members) {
                    NSMutableDictionary<NSUUID *, NSString *> *list = self.groupMembers[group.uuid];
                    if (!list) {
                        list = [[NSMutableDictionary alloc] init];
                        [self.groupMembers setObject:list forKey:group.uuid];
                    }
                    for (TLGroupMember *member in members) {
                        [list setObject:member.name forKey:member.twincodeOutboundId];
                    }
                }
                self.groupIndex++;
                if (self.groupIndex >= self.groups.count) {
                    self.state |= GET_GROUP_MEMBER_DONE;
                } else {
                    self.state &= ~GET_GROUP_MEMBER;
                }
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_GROUP_MEMBER_DONE) == 0) {
            return;
        }
    }

    // Optional step: after getting the space, get the list of conversations.
    if ((self.work & GET_CONVERSATIONS) != 0 && self.conversations && self.filter) {
        if ((self.state & GET_CONVERSATIONS) == 0) {
            self.state |= GET_CONVERSATIONS;

            NSMutableArray<id<TLConversation>> *conversations = [[self.twinmeContext getConversationService] listConversationsWithFilter:self.filter];
            [self.conversations addObjectsFromArray:conversations];
        }
    }

    //
    // Optional step, get the list of contacts.
    //
    if ((self.work & GET_CONTACTS) != 0) {
        if ((self.state & GET_CONTACTS) == 0) {
            self.state |= GET_CONTACTS;

            [self.twinmeContext findContactsWithFilter:self.filter withBlock:^(NSMutableArray<TLContact *> *list) {
                if (self.contacts) {
                    [list addObjectsFromArray:self.contacts];
                }
                self.contacts = list;
                self.state |= GET_CONTACTS_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_CONTACTS_DONE) == 0) {
            return;
        }
    }
    
    //
    // Optional step, get the list of groups.
    //
    if ((self.work & GET_GROUPS) != 0) {
        if ((self.state & GET_GROUPS) == 0) {
            self.state |= GET_GROUPS;
        
            [self.twinmeContext findGroupsWithFilter:self.filter withBlock:^(NSMutableArray<TLGroup *> *groups) {
                if (self.groups) {
                    [groups addObjectsFromArray:self.groups];
                }
                self.groups = groups;
                self.state |= GET_GROUPS_DONE;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_GROUPS_DONE) == 0) {
            return;
        }
    }

    //
    // Optional step, get the list of group members.
    //
    if ((self.work & LIST_GROUP_MEMBER) != 0) {
        if ((self.state & LIST_GROUP_MEMBER) == 0) {
            self.state |= LIST_GROUP_MEMBER;

            [self listGroupMembers];
            [self onOperation];
            return;
        }
    }
    
    //
    // Optional step, get the list of spaces (excluding the secret spaces).
    //
    if ((self.work & GET_SPACES) != 0) {
        if ((self.state & GET_SPACES) == 0) {
            self.state |= GET_SPACES;
        
            [self.twinmeContext findSpacesWithPredicate:^BOOL(TLSpace *space) {
                return !space.settings.isSecret;

            } withBlock:^(NSMutableArray<TLSpace *> *spaces) {
                self.spaces = spaces;
                self.state |= GET_SPACES_DONE;
                self.addSpacePrefix = spaces != nil && spaces.count > 1;
                [self onOperation];
            }];
            return;
        }
        if ((self.state & GET_SPACES_DONE) == 0) {
            return;
        }
        if (self.spaces && self.spaces.count > 0) {
            TLSpace *space = [self.spaces lastObject];
            [self.spaces removeLastObject];
            [self prepareWithSpace:space reset:false];
            return;
        }
    }

    //
    // Phase 1: scan the conversation.
    //
    if ((self.work & EXPORT_PHASE_1) != 0) {
        if ((self.state & EXPORT_PHASE_1) == 0) {
            self.state |= EXPORT_PHASE_1;
            if (!self.exporter) {
                self.exporter = [[TLExporter alloc] initWithTwinmeContext:self.twinmeContext delegate:self.delegate dateFilter:self.dateFilter typeFilter:self.typeFilter statAllDescriptors:self.statAllDescriptors];
            }
            self.exporter.dateFilter = self.dateFilter;
            self.exporter.addSpacePrefix = self.addSpacePrefix;
            [self.exporter updateWithState:TLExportStateScanning];
            dispatch_async(self.exportQueue, ^{
                if (self.contacts) {
                    [self.exporter exportWithContacts:self.contacts members:self.groupMembers];
                }
                if (self.groups) {
                    [self.exporter exportWithGroups:self.groups members:self.groupMembers];
                }
                
                // Finish the step from the twinlife queue.
                dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
                    [self.exporter updateWithState:TLExportStateWait];
                    self.state |= EXPORT_PHASE_1_DONE;
                    [self onOperation];
                });
            });
        }
        if ((self.state & EXPORT_PHASE_1_DONE) == 0) {
            return;
        }
    }

    //
    // Phase 2: export the conversation.
    //
    if ((self.work & EXPORT_PHASE_2) != 0 && self.exporter) {
        if ((self.state & EXPORT_PHASE_2) == 0) {
            self.state |= EXPORT_PHASE_2;
            self.exporter.dateFilter = self.dateFilter;
            self.exporter.typeFilter = self.typeFilter;
            [self.exporter updateWithState:TLExportStateExporting];
            dispatch_async(self.exportQueue, ^{
                [self.exporter createZipWithPath:self.path password:self.password];
                if (self.contacts) {
                    [self.exporter exportWithContacts:self.contacts members:self.groupMembers];
                }
                if (self.groups) {
                    [self.exporter exportWithGroups:self.groups members:self.groupMembers];
                }
                [self.exporter closeZip];

                // Finish the step from the twinlife queue.
                dispatch_async(self.twinmeContext.twinlife.twinlifeQueue, ^{
                    [self.exporter updateWithState:TLExportStateDone];
                    self.state |= EXPORT_PHASE_2_DONE;
                    [self onOperation];
                });
            });
        }
        if ((self.state & EXPORT_PHASE_2_DONE) == 0) {
            return;
        }
    }
}

- (void)listGroupMembers {
    DDLogVerbose(@"%@ listGroupMembers", LOG_TAG);

    TLConversationService *conversationService = [self.twinmeContext getConversationService];

    if (self.contacts) {
        for (TLContact *contact in self.contacts) {
            if (![contact isTwinroom]) {
                continue;
            }
            
            id<TLConversation> conversation = [conversationService getConversationWithSubject:contact];
            if (!conversation) {
                continue;
            }
            
            NSSet<NSUUID *> *twincodes = [conversationService getConversationTwincodesWithSubject:contact beforeTimestamp:self.dateFilter];
            for (NSUUID *twincode in twincodes) {
                [self.groupMemberList addObject:[[TLExportExecutorGroupMemberQuery alloc] initWithGroup:contact memberTwincodeOutboundId:twincode]];
            }
        }
    }

    if (self.groups) {
        for (TLGroup *group in self.groups) {
            id<TLConversation> conversation = [conversationService getConversationWithSubject:group];
            if (!conversation || ![conversation conformsToProtocol:@protocol(TLGroupConversation)]) {
                continue;
            }
            id<TLGroupConversation> groupConversation = (id<TLGroupConversation>) conversation;
            
            NSArray<id<TLGroupMemberConversation>>* members = [groupConversation groupMembersWithFilter:TLGroupMemberFilterTypeJoinedMembers];
            for (id<TLGroupMemberConversation> member in members) {
                [self.groupMemberList addObject:[[TLExportExecutorGroupMemberQuery alloc] initWithGroup:group memberTwincodeOutboundId:member.peerTwincodeOutboundId]];
            }
        }
    }
    if (self.groupMemberList.count == 0) {
        self.state |= GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE;
    } else {
        self.state &= ~(GET_GROUP_MEMBER | GET_GROUP_MEMBER_DONE);
        self.currentGroupMember = [self.groupMemberList lastObject];
        [self.groupMemberList removeLastObject];
    }
}

@end
