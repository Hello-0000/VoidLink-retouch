//
//  StreamGestureBindings.m
//  VoidLink
//

#import <UIKit/UIKit.h>
#import "StreamGestureBindings.h"
#import "DataManager.h"
#import "LocalizationHelper.h"

NSString * const StreamGestureBindingsDefaultsKey = @"StreamGestureBindings";
NSString * const StreamGestureCommandDefaultsKey = @"StreamGestureCommand";
NSString * const StreamGestureCommandNameDefaultsKey = @"StreamGestureCommandName";
static NSString * const StreamGestureCommandOnLeaveDefaultsKey = @"StreamGestureCommandOnLeave";
NSString * const StreamGestureBindingsMigrationDefaultsKey = @"StreamGestureBindingsMigrationV1";

@implementation StreamGestureBindings

#pragma mark - Tables

+ (NSArray<NSNumber *> *)allActions {
    return @[@(StreamGestureActionSettings), @(StreamGestureActionToolbox), @(StreamGestureActionSoftKeyboard),
             @(StreamGestureActionLayoutEditor), @(StreamGestureActionToggleOsc), @(StreamGestureActionGestureCommand)];
}

// Repair order when stored data breaks an invariant: earlier actions keep
// their trigger, later duplicates fall back to None.
+ (NSArray<NSNumber *> *)repairPriority {
    return @[@(StreamGestureActionSettings), @(StreamGestureActionToggleOsc), @(StreamGestureActionSoftKeyboard),
             @(StreamGestureActionLayoutEditor), @(StreamGestureActionToolbox), @(StreamGestureActionGestureCommand)];
}

+ (NSArray<NSNumber *> *)allTriggers {
    return @[@(StreamGestureTriggerLeftEdge), @(StreamGestureTriggerRightEdge), @(StreamGestureTriggerHold3),
             @(StreamGestureTriggerHold4), @(StreamGestureTriggerHold5), @(StreamGestureTriggerNone)];
}

+ (NSString *)keyForAction:(StreamGestureAction)action {
    switch (action) {
        case StreamGestureActionSettings: return @"settings";
        case StreamGestureActionToolbox: return @"toolbox";
        case StreamGestureActionSoftKeyboard: return @"softKeyboard";
        case StreamGestureActionLayoutEditor: return @"layoutEditor";
        case StreamGestureActionToggleOsc: return @"toggleOsc";
        case StreamGestureActionGestureCommand: return @"gestureCommand";
        default: return @"";
    }
}

+ (NSString *)keyForTrigger:(StreamGestureTrigger)trigger {
    switch (trigger) {
        case StreamGestureTriggerLeftEdge: return @"leftEdge";
        case StreamGestureTriggerRightEdge: return @"rightEdge";
        case StreamGestureTriggerHold3: return @"hold3";
        case StreamGestureTriggerHold4: return @"hold4";
        case StreamGestureTriggerHold5: return @"hold5";
        default: return @"none";
    }
}

+ (StreamGestureTrigger)triggerForKey:(id)key {
    if (![key isKindOfClass:[NSString class]]) return StreamGestureTriggerNone;
    for (NSNumber *t in [self allTriggers]) {
        if ([[self keyForTrigger:t.integerValue] isEqualToString:key]) return t.integerValue;
    }
    return StreamGestureTriggerNone;
}

+ (NSInteger)fingerCountForTrigger:(StreamGestureTrigger)trigger {
    switch (trigger) {
        case StreamGestureTriggerHold3: return 3;
        case StreamGestureTriggerHold4: return 4;
        case StreamGestureTriggerHold5: return 5;
        default: return 0;
    }
}

+ (StreamGestureTrigger)holdTriggerForFingerCount:(NSInteger)fingers {
    switch (fingers) {
        case 3: return StreamGestureTriggerHold3;
        case 4: return StreamGestureTriggerHold4;
        case 5: return StreamGestureTriggerHold5;
        default: return StreamGestureTriggerNone;
    }
}

+ (BOOL)isEdgeTrigger:(StreamGestureTrigger)trigger {
    return trigger == StreamGestureTriggerLeftEdge || trigger == StreamGestureTriggerRightEdge;
}

#pragma mark - Storage

