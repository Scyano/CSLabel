//
//  CSLabel.h
//  CSLabel
//
//  Created by Pan Xiao Ping on 15/11/4.
//  Copyright © 2015年 Cimu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSTextLink.h"
#import "CSTextAttachment.h"
#import "CSHTMLReader.h"

@class CSLabel;

@protocol CSLabelDelegate <NSObject>
@optional

/**
 *  图片下载完毕刷新回调
 *
 *  @param label CSLabel instance
 */
- (void)CSLabelDidUpdateAttachment:(CSLabel *)label atRange:(NSRange)range;


/**
 *  超链接，包含图片类型
 *
 *  @param label CSLabel instance
 *  @param link  包含 link type, link range, link glyphRect, link attributedString
 */
- (void)CSLabel:(CSLabel *)label didSelectLink:(CSTextLink *)link;
@end

@interface CSLabel : UIView
@property(weak)      id <CSLabelDelegate> delegate;
@property(nonatomic) NSAttributedString *attributedText;
@property(nonatomic) UIColor *linkTextColor    UI_APPEARANCE_SELECTOR;
@property(nonatomic) UIEdgeInsets contentInset;

@property(nonatomic) CGFloat preferredLayoutWidth;
@end


@interface CSLabel (HTML)
/**
 *  加载HTML
 *
 *  @param HTML  纯HTML字符串，无css
 *  @param attrs Attributes
 */
- (void)setHTML:(NSString *)html withAttributes:(NSDictionary *)attrs;
@end