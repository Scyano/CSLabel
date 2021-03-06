//
//  CSLabel.m
//  CSLabel
//
//  Created by Pan Xiao Ping on 15/11/4.
//  Copyright © 2015年 Cimu. All rights reserved.
//

#import "CSLabel.h"

NSString* const CSLinkAttributeName = @"CSLinkAttributeName";

@interface CSLabel() <UIGestureRecognizerDelegate, NSLayoutManagerDelegate>
{
@private
    BOOL _needUpdateDisplay;
    BOOL _shouldLoadAttachments;
}
@property (strong, nonatomic) NSLayoutManager *layoutManager;
@property (strong, nonatomic) NSTextStorage *textStorage;
@property (strong, nonatomic) NSTextContainer *textContainer;

@property (strong, nonatomic) NSArray *links;
@property (strong, nonatomic) CSTextLink *activeLink;
@end

@implementation CSLabel

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.textStorage = [NSTextStorage new];
    
    self.layoutManager = [NSLayoutManager new];
    self.layoutManager.allowsNonContiguousLayout = NO;
    self.layoutManager.delegate = self;
    
    self.textContainer = [NSTextContainer new];
    self.textContainer.maximumNumberOfLines = 0;
    self.textContainer.lineFragmentPadding = 0.0f;
    self.textContainer.lineBreakMode = NSLineBreakByWordWrapping;
    self.textContainer.size = (CGSize){CGFLOAT_MAX , CGFLOAT_MAX};
    
    [self.textStorage addLayoutManager:self.layoutManager];
    [self.layoutManager addTextContainer:self.textContainer];
    [self.layoutManager ensureLayoutForTextContainer:self.textContainer];
    
    self.contentInset = UIEdgeInsetsZero;
    self.userInteractionEnabled = YES;
    self.backgroundColor = [UIColor clearColor];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_attachemntDidUpdatedNotify:) name:CSTextAttachmentDidDownloadNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_attachemntDidUpdatedNotify:) name:CSTextAttachmentFailedDownloadNotification object:nil];
    
}

#pragma mark - private

- (void)_attachemntDidUpdatedNotify:(NSNotification *)notification
{
    if (!self.superview) {
        return;
    }
    CSTextAttachment *notiAttachment = notification.object;
    
    NSMutableSet *updatedRangeSet = [NSMutableSet set];
    [self.attributedText enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, self.attributedText.length) options:0 usingBlock:^(CSTextAttachment * _Nullable attachment, NSRange range, BOOL * _Nonnull stop) {
        if ([attachment isKindOfClass:CSTextAttachment.class] && [attachment.contentURL isEqualToString:notiAttachment.contentURL]) {
            [updatedRangeSet addObject:[NSValue valueWithRange:range]];
        }
    }];
    
    if (updatedRangeSet.count) {
        [updatedRangeSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSRange range = [obj rangeValue];
            [self.layoutManager invalidateLayoutForCharacterRange:range actualCharacterRange:NULL];
        }];
        
        [self setNeedsUpdateIntrinsicContentSize];
        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout];
        
        [updatedRangeSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSRange range = [obj rangeValue];
            if ([self.delegate respondsToSelector:@selector(CSLabelDidUpdateAttachment:atRange:)]) {
                [self.delegate CSLabelDidUpdateAttachment:self atRange:range];
            }
        }];
    }
}

- (CSTextLink *)_linkAtPoint:(CGPoint)location {
    location.x -= self.contentInset.left;
    location.y -= self.contentInset.top;
    NSUInteger glyphIdx = [self.layoutManager glyphIndexForPoint:location inTextContainer:self.textContainer];
    
    //apple文档上写有说 如果location的区域没字形，可能返回的是最近的字形index，所以我们再找到这个字形所处于的rect来确认
    CGRect glyphRect = [self.layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIdx, 1) inTextContainer:self.textContainer];
    if (!CGRectContainsPoint(glyphRect, location))
        return nil;
    
    NSUInteger charIndex = [self.layoutManager characterIndexForGlyphAtIndex:glyphIdx];
    
    for (CSTextLink *link in self.links) {
        if (NSLocationInRange(charIndex , link.range)) {
            link.glyphRect = glyphRect;
            return link;
        }
    }
    return nil;
}