// One-time import of the legacy Core Data gesture fields.
+ (NSDictionary<NSString *, NSString *> *)migratedBindings {
    TemporarySettings *settings = [[[DataManager alloc] init] getSettings];
    NSInteger edge = settings.slideToSettingsScreenEdge ? settings.slideToSettingsScreenEdge.integerValue : UIRectEdgeLeft;
    NSInteger keyboardFingers = settings.keyboardToggleFingers ? settings.keyboardToggleFingers.integerValue : 3;
    NSInteger layoutFingers = settings.oscLayoutToolFingers ? settings.oscLayoutToolFingers.integerValue : 4;

    NSMutableDictionary<NSNumber *, NSNumber *> *map = [NSMutableDictionary dictionary];
    NSMutableSet<NSNumber *> *used = [NSMutableSet set];
    void (^bind)(StreamGestureAction, StreamGestureTrigger) = ^(StreamGestureAction action, StreamGestureTrigger trigger) {
        if (trigger != StreamGestureTriggerNone && [used containsObject:@(trigger)]) trigger = StreamGestureTriggerNone;
        map[@(action)] = @(trigger);
        if (trigger != StreamGestureTriggerNone) [used addObject:@(trigger)];
    };

    // Settings: Left -> left edge, Right -> right edge, anything else (both
    // edges / garbage) -> left edge.
    bind(StreamGestureActionSettings, edge == UIRectEdgeRight ? StreamGestureTriggerRightEdge : StreamGestureTriggerLeftEdge);
    // The OSC toggle was hard-wired to the right edge.
    bind(StreamGestureActionToggleOsc, StreamGestureTriggerRightEdge);
    // Soft keyboard: 3/4/5 fingers -> hold; "off" was stored as 20 (any value
    // outside 3...5) -> None.
    bind(StreamGestureActionSoftKeyboard, [self holdTriggerForFingerCount:keyboardFingers]);
    StreamGestureTrigger layout = [self holdTriggerForFingerCount:layoutFingers];
    if (layout == StreamGestureTriggerNone || [used containsObject:@(layout)]) layout = StreamGestureTriggerHold4;
    bind(StreamGestureActionLayoutEditor, layout);
    bind(StreamGestureActionToolbox, StreamGestureTriggerNone);
    bind(StreamGestureActionGestureCommand, StreamGestureTriggerNone);

    NSMutableDictionary<NSString *, NSString *> *stored = [NSMutableDictionary dictionary];
    for (NSNumber *action in map) {
        stored[[self keyForAction:action.integerValue]] = [self keyForTrigger:map[action].integerValue];
    }
    return stored;
}

// Reads (migrating first if needed) and repairs the stored table. Returns
// action -> trigger for every action.
+ (NSDictionary<NSNumber *, NSNumber *> *)loadBindings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *stored = [defaults dictionaryForKey:StreamGestureBindingsDefaultsKey];
    if (![defaults boolForKey:StreamGestureBindingsMigrationDefaultsKey]) {
        if (stored == nil) {
            stored = [self migratedBindings];
            [defaults setObject:stored forKey:StreamGestureBindingsDefaultsKey];
        }
        [defaults setBool:YES forKey:StreamGestureBindingsMigrationDefaultsKey];
    }

    NSMutableDictionary<NSNumber *, NSNumber *> *result = [NSMutableDictionary dictionary];
    NSMutableSet<NSNumber *> *used = [NSMutableSet set];
    BOOL repaired = NO;
    for (NSNumber *action in [self repairPriority]) {
        StreamGestureTrigger trigger = [self triggerForKey:stored[[self keyForAction:action.integerValue]]];
        if (trigger != StreamGestureTriggerNone && [used containsObject:@(trigger)]) {
            trigger = StreamGestureTriggerNone;
            repaired = YES;
        }
        if (action.integerValue == StreamGestureActionSettings && trigger == StreamGestureTriggerNone) {
            trigger = StreamGestureTriggerLeftEdge; // first in the priority list, so always free
            repaired = YES;
        }
        result[action] = @(trigger);
        if (trigger != StreamGestureTriggerNone) [used addObject:@(trigger)];
    }
    if (repaired) [self storeBindings:result];
    return result;
}

+ (void)storeBindings:(NSDictionary<NSNumber *, NSNumber *> *)bindings {
    NSMutableDictionary<NSString *, NSString *> *stored = [NSMutableDictionary dictionary];
    for (NSNumber *action in bindings) {
        stored[[self keyForAction:action.integerValue]] = [self keyForTrigger:bindings[action].integerValue];
    }
    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:StreamGestureBindingsDefaultsKey];
}

#pragma mark - API

