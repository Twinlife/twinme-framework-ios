/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Twinlife/TLConversationService.h>

typedef enum {
    // Exporter is ready to scan the media and files to be exported.
    TLExportStateReady,

    // Exporter is scanning the selected contact & groups conversations.
    TLExportStateScanning,

    // Exporter has finished scanning and is waiting for the export action.
    TLExportStateWait,

    // Exporter is exporting media files.
    TLExportStateExporting,

    // Exporter has finished successfully.
    TLExportStateDone,

    // Exporter stopped with an error.
    TLExportStateError

} TLExportState;

/**
 * Interface: TLExportStats
 *
 * Statistics about the export process.
 */
@interface TLExportStats : NSObject

@property (nonatomic) int64_t conversationCount;
@property (nonatomic) int64_t imageCount;
@property (nonatomic) int64_t imageSize;
@property (nonatomic) int64_t videoCount;
@property (nonatomic) int64_t videoSize;
@property (nonatomic) int64_t fileCount;
@property (nonatomic) int64_t fileSize;
@property (nonatomic) int64_t audioCount;
@property (nonatomic) int64_t audioSize;
@property (nonatomic) int64_t msgCount;
@property (nonatomic) int64_t msgSize;
@property (nonatomic) int64_t totalSize;

@end

/**
 * Export observer to report asynchronous progress of the export process done by the ExportExecutor.
 *
 * The observer methods are called from an exporter thread (not the UI thread).
 */
@protocol TLExportDelegate

/**
 * Give information about the exporter progress.
 *
 * @param state the current export state.
 * @param stats the current stats about the export.
 */
- (void) onProgressWithState:(TLExportState)state stats:(nonnull TLExportStats *)stats;

/**
 * Report an error raised while exporting medias.
 *
 * @param message the error message.
 */
- (void) onErrorWithMessage:(nonnull NSString *)message;

@end

//
// Interface: TLExportExecutor
//

@class TLTwinmeContext;
@class TLGroupMember;
@class TLContact;
@class TLGroup;
@class TLSpace;
@protocol TLConversation;

/**
 * Public exporter to export contact and group conversations.
 *
 * - the ExportExecutor instance is created and associated with an TLExportDelegate.
 *   the delegate will be called at different steps during the scanning and export process.
 * - the export filter is configured with typeFilter and dateFilter to choose
 *   the descriptors and filter on the date.
 * - the scanning process is started by calling prepareWithContacts: or prepareWithGroups: or prepareWithSpace:.
 *   during that process, conversations are scanned and the delegate is called to report
 *   in the TLExportStats some statistics about the export.  When the state reported is
 *   TLExportStateWait, the export stats reported by onProgressWithState: indicates the expected size
 *   of the final export.
 * - the export process is started by calling runExportWithPath: and giving the directory where
 *   conversations are exported.  While exporting, the observer is also called with
 *   a new TLExportStats that indicates the current export state.  When the final state
 *   reached TLExportStateDone, the export process is finished.
 *
 * The scanning and export processes are executed from a dedicated thread.
 */
@interface TLExportExecutor : NSObject

@property (nonatomic, nullable) NSArray<NSNumber *> *typeFilter;
@property (nonatomic) int64_t dateFilter;
@property (nonatomic, readonly, nullable) NSMutableArray<id<TLConversation>> *conversations;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<TLExportDelegate>)delegate statAllDescriptors:(BOOL)statAllDescriptors needConversations:(BOOL)needConversations;

/**
 * Prepare the export process to export the conversations of the list of contacts.
 * The scanning process is started.
 *
 * @param contacts the list of contacts to export.
 */
- (void)prepareWithContacts:(nonnull NSArray<TLContact *> *)contacts;

/**
 * Prepare the export process to export the conversations of the list of groups.
 * The scanning process is started.
 *
 * @param groups the list of groups to export.
 */
- (void)prepareWithGroups:(nonnull NSArray<TLGroup *> *)groups;

/**
 * Prepare the export process to export the conversations of the space.
 * The contacts and groups of the space is first retrieved and the scanning process is started.
 *
 * @param space the space to export.
 * @param reset when true clear existing lists.
 */
- (void)prepareWithSpace:(nonnull TLSpace *)space reset:(BOOL)reset;

/**
 * Prepare the export process for every visible space.  Secret spaces are ignored and must be entered manually.
 */
- (void)prepareAll;

/**
 * After the prepare action and scanning process, export the selected conversations to
 * the given external directory.
 *
 * @param path the directory where the conversations are exported.
 * @param password the optional password to protect the ZIP archive.
 */
- (void)runExportWithPath:(nonnull NSString *)path password:(nullable NSString *)password;

- (void)dispose;

/**
 * Sanitize the name to get a valid export file name.
 *
 *@param name the space/group or contact name.
 *@return the name with special characters removed.
 */
+ (nonnull NSString *)exportWithName:(nonnull NSString *)name;

@end
