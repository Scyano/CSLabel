//
//  NSString+HtmlTagRemove.h
//  youyushe
//
//  Created by Pan Xiao Ping on 14-9-4.
//  Copyright (c) 2014年 cimu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (CSHTML)
- (BOOL)isHTMLBlank;
- (NSString *)stringByRemoveHTMLTag;
- (NSString *)stringByRemoveNewlineCharacters;
- (NSString *)stringByReplaceLaTextToImageUrl;
@end
