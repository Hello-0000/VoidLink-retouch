//
//  MultiFingerHoldGestureRecognizer.m
//  VoidLink
//

#import <UIKit/UIGestureRecognizerSubclass.h>
#import "MultiFingerHoldGestureRecognizer.h"
#import "StreamView.h"
#import "VoidLink-Swift.h"

#pragma mark - Progress ring

@interface MultiFingerHoldRingView : UIView
- (void)setProgress:(CGFloat)progress;
- (void)fadeIn;
- (void)dismissFired:(BOOL)fired;
@end

@implementation MultiFingerHoldRingView {
    CAShapeLayer *_trackLayer;
    CAShapeLayer *_progressLayer;
}

static const CGFloat kRingSize = 56.0;
static const CGFloat kRingLineWidth = 3.0;

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, kRingSize, kRingSize)];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
        self.layer.cornerRadius = kRingSize / 2.0;
        self.alpha = 0;

        CGFloat radius = kRingSize / 2.0 - 8.0;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kRingSize / 2.0, kRingSize / 2.0)
                                                            radius:radius
                                                        startAngle:-M_PI_2
                                                          endAngle:-M_PI_2 + 2 * M_PI
                                                         clockwise:YES];
        _trackLayer = [CAShapeLayer layer];
        _trackLayer.path = path.CGPath;
        _trackLayer.fillColor = UIColor.clearColor.CGColor;
        _trackLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25].CGColor;
        _trackLayer.lineWidth = kRingLineWidth;
        [self.layer addSublayer:_trackLayer];

        _progressLayer = [CAShapeLayer layer];
        _progressLayer.path = path.CGPath;
        _progressLayer.fillColor = UIColor.clearColor.CGColor;
        _progressLayer.strokeColor = UIColor.whiteColor.CGColor;
        _progressLayer.lineWidth = kRingLineWidth;
        _progressLayer.lineCap = kCALineCapRound;
        _progressLayer.strokeEnd = 0;
        [self.layer addSublayer:_progressLayer];
    }
    return self;
}

- (void)setProgress:(CGFloat)progress {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _progressLayer.strokeEnd = MAX(0, MIN(1, progress));
    [CATransaction commit];
}

- (void)fadeIn {
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.alpha = 1;
    } completion:nil];
}

- (void)dismissFired:(BOOL)fired {
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.alpha = 0;
        if (fired) self.transform = CGAffineTransformMakeScale(1.3, 1.3);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

#pragma mark - Recognizer

@implementation MultiFingerHoldGestureRecognizer {
    NSMutableArray<UITouch *> *_tracked;                     // counted fingers, in landing order
    NSMapTable<UITouch *, NSValue *> *_anchors;              // position when the count last changed
    NSHashTable<UITouch *> *_firedTouches;                   // fingers of the last recognized hold (weak)
    BOOL _roundInvalid;                                      // a finger moved: wait until every finger lifts
    BOOL _timing;
    NSInteger _timingCount;
    CFTimeInterval _timingStart;
    CADisplayLink *_displayLink;
    MultiFingerHoldRingView *_ring;
    UIImpactFeedbackGenerator *_haptic;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    self = [super initWithTarget:target action:action];
    if (self) {
        _holdDuration = 1.5;
        _ringDelay = 0.5;
        _movementTolerance = 12.0;
        _tracked = [NSMutableArray array];
        _anchors = [NSMapTable weakToStrongObjectsMapTable];
        _firedTouches = [NSHashTable weakObjectsHashTable];
        self.allowedTouchTypes = @[@(UITouchTypeDirect)]; // Pencil never takes part
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = NO;
        self.cancelsTouchesInView = YES;
    }
    return self;
}

// Never block, and never be blocked by, the other stream recognizers (2-finger
// right click, scroll view pan / zoom, edge swipes, fullscreen double tap).
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer { return NO; }
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer { return NO; }

#pragma mark Touch classification

// Fingers on an OSC control or any UIControl are not the stream's.
- (BOOL)touchCounts:(UITouch *)touch {
    UIView *host = self.view;
    for (UIView *v = touch.view; v != nil && v != host; v = v.superview) {
        if ([v isKindOfClass:[OnScreenWidgetView class]]) return NO;
        if ([v isKindOfClass:[UIControl class]]) return NO;
    }
    StreamView *streamView = self.streamView;
    if (streamView && host && [streamView pointHitsAnyVisibleLegacyOscButton:[touch locationInView:host]]) return NO;
    // OSC ON/OFF exemption + palm rejection; withheld fingers still count.
    if ([[StreamView streamTouchesFrom:[NSSet setWithObject:touch] includingWithheld:YES] count] == 0) return NO;
    return YES;
}

- (NSInteger)currentCount {
    if (_tracked.count == 0) return 0;
    // A finger can be re-judged a palm after landing; drop it from the count.
    return [[StreamView streamTouchesFrom:[NSSet setWithArray:_tracked] includingWithheld:YES] count];
}

- (BOOL)firedHoldStillDown:(UIEvent *)event {
    NSSet<UITouch *> *all = [event allTouches];
    for (UITouch *touch in _firedTouches.allObjects) {
        if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled || ![all containsObject:touch]) {
            [_firedTouches removeObject:touch];
        }
    }
    return _firedTouches.count > 0;
}

