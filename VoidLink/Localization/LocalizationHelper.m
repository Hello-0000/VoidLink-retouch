//
//  LocalizationHelper.m
//  VoidLink
//
//  Created by True砖家 on 2024/6/30.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import "LocalizationHelper.h"

@implementation LocalizationHelper

/* Fallback localized strings for keys not found in Localizable.xcstrings.
 * This allows us to ship new strings without immediately editing the catalog.
 */
+ (NSString *)osc_languageCodePrefix {
    NSString *lang = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    if ([lang hasPrefix:@"zh"]) return @"zh";
    return @"en";
}

+ (NSDictionary *)osc_fallbackDictionaryForLanguage:(NSString *)prefix {
    static NSDictionary *zhDict; static NSDictionary *enDict; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zhDict = @{
            @"Palm Rejection": @"手掌误触过滤",
            @"Palm Radius Threshold": @"手掌判定半径",
            @"Pencil Hold": @"Pencil 长按",
            @"Long Press": @"长按",
            @"Long + Hard": @"长按+重按",
            @"Hard Only": @"仅重按",
            @"Pencil Hold Delay": @"Pencil 长按时长",
            @"Pencil Hard Press Threshold": @"Pencil 重按阈值",
            @"Pencil Scroll Points Per Notch": @"Pencil 滚动每格距离",
            @"Pencil Scroll Follows Tip": @"Pencil 滚动内容跟随笔尖",
            @"Pencil Scroll Zone Radius": @"Pencil 持续滚动起始距离",
            @"Pencil Scroll Max Speed": @"Pencil 持续滚动最高速度",
            @"PairingHelpTitle": @"配对布局说明",
            @"PairingHelpMessage": @"你可以提前创建好偏好的横屏和竖屏布局，在这里进行绑定。绑定后，旋转屏幕将在绑定的两个布局之间切换。\n注意：默认布局和模板布局不支持绑定。",
            @"Unpair": @"解除配对",
            @"BindOrientationLayout:%@": @"绑定%@布局",
            @"PortraitShort": @"竖屏",
            @"LandscapeShort": @"横屏",
            @"ConfirmDelete": @"确认删除",
            @"ConfirmDeleteProfile:%@": @"确定要删除布局'%@'吗？",
            @"DeleteTemplateNotAllowed:%@": @"删除'%@'模板布局是不被允许的",
            @"UnnamedProfile": @"未命名配置",
            @"OK": @"我知道了",
            @"Save": @"保存",
            @"Cancel": @"取消",
            @"CurrentLayoutShort": @"当前布局",
            @"SelectLayoutToPair:%@": @"选择要绑定的%@布局",
            @"LockToCurrentOrientation": @"锁定为当前方向布局",
            @"UnlockOrientation": @"解除锁定",
            @"LockOrientationHelpTitle": @"方向锁定说明",
            @"LockOrientationHelpMessage": @"点击后会把此布局锁定到当前屏幕方向。横屏和竖屏可各自锁定不同布局，旋转时系统会自动切换。",
            @"Open Settings": @"打开设置",
            @"Open Toolbox": @"打开工具箱",
            @"Soft Keyboard": @"软键盘",
            @"Layout Editor": @"布局编辑器",
            @"Show/Hide On-Screen Controls": @"显示/隐藏屏幕控件",
            @"Gesture Command": @"手势指令",
            @"Gesture Command Target": @"指令",
            @"Edge Swipe Distance": @"边缘滑动距离",
            @"Left Edge Swipe": @"左边缘滑动",
            @"Right Edge Swipe": @"右边缘滑动",
            @"3-Finger Hold": @"三指长按",
            @"4-Finger Hold": @"四指长按",
            @"5-Finger Hold": @"五指长按",
            @"Gesture Trigger Off": @"禁用",
            @"Pause Emulator When Away": @"离开时暂停模拟器",
            @"Not Set": @"未设置",
            @"Custom Command…": @"自定义指令…",
            @"Invalid Command": @"无效指令",
            @"Settings Section: Display": @"画面",
            @"Settings Section: Touch": @"触控",
            @"Settings Section: On-Screen Controls": @"屏幕控件",
            @"Settings Section: Controller": @"手柄",
            @"Settings Section: Apple Pencil": @"Apple Pencil",
            @"Settings Section: Mouse & Keyboard": @"鼠标与键盘",
            @"Settings Section: General": @"通用",
            @"Controller: Swap A/B": @"实体手柄：交换 A/B",
            @"Controller: Swap X/Y": @"实体手柄：交换 X/Y"
        };
        enDict = @{
            @"PairingHelpTitle": @"Pairing Help",
            @"PairingHelpMessage": @"You can pre-create preferred landscape and portrait layouts and pair them here. After pairing, rotating the device switches between the two layouts.\nNote: Default and template layouts do not support pairing.",
            @"Unpair": @"Unpair",
            @"BindOrientationLayout:%@": @"Pair %@",
            @"PortraitShort": @"Portrait",
            @"LandscapeShort": @"Landscape",
            @"ConfirmDelete": @"Confirm Delete",
            @"ConfirmDeleteProfile:%@": @"Are you sure you want to delete '%@'?",
            @"DeleteTemplateNotAllowed:%@": @"Deleting template layout '%@' is not allowed",
            @"UnnamedProfile": @"Untitled",
            @"OK": @"OK",
            @"Save": @"Save",
            @"Cancel": @"Cancel",
            @"CurrentLayoutShort": @"Current",
            @"SelectLayoutToPair:%@": @"Select layout to pair: %@",
            @"LockToCurrentOrientation": @"Lock to Current Orientation",
            @"UnlockOrientation": @"Unlock Orientation",
            @"LockOrientationHelpTitle": @"Orientation Lock Help",
            @"LockOrientationHelpMessage": @"Tapping will lock this layout to the current screen orientation. You can lock different layouts for Landscape and Portrait. The system will auto switch when rotating.",
            @"Open Settings": @"Open Settings",
            @"Open Toolbox": @"Open Toolbox",
            @"Soft Keyboard": @"Soft Keyboard",
            @"Layout Editor": @"Layout Editor",
            @"Show/Hide On-Screen Controls": @"Show/Hide On-Screen Controls",
            @"Gesture Command": @"Gesture Command",
            @"Gesture Command Target": @"Command",
            @"Edge Swipe Distance": @"Edge Swipe Distance",
            @"Left Edge Swipe": @"Left Edge Swipe",
            @"Right Edge Swipe": @"Right Edge Swipe",
            @"3-Finger Hold": @"3-Finger Hold",
            @"4-Finger Hold": @"4-Finger Hold",
            @"5-Finger Hold": @"5-Finger Hold",
            @"Gesture Trigger Off": @"Off",
            @"Pause Emulator When Away": @"Pause Emulator When Away",
            @"Not Set": @"Not Set",
            @"Custom Command…": @"Custom Command…",
            @"Invalid Command": @"Invalid Command",
            @"Settings Section: Display": @"Display",
            @"Settings Section: Touch": @"Touch",
            @"Settings Section: On-Screen Controls": @"On-Screen Controls",
            @"Settings Section: Controller": @"Controller",
            @"Settings Section: Apple Pencil": @"Apple Pencil",
            @"Settings Section: Mouse & Keyboard": @"Mouse & Keyboard",
            @"Settings Section: General": @"General",
            @"Controller: Swap A/B": @"Controller: Swap A/B",
            @"Controller: Swap X/Y": @"Controller: Swap X/Y"
        };
    });
    return [prefix isEqualToString:@"zh"] ? zhDict : enDict;
}

+ (NSString *)localizedStringForKey:(NSString *)key, ... {
    va_list args;
    va_start(args, key);

    NSString *format = NSLocalizedStringFromTable(key, @"Localizable", nil);
    if ([format isEqualToString:key]) { // not found in catalog, use fallback
        NSString *lang = [self osc_languageCodePrefix];
        NSString *fallback = [[self osc_fallbackDictionaryForLanguage:lang] objectForKey:key];
        if (fallback) {
            format = fallback;
        }
    }
    NSString *result = [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);
    return result;
}

@end
