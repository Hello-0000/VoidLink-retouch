//
//  MenuSectionView.h
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//
// MenuSectionView.m

#import "MenuSectionView.h"
#import "ThemeManager.h"

const CGFloat MenuSectionRowInset = 16;

static const CGFloat MenuSectionRowVerticalPadding = 8;
static const CGFloat MenuSectionRowMinHeight = 44;
static const CGFloat MenuSectionCardCornerRadius = 12;
static const CGFloat MenuSectionCardVerticalPadding = 4;
static NSString *const MenuSectionRowSeparatorIdentifier = @"rowSeparator";
static NSString *const MenuSectionRowMinHeightIdentifier = @"rowMinHeight";

@interface MenuSectionView ()

@property (nonatomic, strong) UIStackView *rootStackView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *toggleArea;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) NSLayoutConstraint *expandedBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *collapsedBottomConstraint;

@end

@implementation MenuSectionView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _leadingTrailingPadding = 0;
    _separatorLinePadding = 22; // gap below the card, before the next section
    _sectionTitle = @"Section";
    _expanded = YES;
    _backgroundColor = [UIColor clearColor];
    _rootStackViewSpacing = 0;
    _subStackViews = [NSMutableArray array];
    _headerViewHeight = 37;
    _headerViewVerticalSpacing = 6;

    self.backgroundColor = _backgroundColor;

    // Header: icon, title, fold chevron
    _headerView = [[UIView alloc] init];
    _headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_headerView];

    _iconImageView = [[UIImageView alloc] init];
    _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    _iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconImageView.tintColor = [ThemeManager sidebarTextPrimary];
    [_headerView addSubview:_iconImageView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = _sectionTitle;
    _titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    _titleLabel.textColor = [ThemeManager sidebarTextPrimary];
    _titleLabel.textAlignment = NSTextAlignmentLeft;
    _titleLabel.accessibilityIdentifier = @"sectionTitle"; // keeps the theme pass off it
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerView addSubview:_titleLabel];

    _toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _toggleArea = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:_headerViewHeight*0.31 weight:UIImageSymbolWeightBold];
    [_toggleButton setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:config] forState:UIControlStateNormal];
    _toggleButton.tintColor = [ThemeManager sidebarTextSecondary];
    [_toggleButton addTarget:self action:@selector(toggleFold) forControlEvents:UIControlEventTouchUpInside];
    [_toggleArea addTarget:self action:@selector(toggleFold) forControlEvents:UIControlEventTouchUpInside];
    _toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    _toggleArea.translatesAutoresizingMaskIntoConstraints = NO;
    [_headerView addSubview:_toggleButton];
    [_headerView addSubview:_toggleArea];

    // Card holding the rows
    _cardView = [[UIView alloc] init];
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    _cardView.backgroundColor = [ThemeManager sidebarCard];
    _cardView.layer.cornerRadius = MenuSectionCardCornerRadius;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:_cardView];

    _rootStackView = [[UIStackView alloc] init];
    _rootStackView.axis = UILayoutConstraintAxisVertical;
    _rootStackView.spacing = _rootStackViewSpacing;
    _rootStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_rootStackView];

    [self setupConstraints];
    [self updateViewForFoldState];
}

