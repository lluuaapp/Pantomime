/*
**  CWFolder.m
**
**  Copyright (c) 2001-2006
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

#import "CWFolder.h"

#import "CWConstants.h"
#import "CWContainer.h"
#import "CWFlags.h"
#import "CWMessage.h"
#import "NSString+CWExtensions.h"

//
//
//
@implementation CWFolder 

- (id) initWithName: (NSString *) theName
{
    self = [super init];
    if (self)
    {
        _properties = [[NSMutableDictionary alloc] init];
        _allVisibleMessages = nil;
        
        allMessages = [[NSMutableArray alloc] init];
        
        //
        // By default, we don't do message threading so we don't
        // initialize this ivar for no reasons
        //
        _allContainers = nil;
        _cacheManager = nil;
        _mode = PantomimeUnknownMode;
        
        [self setName: theName];
        [self setShowDeleted: NO];
        [self setShowRead: YES];
    }
    return self;
}


//
//
//
- (void) dealloc
{
  //
  // To be safe, we set the value of the _folder ivar of all CWMessage
  // instances to nil value in case something is retaining them.
  //
  [allMessages makeObjectsPerformSelector: @selector(setFolder:) withObject: nil];
}


//
// NSCopying protocol (FIXME)
//
- (id) copyWithZone: (NSZone *) zone
{
  return self;
}

//
//
//
- (void) appendMessage: (CWMessage *) theMessage
{
    if (theMessage)
    {
        [allMessages addObject: theMessage];
        
        if (_allVisibleMessages)
        {
            [_allVisibleMessages addObject: theMessage];
        }
        
        // FIXME
        // If we've done message threading, we simply append the message
        // to the end of our containers array. We might want to place
        // it in the right thread in the future.
        if (_allContainers)
        {
            CWContainer *aContainer;
            
            aContainer = [[CWContainer alloc] init];
            aContainer.message = theMessage;
            [theMessage setProperty:aContainer  forKey:@"Container"];
            [_allContainers addObject: aContainer];
        }
    }
}


//
//
//
- (void) appendMessageFromRawSource: (NSData *) theData
                              flags: (CWFlags *) theFlags
{
    NSAssert2(0, @"Subclass %@ should override %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}


//
//
//
- (NSArray *) allContainers
{
  return _allContainers;
}


//
//
//
- (NSArray *) allMessages
{ 
  if (_allVisibleMessages == nil)
    {
      NSInteger i, count;

      count = [allMessages count];
      _allVisibleMessages = [[NSMutableArray alloc] initWithCapacity: count];

      // quick
      if (_show_deleted && _show_read)
	{
	  [_allVisibleMessages addObjectsFromArray: allMessages];
	  return _allVisibleMessages;
	}

      for (i = 0; i < count; i++)
	{
	  CWMessage *aMessage;
	  
	  aMessage = [allMessages objectAtIndex: i];
      
	  // We show or hide deleted messages
	  if (_show_deleted)
	    {
	      [_allVisibleMessages addObject: aMessage];
	    }
	  else
	    {
	      if ([[aMessage flags] contain: PantomimeDeleted])
		{
		  // Do nothing
		  continue;
		}
	      else
		{
		  [_allVisibleMessages addObject: aMessage];
		}
	    }

	  // We show or hide read messages
	  if (_show_read)
	    {
	      if (![_allVisibleMessages containsObject: aMessage])
		{
		  [_allVisibleMessages addObject: aMessage];
		}
	    }
	  else
	    {
	      if ([[aMessage flags] contain: PantomimeSeen])
		{
		  if (![[aMessage flags] contain: PantomimeDeleted])
		    {
		      [_allVisibleMessages removeObject: aMessage];
		    }
		}
	      else if (![_allVisibleMessages containsObject: aMessage])
		{
		  [_allVisibleMessages addObject: aMessage];
		}
	    }
	}
    }

  return _allVisibleMessages;
}


//
//
//
- (void) setMessages: (NSArray *) theMessages
{
    if (theMessages)
    {
        allMessages = [[NSMutableArray alloc] initWithArray: theMessages];
        
        if (_allContainers)
        {
            [self thread];
        }
    }
    else
    {
        allMessages = nil;
    }
    
    _allVisibleMessages = nil;
}


//
//
//
- (CWMessage *) messageAtIndex: (NSInteger) theIndex
{
  if (theIndex < 0 || theIndex >= [self count])
    {
      return nil;
    }
  
  return [[self allMessages] objectAtIndex: theIndex];
}


//
//
//
- (NSInteger) count
{
  return [[self allMessages] count];
}


//
//
//
- (void) close
{
    NSAssert2(0, @"Subclass %@ should override %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    return;
}


//
//
//
- (void) expunge
{
    NSAssert2(0, @"Subclass %@ should override %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}


//
//
//
- (id) store
{
  return _store;
}


//
// No need to retain the store here since our store object
// retains our folder object.
//
- (void) setStore: (id) theStore
{
  _store = theStore;
}


//
//
//
- (void) removeMessage: (CWMessage *) theMessage
{
  if (theMessage)
    {
      [allMessages removeObject: theMessage];
      
      if (_allVisibleMessages)
	{
	  [_allVisibleMessages removeObject: theMessage];
	}

      // FIXME - We must go through our _allContainers ivar in order
      //         to find the message that has just been removed from
      //         this folder. We must go through all levels.
      //         Right now, we simply do again our message threading algo
      if (_allContainers)
	{
	  [self thread];
	}
    }
}


//
//
//
- (BOOL) showDeleted
{
  return _show_deleted;
}


//
//
//
- (void) setShowDeleted: (BOOL) theBOOL
{
  if (theBOOL != _show_deleted)
    {
      _show_deleted = theBOOL;
      _allVisibleMessages = nil;
    }
}


//
//
//
- (BOOL) showRead
{
  return _show_read;
}


//
//
//
- (void) setShowRead: (BOOL) theBOOL
{
  if (theBOOL != _show_read)
    {
      _show_read = theBOOL;
        _allVisibleMessages = nil;
    }
}


//
//
//
- (NSInteger) numberOfDeletedMessages
{
    NSUInteger count = 0;
    for (CWMessage *message in allMessages)
    {
        if ([[message flags] contain:PantomimeDeleted])
        {
            count++;
        }
    }
    
    return count;
}


//
//
//
- (NSInteger) numberOfUnreadMessages
{
    NSUInteger count = 0;
    for (CWMessage *message in allMessages)
    {
        if ([[message flags] contain:PantomimeSeen])
        {
            count++;
        }
    }
    
    return count;
}


//
//
//
- (long) size;
{
    long size = 0;
    
    for (CWMessage *message in allMessages)
    {
        size += [message size];
    }
    
    return size;
}


//
//
//
- (void) updateCache
{
    _allVisibleMessages = nil;
}


//
//
//
- (void) thread
{
    NSMutableDictionary *idTable;
    NSMutableDictionary *subjectTable;

  // We clean up ...
  _allContainers = nil;

  // We create our local autorelease pool
    @autoreleasepool
    {
        // Build id_table and our containers mutable array
        idTable = [[NSMutableDictionary alloc] init];
        _allContainers = [[NSMutableArray alloc] init];
        
        //
        // 1. A., B. and C.
        //
        for (CWMessage *aMessage in allMessages)
        {
            CWContainer *aContainer = nil;
            
            // We skip messages that don't have a valid Message-ID
            if (![aMessage messageID])
            {
                aContainer = [[CWContainer alloc] init];
                aContainer.message = aMessage;
                [aMessage setProperty: aContainer  forKey: @"Container"];
                [_allContainers addObject: aContainer];
                continue;
            }
            
            //
            // A.
            //
            aContainer = [idTable valueForKey:[aMessage messageID]];
            
            if (aContainer)
            {
                //aContainer.message = aMessage;
                
                if (aContainer.message != aMessage)
                {
                    aContainer = [[CWContainer alloc] init];
                    aContainer.message = aMessage;
                    [aMessage setProperty: aContainer  forKey: @"Container"];
                    [idTable setValue:aContainer forKey:[aMessage messageID]];
                    aContainer = nil;
                }
            }
            else
            {
                aContainer = [[CWContainer alloc] init];
                aContainer.message = aMessage;
                [aMessage setProperty: aContainer  forKey: @"Container"];
                [idTable setValue:aContainer forKey:[aMessage messageID]];
                aContainer = nil;
            }
            
            //
            // B. For each element in the message's References field:
            //
            NSArray *references = [aMessage references];
            for (NSString *aReference in references)
            {
                // Find a container object for the given Message-ID
                aContainer = [idTable valueForKey:aReference];

                if (aContainer)
                {
                    // We found it. We use that.
                }
                // Otherwise, make (and index) one (new Container) with a null Message
                else 
                {
                    aContainer = [[CWContainer alloc] init];
                    [idTable setValue:aContainer forKey:aReference];
                }
                
                // NOTE:
                // aContainer is valid here. It points to the message (could be a nil message)
                // that has a Message-ID equals to the current aReference value.
                
                // If we are currently using the last References's entry of our list,
                // we simply break the loop since we are gonna set it in C.
                //if ( j == ([[aMessage allReferences] count] - 1) )
                //  {
                //    break;
                // }
                
                // Link the References field's Containers together in the order implied by the References header.
                // The last references
                if ((aReference == [references lastObject]) &&
                    (nil != aContainer) &&
                    aContainer.parent == nil)
                {
                    // We grab the container of our current message
                    [(CWContainer *)[idTable valueForKey:[aMessage messageID]] setParent:aContainer];
                }
                
                // We set the child
                //if ( aContainer.message != aMessage &&
                //     aContainer.child == nil )
                //  {
                //    [aContainer setChild: NSMapGet(id_table, [aMessage messageID])];
                //  }	      
                
            } // for (j = 0; ...
            
            // NOTE: The loop is over here. It was an ascending loop so
            //       aReference points to the LAST reference in our References list
            
            //
            // C. Set the parent of this message to be the last element in References. 
            //
            // NOTE: Again, aReference points to the last Message-ID in the References list
            
            // We get the container for the CURRENT message
            aContainer = (CWContainer *)[idTable valueForKey:[aMessage messageID]];
            
            // If we have no References and no In-Reply-To fields, we simply set a
            // the parent to nil since it can be the message that started the thread.
            if ([references count] == 0 &&
                [aMessage headerValueForName: @"In-Reply-To"] == nil)
            {
                [aContainer setParent: nil];
            }
            // If we have no References but an In-Reply-To field, that becomes our parent.
            else if ([references count] == 0 &&
                     [aMessage headerValueForName: @"In-Reply-To"])
            {
                [aContainer setParent: (CWContainer *)[idTable valueForKey:[aMessage headerValueForName: @"In-Reply-To"]]];
                // FIXME, should we really do that? or should we do it in B?
                [(CWContainer *)[idTable valueForKey:[aMessage headerValueForName: @"In-Reply-To"]] setChild: aContainer];
            }
            else
            {
                [aContainer setParent:(CWContainer *)[idTable valueForKey:[references lastObject]]];
                [(CWContainer *)[idTable valueForKey:[references lastObject]] setChild:aContainer];
            }
            
        } // for (i = 0; ...
        
        //
        // 2. Find the root set.
        //
        [_allContainers addObjectsFromArray:[idTable allValues]];
        
        //while (NO)
        for (NSInteger i = ([_allContainers count] - 1); i >= 0; i--)
        {
            CWContainer *aContainer = [_allContainers objectAtIndex:i];
            
            if (aContainer.parent != nil)
            {
                [_allContainers removeObjectAtIndex:i];
            }
        }
        
        //
        // 3. Discard id_table.
        //
        
        
        //
        // 4. Prune empty containers.
        //
        //while (NO)
        for (NSInteger i = ([_allContainers count] - 1); i >= 0; i--)
        {
            CWContainer *aContainer = [_allContainers objectAtIndex:i];
            
            // Recursively walk all containers under the root set.
            while (aContainer)
            {
                // A. If it is an empty container with no children, nuke it
                if (aContainer.message == nil &&
                    aContainer.child == nil)
                {
                    // We nuke it
                    // FIXME: Won't work for non-root containers.
                    [_allContainers removeObject: aContainer];
                }
                
                // B. If the Container has no Message, but does have children, remove this container but 
                //    promote its children to this level (that is, splice them in to the current child list.)
                //    Do not promote the children if doing so would promote them to the root set 
                //    -- unless there is only one child, in which case, do. 
                // FIXME: We promote to the root no matter what :)
                if (aContainer.message == nil && aContainer.child)
                {
                    CWContainer *c = aContainer;
                    [c.child setParent: nil];
                    [_allContainers removeObject:c];
                    [_allContainers addObject:c.child]; // We promote the the root for now
                    
                    // We go to our child and we continue to loop
                    //aContainer = aContainer.child;
                    aContainer = [aContainer childAtIndex: ([aContainer count]-1)];
                    continue;
                }
                
                //aContainer = aContainer.child;
                aContainer = [aContainer childAtIndex: ([aContainer count]-1)];
            }
            
        }
        
        //
        // 5. Group root set by subject.
        //
        // A. Construct a new hash table, subject_table, which associates subject 
        //    strings with Container objects.
        subjectTable = [[NSMutableDictionary alloc] init];
        
        //
        // B. For each Container in the root set:
        //
        
        //while (NO)
        for (CWContainer *aContainer in _allContainers)
        {
            CWMessage *aMessage = aContainer.message;
            NSString *aString = [aMessage subject];
            
            if (aString)
            {
                aString = [aMessage baseSubject];
                
                // If the subject is now "", give up on this Container.
                if ([aString length] == 0)
                {
                    //aContainer = aContainer.child;
                    continue;
                }
                
                // We set the new subject
                //[aMessage setSubject: aString];
                
                // Add this Container to the subject_table if:
                // o There is no container in the table with this subject, or
                // o This one is an empty container and the old one is not: 
                //   the empty one is more interesting as a root, so put it in the table instead.
                // o The container in the table has a ``Re:'' version of this subject, 
                //   and this container has a non-``Re:'' version of this subject. 
                //   The non-re version is the more interesting of the two.
                if (![subjectTable valueForKey:aString])
                {
                    [subjectTable setValue:aContainer forKey:aString];
                }
                else
                {
                    NSString *aSubject;
                    
                    // We obtain the subject of the message of our container.
                    aSubject = [((CWContainer *)[subjectTable valueForKey:aString]).message subject];
                    
                    if ([aSubject hasREPrefix] && ![[aMessage subject] hasREPrefix])
                    {
                        // We replace the container
                        [subjectTable removeObjectForKey:aString];
                        [subjectTable setValue:aContainer forKey:[aMessage subject]];
                    }
                }
                
            } // if ( aString )
        }
        
        //
        // C. Now the subject_table is populated with one entry for each subject which occurs in 
        //    the root set. Now iterate over the root set, and gather together the difference.
        //
        //while (NO)
        for (NSInteger i = ([_allContainers count] - 1); i >= 0; i--)
        {
            CWContainer *aContainer = [_allContainers objectAtIndex:i];
            NSString *aSubject = [aContainer.message subject];
            NSString *aString = [aContainer.message baseSubject];
            
            // Look up the Container of that subject in the table.
            // If it is null, or if it is this container, continue.
            CWContainer *containerFromTable = [subjectTable valueForKey:aString];
            
            if (!containerFromTable || containerFromTable == aContainer) 
            {
                continue; 
            }
            
            // If that container is a non-empty, and that message's subject does 
            // not begin with ``Re:'', but this message's subject does, then make this be a child of the other.
            if (![[containerFromTable.message subject] hasREPrefix] &&
                [aSubject hasREPrefix])
            {
                [aContainer setParent: containerFromTable];
                [containerFromTable setChild: aContainer]; 
                [_allContainers removeObject: aContainer];
            }
            // If that container is a non-empty, and that message's subject begins with ``Re:'', 
            // but this  message's subject does not, then make that be a child of this one -- 
            // they were misordered. (This happens somewhat implicitly, since if there are two
            // messages, one with Re: and one without, the one without will be in the hash table,
            // regardless of the order in which they were seen.)
            else if ([[containerFromTable.message subject] hasREPrefix] &&
                     ![aSubject hasREPrefix])
            {
                [containerFromTable setParent: aContainer];
                [aContainer setChild: containerFromTable]; 
                [_allContainers removeObject: containerFromTable];
            }
            // Otherwise, make a new empty container and make both msgs be a child of it. 
            // This catches the both-are-replies and neither-are-replies cases, and makes them 
            // be siblings instead of asserting a hierarchical relationship which might not be true.
        }
        
        
        //
        // 6.  Now you're done threading!
        //
        //     Specifically, you no longer need the ``parent'' slot of the Container object, 
        //     so if you wanted to flush the data out into a smaller, longer-lived structure, you 
        //     could reclaim some storage as a result. 
        //
        // GNUMail.app DOES USE the parent slot so we keep it.
        
        //
        // 7.  Now, sort the siblings.
        //     
        //     At this point, the parent-child relationships are set. However, the sibling ordering 
        //     has not been adjusted, so now is the time to walk the tree one last time and order the siblings 
        //     by date, sender, subject, or whatever. This step could also be merged in to the end of step 4, 
        //     above, but it's probably clearer to make it be a final pass. If you were careful, you could 
        //     also sort the messages first and take care in the above algorithm to not perturb the ordering,
        //      but that doesn't really save anything. 
        //
        // By default we at least sort everything by number.
        //[_allContainers sortUsingSelector: @selector(compareAccordingToNumber:)];
        
    }
}


//
//
//
- (void) unthread
{
    NSInteger count;
    
    count = [allMessages count];
    
    while (count--)
    {
        [(CWMessage*)[allMessages objectAtIndex: count] setProperty: nil  forKey: @"Container"];
    }
    
    _allContainers = nil;
}

//
//
//
- (void) search: (NSString *) theString
	   mask: (PantomimeSearchMask) theMask
	options: (PantomimeSearchOption) theOptions
{
    NSAssert2(0, @"Subclass %@ should override %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

//
//
//
- (PantomimeFolderMode) mode
{
  return _mode;
}


//
//
//
- (void) setMode: (PantomimeFolderMode) theMode
{
  _mode = theMode;
}


//
//
//
- (void) setFlags:(CWFlags*)theFlags
         messages:(NSArray*)theMessages
{
    for (CWMessage *message in theMessages)
    {
        [message setFlags:theFlags];
    }
}


//
//
//
- (id) propertyForKey: (id) theKey
{
  return [_properties objectForKey: theKey];
}


//
//
//
- (void) setProperty: (id) theProperty
	      forKey: (id) theKey
{
  if (theProperty)
    {
      [_properties setObject: theProperty  forKey: theKey];
    }
  else
    {
      [_properties removeObjectForKey: theKey];
    }
}

@end



