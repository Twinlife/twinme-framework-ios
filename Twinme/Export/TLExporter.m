/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <SSZipArchive.h>
#import <zlib.h>

#import <Twinlife/TLTwinlife.h>

#import "TLExportExecutor.h"
#import "TLTwinmeContextImpl.h"
#import "TLMessage.h"
#import "TLContact.h"
#import "TLGroup.h"
#import "TLSpace.h"
#import "TLGroupMember.h"
#import "TLExporter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define MESSAGE_BUFFER_SIZE (64 * 1024)
#define TwinmeLocalizedString(key, comment) NSLocalizedString((key), (comment))

// List of descriptor types that can be exported.
static const TLDescriptorType EXPORT_TYPES[] = {
    TLDescriptorTypeFileDescriptor,
    TLDescriptorTypeImageDescriptor,
    TLDescriptorTypeAudioDescriptor,
    TLDescriptorTypeVideoDescriptor,
    TLDescriptorTypeNamedFileDescriptor,
    TLDescriptorTypeObjectDescriptor
};
static const int EXPORT_TYPES_COUNT = sizeof(EXPORT_TYPES) / sizeof(EXPORT_TYPES[0]);

@interface TLExportInfo : NSObject

@property (nonatomic, readonly) int64_t date;
@property (nonatomic, nonnull) NSString *text;

- (nonnull instancetype)initWithDate:(int64_t)date text:(nonnull NSString *)text;

@end

//
// Interface: TLExporter ()
//

@interface TLExporter ()

@property (nonatomic, weak, nullable) id<TLExportDelegate> delegate;
@property (nonatomic, readonly, nonnull) TLConversationService *conversationService;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID *, NSString *> *dirNames;
@property (nonatomic, readonly, nonnull) NSMutableSet<NSString *> *usedDirNames;
@property (nonatomic, readonly) BOOL statAllDescriptors;

@property (nonatomic, nonnull) TLExportStats *stats;
@property (nonatomic) TLExportState state;
@property (nonatomic) BOOL exportEnabled;
@property (nonatomic) BOOL dirCreated;
@property (nonatomic, nullable) NSString *dirName;
@property (nonatomic, nullable) SSZipArchive *zip;
@property (nonatomic, nullable) NSString *password;
@property (nonatomic, nullable) NSMutableArray<TLExportInfo *> *descriptors;

/**
 * Report an error message and put the exporter in error state.
 *
 * @param message the message to report.
 */
- (void)errorWithMessage:(nonnull NSString *)message;

/**
 * Build a name to associate with a twincode and make sure names are valid to build file and directory
 * names and that they are unique.  Special characters are removed and duplicate names have a counter
 * added at the end.
 *
 * @param name the name to add.
 * @param usedNames a set of names which are already used in the current directory.
 * @return the name to use (unique and with special characters removed).
 */
- (nonnull NSString *)buildNameWithName:(nonnull NSString *)name usedNames:(nonnull NSMutableSet<NSString *> *)usedNames;

- (nonnull NSString *)buildDirNameWithName:(nonnull NSString *)name usedNames:(nonnull NSMutableSet<NSString *> *)usedNames subject:(nonnull id<TLOriginator>)subject;

/**
 * Export the conversation associated with our identity twincode.
 *
 * @param name the directory base name to export this conversation.
 * @param subject the repository object for the conversation to export.
 * @param names a mapping of twincodes to local prefix names to be used for file export.
 * @param usedNames a set of names which are already used in the current directory.
 * @param members the group or twinroom members.
 */
- (void)exportWithName:(nonnull NSString *)name subject:(nonnull id<TLRepositoryObject>)subject names:(nonnull NSMutableDictionary<NSUUID *, NSString *> *)names usedNames:(nonnull NSMutableSet<NSString *> *)usedNames members:(nullable NSDictionary<NSUUID *, NSString *> *)members;

- (void)exportWithObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor senderName:(nonnull NSString *)senderName;

- (void)exportWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor path:(nonnull NSString *)path senderName:(nonnull NSString *)senderName thumbnail:(BOOL)thumbnail ext:(nonnull NSString *)ext;

- (void)exportWithImageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor senderName:(nonnull NSString *)senderName;

- (void)exportWithVideoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor senderName:(nonnull NSString *)senderName;

