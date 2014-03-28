/*
**  CWContainer.h
**
**  Copyright (c) 2002-2004
**
**  Author: Ludovic Marcotte <ludovic@Sophos.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**  
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**  
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#import <Foundation/Foundation.h>

@class CWMessage;

/*!
  @class CWContainer
  @discussion This class is a simple placeholder used when doing message threading.
              A container is composed of a CWMessage instance which might be nil, a parent,
	      child and next CWContainer instances. For a full description of the implemented
	      algorithm, see <a href="http://www.jwz.org/doc/threading.html">message threading</a>.
	      Instance variables of this class must be accessed directly (ie., without
	      an accessor) - for performance reasons.
*/
@interface CWContainer : NSObject

@property CWMessage *message;
@property (nonatomic) CWContainer *parent;
@property (nonatomic) CWContainer *child;
@property (nonatomic) CWContainer *next;

/*!
  @method childAtIndex:
  @discussion This method is used to get the child at the specified index.
  @param theIndex The index of the child, which is 0 based.
  @result The CWContainer instance.
*/
- (CWContainer *) childAtIndex:(NSUInteger)theIndex;

/*!
  @method count
  @discussion This method is used to obtain the number of children of
              the receiver.
  @result The number of children.
*/
- (NSUInteger) count;

/*!
  @method allChildren
  @discussion This method is used to obtain all children of the receiver.
  @result All children
*/
- (NSArray *) allChildren;

@end
