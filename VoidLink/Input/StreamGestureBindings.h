//
//  StreamGestureBindings.h
//  VoidLink
//
//  Single source of truth for the in-stream gesture table: which trigger
//  (left / right edge swipe, 3/4/5-finger hold) performs which action.
//  Stored in NSUserDefaults (not Core Data). The legacy Core Data fields
//  (slideToSettingsScreenEdge, keyboardToggleFingers, oscLayoutToolFingers)
//  are only read once, by the V1 migration.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, StreamGestureAction) {
    StreamGestureActionNone = -1,
    StreamGestureActionSettings = 0,
    StreamGestureActionToolbox,
    StreamGestureActionSoftKeyboard,
    StreamGestureActionLayoutEditor,
    StreamGestureActionToggleOsc,
    StreamGestureActionGestureCommand,
};

typedef NS_ENUM(NSInteger, StreamGestureTrigger) {
    StreamGestureTriggerNone = 0,
    StreamGestureTriggerLeftEdge,
    StreamGestureTriggerRightEdge,
    StreamGestureTriggerHold3,
    StreamGestureTriggerHold4,
    StreamGestureTriggerHold5,
};

extern NSString * const StreamGestureBindingsDefaultsKey;        // @"StreamGestureBindings"
extern NSString * const StreamGestureCommandDefaultsKey;         // @"StreamGestureCommand"
extern NSString * const StreamGestureCommandNameDefaultsKey;     // @"StreamGestureCommandName"
extern NSString * const StreamGestureBindingsMigrationDefaultsKey; // @"StreamGestureBindingsMigrationV1"

@interface StreamGestureBindings : NSObject

// Display order of the settings rows.
+ (NSArray<NSNumber *> *)allActions;
// Menu order: left edge, right edge, 3/4/5-finger hold, off.
+ (NSArray<NSNumber *> *)allTriggers;

+ (StreamGestureTrigger)triggerForAction:(StreamGestureAction)action;
// StreamGestureActionNone when the trigger is free (or is None).
+ (StreamGestureAction)actionForTrigger:(StreamGestureTrigger)trigger;
// Binds `trigger` to `action`. If another action held `trigger`, it takes over
// `action`'s previous trigger (swap) and is returned; otherwise returns
// StreamGestureActionNone. Refused (no change, returns None): Settings -> None,
// or taking the trigger Settings holds away from it.
+ (StreamGestureAction)assignTrigger:(StreamGestureTrigger)trigger toAction:(StreamGestureAction)action;

// 3 / 4 / 5 for the hold triggers, 0 otherwise.
+ (NSInteger)fingerCountForTrigger:(StreamGestureTrigger)trigger;
+ (StreamGestureTrigger)holdTriggerForFingerCount:(NSInteger)fingers;
+ (BOOL)isEdgeTrigger:(StreamGestureTrigger)trigger;

// The gesture command: same string format as a widget's cmdString / a toolbox
// command. Empty string when none was chosen.
+ (NSString *)commandString;
+ (NSString *)commandDisplayName;
+ (void)setCommandString:(NSString *)cmdString displayName:(NSString *)displayName;

// Also send the gesture command when the stream is left (exit or lock /
// background) while a 16:9 game is up. Default on.
+ (BOOL)sendCommandOnLeave;
+ (void)setSendCommandOnLeave:(BOOL)enabled;

+ (NSString *)localizedTitleForAction:(StreamGestureAction)action;
+ (NSString *)localizedTitleForTrigger:(StreamGestureTrigger)trigger;

@end

NS_ASSUME_NONNULL_END