- (void)exportWithAudioDescriptor:(nonnull TLAudioDescriptor *)audioDescriptor senderName:(nonnull NSString *)senderName;

@end

//
// Implementation: TLExportInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLExportInfo"

@implementation TLExportInfo

- (nonnull instancetype)initWithDate:(int64_t)date text:(nonnull NSString *)text {
    
    self = [super init];
    if (self) {
        _date = date;
        _text = text;
    }
    return self;
}

@end

//
// Implementation: TLExporter
//

#undef LOG_TAG
#define LOG_TAG @"TLExporter"

@implementation TLExporter

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<TLExportDelegate>)delegate dateFilter:(int64_t)dateFilter typeFilter:(nullable NSArray<NSNumber *> *)typeFilter statAllDescriptors:(BOOL)statAllDescriptors {
    DDLogVerbose(@"%@ initWithTwinmeContext:: %@ dateFilter: %lld typeFilter: %@", LOG_TAG, twinmeContext, dateFilter, typeFilter);
    
    self = [super init];
    if (self) {
        _delegate = delegate;
        _conversationService = [twinmeContext getConversationService];
        _dirNames = [[NSMutableDictionary alloc] init];
        _usedDirNames = [[NSMutableSet alloc] init];
        _dateFilter = dateFilter;
        _statAllDescriptors = statAllDescriptors;
        if (typeFilter) {
            _typeFilter = typeFilter;
        } else {
            _typeFilter = @[@(TLDescriptorTypeImageDescriptor), @(TLDescriptorTypeAudioDescriptor), @(TLDescriptorTypeVideoDescriptor), @(TLDescriptorTypeNamedFileDescriptor)];
        }
        
        _state = TLExportStateReady;
        _exportEnabled = NO;
        _stats = [[TLExportStats alloc] init];
    }
    return self;
}

- (void)updateWithState:(TLExportState)state {
    DDLogVerbose(@"%@ updateWithState %d", LOG_TAG, state);
    
    if (state == TLExportStateScanning) {
        self.stats = [[TLExportStats alloc] init];
    }
    
    if (self.state != TLExportStateError) {
        self.state = state;
        [self.delegate onProgressWithState:state stats:self.stats];
    }
}

- (void)createZipWithPath:(nonnull NSString *)path password:(nullable NSString *)password {
    DDLogVerbose(@"%@ createZipWithPath: %@", LOG_TAG, path);
    
    if (self.zip) {
        [self.delegate onErrorWithMessage:@"a ZIP is opened"];
        return;
    }
    
    self.stats = [[TLExportStats alloc] init];
    self.exportEnabled = YES;
    
    self.zip = [[SSZipArchive alloc] initWithPath:path];
    BOOL success = [self.zip open];
    if (!success) {
        [self errorWithMessage:@"cannot create zip"];
        return;
    }
    self.password = password;
}

- (void)closeZip {
    DDLogVerbose(@"%@ closeZip", LOG_TAG);
    
    if (self.zip) {
        if (![self.zip close]) {
            [self errorWithMessage:@"closing zip with error"];
        }
        self.zip = nil;
    }
}

- (void)errorWithMessage:(nonnull NSString *)message {
    DDLogVerbose(@"%@ errorWithMessage: %@", LOG_TAG, message);
    DDLogError(@"%@ failed to save the ZIP export archive: %@", LOG_TAG, message);
    
    self.state = TLExportStateError;
    [self.delegate onErrorWithMessage:message];
    if (self.zip) {
        [self.zip close];
        self.zip = nil;
    }
}