- (void)setupConstraints {
    CGFloat iconSize = _headerViewHeight - 6;
    [NSLayoutConstraint activateConstraints:@[
        [_headerView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_headerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_headerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_headerView.heightAnchor constraintEqualToConstant:_headerViewHeight],

        [_iconImageView.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor constant:4],
        [_iconImageView.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        [_iconImageView.widthAnchor constraintEqualToConstant:iconSize],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconImageView.trailingAnchor constant:8],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_toggleButton.leadingAnchor constant:-8],

        [_toggleButton.trailingAnchor constraintEqualToAnchor:_headerView.trailingAnchor constant:-4],
        [_toggleButton.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        [_toggleButton.widthAnchor constraintEqualToConstant:_headerViewHeight*0.8],
        [_toggleButton.heightAnchor constraintEqualToConstant:_headerViewHeight*0.8],

        [_toggleArea.leadingAnchor constraintEqualToAnchor:_headerView.leadingAnchor],
        [_toggleArea.centerYAnchor constraintEqualToAnchor:_headerView.centerYAnchor],
        [_toggleArea.trailingAnchor constraintEqualToAnchor:_toggleButton.leadingAnchor],
        [_toggleArea.heightAnchor constraintEqualToConstant:_headerViewHeight],

        [_cardView.topAnchor constraintEqualToAnchor:_headerView.bottomAnchor constant:_headerViewVerticalSpacing],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [_rootStackView.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:MenuSectionCardVerticalPadding],
        [_rootStackView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-MenuSectionCardVerticalPadding],
        [_rootStackView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:MenuSectionRowInset],
        [_rootStackView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-MenuSectionRowInset],
    ]];
    _expandedBottomConstraint = [_cardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-_separatorLinePadding];
    _collapsedBottomConstraint = [_headerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-_headerViewVerticalSpacing];
}

#pragma mark - Row styling

+ (void)styleRow:(UIStackView *)row indented:(BOOL)indented {
    if (!row) return;
    // Storyboard rows carry fixed widths (380pt) from the old free-standing
    // layout; inside a card the row width comes from the card.
    NSMutableArray<NSLayoutConstraint *> *fixedWidths = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in row.constraints) {
        if (constraint.firstItem == row && constraint.firstAttribute == NSLayoutAttributeWidth
            && constraint.secondItem == nil && constraint.active) [fixedWidths addObject:constraint];
    }
    [NSLayoutConstraint deactivateConstraints:fixedWidths];
    row.layoutMarginsRelativeArrangement = YES;
    row.layoutMargins = UIEdgeInsetsMake(MenuSectionRowVerticalPadding, indented ? MenuSectionRowInset : 0, MenuSectionRowVerticalPadding, 0);
    if (row.axis == UILayoutConstraintAxisHorizontal) row.alignment = UIStackViewAlignmentCenter;

    BOOL hasMinHeight = NO;
    for (NSLayoutConstraint *constraint in row.constraints) {
        if ([constraint.identifier isEqualToString:MenuSectionRowMinHeightIdentifier]) { hasMinHeight = YES; break; }
    }
    if (!hasMinHeight) {
        // Below required so a hidden row can still collapse to zero height.
        NSLayoutConstraint *minHeight = [row.heightAnchor constraintGreaterThanOrEqualToConstant:MenuSectionRowMinHeight];
        minHeight.priority = UILayoutPriorityRequired - 1;
        minHeight.identifier = MenuSectionRowMinHeightIdentifier;
        minHeight.active = YES;
    }
    [self separatorForRow:row];
}

+ (UIView *)separatorForRow:(UIStackView *)row {
    for (UIView *view in row.subviews) {
        if ([view.accessibilityIdentifier isEqualToString:MenuSectionRowSeparatorIdentifier]) return view;
    }
    UIView *separator = [[UIView alloc] init];
    separator.accessibilityIdentifier = MenuSectionRowSeparatorIdentifier;
    separator.userInteractionEnabled = NO;
    separator.backgroundColor = [ThemeManager sidebarSeparator];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.hidden = YES;
    [row addSubview:separator];
    CGFloat scale = UIScreen.mainScreen.scale > 0 ? UIScreen.mainScreen.scale : 2;
    // Starts at the row's text edge (16pt into the card) and runs to the card's edge.
    [NSLayoutConstraint activateConstraints:@[
        [separator.topAnchor constraintEqualToAnchor:row.topAnchor],
        [separator.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:MenuSectionRowInset],
        [separator.heightAnchor constraintEqualToConstant:1.0 / scale],
    ]];
    return separator;
}

