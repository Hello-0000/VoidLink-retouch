//
//  ThemeManager.h
//  VoidLink
//
//  Created by True砖家 on 2025.5.25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ThemeManager:NSObject

@property (class, nonatomic, assign) UIUserInterfaceStyle userInterfaceStyle;
+ (UIColor *)appPrimaryColor;
+ (UIColor *)appSecondaryColor;
+ (UIColor *)appPrimaryColorWithAlpha;
+ (UIColor *)widgetBackgroundColor;
+ (UIColor *)appBackgroundColor;
+ (UIColor *)separatorColor;
+ (UIColor *)textColor;
+ (UIColor *)textColorGray;
+ (UIColor *)lowProfileGray;
+ (UIColor *)textTintColorWithAlpha;

// Settings sidebar tokens. Dynamic colors that resolve against the view's
// trait collection (dark / light); used only by the settings sidebar.
+ (UIColor *)sidebarBackground;
+ (UIColor *)sidebarCard;
+ (UIColor *)sidebarControlFill;   // switch off-state, slider track, segmented background
+ (UIColor *)sidebarSeparator;
+ (UIColor *)sidebarTextPrimary;
+ (UIColor *)sidebarTextSecondary;
+ (UIColor *)sidebarAccent;

@end