- (void)exportWithContacts:(nonnull NSArray<TLContact *> *)contacts members:(nonnull NSDictionary<NSUUID *, NSDictionary<NSUUID *, NSString *> *> *)members {
    DDLogVerbose(@"%@ exportWithContacts %@ members: %@", LOG_TAG, contacts, members);
    
    for (TLContact *contact in contacts) {
        NSUUID *twincodeOutboundId = contact.twincodeOutboundId;
        NSString *identityName = contact.identityName;
        if (!twincodeOutboundId || !identityName) {
            continue;
        }
        
        NSUUID *peerTwincodeOutboundId = contact.peerTwincodeOutboundId;
        NSString *contactName = contact.name;
        if (!peerTwincodeOutboundId || !contactName) {
            continue;
        }
        
        if (!self.exportEnabled) {
            [self.dirNames setObject:[self buildDirNameWithName:contactName usedNames:self.usedDirNames subject:contact] forKey:peerTwincodeOutboundId];
        }
        
        // Export tree is:
        //  <contact-name>/<sender-name>_<sequence>.<ext>
        NSString *dirName = self.dirNames[peerTwincodeOutboundId];
        if (!dirName) {
            return;
        }
        
        NSMutableDictionary<NSUUID *, NSString *> *localNames = [[NSMutableDictionary alloc] init];
        NSMutableSet<NSString *> *usedNames = [[NSMutableSet alloc] init];
        NSDictionary<NSUUID *, NSString *> *roomMembers = members[contact.uuid];
        [localNames setObject:[self buildNameWithName:identityName usedNames:usedNames] forKey:twincodeOutboundId];
        [localNames setObject:[self buildNameWithName:contactName usedNames:usedNames] forKey:peerTwincodeOutboundId];
        [self exportWithName:dirName subject:contact names:localNames usedNames:usedNames members:roomMembers];
    }
}

- (void)exportWithGroups:(nonnull NSArray<TLGroup *> *)groups members:(nonnull NSDictionary<NSUUID *, NSDictionary<NSUUID *, NSString *> *> *)members {
    DDLogVerbose(@"%@ exportWithGroups %@ members: %@", LOG_TAG, groups, members);
    
    for (TLGroup *group in groups) {
        NSUUID *twincodeOutboundId = group.twincodeOutboundId;
        NSString *identityName = group.identityName;
        if (!twincodeOutboundId || !identityName) {
            continue;
        }
        
        NSUUID *groupId = group.uuid;
        NSString *groupName = group.name;
        if (!groupId || !groupName) {
            continue;
        }
        
        if (!self.exportEnabled) {
            [self.dirNames setObject:[self buildDirNameWithName:groupName usedNames:self.usedDirNames subject:group] forKey:groupId];
        }
        
        // Export tree is:
        //  <contact-name>/<sender-name>_<sequence>.<ext>
        NSString *dirName = self.dirNames[groupId];
        if (!dirName) {
            return;
        }
        
        NSMutableDictionary<NSUUID *, NSString *> *localNames = [[NSMutableDictionary alloc] init];
        NSMutableSet<NSString *> *usedNames = [[NSMutableSet alloc] init];
        NSDictionary<NSUUID *, NSString *> *groupMembers = members[groupId];
        [localNames setObject:[self buildNameWithName:identityName usedNames:usedNames] forKey:twincodeOutboundId];
        [self exportWithName:dirName subject:group names:localNames usedNames:usedNames members:groupMembers];
    }
}

#pragma mark - Private methods

- (nonnull NSString *)buildNameWithName:(nonnull NSString *)name usedNames:(nonnull NSMutableSet<NSString *> *)usedNames {
    DDLogVerbose(@"%@ buildNameWithName %@ name: %@", LOG_TAG, name, usedNames);
    
    name = [TLExportExecutor exportWithName:name];
    
    if ([usedNames containsObject:name]) {
        int count = 1;
        NSString *newString;
        do {
            newString = [NSString stringWithFormat:@"%@_%d", name, count];
            count++;
        } while ([usedNames containsObject:newString]);
        name = newString;
    }
    [usedNames addObject:name];
    return name;
}

- (nonnull NSString *)buildDirNameWithName:(nonnull NSString *)name usedNames:(nonnull NSMutableSet<NSString *> *)usedNames subject:(nonnull id<TLOriginator>)subject {
    DDLogVerbose(@"%@ buildDirNameWithName %@ name: %@ subject: %@", LOG_TAG, name, usedNames, subject);

    NSString *dirname = [self buildNameWithName:name usedNames:usedNames];
    if (self.addSpacePrefix) {
        TLSpace *space = subject.space;
        if (space) {
            dirname = [NSString stringWithFormat:@"%@/%@", [TLExportExecutor exportWithName:space.settings.name], dirname];
        }
    }
    return dirname;
}

