//
//  MultiFingerHoldGestureRecognizer.h
//  VoidLink
//
//  3/4/5-finger hold on the stream (soft keyboard, layout editor, ... — see
//  StreamGestureBindings). Discrete: recognizes once the same set of fingers
//  has stayed put for `holdDuration`, with a progress ring from `ringDelay`.
//
//  Counting: only fingers on the stream picture count, including the ones the
//  OSC touch block withholds from the host. Fingers on an OSC control (widget
//  views, legacy OSC layers, any UIControl such as the OSC ON/OFF button) and
//  palms are not tracked at all, so they are neither counted nor cancelled.
//  While Possible nothing is delayed or cancelled; on recognition UIKit cancels
//  the tracked touches in the view (cancelsTouchesInView), which releases them
//  host-side through StreamView's touchesCancelled.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class StreamView;

@interface MultiFingerHoldGestureRecognizer : UIGestureRecognizer

// Asked whenever the finger count changes and again right before firing:
// return NO and that count never times / fires (no binding, disabled state).
@property (nonatomic, copy, nullable) BOOL (^fingerCountEnabled)(NSInteger fingers);
// Used to hit-test the legacy CALayer OSC buttons (they aren't views).
@property (nonatomic, weak, nullable) StreamView *streamView;

@property (nonatomic, assign) NSTimeInterval holdDuration;   // default 1.5s
@property (nonatomic, assign) NSTimeInterval ringDelay;      // default 0.5s
@property (nonatomic, assign) CGFloat movementTolerance;     // default 30pt; drifting further restarts the timer

// Valid in the action callback.
@property (nonatomic, readonly) NSInteger recognizedFingerCount;
// Screen height minus the lowest finger's y at recognition (keyboard lift).
@property (nonatomic, readonly) CGFloat lowestTouchPointHeight;

@end

NS_ASSUME_NONNULL_END