+ (StreamGestureTrigger)triggerForAction:(StreamGestureAction)action {
    NSNumber *trigger = [self loadBindings][@(action)];
    return trigger ? trigger.integerValue : StreamGestureTriggerNone;
}

+ (StreamGestureAction)actionForTrigger:(StreamGestureTrigger)trigger {
    if (trigger == StreamGestureTriggerNone) return StreamGestureActionNone;
    NSDictionary<NSNumber *, NSNumber *> *bindings = [self loadBindings];
    for (NSNumber *action in bindings) {
        if (bindings[action].integerValue == trigger) return action.integerValue;
    }
    return StreamGestureActionNone;
}

+ (StreamGestureAction)assignTrigger:(StreamGestureTrigger)trigger toAction:(StreamGestureAction)action {
    if (action == StreamGestureActionNone) return StreamGestureActionNone;
    if (action == StreamGestureActionSettings && trigger == StreamGestureTriggerNone) return StreamGestureActionNone;
    NSMutableDictionary<NSNumber *, NSNumber *> *bindings = [[self loadBindings] mutableCopy];
    StreamGestureTrigger previous = bindings[@(action)].integerValue;
    if (previous == trigger) return StreamGestureActionNone;

    StreamGestureAction owner = StreamGestureActionNone;
    if (trigger != StreamGestureTriggerNone) {
        for (NSNumber *other in bindings) {
            if (other.integerValue != action && bindings[other].integerValue == trigger) {
                owner = other.integerValue;
                break;
            }
        }
    }
    if (owner == StreamGestureActionSettings) return StreamGestureActionNone; // Settings keeps its trigger

    bindings[@(action)] = @(trigger);
    if (owner != StreamGestureActionNone) bindings[@(owner)] = @(previous);
    [self storeBindings:bindings];
    return owner;
}

+ (NSString *)commandString {
    NSString *cmd = [[NSUserDefaults standardUserDefaults] stringForKey:StreamGestureCommandDefaultsKey];
    return cmd ?: @"";
}

+ (BOOL)sendCommandOnLeave {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:StreamGestureCommandOnLeaveDefaultsKey];
    return stored == nil ? YES : [stored boolValue];
}

+ (void)setSendCommandOnLeave:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:StreamGestureCommandOnLeaveDefaultsKey];
}

+ (NSString *)commandDisplayName {
    NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:StreamGestureCommandNameDefaultsKey];
    if (name.length > 0) return name;
    return [self commandString];
}

+ (void)setCommandString:(NSString *)cmdString displayName:(NSString *)displayName {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:cmdString ?: @"" forKey:StreamGestureCommandDefaultsKey];
    [defaults setObject:displayName ?: @"" forKey:StreamGestureCommandNameDefaultsKey];
}

+ (NSString *)localizedTitleForAction:(StreamGestureAction)action {
    switch (action) {
        case StreamGestureActionSettings: return [LocalizationHelper localizedStringForKey:@"Open Settings"];
        case StreamGestureActionToolbox: return [LocalizationHelper localizedStringForKey:@"Open Toolbox"];
        case StreamGestureActionSoftKeyboard: return [LocalizationHelper localizedStringForKey:@"Soft Keyboard"];
        case StreamGestureActionLayoutEditor: return [LocalizationHelper localizedStringForKey:@"Layout Editor"];
        case StreamGestureActionToggleOsc: return [LocalizationHelper localizedStringForKey:@"Show/Hide On-Screen Controls"];
        case StreamGestureActionGestureCommand: return [LocalizationHelper localizedStringForKey:@"Gesture Command"];
        default: return @"";
    }
}

+ (NSString *)localizedTitleForTrigger:(StreamGestureTrigger)trigger {
    switch (trigger) {
        case StreamGestureTriggerLeftEdge: return [LocalizationHelper localizedStringForKey:@"Left Edge Swipe"];
        case StreamGestureTriggerRightEdge: return [LocalizationHelper localizedStringForKey:@"Right Edge Swipe"];
        case StreamGestureTriggerHold3: return [LocalizationHelper localizedStringForKey:@"3-Finger Hold"];
        case StreamGestureTriggerHold4: return [LocalizationHelper localizedStringForKey:@"4-Finger Hold"];
        case StreamGestureTriggerHold5: return [LocalizationHelper localizedStringForKey:@"5-Finger Hold"];
        default: return [LocalizationHelper localizedStringForKey:@"Gesture Trigger Off"];
    }
}

@end
