/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLExporter
//

@protocol TLExportDelegate;
@class TLTwinmeContext;
@class TLGroupMember;
@class TLContact;
@class TLGroup;

/**
 * Export conversations:
 *
 * - the exporter is created by the TLExportExecutor when we start scanning the conversations to export.
 *   it is released immediately after the export has finished.
 * - the exportWithXXX: methods are called two times for a same contact/group.  A first time during a
 *   scanning pass where we collect media sizes and identify the names used to export contacts/groups
 *   and sender prefixes.
 * - the exportWithXXX: methods must be called from a dedicated export thread because the export process
 *   is a long running process and we must not block neither the UI thread nor the Twinlife execution thread.
 */
@interface TLExporter : NSObject

@property (nonatomic) int64_t dateFilter;
@property (nonatomic, nonnull) NSArray<NSNumber *> *typeFilter;
@property (nonatomic) BOOL addSpacePrefix;

- (nonnull instancetype)initWithTwinmeContext:(nonnull TLTwinmeContext *)twinmeContext delegate:(nonnull id<TLExportDelegate>)delegate dateFilter:(int64_t)dateFilter typeFilter:(nullable NSArray<NSNumber *> *)typeFilter statAllDescriptors:(BOOL)statAllDescriptors;

/**
 * Set a new state to the exporter.
 *
 * @param state the new state.
 */
- (void)updateWithState:(TLExportState)state;

/**
 * Create the ZIP file at the given path. The ZipArchive is created and is ready to be populated by the exportWithXXX operations.
 *
 * @param path the path for the ZIP file
 * @param password the optional password to protect the ZIP archive.
 */
- (void)createZipWithPath:(nonnull NSString *)path password:(nullable NSString *)password;

/**
 * Close the zip and check that everything succeeded.
 */
- (void)closeZip;

/**
 * Export the contact conversation according to the selected filters.
 *
 * @param contacts the list of contacts to export.
 * @param members a mapping of room members with their names.
 */
- (void)exportWithContacts:(nonnull NSArray<TLContact *> *)contacts members:(nonnull NSDictionary<NSUUID *, NSDictionary<NSUUID *, NSString *> *> *)members;

/**
 * Export the group conversation according to the selected filters.
 *
 * @param groups the list of groups to export.
 * @param members a mapping of group members with their names.
 */
- (void)exportWithGroups:(nonnull NSArray<TLGroup *> *)groups members:(nonnull NSDictionary<NSUUID *, NSDictionary<NSUUID *, NSString *> *> *)members;

@end
