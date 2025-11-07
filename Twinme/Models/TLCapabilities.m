/*
 *  Copyright (c) 2021-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <Twinlife/TLAttributeNameValue.h>
#import <Twinlife/NSUUID+Extensions.h>

#import "TLTwinmeAttributes.h"
#import "TLSchedule.h"
#import "TLCapabilities.h"

// Name of non-toggleable capabilities.
#define CAP_NAME_CLASS @"class"
#define CAP_NAME_SCHEDULE @"schedule"
#define CAP_NAME_TRUSTED  @"trusted"

// Internal representation of a capability.
// This can change between versions.
typedef NS_OPTIONS(NSInteger, ToggleableCapValue) {
    PARSED              = 1 << 0,
    ADMIN               = 1 << 1,
    DATA                = 1 << 2,
    AUDIO               = 1 << 3,
    VIDEO               = 1 << 4,
    ACCEPT_AUDIO        = 1 << 5,
    ACCEPT_VIDEO        = 1 << 6,
    VISIBILITY          = 1 << 7,
    OWNER               = 1 << 8,
    MODERATE            = 1 << 9,
    INVITE              = 1 << 10,
    TRANSFER            = 1 << 11,
    GROUP_CALL          = 1 << 12,
    AUTO_ANSWER_CALL    = 1 << 13,  //For compatibility with Android app only, not technically doable under iOS
    DISCREET            = 1 << 14,
    ZOOMABLE            = 1 << 15,
    NOT_ZOOMABLE        = 1 << 16
};

// The default capabilities.
static const int CAP_DEFAULT = PARSED | DATA | AUDIO |
        VIDEO | ACCEPT_VIDEO | ACCEPT_AUDIO | VISIBILITY | INVITE;

static const int CAP_NO_CALL = ~(AUDIO | VIDEO | ACCEPT_AUDIO | ACCEPT_AUDIO);

@interface ToggleableCap : NSObject

@property (readonly) ToggleableCapValue value;
@property (nonnull, readonly) NSString *label;
@property (readonly) bool enabledByDefault;

- (nonnull instancetype)initWithValue:(ToggleableCapValue)value label:(nonnull NSString *)label;

- (nonnull instancetype)initWithValue:(ToggleableCapValue)value label:(nonnull NSString *)label enabledByDefault:(bool)enabledByDefault;

@end

@implementation ToggleableCap

- (nonnull instancetype)initWithValue:(ToggleableCapValue)value label:(nonnull NSString *)label {
    self = [super init];
    
    if(self){
        _value = value;
        _label = label;
        _enabledByDefault = YES;
    }
    return self;
}

- (nonnull instancetype)initWithValue:(ToggleableCapValue)value label:(nonnull NSString *)label enabledByDefault:(bool)enabledByDefault {
    self = [super init];
    
    if(self){
        _value = value;
        _label = label;
        _enabledByDefault = enabledByDefault;
    }
    return self;
}
@end


@interface Kind : NSObject
@property (nonatomic, readonly) TLTwincodeKind kind;
@property (nonatomic, nonnull, readonly) NSString *value;
@property (nonatomic, readonly) int override;

- (nonnull instancetype)initWithKind:(TLTwincodeKind)kind value:(nonnull NSString *)value override:(int)override;
@end

@implementation Kind
- (nonnull instancetype)initWithKind:(TLTwincodeKind)kind value:(nonnull NSString *)value override:(int)override {
    if(self = [super init]){
        _kind = kind;
        _value = value;
        _override = override;
    }
    return self;
}
@end

@interface KindAndValue : NSObject
@property (nonatomic, readonly) TLTwincodeKind kind;
@property (nonatomic, readonly) NSString *value;
@end

@interface TLCapabilities ()

@property (class, nonatomic, nonnull, readonly) NSArray<ToggleableCap *> *toggleableCaps;
@property (class, nonatomic, nonnull, readonly) NSArray<Kind *> *twincodeKinds;

/// An optional set of configuration properties.
@property (nullable) NSString *capabilities;
@property int64_t flags;
@property TLTwincodeKind twincodeKind;
@property (nullable) NSString *trusted;

- (void)parse;

- (void)update;

- (void)changeCapabilityWithCapability:(ToggleableCapValue)capability remove:(BOOL)remove;

- (BOOL)hasCapWithCap:(ToggleableCapValue)cap;

- (void)setCapWithCap:(ToggleableCapValue)cap value:(BOOL)value;
@end

//
// Implementation: TLSettings
//

@implementation TLCapabilities

@synthesize schedule = _schedule;

- (nullable instancetype)init {
    
    self = [super init];
    if (self) {
        _capabilities = nil;
        _flags = 0;
        _twincodeKind = TLTwincodeKindContact;
    }

    return self;
}

- (nullable instancetype)initWithCapabilities:(nonnull NSString *)capabilities {
    
    self = [super init];
    if (self) {
        _capabilities = capabilities;
        _flags = 0;
        _twincodeKind = TLTwincodeKindContact;
    }

    return self;
}

- (nullable instancetype)initWithTwincodeKind:(TLTwincodeKind)kind admin:(BOOL)admin {
    
    self = [super init];
    if (self) {
        _capabilities = nil;
        _flags = CAP_DEFAULT;
        if (admin) {
            _flags |= ADMIN;
        }
        _twincodeKind = kind;
        [self update];
    }

    return self;
}

- (TLTwincodeKind)kind {
    
    [self parse];
    return self.twincodeKind;
}

- (BOOL)hasOwner {
    return [self hasCapWithCap:OWNER];
}

- (BOOL)hasAdmin {
    return [self hasCapWithCap:ADMIN];
}

- (BOOL)hasModerate {
    return [self hasCapWithCap:MODERATE];
}

- (BOOL)hasAudio {
    return [self hasCapWithCap:AUDIO];
}

- (BOOL)hasAudioReceiver {
    return [self hasCapWithCap:ACCEPT_AUDIO];
}

- (BOOL)hasVideo {
    return [self hasCapWithCap:VIDEO];
}

- (BOOL)hasVideoReceiver {
    return [self hasCapWithCap:ACCEPT_VIDEO];
}

- (BOOL)hasData {
    return [self hasCapWithCap:DATA];
}

- (BOOL)hasVisibility {
    return [self hasCapWithCap:VISIBILITY];
}

- (BOOL)hasAcceptInvitation {
    return [self hasCapWithCap:INVITE];
}

- (BOOL)hasTransfer {
   return [self hasCapWithCap:TRANSFER];
}

- (BOOL)hasGroupCall {
   return [self hasCapWithCap:GROUP_CALL];
}

- (BOOL)hasDiscreet {
    return [self hasCapWithCap:DISCREET];
}

- (TLVideoZoomable)zoomable {
    if ([self hasCapWithCap:NOT_ZOOMABLE]) {
        return TLVideoZoomableNever;
    }
    if ([self hasCapWithCap:ZOOMABLE]) {
        return TLVideoZoomableAllow;
    }
    return TLVideoZoomableAsk;
}

- (void)setCapAdminWithValue:(BOOL)value {
    [self setCapWithCap:ADMIN value:value];
}

- (void)setCapModerateWithValue:(BOOL)value {
    [self setCapWithCap:MODERATE value:value];
}

- (void)setCapAudioWithValue:(BOOL)value {
    [self setCapWithCap:AUDIO value:value];
}

- (void)setCapVideoWithValue:(BOOL)value {
    [self setCapWithCap:VIDEO value:value];
}

- (void)setCapDataWithValue:(BOOL)value {
    [self setCapWithCap:DATA value:value];
}

- (void)setCapVisibilityWithValue:(BOOL)value {
    [self setCapWithCap:VISIBILITY value:value];
}

- (void)setCapAcceptInvitationWithValue:(BOOL)value {
    [self setCapWithCap:INVITE value:value];
}

- (void)setCapTransferWithValue:(BOOL)value {
    [self setCapWithCap:TRANSFER value:value];
}

- (void)setCapGroupCallWithValue:(BOOL)value {
    [self setCapWithCap:GROUP_CALL value:value];
}

- (void)setCapDiscreetWithValue:(BOOL)value {
    [self setCapWithCap:DISCREET value:value];
}

- (void)setKindWithValue:(TLTwincodeKind)value {

    [self parse];
    self.twincodeKind = value;
    [self update];
}

- (void)setTrustedWithValue:(nullable NSUUID *)value {
    
    [self parse];
    self.trusted = [value UUIDString];
    [self update];
}

- (BOOL)isTrustedWithTwincodeId:(nonnull NSUUID*)twincodeId {
    
    [self parse];
    return [twincodeId isEqual:[NSUUID toUUID:self.trusted]];
}

- (void)setZoomableWithValue:(TLVideoZoomable)value {

    [self parse];
    switch (value) {
        case TLVideoZoomableNever:
            [self setCapWithCap:NOT_ZOOMABLE value:YES];
            [self setCapWithCap:ZOOMABLE value:NO];
            break;

        case TLVideoZoomableAllow:
            [self setCapWithCap:NOT_ZOOMABLE value:NO];
            [self setCapWithCap:ZOOMABLE value:YES];
            break;

        case TLVideoZoomableAsk:
            [self setCapWithCap:NOT_ZOOMABLE value:NO];
            [self setCapWithCap:ZOOMABLE value:NO];
            break;
    }
    [self update];
}

- (nullable NSString *)attributeValue {
    
    return self.capabilities;
}

- (nullable TLSchedule *)schedule {
    [self parse];
    return _schedule;
}
- (void)setSchedule:(nullable TLSchedule *)schedule {
    [self parse];
    _schedule = schedule;
    [self update];
}

- (void)parse {

    if (self.flags & PARSED) {
        return;
    }

    self.flags |= CAP_DEFAULT;
    if (!self.capabilities) {
        return;
    }

    NSArray<NSString *> *lines = [self.capabilities componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSRange pos = [line rangeOfString:@"="];
        NSString *capName;
        NSString *capValue;
        
        if (pos.length > 0) {
            capName = [line substringToIndex:pos.location];
            capValue = [line substringFromIndex:pos.location + 1];
        } else {
            capName = line;
            capValue = nil;
        }
        if (capName.length == 0) {
            continue;
        }

        BOOL removeMode = NO;
        if ([capName characterAtIndex:0] == '!') {
            removeMode = YES;
            capName = [capName substringFromIndex:1];
            if (capName.length == 0) {
                continue;
            }
        }

        if ([capName isEqualToString:CAP_NAME_CLASS]) {
            if(capValue){
                Kind *cap = [TLCapabilities getKindWithValue:capValue];
                if(cap){
                    self.twincodeKind = cap.kind;
                    if(cap.override != 0){
                        self.flags &= cap.override;
                    }
                }
            }
        } else if ([capName isEqualToString:CAP_NAME_SCHEDULE]){
            if(capValue){
                _schedule = [TLSchedule ofCapabilityWithCapabilityString:capValue];
            }
        } else if ([capName isEqualToString:CAP_NAME_TRUSTED]) {
            if (capValue) {
                _trusted = capValue;
            }
        } else {
            ToggleableCap *cap = [TLCapabilities getToggleableCapWithLabel:capName];
            if(cap){
                [self changeCapabilityWithCapability:(int)cap.value remove:removeMode];
            }
        }
    }
}

- (void)update {

    if (self.twincodeKind == TLTwincodeKindContact && self.flags == CAP_DEFAULT && !self.schedule && !self.trusted) {
        self.capabilities = @"";
        return;
    }

    NSMutableString *cap = [[NSMutableString alloc] initWithCapacity:32];
    if (self.twincodeKind != TLTwincodeKindContact) {
        Kind *kind = [TLCapabilities getKindWithTwincodeKind:self.twincodeKind];
        [cap appendString:CAP_NAME_CLASS];
        [cap appendString:@"="];
        [cap appendString:kind.value];
    }
    
    for(ToggleableCap *toggleableCap in TLCapabilities.toggleableCaps){
        if(toggleableCap.value == PARSED){
            continue;
        }
        if(toggleableCap.enabledByDefault){
            if((self.flags & toggleableCap.value) == 0){
                if (cap.length > 0) {
                    [cap appendString:@"\n"];
                }
                [cap appendString:@"!"];
                [cap appendString:toggleableCap.label];
            }
        } else {
            if((self.flags & toggleableCap.value) != 0){
                if (cap.length > 0) {
                    [cap appendString:@"\n"];
                }
                [cap appendString:toggleableCap.label];
            }
        }
    }
    
    if(_schedule){
        if(cap.length > 0){
            [cap appendString:@"\n"];
        }
        [cap appendString:CAP_NAME_SCHEDULE];
        [cap appendString:@"="];
        [cap appendString:[_schedule toCapability]];
    }
    if (_trusted) {
        if (cap.length > 0){
            [cap appendString:@"\n"];
        }
        [cap appendString:CAP_NAME_TRUSTED];
        [cap appendString:@"="];
        [cap appendString:_trusted];
    }

    self.capabilities = cap;
}

- (void)changeCapabilityWithCapability:(ToggleableCapValue)capability remove:(BOOL)remove {

    if (remove) {
        self.flags &= ~capability;
    } else {
        self.flags |= capability;
    }
}

- (void)setCapWithCap:(ToggleableCapValue)cap value:(BOOL)value {

    [self parse];
    [self changeCapabilityWithCapability:cap remove:!value];
    [self update];
}

- (BOOL)hasCapWithCap:(ToggleableCapValue)cap {
    [self parse];
    return self.flags & cap;
}

+ (nonnull NSArray<ToggleableCap *> *) toggleableCaps {
    
    static NSArray<ToggleableCap *> *CAPS = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CAPS = @[
            [[ToggleableCap alloc] initWithValue:PARSED label:@"parsed" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:ADMIN label:@"admin" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:DATA label:@"data"],
            [[ToggleableCap alloc] initWithValue:AUDIO label:@"audio"],
            [[ToggleableCap alloc] initWithValue:VIDEO label:@"video"],
            [[ToggleableCap alloc] initWithValue:ACCEPT_AUDIO label:@"accept-audio"],
            [[ToggleableCap alloc] initWithValue:ACCEPT_VIDEO label:@"accept-video"],
            [[ToggleableCap alloc] initWithValue:VISIBILITY label:@"visibility"],
            [[ToggleableCap alloc] initWithValue:OWNER label:@"owner" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:MODERATE label:@"moderate" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:INVITE label:@"invite"],
            [[ToggleableCap alloc] initWithValue:TRANSFER label:@"transfer" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:GROUP_CALL label:@"group-call" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:AUTO_ANSWER_CALL label:@"auto-answer-call" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:DISCREET label:@"discreet" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:ZOOMABLE label:@"zoomable" enabledByDefault:NO],
            [[ToggleableCap alloc] initWithValue:NOT_ZOOMABLE label:@"not-zoomable" enabledByDefault:NO]
        ];
    });
    return CAPS;
}

+ (nonnull NSArray<Kind *> *) twincodeKinds {
    
    static NSArray<Kind *> *CAPS = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CAPS = @[
            [[Kind alloc] initWithKind:TLTwincodeKindGroup value:@"group" override:CAP_NO_CALL],
            [[Kind alloc] initWithKind:TLTwincodeKindGroupMember value:@"group-member" override:CAP_NO_CALL],
            [[Kind alloc] initWithKind:TLTwincodeKindAccountMigration value:@"account-migration" override:CAP_NO_CALL],
            [[Kind alloc] initWithKind:TLTwincodeKindSpace value:@"space" override:CAP_NO_CALL],
            [[Kind alloc] initWithKind:TLTwincodeKindInvitation value:@"invitation" override:CAP_NO_CALL & ~DATA],
            [[Kind alloc] initWithKind:TLTwincodeKindCallReceiver value:@"call-receiver" override:0],
            [[Kind alloc] initWithKind:TLTwincodeKindContact value:@"contact" override:0],
            [[Kind alloc] initWithKind:TLTwincodeKindTwinroom value:@"twinroom" override:0]
        ];
    });
    return CAPS;
}

+ (nullable ToggleableCap *) getToggleableCapWithLabel:(nonnull NSString *)label{
    for(ToggleableCap *cap in TLCapabilities.toggleableCaps){
        if([cap.label isEqualToString:label]){
            return cap;
        }
    }
    return nil;
}

+ (nonnull Kind *) getKindWithValue:(NSString *)value {
    for(Kind *cap in TLCapabilities.twincodeKinds){
        if([cap.value isEqualToString:value]){
            return cap;
        }
    }
    @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Kind not found in twincodeKinds array" userInfo:nil];}

+ (nonnull Kind *) getKindWithTwincodeKind:(TLTwincodeKind)kind {
    for(Kind *cap in TLCapabilities.twincodeKinds){
        if(cap.kind == kind){
            return cap;
        }
    }
    @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"Kind not found in twincodeKinds array" userInfo:nil];
}

@end