- (BOOL)isValidDescriptorType:(nonnull NSNumber *)value {
    
    for (int i = 0; i < EXPORT_TYPES_COUNT; i++) {
        if (EXPORT_TYPES[i] == value.intValue) {
            return YES;
        }
    }
    return NO;
}

- (void)exportWithName:(nonnull NSString *)name subject:(nonnull id<TLRepositoryObject>)subject names:(nonnull NSMutableDictionary<NSUUID *, NSString *> *)names usedNames:(nonnull NSMutableSet<NSString *> *)usedNames members:(nullable NSDictionary<NSUUID *, NSString *> *)members {
    DDLogVerbose(@"%@ exportWithName %@ subject: %@ names: %@ usedNames: %@ members: %@", LOG_TAG, name, subject, names, usedNames, members);

    id<TLConversation> conversation = [self.conversationService getConversationWithSubject:subject];
    if (!conversation) {
        return;
    }
    NSUUID *twincodeOutboundId = conversation.twincodeOutboundId;

    if (members) {
        for (NSUUID *memberId in members) {
            NSString *name = members[memberId];
            if (name) {
                [names setObject:[self buildNameWithName:name usedNames:usedNames] forKey:memberId];
            }
        }
    }

    self.stats.conversationCount++;
    [self.delegate onProgressWithState:self.state stats:self.stats];

    self.dirCreated = NO;
    self.dirName = name;
    if (self.exportEnabled) {
        self.descriptors = [[NSMutableArray alloc] initWithCapacity:100];
    } else {
        self.descriptors = nil;
    }

    BOOL checkCopy = self.exportEnabled || !self.statAllDescriptors;
    for (NSNumber *type in self.typeFilter) {
        
        if (![self isValidDescriptorType:type]) {
            DDLogError(@"%@ invalid type %@", LOG_TAG, type);
            return;
        }

        TLDescriptorType t = type.intValue;
        int64_t beforeTimestamp = self.dateFilter;
        while (1) {
            NSArray<TLDescriptor *> *descriptors = [self.conversationService getDescriptorsWithConversation:conversation descriptorType:t callsMode:TLDisplayCallsModeAll beforeTimestamp:beforeTimestamp maxDescriptors:10];

            if (!descriptors || descriptors.count == 0) {
                break;
            }

            if (t == TLDescriptorTypeObjectDescriptor) {

                for (TLDescriptor *descriptor in descriptors) {
                    if (self.state == TLExportStateError) {
                        return;
                    }
                    
                    if (checkCopy && ([descriptor isExpired] || descriptor.deletedTimestamp > 0 || descriptor.expireTimeout > 0)) {
                        continue;
                    }

                    // Make sure we have a name for this descriptor.
                    NSUUID *twincodeId = descriptor.descriptorId.twincodeOutboundId;
                    NSString *senderName = names[twincodeId];
                    if (checkCopy && !senderName) {
                        continue;
                    }
                    
                    TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)descriptor;
                    if (checkCopy && (![objectDescriptor copyAllowed] && ![twincodeOutboundId isEqual:twincodeId])) {
                        continue;
                    }
                    
                    [self exportWithObjectDescriptor:objectDescriptor senderName:senderName];

                    // If the delegate disappeared, stop immediately.
                    if (!self.delegate) {
                        return;
                    }
                    [self.delegate onProgressWithState:self.state stats:self.stats];
                }

            } else {
                for (TLDescriptor *descriptor in descriptors) {
                    if (self.state == TLExportStateError) {
                        return;
                    }
                    
                    if (checkCopy && ([descriptor isExpired] || descriptor.deletedTimestamp > 0 || descriptor.expireTimeout > 0)) {
                        continue;
                    }

                    // Make sure we have a name for this descriptor.
                    NSUUID *twincodeId = descriptor.descriptorId.twincodeOutboundId;
                    NSString *senderName = names[twincodeId];
                    if (checkCopy && !senderName) {
                        continue;
                    }

                    // Don't export a descriptor that is protected against copies and we are not the owner.
                    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)descriptor;
                    if (checkCopy && (![fileDescriptor copyAllowed] && ![twincodeOutboundId isEqual:twincodeId])) {
                        continue;
                    }

                    if (checkCopy && ![fileDescriptor isAvailable]) {
                        continue;
                    }
                    switch (t) {
                        case TLDescriptorTypeImageDescriptor:
                            [self exportWithImageDescriptor:(TLImageDescriptor *)fileDescriptor senderName:senderName];
                            break;

                        case TLDescriptorTypeAudioDescriptor:
                            [self exportWithAudioDescriptor:(TLAudioDescriptor *)fileDescriptor senderName:senderName];
                            break;

                        case TLDescriptorTypeVideoDescriptor:
                            [self exportWithVideoDescriptor:(TLVideoDescriptor *)fileDescriptor senderName:senderName];
                            break;

                        case TLDescriptorTypeNamedFileDescriptor:
                            [self exportWithNameDescriptor:(TLNamedFileDescriptor *)fileDescriptor senderName:senderName];
                            break;

                        case TLDescriptorTypeFileDescriptor:
                            [self exportWithFileDescriptor:fileDescriptor path:[fileDescriptor getURL].path senderName:senderName thumbnail:NO ext:[fileDescriptor extension]];
                            break;

                        default:
                            break;
                    }

                    // If the delegate disappeared, stop immediately.
                    if (!self.delegate) {
                        return;
                    }
                    [self.delegate onProgressWithState:self.state stats:self.stats];
                }
            }

            beforeTimestamp = descriptors[descriptors.count - 1].createdTimestamp;
        }
    }

    if (self.descriptors) {
        [self exportMessages];
        self.descriptors = nil;
    }
}