#pragma mark - touches

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    self.activeLink = [self _linkAtPoint:[touch locationInView:self]];
    
    if (!self.activeLink) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.activeLink) {
        UITouch *touch = [touches anyObject];
        if (![self.activeLink isEqual:[self _linkAtPoint:[touch locationInView:self]]]) {
            self.activeLink = nil;
        }
    } else {
        [super touchesMoved:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.activeLink) {
        self.activeLink = nil;
    } else {
        [super touchesCancelled:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.activeLink) {
        if ([self.delegate respondsToSelector:@selector(CSLabel:didSelectLink:)]) {
            [self.delegate CSLabel:self didSelectLink:self.activeLink];
        }
        self.activeLink = nil;
    } else {
        [super touchesEnded:touches withEvent:event];
    }
}

#pragma mark - sizeThatFits

- (CGSize)sizeThatFits:(CGSize)size
{
    if (_attributedText == nil) {
        return CGSizeZero;
    }
    size.width -= self.contentInset.left + self.contentInset.right;
    size.width = size.width > 0 ? size.width : FLT_MAX;
    size.height -= self.contentInset.top + self.contentInset.bottom;
    size.height = size.height > 0 ? size.height : FLT_MAX;
    
    _textContainer.size = size;
    
    CGSize resultSize = [_layoutManager usedRectForTextContainer:_textContainer].size;
    resultSize.width += self.contentInset.left + self.contentInset.right;
    resultSize.height += self.contentInset.top + self.contentInset.bottom;
    
    return CGSizeMake(ceil(resultSize.width), ceil(resultSize.height));
}

- (CGSize)intrinsicContentSize
{
    return [self sizeThatFits:CGSizeMake(self.preferredLayoutWidth, -1)];
}

#pragma mark - setter

- (void)setActiveLink:(CSTextLink *)activeLink {
    if (_activeLink != activeLink) {
        CSTextLink *oldLink = _activeLink;
        _activeLink = activeLink;
        
        if (oldLink.type == CSTextLinkTypeURL || activeLink.type == CSTextLinkTypeURL) {
            _needUpdateDisplay = YES;
            [self setNeedsDisplay];
        }
    }
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    _contentInset = contentInset;
    [self setNeedsUpdateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    _attributedText = [attributedText copy];
    
    NSMutableArray *links = [NSMutableArray array];
    [self.attributedText enumerateAttributesInRange:NSMakeRange(0, self.attributedText.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        NSAttributedString *attrinbutedString = [_attributedText attributedSubstringFromRange:range];
        if (attrs[NSLinkAttributeName]) {
            CSTextLink *link = [CSTextLink new];
            link.type = CSTextLinkTypeURL;
            link.attributedDictionary = [attrinbutedString attributesAtIndex:0 effectiveRange:nil];
            link.text = attributedText.string;
            link.range = range;
            [links addObject:link];
        }
        if (attrs[NSAttachmentAttributeName]) {
            CSTextLink *link = [CSTextLink new];
            link.type = CSTextLinkTypeImage;
            link.attributedDictionary = [attrinbutedString attributesAtIndex:0 effectiveRange:nil];
            link.text = attributedText.string;
            link.range = range;
            [links addObject:link];
        }
    }];
    self.links = [links copy];
    self.activeLink = nil;
    
    NSMutableAttributedString *drawText = [[NSMutableAttributedString alloc] initWithAttributedString:_attributedText];
    [drawText enumerateAttributesInRange:NSMakeRange(0, drawText.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        if (attrs[NSLinkAttributeName]) {
            NSMutableDictionary *mutableLinkAttributes = [attrs mutableCopy];
            [mutableLinkAttributes setValue:attrs[NSLinkAttributeName] forKey:CSLinkAttributeName];
            [mutableLinkAttributes removeObjectForKey:NSLinkAttributeName];
            [mutableLinkAttributes setValue:self.linkTextColor ?: [[self.class appearance] linkTextColor] ?: [UIColor blueColor] forKey:NSForegroundColorAttributeName];
            [drawText setAttributes:mutableLinkAttributes range:range];
        }
    }];
    
    [self.textStorage setAttributedString:drawText];
    [self setNeedsUpdateIntrinsicContentSize];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)setPreferredLayoutWidth:(CGFloat)preferredLayoutWidth {
    if (_preferredLayoutWidth != preferredLayoutWidth) {
        _preferredLayoutWidth = preferredLayoutWidth;
        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout];
    }
}

- (void)setNeedsAttachmentsLoad {
    [self.attributedText enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, self.attributedText.length) options:0 usingBlock:^(CSTextAttachment * _Nullable attachment, NSRange range, BOOL * _Nonnull stop) {
        if ([attachment isKindOfClass:CSTextAttachment.class]) {
            [attachment setNeedsLoad];
        }
    }];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    _shouldLoadAttachments = newWindow != nil;
}

