/*
   NSScrollView.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: July 1997
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: October 1998
   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: February 1999

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <gnustep/gui/config.h>
#include <math.h>

#include <Foundation/NSException.h>
#include <AppKit/NSScroller.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSClipView.h>
#include <AppKit/NSScrollView.h>
#include <AppKit/NSRulerView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/PSOperators.h>

@implementation NSScrollView

/*
 * Class variables
 */
static Class rulerViewClass = nil;

/*
 * Class methods
 */
+ (void) initialize
{
  if (self == [NSScrollView class])
    {
      NSDebugLog(@"Initialize NSScrollView class\n");
      [self setVersion: 1];
    }
}

+ (void) setRulerViewClass: (Class)aClass
{
  rulerViewClass = aClass;
}

+ (Class) rulerViewClass
{
  return rulerViewClass;
}

+ (NSSize) contentSizeForFrameSize: (NSSize)frameSize
	     hasHorizontalScroller: (BOOL)hFlag
	       hasVerticalScroller: (BOOL)vFlag
			borderType: (NSBorderType)borderType
{
  NSSize size = frameSize;

  /*
   * Substract 1 from the width and height of
   * the line that separates the horizontal
   * and vertical scroller from the clip view
   */
  if (hFlag)
    {
      size.height -= [NSScroller scrollerWidth];
      size.height -= 1;
    }
  if (vFlag)
    {
      size.width -= [NSScroller scrollerWidth];
      size.width -= 1;
    }

  switch (borderType)
    {
      case NSNoBorder:
	break;

      case NSLineBorder:
	size.width -= 2;
	size.height -= 2;
	break;

      case NSBezelBorder:
      case NSGrooveBorder:
	size.width -= 4;
	size.height -= 4;
	break;
    }

  return size;
}

+ (NSSize) frameSizeForContentSize: (NSSize)contentSize
	     hasHorizontalScroller: (BOOL)hFlag
	       hasVerticalScroller: (BOOL)vFlag
			borderType: (NSBorderType)borderType
{
  NSSize size = contentSize;

  /*
   * Add 1 to the width and height for the line that separates the
   * horizontal and vertical scroller from the clip view.
   */
  if (hFlag)
    {
      size.height += [NSScroller scrollerWidth];
      size.height += 1;
    }
  if (vFlag)
    {
      size.width += [NSScroller scrollerWidth];
      size.width += 1;
    }

  switch (borderType)
    {
      case NSNoBorder:
	break;

      case NSLineBorder:
	size.width += 2;
	size.height += 2;
	break;

      case NSBezelBorder:
      case NSGrooveBorder:
	size.width += 4;
	size.height += 4;
	break;
    }

  return size;
}

/*
 * Instance methods
 */
- (id) initWithFrame: (NSRect)rect
{
  [super initWithFrame: rect];
  [self setContentView: AUTORELEASE([NSClipView new])];
  _hLineScroll = 10;
  _hPageScroll = 10;
  _vLineScroll = 10;
  _vPageScroll = 10;
  _borderType = NSBezelBorder;
  _scrollsDynamically = YES;
  [self tile];

  return self;
}

- (id) init
{
  return [self initWithFrame: NSZeroRect];
}

- (void) dealloc
{
  TEST_RELEASE(_contentView);

  TEST_RELEASE(_horizScroller);
  TEST_RELEASE(_vertScroller);
  TEST_RELEASE(_horizRuler);
  TEST_RELEASE(_vertRuler);

  [super dealloc];
}

- (BOOL) isFlipped
{
  return YES;
}