#pragma mark Touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // One recognition per hold: until every finger of the last one has lifted,
    // new fingers are not tracked.
    BOOL blocked = [self firedHoldStillDown:event];
    BOOL added = NO;
    for (UITouch *touch in touches) {
        if (blocked || ![self touchCounts:touch]) {
            [self ignoreTouch:touch forEvent:event];
            continue;
        }
        if (![_tracked containsObject:touch]) {
            [_tracked addObject:touch];
            added = YES;
        }
    }
    if (added) [self countChanged];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_timing || _roundInvalid) return;
    UIView *host = self.view;
    for (UITouch *touch in touches) {
        NSValue *anchor = [_anchors objectForKey:touch];
        if (!anchor) continue;
        CGPoint start = anchor.CGPointValue;
        CGPoint now = [touch locationInView:host];
        if (hypot(now.x - start.x, now.y - start.y) > _movementTolerance) {
            _roundInvalid = YES;
            [self stopTimingFired:NO];
            return;
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self removeTouches:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self removeTouches:touches];
}

- (void)removeTouches:(NSSet<UITouch *> *)touches {
    BOOL removed = NO;
    for (UITouch *touch in touches) {
        if ([_tracked containsObject:touch]) {
            [_tracked removeObject:touch];
            [_anchors removeObjectForKey:touch];
            removed = YES;
        }
    }
    if (!removed) return;
    if (_tracked.count == 0) {
        // Every counted finger is up: a new round may start (stay Possible so a
        // finger still held on an OSC control doesn't lock us out).
        _roundInvalid = NO;
        [self stopTimingFired:NO];
        return;
    }
    [self countChanged];
}

#pragma mark Timing

- (void)countChanged {
    [self stopTimingFired:NO];
    if (_roundInvalid || self.state != UIGestureRecognizerStatePossible) return;
    NSInteger count = [self currentCount];
    if (count < 3 || count > 5) return;
    if (self.fingerCountEnabled && !self.fingerCountEnabled(count)) return;

    UIView *host = self.view;
    if (!host) return;
    [_anchors removeAllObjects];
    for (UITouch *touch in _tracked) {
        [_anchors setObject:[NSValue valueWithCGPoint:[touch locationInView:host]] forKey:touch];
    }
    _timing = YES;
    _timingCount = count;
    _timingStart = CACurrentMediaTime();
    if (!_haptic) _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [_haptic prepare];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopTimingFired:(BOOL)fired {
    _timing = NO;
    [_displayLink invalidate];
    _displayLink = nil;
    if (_ring) {
        [_ring dismissFired:fired];
        _ring = nil;
    }
}

- (CGPoint)centroid {
    UIView *host = self.view;
    CGFloat x = 0, y = 0;
    for (UITouch *touch in _tracked) {
        CGPoint p = [touch locationInView:host];
        x += p.x; y += p.y;
    }
    NSUInteger n = MAX(_tracked.count, (NSUInteger)1);
    return CGPointMake(x / n, y / n);
}

- (void)tick:(CADisplayLink *)link {
    if (!_timing || self.state != UIGestureRecognizerStatePossible) {
        [self stopTimingFired:NO];
        return;
    }
    UIView *host = self.view;
    if (!host) { [self stopTimingFired:NO]; return; }
    CFTimeInterval elapsed = CACurrentMediaTime() - _timingStart;

    if (elapsed >= _ringDelay) {
        if (!_ring) {
            _ring = [[MultiFingerHoldRingView alloc] init];
            [host addSubview:_ring];
            _ring.center = [self centroid];
            [_ring fadeIn];
        }
        [host bringSubviewToFront:_ring];
        _ring.center = [self centroid];
        CGFloat span = MAX(_holdDuration - _ringDelay, 0.01);
        [_ring setProgress:(elapsed - _ringDelay) / span];
    }

    if (elapsed >= _holdDuration) {
        [self fire];
    }
}

- (void)fire {
    NSInteger count = [self currentCount];
    if (count != _timingCount || (self.fingerCountEnabled && !self.fingerCountEnabled(count))) {
        [self stopTimingFired:NO];
        return;
    }
    CGFloat screenHeight = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    CGFloat lowestY = 0;
    UIView *host = self.view;
    for (UITouch *touch in _tracked) {
        CGFloat y = [touch locationInView:host].y;
        if (y > lowestY) lowestY = y;
    }
    _lowestTouchPointHeight = screenHeight - lowestY;
    _recognizedFingerCount = count;
    [_firedTouches removeAllObjects];
    for (UITouch *touch in _tracked) [_firedTouches addObject:touch];

    [_haptic impactOccurred];
    [self stopTimingFired:YES];
    // Recognized -> UIKit cancels the tracked touches in the view (host release).
    self.state = UIGestureRecognizerStateRecognized;
}

- (void)reset {
    [super reset];
    [self stopTimingFired:NO];
    [_tracked removeAllObjects];
    [_anchors removeAllObjects];
    _roundInvalid = NO;
}

@end
