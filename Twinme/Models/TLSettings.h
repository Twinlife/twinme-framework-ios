/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLAttributeNameValue;

//
// Interface: TLSpaceSettings
//

@interface TLSettings : NSObject

#ifdef SPACE_SETTINGS_IMPLEMENTATION
/// An optional set of configuration properties (internal for TLSettings and TLSpaceSettings.
@property (nullable) NSMutableDictionary<NSString *, NSString *> *properties;
#endif

/// The optional description.
@property (nullable) NSString *objectDescription;

- (nullable instancetype)init;

- (nullable instancetype)initWithSettings:(nonnull TLSettings *)settings;

/// Get the boolean value associated with the name or return the default value.
- (BOOL)getBooleanWithName:(nonnull NSString *)name defaultValue:(BOOL)defaultValue;

/// Get the string value associated with the name or return the default value.
- (nonnull NSString *)getStringWithName:(nonnull NSString *)name defaultValue:(nonnull NSString *)defaultValue;

/// Get the color value associated with the name or return the default color.
- (nonnull UIColor *)getColorWithName:(nonnull NSString *)name defaultValue:(nonnull UIColor *)defaultValue;

/// Get the UUID value associated with the name or return nil if there is none.
- (nullable NSUUID *)getUUIDWithName:(nonnull NSString *)name;

/// Set the boolean value for the given name.
- (void)setBooleanWithName:(nonnull NSString *)name value:(BOOL)value;

/// Set the string value for the given name.
- (void)setStringWithName:(nonnull NSString *)name value:(nullable NSString *)value;

/// Set the color value for the given name.
- (void)setColorWithName:(nonnull NSString *)name value:(nonnull UIColor *)value;

/// Set the UUID value for the given name.
- (void)setUUIDWithName:(nonnull NSString *)name value:(nonnull NSUUID *)value;

/// Remove the property with the given name.
- (void)removeWithName:(nonnull NSString *)name;

@end
