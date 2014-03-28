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


//
//
//
@implementation CWContainer

- (id) init
{
  self = [super init];

  message = nil;
  parent = nil;
  child = nil;
  next = nil;

  return self;
}

//
// access / mutation methods
//
- (void) setParent: (CWContainer *) theParent
{
    if (theParent && theParent != self)
    {
        parent = theParent;
    }
    else
    {
        parent = nil;
    }
}


// 
//
//
// #warning Fix mem leaks
- (void) setChild: (CWContainer *) theChild
{
    if (!theChild || theChild == self || theChild->next == self || theChild == child)
    {
        return;
    }
    
    if (theChild)
    {
        CWContainer *aChild;
        
        // We search down in the children of theChild to be sure that
        // self IS NOT reachable
        // FIXME - we should use childrenEnumerator since we are NOT looping
        // in all children with this code
        aChild = theChild->child;
        
        while (aChild)
      	{
            if (aChild == self)
      	    {
                return;
      	    }
            aChild = aChild->next;
      	}
        
        
        // We finally add it!
        if (!child)
        {
            child = theChild;
        }
        else
        {	  
            aChild = child;
            
            // We go at the end of our list of children
            //while ( aChild->next != nil && aChild->next != aChild )
            while (aChild->next != nil)
            {     
                if (aChild->next == aChild)
                {
                    aChild->next = theChild;
                    return;
                }
                
                // We don't add the child if it's already there
                if (aChild == theChild)
                {
                    return;
                }
                
                aChild = aChild->next;
            }
            
            aChild->next = theChild;
        }
        
    }
    else
    {
        child = nil;
    }
}


//
//
//
- (CWContainer *) childAtIndex: (NSUInteger) theIndex
{
  CWContainer *aChild;
  NSUInteger i;

  aChild = child;

  for (i = 0; i < theIndex && aChild; i++)
    {     
      aChild = aChild->next;
    }

  return aChild;
}


//
//
//
- (NSUInteger) count
{
  if (child)
    {
      CWContainer *aChild;
      NSUInteger count;

      aChild = child;
      count = 0;

      while (aChild)
	{
	  //if ( aChild == self || aChild->next == aChild )
	  if (aChild == self)
	    {
	      count = 1;
	      break;
	    }

	  aChild = aChild->next;
	  count++;
	}

      return count;
    }
  
  return 0;
}


//
//
//
- (void) setNext: (CWContainer *) theNext
{
    next = theNext;
}


//
//
//
- (NSEnumerator *) childrenEnumerator
{
    NSMutableArray *aMutableArray;
    CWContainer *aContainer;
    
    aMutableArray = [[NSMutableArray alloc] init];
    
    aContainer = child;
    
    while (aContainer)
    {
        [aMutableArray addObject: aContainer];
        
        // We add, recursively, all its children
        [aMutableArray addObjectsFromArray: [[aContainer childrenEnumerator] allObjects]];
        
        // We get our next container
        aContainer = aContainer->next;
    }
    
    return [aMutableArray objectEnumerator];
}

@end