- (void)exportWithObjectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor senderName:(nonnull NSString *)senderName {
    DDLogVerbose(@"%@ exportWithObjectDescriptor %@ senderName: %@", LOG_TAG, objectDescriptor, senderName);

    self.stats.msgCount++;
    if (self.exportEnabled) {
        NSString *message = objectDescriptor.message;

        [self.descriptors addObject:[[TLExportInfo alloc] initWithDate:objectDescriptor.createdTimestamp text:[NSString stringWithFormat:@"%@: %@", senderName, message]]];
    }
}

- (void)exportMessages {
    DDLogVerbose(@"%@ exportMessages", LOG_TAG);

    if (self.zip && self.descriptors.count > 0) {

        if (!self.dirCreated) {
            NSString *dirPath = @"/";
            if (![self.zip writeFolderAtPath:dirPath withFolderName:self.dirName withPassword:self.password]) {
                [self errorWithMessage:@"cannot create ZIP directory"];
            }
            self.dirCreated = YES;
        }
        
        [self.descriptors sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
            TLExportInfo *info1 = (TLExportInfo *)obj1;
            TLExportInfo *info2 = (TLExportInfo *)obj2;
            
            if (info1.date < info2.date) {
                return NSOrderedAscending;
            } else if (info1.date > info2.date) {
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];

        NSMutableString *messages = [[NSMutableString alloc] initWithCapacity:MESSAGE_BUFFER_SIZE];
        for (TLExportInfo *info in self.descriptors) {
            NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:info.date / 1000L];
            NSString *localizedDateTime = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];

            [messages appendFormat:@"[%@] %@\r\n", localizedDateTime, info.text];
        }

        NSString *fileName = [NSString stringWithFormat:@"%@/messages.txt", self.dirName];
        NSData *data = [messages dataUsingEncoding:NSUTF8StringEncoding];
        if (![self.zip writeData:data filename:fileName compressionLevel:Z_DEFAULT_COMPRESSION password:self.password AES:self.password != nil]) {
            [self errorWithMessage:@"cannot write ZIP entry"];
        }
    }
}

- (void)exportWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor path:(nonnull NSString *)path senderName:(nonnull NSString *)senderName thumbnail:(BOOL)thumbnail ext:(nonnull NSString *)ext {
    DDLogVerbose(@"%@ exportWithContact %@ path: %@ senderName: %@ thumbnail: %d ext: %@", LOG_TAG, fileDescriptor, path, senderName, thumbnail, ext);

    if (self.zip) {
        if (!self.dirCreated) {
            NSString *dirPath = [path stringByDeletingLastPathComponent];
            if (![self.zip writeFolderAtPath:dirPath withFolderName:self.dirName withPassword:self.password]) {
                [self errorWithMessage:@"cannot create ZIP directory"];
            }
            self.dirCreated = YES;
        }
        
        TLDescriptorId *descriptorId = fileDescriptor.descriptorId;
        NSString *suffix = thumbnail ? @"-thumbnail" : @"";
        NSString *fileName = [NSString stringWithFormat:@"%@/%@_%lld%@.%@", self.dirName, senderName, descriptorId.sequenceId, suffix, ext];
        [self.descriptors addObject:[[TLExportInfo alloc] initWithDate:fileDescriptor.createdTimestamp text:[NSString stringWithFormat:@"%@: %@ <%@_%lld.%@>", senderName, TwinmeLocalizedString(@"File", nil), senderName, descriptorId.sequenceId, ext]]];
        if (![self.zip writeFileAtPath:path withFileName:fileName compressionLevel:Z_DEFAULT_COMPRESSION password:self.password AES:self.password != nil]) {
            [self errorWithMessage:@"cannot write ZIP entry"];
        }
    }
}

