/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Synchronization based on copy-on-write pattern
//
// version: 1.2
//

#import <Twinlife/TLAttributeNameValue.h>

#define SPACE_SETTINGS_IMPLEMENTATION
#import "TLTwinmeAttributes.h"
#import "TLSettings.h"

//
// Implementation: TLSettings
//

@implementation TLSettings

- (nullable instancetype)init {
    
    self = [super init];
    if (self) {
        _properties = nil;
    }

    return self;
}

- (nullable instancetype)initWithSettings:(nonnull TLSettings *)settings {
    
    self = [super init];
    if (self) {
        if (settings.properties) {
            _properties = [[NSMutableDictionary alloc] initWithDictionary:settings.properties];
        }
    }
    return self;
}

- (nullable instancetype)initWithUUID:(nonnull NSUUID *)uuid settings:(nonnull TLSettings *)settings {
    
    self = [super init];
    if (self) {
        if (settings.properties) {
            _properties = [[NSMutableDictionary alloc] initWithDictionary:settings.properties];
        }
    }
    return self;
}

- (BOOL)getBooleanWithName:(nonnull NSString *)name defaultValue:(BOOL)defaultValue {
    
    if (!self.properties) {

        return defaultValue;
    }

    NSString *value = self.properties[name];
    if (!value) {
        
        return defaultValue;
    }

    return [value isEqualToString:@"1"];
}

- (nonnull NSString *)getStringWithName:(nonnull NSString *)name defaultValue:(nonnull NSString *)defaultValue {
    
    if (!self.properties) {

        return defaultValue;
    }

    NSString *value = self.properties[name];
    if (!value) {
        
        return defaultValue;
    }

    return value;
}

- (nonnull UIColor *)getColorWithName:(nonnull NSString *)name defaultValue:(nonnull UIColor *)defaultValue {
    
    if (!self.properties) {

        return defaultValue;
    }

    NSString *value = self.properties[name];
    if (!value) {
        
        return defaultValue;
    }

    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:value];
    if (![scanner scanHexInt:&rgbValue]) {
        
        return defaultValue;
    }

    if (value.length == 6) {
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255. green:((rgbValue & 0xFF00) >> 8) / 255. blue:(rgbValue & 0xFF) / 255. alpha:1.0];

    } else if (value.length == 8) {
        return [UIColor colorWithRed:((rgbValue & 0xFF000000) >> 24) / 255. green:((rgbValue & 0xFF0000) >> 16) / 255. blue:((rgbValue & 0xFF00) >> 8) / 255. alpha:(rgbValue & 0x0FF) / 255.];

    } else {
        return defaultValue;
    }
}

- (nullable NSUUID *)getUUIDWithName:(nonnull NSString *)name {

    if (!self.properties) {

        return nil;
    }
    
    NSString *value = self.properties[name];
    if (!value) {
        
        return nil;
    }

    return [[NSUUID alloc] initWithUUIDString:value];
}

- (void)setBooleanWithName:(nonnull NSString *)name value:(BOOL)value {
    
    if (!self.properties) {
        self.properties = [[NSMutableDictionary alloc] init];
    }

    [self.properties setObject:value ? @"1" : @"0" forKey:name];
}

- (void)setStringWithName:(nonnull NSString *)name value:(nullable NSString *)value {
    
    if (!self.properties) {
        if (!value) {
            return;
        }

        self.properties = [[NSMutableDictionary alloc] init];
    } else if (!value) {
        [self.properties removeObjectForKey:name];
        return;
    }

    [self.properties setObject:value forKey:name];
}

- (void)setColorWithName:(nonnull NSString *)name value:(nonnull UIColor *)value {
    
    if (!self.properties) {
        self.properties = [[NSMutableDictionary alloc] init];
    }

    CGFloat red, green, blue, alpha;
    [value getRed:&red green:&green blue:&blue alpha:&alpha];
    long alphaValue = lround(alpha * 255);

    if (alphaValue == 255) {
        [self.properties setObject:[NSString stringWithFormat:@"%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255)] forKey:name];
    } else {
        [self.properties setObject:[NSString stringWithFormat:@"%02lX%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255), alphaValue] forKey:name];
    }
}

- (void)setUUIDWithName:(nonnull NSString *)name value:(nonnull NSUUID *)value {
    
    if (!self.properties) {
        self.properties = [[NSMutableDictionary alloc] init];
    }

    [self.properties setObject:value.UUIDString forKey:name];
}

- (void)removeWithName:(nonnull NSString *)name {
    
    if (self.properties) {
        [self.properties removeObjectForKey:name];
    }
}

@end