#pragma mark - layout

- (void)invalidateIntrinsicContentSize {
    _needUpdateDisplay = YES;
    [super invalidateIntrinsicContentSize];
}

- (void)setNeedsUpdateIntrinsicContentSize {
    _needUpdateDisplay = YES;
    _preferredLayoutWidth = -1;
}

- (void)layoutSubviews {
    if (self.preferredLayoutWidth != self.bounds.size.width) {
        self.preferredLayoutWidth = self.bounds.size.width;
        return;
    }
    
    self.textContainer.size = UIEdgeInsetsInsetRect(self.bounds, self.contentInset).size;
    [super layoutSubviews];
    [self setNeedsDisplay];
    
    if (_shouldLoadAttachments) {
        [self setNeedsAttachmentsLoad];
    }
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    if (layer == self.layer) {
        [layer removeAllAnimations];
    }
    [super layoutSublayersOfLayer:layer];
}

- (void)setNeedsDisplay {
    if (_needUpdateDisplay) {
        [super setNeedsDisplay];
        _needUpdateDisplay = NO;
    }
}

#pragma mark - draw

- (void)drawRect:(CGRect)rect {
    if (self.activeLink) {
        [self.attributedText enumerateAttributesInRange:NSMakeRange(0, self.attributedText.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            if (_activeLink.type == CSTextLinkTypeURL && NSEqualRanges(self.activeLink.range, range)) {
                [self drawActiveLinkBackgroundAtRange:range];
                *stop = YES;
            }
        }];
    }
    
    CGRect textFrame = UIEdgeInsetsInsetRect(self.bounds, self.contentInset);
    NSRange glyphRange = [_layoutManager glyphRangeForTextContainer:_textContainer];
    
    [_layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:textFrame.origin];
    [_layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:textFrame.origin];
}

- (void)drawActiveLinkBackgroundAtRange:(NSRange)range
{
    NSParagraphStyle *paragraph = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:range.location effectiveRange:nil];
    CGFloat fixY = paragraph.lineSpacing;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
    [self.layoutManager enumerateEnclosingRectsForGlyphRange:glyphRange withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0) inTextContainer:self.textContainer usingBlock:^(CGRect rect, BOOL *stop) {
        
        rect.origin.x += self.contentInset.left;
        rect.origin.y += self.contentInset.top;
        rect.origin.x = ceil(rect.origin.x);
        rect.origin.y = ceil(rect.origin.y);
        rect.size.width = ceil(rect.size.width);
        rect.size.height = ceil(rect.size.height - fixY);
        
        CGContextAddPath(context, [UIBezierPath bezierPathWithRect:rect].CGPath);
        CGContextSetFillColorWithColor(context, [[[UIColor lightGrayColor] colorWithAlphaComponent:0.8] CGColor]);
        CGContextFillPath(context);
    }];
}

#pragma mark - layoutManager delegate

- (BOOL)layoutManager:(NSLayoutManager *)layoutManager shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)charIndex {
    for (CSTextLink *link in self.links) {
        if (NSLocationInRange(charIndex, link.range)) {
            return NO;
        }
    }
    return YES;
}

@end

@implementation CSLabel (HTML)

- (void)setHTML:(NSString *)html withAttributes:(NSDictionary *)attrs {
    self.attributedText = [[NSAttributedString alloc] initWithHTML:html attributes:attrs];
}

@end