+ (void)refreshSeparatorsInStack:(UIStackView *)container {
    BOOL first = YES;
    for (UIView *view in container.arrangedSubviews) {
        if (![view isKindOfClass:[UIStackView class]]) continue;
        UIView *separator = [self separatorForRow:(UIStackView *)view];
        if (view.hidden) { separator.hidden = YES; continue; }
        separator.hidden = first;
        first = NO;
    }
}

#pragma mark - Public Methods

- (void)setSectionWithIcon:(UIImage *)icon andSize:(CGFloat)size{
    UIImageSymbolConfiguration *config;
    if(icon.isSymbolImage) config = [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold];
    else{
        config = [UIImageSymbolConfiguration configurationWithPointSize:size];
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    _iconImageView.image = [icon imageWithConfiguration:config];
    _iconImageView.tintColor = [ThemeManager sidebarTextPrimary];
    _iconImageView.hidden = (icon == nil);
}

- (void)setLeadingTrailingPadding:(CGFloat)leadingTrailingPadding {
    _leadingTrailingPadding = leadingTrailingPadding;
}

- (void)setSectionTitle:(NSString *)sectionTitle {
    _sectionTitle = sectionTitle;
    _titleLabel.text = sectionTitle;
}

- (void)setExpanded:(BOOL)isExpanded {
    _expanded = isExpanded;
    [self updateViewForFoldState];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    _backgroundColor = backgroundColor;
}

- (void)setRootStackViewSpacing:(CGFloat)rootStackViewSpacing {
    _rootStackViewSpacing = rootStackViewSpacing;
    _rootStackView.spacing = rootStackViewSpacing;
}

- (void)addSubStackView:(UIStackView *)stackView {
    if (!stackView) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [UIView performWithoutAnimation:^{
        if (![self->_subStackViews containsObject:stackView]) {
            [self->_subStackViews addObject:stackView];
            [self->_rootStackView addArrangedSubview:stackView];
        }
    }];
    [CATransaction commit];
}

- (void)addToParentStack:(UIStackView *)parentStack {
    [parentStack insertArrangedSubview:self atIndex:parentStack.arrangedSubviews.count];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.leadingAnchor constraintEqualToAnchor:parentStack.leadingAnchor constant:0],
        [self.trailingAnchor constraintEqualToAnchor:parentStack.trailingAnchor constant:0],
    ]];
}

- (void)removeSubStackView:(UIStackView *)stackView {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if ([_subStackViews containsObject:stackView]) {
        [_subStackViews removeObject:stackView];
        [_rootStackView removeArrangedSubview:stackView];
        [stackView removeFromSuperview];
        [self updateViewForFoldState];
    }
    [CATransaction commit];
}

- (void)updateLayout {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Private Methods

- (void)toggleFold {
    self.expanded = !self.expanded;
}

- (SettingsMenuMode)getSettingsMenuMode {
    if ([self.delegate respondsToSelector:@selector(getSettingsMenuMode)]) {
        return [self.delegate getSettingsMenuMode];
    } else return AllSettings;
}

// Self-sizing: the section's height follows its header and (when expanded)
// its card; hidden rows collapse inside the card's stack.
- (void)updateViewForFoldState {
    NSInteger visibleCount = 0;
    for (UIView *subview in _rootStackView.arrangedSubviews) {
        if (!subview.isHidden) visibleCount++;
    }
    self.hidden = visibleCount == 0;

    [MenuSectionView refreshSeparatorsInStack:_rootStackView];

    _cardView.hidden = !_expanded;
    if (_expanded) {
        _collapsedBottomConstraint.active = NO;
        _expandedBottomConstraint.active = YES;
        _toggleButton.transform = CGAffineTransformMakeRotation(M_PI+M_PI_2);
    } else {
        _expandedBottomConstraint.active = NO;
        _collapsedBottomConstraint.active = YES;
        _toggleButton.transform = CGAffineTransformIdentity;
    }
    [self setNeedsLayout];

    if ([self.delegate respondsToSelector:@selector(hideOverlappedDynamicLabels)]) {
        [self.delegate hideOverlappedDynamicLabels];
    }
}

@end
