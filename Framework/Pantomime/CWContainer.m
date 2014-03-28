/*
**  CWContainer.m
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

#import "CWContainer.h"

#import "CWConstants.h"
#import "CWInternetAddress.h"
#import "CWMessage.h"


@interface CWContainer ()

@property (nonatomic) CWContainer *parent;
@property (nonatomic) CWContainer *child;
@property (nonatomic) CWContainer *next;

@end

//
//
//
@implementation CWContainer

//
// access / mutation methods
//
- (void) setParent: (CWContainer *) theParent
{
    if (theParent && theParent != self)
    {
        _parent = theParent;
    }
    else
    {
        _parent = nil;
    }
}


// 
//
//
// #warning Fix mem leaks
- (void) setChild: (CWContainer *) theChild
{
    if (!theChild || theChild == self || theChild.next == self || theChild == self.child)
    {
        return;
    }
    
    if (theChild)
    {
        CWContainer *aChild = nil;
        
        // We search down in the children of theChild to be sure that
        // self IS NOT reachable
        // FIXME - we should use childrenEnumerator since we are NOT looping
        // in all children with this code
        for (aChild in [self allChildren])
      	{
            if (aChild == self)
      	    {
                return;
      	    }
      	}
        
        
        // We finally add it!
        if (!_child)
        {
            _child = theChild;
        }
        else
        {
            aChild = _child;
            
            // We go at the end of our list of children
            //while ( aChild.next != nil && aChild.next != aChild )
            while (aChild.next != nil)
            {
                if (aChild.next == aChild)
                {
                    aChild.next = theChild;
                    return;
                }
                
                // We don't add the child if it's already there
                if (aChild == theChild)
                {
                    return;
                }
                
                aChild = aChild.next;
            }
            
            aChild.next = theChild;
        }
        
    }
    else
    {
        _child = nil;
    }
}


//
//
//
- (CWContainer *) childAtIndex: (NSUInteger) theIndex
{
    CWContainer *aChild;
    NSUInteger i;
    
    aChild = self.child;
    
    for (i = 0; i < theIndex && aChild; i++)
    {
        aChild = aChild.next;
    }
    
    return aChild;
}


//
//
//
- (NSUInteger) count
{
    if (self.child)
    {
        CWContainer *aChild;
        NSUInteger count;
        
        aChild = self.child;
        count = 0;
        
        while (aChild)
        {
            //if ( aChild == self || aChild.next == aChild )
            if (aChild == self)
            {
                count = 1;
                break;
            }
            
            aChild = aChild.next;
            count++;
        }
        
        return count;
    }
    
    return 0;
}


//
//
//
- (void) setNext:(CWContainer *)theNext
{
    _next = theNext;
}


//
//
//
- (NSArray *) allChildren
{
    NSMutableArray *aMutableArray;
    CWContainer *aContainer;
    
    aMutableArray = [[NSMutableArray alloc] init];
    
    aContainer = self.child;
    
    while (aContainer)
    {
        [aMutableArray addObject: aContainer];
        
        // We add, recursively, all its children
        [aMutableArray addObjectsFromArray:[aContainer allChildren]];
        
        // We get our next container
        aContainer = aContainer.next;
    }
    
    return [NSArray arrayWithArray:aMutableArray];
}

@end
