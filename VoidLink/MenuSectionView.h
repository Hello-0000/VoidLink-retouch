//
//  MenuSectionView.h
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

// MenuSectionView.h

#import <UIKit/UIKit.h>
#import "DataManager.h"

@protocol MenuSectionDelegate <NSObject>
- (void)hideOverlappedDynamicLabels;
- (SettingsMenuMode)getSettingsMenuMode;
@end

// Inner left/right padding of a settings card; rows and separators line up on it.
extern const CGFloat MenuSectionRowInset;

// One settings group: a header (icon, title, fold chevron) above a rounded
// card holding the rows. Rows are separated by hairlines inside the card.
@interface MenuSectionView : UIView

// 外部可访问属性
@property (nonatomic, assign) CGFloat leadingTrailingPadding;
@property (nonatomic, assign) CGFloat separatorLinePadding;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) CGFloat rootStackViewSpacing;
@property (nonatomic, assign) CGFloat headerViewHeight;
@property (nonatomic, assign) CGFloat headerViewVerticalSpacing;
@property (nonatomic, strong) NSMutableArray<UIStackView *> *subStackViews;
@property (nonatomic, weak) id<MenuSectionDelegate> delegate; // Delegate property

// 方法
- (void)setSectionWithIcon:(UIImage *)icon andSize:(CGFloat)size;
- (void)addSubStackView:(UIStackView *)stack;
- (void)addToParentStack:(UIStackView *)parentStack;
- (void)removeSubStackView:(UIStackView *)stackView;
- (void)updateLayout;
- (void)updateViewForFoldState;

// Row metrics shared by sections and the favorites list: vertical padding,
// 44pt minimum height, a 16pt leading indent for dependent rows, controls
// centered in single-line rows. Safe to call repeatedly.
+ (void)styleRow:(UIStackView *)row indented:(BOOL)indented;
// Shows a hairline above every visible row except the first one in `container`.
+ (void)refreshSeparatorsInStack:(UIStackView *)container;

@end