- (void) setContentView: (NSClipView*)aView
{
  ASSIGN((id)_contentView, (id)aView);
  [self addSubview: _contentView];
  [_contentView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [self tile];
}

- (void) setHorizontalScroller: (NSScroller*)aScroller
{
  [_horizScroller removeFromSuperview];

  /*
   * Do not add the scroller view to the subviews array yet;
   * -setHasHorizontalScroller must be invoked first
   */
  ASSIGN(_horizScroller, aScroller);
  if (_horizScroller)
    {
      [_horizScroller setAutoresizingMask: NSViewWidthSizable];
      [_horizScroller setTarget: self];
      [_horizScroller setAction: @selector(_doScroll:)];
    }
}

- (void) setHasHorizontalScroller: (BOOL)flag
{
  if (_hasHorizScroller == flag)
    return;

  _hasHorizScroller = flag;

  if (_hasHorizScroller)
    {
      if (!_horizScroller)
	[self setHorizontalScroller: AUTORELEASE([NSScroller new])];
      [self addSubview: _horizScroller];
    }
  else
    [_horizScroller removeFromSuperview];

  [self tile];
}

- (void) setVerticalScroller: (NSScroller*)aScroller
{
  [_vertScroller removeFromSuperview];

  /*
   * Do not add the scroller view to the subviews array yet;
   * -setHasVerticalScroller must be invoked first
   */
  ASSIGN(_vertScroller, aScroller);
  if (_vertScroller)
    {
      [_vertScroller setAutoresizingMask: NSViewHeightSizable];
      [_vertScroller setTarget: self];
      [_vertScroller setAction: @selector(_doScroll:)];
    }
}

- (void) setHasVerticalScroller: (BOOL)flag
{
  if (_hasVertScroller == flag)
    return;

  _hasVertScroller = flag;

  if (_hasVertScroller)
    {
      if (!_vertScroller)
	{
	  [self setVerticalScroller: AUTORELEASE([NSScroller new])];
	  if (_contentView && !_contentView->_rFlags.flipped_view)
	    [_vertScroller setFloatValue: 1];
	}
      [self addSubview: _vertScroller];
    }
  else
    [_vertScroller removeFromSuperview];

  [self tile];
}

- (void) _doScroll: (NSScroller*)scroller
{
  float		floatValue = [scroller floatValue];
  NSRect	clipViewBounds = [_contentView bounds];
  NSScrollerPart hitPart = [scroller hitPart];
  NSRect	documentRect = [_contentView documentRect];
  float		amount = 0;
  NSPoint	point = clipViewBounds.origin;

  NSDebugLog (@"_doScroll: float value = %f", floatValue);

  /* do nothing if scroller is unknown */
  if (scroller != _horizScroller && scroller != _vertScroller)
    return;

  _knobMoved = NO;

  if (hitPart == NSScrollerKnob || hitPart == NSScrollerKnobSlot)
    _knobMoved = YES;
  else
    {
      if (hitPart == NSScrollerIncrementLine)
	{
	  if (scroller == _horizScroller)
	    amount = _hLineScroll;
	  else
	    amount = _vLineScroll;
	}
      else if (hitPart == NSScrollerDecrementLine)
	{
	  if (scroller == _horizScroller)
	    amount = -_hLineScroll;
	  else
	    amount = -_vLineScroll;
	}
      else if (hitPart == NSScrollerIncrementPage)
	{
	  if (scroller == _horizScroller)
	    amount = clipViewBounds.size.width - _hPageScroll;
	  else
	    amount = clipViewBounds.size.height - _vPageScroll;
	}
      else if (hitPart == NSScrollerDecrementPage)
	{
	  if (scroller == _horizScroller)
	    amount = _hPageScroll - clipViewBounds.size.width;
	  else
	    amount = _vPageScroll - clipViewBounds.size.height;
	}
      else
	{
	  return;
	}
    }

  if (!_knobMoved)	/* button scrolling */
    {
      if (scroller == _horizScroller)
	{
	  point.x = clipViewBounds.origin.x + amount;
	}
      else
	{
	  if (!_contentView->_rFlags.flipped_view)
	    {
	      /* If view is flipped reverse the scroll direction */
	      amount = -amount;
	    }
	  NSDebugLog (@"increment/decrement: amount = %f, flipped = %d",
			   amount, _contentView->_rFlags.flipped_view);
	  point.y = clipViewBounds.origin.y + amount;
	}
    }
  else 	/* knob scolling */
    {
      if (scroller == _horizScroller)
	{
	  point.x = floatValue * (documentRect.size.width
			      		- clipViewBounds.size.width);
	  point.x += documentRect.origin.x;
	}
      else
	{
	  if (!_contentView->_rFlags.flipped_view)
	    floatValue = 1 - floatValue;
	  point.y = floatValue * (documentRect.size.height
		     			- clipViewBounds.size.height);
	  point.y += documentRect.origin.y;
	}
    }

  [_contentView scrollToPoint: point];
}

- (void) reflectScrolledClipView: (NSClipView*)aClipView
{
  NSRect documentFrame = NSZeroRect;
  NSRect clipViewBounds = NSZeroRect;
  float floatValue;
  float knobProportion;
  id documentView;

  if (aClipView != _contentView)
    return;

  NSDebugLog (@"reflectScrolledClipView:");

  clipViewBounds = [_contentView bounds];
  if ((documentView = [_contentView documentView]))
    documentFrame = [documentView frame];

  if (_hasVertScroller)
    {
      if (documentFrame.size.height <= clipViewBounds.size.height)
	[_vertScroller setEnabled: NO];
      else
	{
	  [_vertScroller setEnabled: YES];
	  knobProportion = clipViewBounds.size.height
	    / documentFrame.size.height;
	  floatValue = (clipViewBounds.origin.y - documentFrame.origin.y)
	    / (documentFrame.size.height - clipViewBounds.size.height);
	  if (!_contentView->_rFlags.flipped_view)
	    floatValue = 1 - floatValue;
	  [_vertScroller setFloatValue: floatValue
			knobProportion: knobProportion];
	}
    }

  if (_hasHorizScroller)
    {
      if (documentFrame.size.width <= clipViewBounds.size.width)
	[_horizScroller setEnabled: NO];
      else
	{
	  [_horizScroller setEnabled: YES];
	  knobProportion = clipViewBounds.size.width
	    / documentFrame.size.width;
	  floatValue = (clipViewBounds.origin.x - documentFrame.origin.x)
	    / (documentFrame.size.width - clipViewBounds.size.width);
	  [_horizScroller setFloatValue: floatValue
			 knobProportion: knobProportion];
	}
    }
}

- (void) setHorizontalRulerView: (NSRulerView*)aRulerView	// FIX ME
{
  ASSIGN(_horizRuler, aRulerView);
}

- (void) setHasHorizontalRuler: (BOOL)flag			// FIX ME
{
  if (_hasHorizRuler == flag)
    return;

  _hasHorizRuler = flag;
}

- (void) setVerticalRulerView: (NSRulerView*)ruler		// FIX ME
{
  ASSIGN(_vertRuler, ruler);
}

- (void) setHasVerticalRuler: (BOOL)flag			// FIX ME
{
  if (_hasVertRuler == flag)
    return;

  _hasVertRuler = flag;
}

- (void) setRulersVisible: (BOOL)flag
{
}

- (void) setFrame: (NSRect)rect
{
  [super setFrame: rect];
  [self tile];
}

- (void) setFrameSize: (NSSize)size
{
  [super setFrameSize: size];
  [self tile];
}

- (void) tile
{
  NSRect boundsRect = [self bounds];
  NSSize contentSize = [isa contentSizeForFrameSize: boundsRect.size
			      hasHorizontalScroller: _hasHorizScroller
				hasVerticalScroller: _hasVertScroller
					 borderType: _borderType];
  float scrollerWidth = [NSScroller scrollerWidth];
  NSRect contentRect = { NSZeroPoint, contentSize };
  NSRect vertScrollerRect = NSZeroRect;
  NSRect horizScrollerRect = NSZeroRect;
  float borderThickness = 0;

  switch ([self borderType])
    {
      case NSNoBorder:
	break;

      case NSLineBorder:
	borderThickness = 1;
	break;

      case NSBezelBorder:
      case NSGrooveBorder:
	borderThickness = 2;
	break;
    }

  contentRect.origin.x = borderThickness;
  contentRect.origin.y = borderThickness;

  if (_hasVertScroller)
    {
      vertScrollerRect.origin.x = boundsRect.origin.x + borderThickness;
      vertScrollerRect.origin.y = boundsRect.origin.y + borderThickness;
      vertScrollerRect.size.width = scrollerWidth;
      vertScrollerRect.size.height =bounds.size.height - 2 * borderThickness;

      contentRect.origin.x += scrollerWidth + 1;
    }

  if (_hasHorizScroller)
    {
      horizScrollerRect.origin.x = contentRect.origin.x;
      horizScrollerRect.origin.y = boundsRect.origin.y + borderThickness;
      horizScrollerRect.size.width = contentRect.size.width;
      horizScrollerRect.size.height = scrollerWidth;

      if (_rFlags.flipped_view)
	{
	  horizScrollerRect.origin.y += contentRect.size.height + 1;
	}
      else
	{
	  contentRect.origin.y += scrollerWidth + 1;
	}
    }

  [_horizScroller setFrame: horizScrollerRect];
  [_vertScroller setFrame: vertScrollerRect];
  [_contentView setFrame: contentRect];
  [self reflectScrolledClipView: (NSClipView*)_contentView];
}

- (void) drawRect: (NSRect)rect
{
  NSGraphicsContext	*ctxt = GSCurrentContext();
  float scrollerWidth = [NSScroller scrollerWidth];
  float horizLinePosition, horizLineLength = [self bounds].size.width;
  float borderThickness = 0;

  DPSgsave(ctxt);
  switch ([self borderType])
    {
      case NSNoBorder:
	break;

      case NSLineBorder:
	borderThickness = 1;
	[[NSColor controlDarkShadowColor] set];
	NSFrameRect(rect);
	break;

      case NSBezelBorder:
	borderThickness = 2;
	NSDrawGrayBezel(rect, rect);
	break;

      case NSGrooveBorder:
	borderThickness = 2;
	NSDrawGroove(rect, rect);
	break;
    }

  horizLinePosition = borderThickness;

  DPSsetlinewidth(ctxt, 1);
  DPSsetgray(ctxt, 0);
  if (_hasVertScroller)
    {
      horizLinePosition = scrollerWidth + borderThickness;
      horizLineLength -= scrollerWidth + 2 * borderThickness;
      DPSmoveto(ctxt, horizLinePosition, borderThickness + 1);
      DPSrlineto(ctxt, 0, [self bounds].size.height - 2 * borderThickness - 1);
      DPSstroke(ctxt);
    }

  if (_hasHorizScroller)
    {
      float	ypos = scrollerWidth + borderThickness + 1;

      if (_rFlags.flipped_view)
	ypos = [self bounds].size.height - ypos;
      DPSmoveto(ctxt, horizLinePosition, ypos);
      DPSrlineto(ctxt, horizLineLength - 1, 0);
      DPSstroke(ctxt);
    }

  DPSgrestore(ctxt);
}

- (NSRect) documentVisibleRect
{
  return [_contentView documentVisibleRect];
}

- (void) setBackgroundColor: (NSColor*)aColor
{
  [_contentView setBackgroundColor: aColor];
}

- (NSColor*) backgroundColor
{
  return [_contentView backgroundColor];
}

- (void) setBorderType: (NSBorderType)borderType
{
  _borderType = borderType;
}

- (void) setDocumentView: (NSView*)aView
{
  [_contentView setDocumentView: aView];
  if (_contentView && !_contentView->_rFlags.flipped_view)
    [_vertScroller setFloatValue: 1];
  [self tile];
}

- (void) resizeSubviewsWithOldSize: (NSSize)oldSize
{
  [super resizeSubviewsWithOldSize: oldSize];
  [self tile];
}

- (id) documentView
{
  return [_contentView documentView];
}

- (NSCursor*) documentCursor
{
  return [_contentView documentCursor];
}

- (void) setDocumentCursor: (NSCursor*)aCursor
{
  [_contentView setDocumentCursor: aCursor];
}

- (BOOL) isOpaque
{
  return YES;
}

- (NSBorderType) borderType
{
  return _borderType;
}

- (BOOL) hasHorizontalRuler
{
  return _hasHorizRuler;
}

- (BOOL) hasHorizontalScroller
{
  return _hasHorizScroller;
}

- (BOOL) hasVerticalRuler
{
  return _hasVertRuler;
}

- (BOOL) hasVerticalScroller
{
  return _hasVertScroller;
}

- (NSSize) contentSize
{
  return [_contentView bounds].size;
}

- (NSClipView*) contentView
{
  return _contentView;
}

- (NSRulerView*) horizontalRulerView
{
  return _horizRuler;
}

- (NSRulerView*) verticalRulerView
{
  return _vertRuler;
}

- (BOOL) rulersVisible
{
  return _rulersVisible;
}

- (void) setLineScroll: (float)aFloat
{
  _hLineScroll = aFloat;
  _vLineScroll = aFloat;
}

- (void) setHorizontalLineScroll: (float)aFloat
{
  _hLineScroll = aFloat;
}

- (void) setVerticalLineScroll: (float)aFloat
{
  _vLineScroll = aFloat;
}

- (float) lineScroll
{
  if (_hLineScroll != _vLineScroll)
    [NSException raise: NSInternalInconsistencyException
		format: @"horizontal and vertical values not same"];
  return _vLineScroll;
}

- (float) horizontalLineScroll
{
  return _hLineScroll;
}

- (float) verticalLineScroll
{
  return _vLineScroll;
}

- (void) setPageScroll: (float)aFloat
{
  _hPageScroll = aFloat;
  _vPageScroll = aFloat;
}

- (void) setHorizontalPageScroll: (float)aFloat
{
  _hPageScroll = aFloat;
}

- (void) setVerticalPageScroll: (float)aFloat
{
  _vPageScroll = aFloat;
}

- (float) pageScroll
{
  if (_hPageScroll != _vPageScroll)
    [NSException raise: NSInternalInconsistencyException
		format: @"horizontal and vertical values not same"];
  return _vPageScroll;
}

- (float) horizontalPageScroll
{
  return _hPageScroll;
}

- (float) verticalPageScroll
{
  return _vPageScroll;
}

- (void) setScrollsDynamically: (BOOL)flag
{
  _scrollsDynamically = flag;
}

- (BOOL) scrollsDynamically
{
  return _scrollsDynamically;
}

- (NSScroller*) horizontalScroller
{
  return _horizScroller;
}

- (NSScroller*) verticalScroller
{
  return _vertScroller;
}

@end