- (void)exportWithNameDescriptor:(nonnull TLNamedFileDescriptor *)namedFileDescriptor senderName:(nonnull NSString *)senderName {
    DDLogVerbose(@"%@ exportWithNameDescriptor %@ senderName: %@", LOG_TAG, namedFileDescriptor, senderName);

    self.stats.fileCount++;
    self.stats.fileSize += [namedFileDescriptor length];
    [self exportWithFileDescriptor:namedFileDescriptor path:[namedFileDescriptor getURL].path senderName:senderName thumbnail:NO ext:[namedFileDescriptor extension]];
}

- (void)exportWithImageDescriptor:(nonnull TLImageDescriptor *)imageDescriptor senderName:(nonnull NSString *)senderName {
    DDLogVerbose(@"%@ exportWithImageDescriptor %@ senderName: %@", LOG_TAG, imageDescriptor, senderName);

    NSString *path;
    NSString *ext;
    BOOL isThumbnail;
    if ([imageDescriptor length] > 0) {
        self.stats.imageCount++;
        self.stats.imageSize += [imageDescriptor length];
        path = [imageDescriptor getURL].path;
        ext = [imageDescriptor extension];
        isThumbnail = NO;
    } else {
        path = [imageDescriptor thumbnailPath];
        if (!path) {
            return;
        }
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSDictionary<NSFileAttributeKey, id> *attrs = [fileManager attributesOfItemAtPath:path error:nil];
        if (!attrs) {
            return;
        }

        self.stats.imageCount++;
        self.stats.imageSize += [attrs fileSize];
        ext = @"jpg";
        isThumbnail = YES;
    }

    [self exportWithFileDescriptor:imageDescriptor path:path senderName:senderName thumbnail:isThumbnail ext:ext];
}

- (void)exportWithVideoDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor senderName:(nonnull NSString *)senderName {
    DDLogVerbose(@"%@ exportWithVideoDescriptor %@ senderName: %@", LOG_TAG, videoDescriptor, senderName);

    NSString *path;
    NSString *ext;
    BOOL isThumbnail;
    if ([videoDescriptor length] > 0) {
        self.stats.videoCount++;
        self.stats.videoSize += [videoDescriptor length];
        path = [videoDescriptor getURL].path;
        ext = [videoDescriptor extension];
        isThumbnail = NO;
    } else {
        path = [videoDescriptor thumbnailPath];
        if (!path) {
            return;
        }
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSDictionary<NSFileAttributeKey, id> *attrs = [fileManager attributesOfItemAtPath:path error:nil];
        if (!attrs) {
            return;
        }

        self.stats.videoCount++;
        self.stats.videoSize += [attrs fileSize];
        ext = @"jpg";
        isThumbnail = YES;
    }

    [self exportWithFileDescriptor:videoDescriptor path:path senderName:senderName thumbnail:isThumbnail ext:ext];
}

- (void)exportWithAudioDescriptor:(nonnull TLAudioDescriptor *)audioDescriptor senderName:(nonnull NSString *)senderName {
    DDLogVerbose(@"%@ exportWithAudioDescriptor %@ senderName: %@", LOG_TAG, audioDescriptor, senderName);

    self.stats.audioCount++;
    self.stats.audioSize += [audioDescriptor length];
    [self exportWithFileDescriptor:audioDescriptor path:[audioDescriptor getURL].path senderName:senderName thumbnail:NO ext:[audioDescriptor extension]];
}

@end
