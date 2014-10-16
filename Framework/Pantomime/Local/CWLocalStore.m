/*
**  CWLocalStore.m
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

#import "CWLocalStore.h"

#import "CWConstants.h"
#import "CWLocalCacheManager.h"
#import "CWLocalFolder.h"
#import "CWLocalFolder+mbox.h"
#import "CWLocalMessage.h"
#import "NSFileManager+CWExtensions.h"
#import "NSString+CWExtensions.h"
#import "CWURLName.h"

//
// Private interface
//
@interface CWLocalStore (Private)

- (void) _enforceFileAttributes;
- (NSEnumerator *) _rebuildFolderEnumerator;

@end


//
//
//
@implementation CWLocalStore

//
//
//
- (id) initWithPath: (NSString *) thePath
{
    BOOL isDirectory;
    
    self = [super init];
    
    [self setPath: thePath];
    
    _openFolders = [[NSMutableDictionary alloc] init];
    _folders = [[NSMutableArray alloc] init];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: thePath  isDirectory: &isDirectory])
    {
        if (!isDirectory)
        {
            return nil;
        }
    }
    else
    {
        return nil;
    }
    
    // Just before returning, we finally enforce our file attributes
    [self _enforceFileAttributes];
    
    return self;
}


//
//
//
- (id) initWithURL: (CWURLName *) theURL
{
  return [self initWithPath: [theURL path]];
}


//
// This method will open automatically Inbox (case-insensitive).
// It may return nil if the opening failed or Inbox wasn't found.
//
- (id) defaultFolder
{
  return [self folderForName: @"Inbox"];
}


//
// This method is used to open the folder theName in the current
// directory of this local store.
//
- (id) folderForName: (NSString *) theName
{
  CWLocalFolder *cachedFolder;

  if (!theName) return nil;

  cachedFolder = [_openFolders objectForKey: theName];
  
  if (!cachedFolder)
    {
      NSEnumerator *anEnumerator;
      NSString *aString;
      
      anEnumerator = [self folderEnumerator];

      while ((aString = [anEnumerator nextObject]))
	{
	  if ([aString compare: theName] == NSOrderedSame)
	    {
	      CWLocalFolder *aFolder;

	      aFolder = [[CWLocalFolder alloc] initWithPath: [NSString stringWithFormat:@"%@/%@", _path, aString]];
	      
	      if (aFolder)
		{
		  [aFolder setStore: self];
		  [aFolder setName: theName];

		  // We now cache it and return it
		  [_openFolders setObject: aFolder  forKey: theName];

		  POST_NOTIFICATION(PantomimeFolderOpenCompleted, self, [NSDictionary dictionaryWithObject: aFolder  forKey: @"Folder"]);
		  PERFORM_SELECTOR_2(self, @selector(folderOpenCompleted:), PantomimeFolderOpenCompleted, aFolder, @"Folder");
		}
	      else
		{
		  POST_NOTIFICATION(PantomimeFolderOpenFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"FolderName"]);
		  PERFORM_SELECTOR_2(self, @selector(folderOpenFailed:), PantomimeFolderOpenFailed, theName, @"FolderName");
		}

	      return aFolder;
	    }
	}
      
      return nil;
    }

  //NSLog(@"Returning cached folder!");
  return cachedFolder;
}


//
//
//
- (id) folderForURL: (NSString *) theURL;
{
  CWURLName *theURLName;
  id aFolder;

  theURLName = [[CWURLName alloc] initWithString: theURL];

  aFolder = [self folderForName: [theURLName foldername]];
  
  return aFolder;
}


//
// This method returns the list of folders contained in 
// a specific directory. It'll currently ignore some things
// like Netscape Mail's summary files and Pantomime's local
// cache files.
//
- (NSEnumerator *) folderEnumerator
{
  if ([_folders count] > 0)
    {
      POST_NOTIFICATION(PantomimeFolderListCompleted, self, [NSDictionary dictionaryWithObject: [_folders objectEnumerator] forKey: @"NSEnumerator"]);
      PERFORM_SELECTOR_2(self, @selector(folderListCompleted:), PantomimeFolderListCompleted, [_folders objectEnumerator], @"NSEnumerator");
      return [_folders objectEnumerator];
    }

  return [self _rebuildFolderEnumerator];
}


//
//
//
- (NSEnumerator *) subscribedFolderEnumerator
{
  return [self folderEnumerator];
}


//
//
//
- (id) delegate
{
  return _delegate;
}

- (void) setDelegate: (id) theDelegate
{
  _delegate = theDelegate;
}


//
//
//
- (NSString *) path
{
  return _path;
}


//
//
//
- (void) setPath: (NSString *) thePath
{
  ASSIGN(_path, thePath);
}


//
//
//
- (void) close
{
    for (CWLocalFolder *aFolder in _openFolders)
    {
        [aFolder close];
    }
}

//
//
//
- (void) removeFolderFromOpenFolders: (CWFolder *) theFolder
{
  [_openFolders removeObjectForKey: [(CWLocalFolder *)theFolder name]];
}


//
//
//
- (BOOL) folderForNameIsOpen: (NSString *) theName
{
    for (CWLocalFolder *aFolder in _openFolders)
    {
        if ([[aFolder name] compare: theName] == NSOrderedSame)
        {
            return YES;
        }
    }
    
    return NO;
}


//
//
//
- (PantomimeFolderType) folderTypeForFolderName: (NSString *) theName
{
  NSString *aString;
  BOOL isDir;

  aString = [NSString stringWithFormat: @"%@/%@", _path, theName];
  
  [[NSFileManager defaultManager] fileExistsAtPath: aString
				  isDirectory: &isDir];
  
  if (isDir)
    {
      // This could be a maildir store. Check for maildir specific subfolders.
      aString = [NSString stringWithFormat: @"%@/%@/cur", _path, theName];
      
      if ( [[NSFileManager defaultManager] fileExistsAtPath: aString
					   isDirectory: &isDir] && isDir )
	{
	  return PantomimeHoldsMessages;
	}
      else
	{
	  return PantomimeHoldsFolders;
	}
    }

  return PantomimeHoldsMessages;
}


//
//
//
- (unichar) folderSeparator
{
  return '/';
}


//
//
//
- (void) createFolderWithName: (NSString *) theName 
			 type: (PantomimeFolderFormat) theType
		     contents: (NSData *) theContents
{
  NSString *aName, *pathToFile;
  NSFileManager *aFileManager;
  NSEnumerator *anEnumerator;
  BOOL b, is_dir;
  NSInteger count;

  aFileManager = [NSFileManager defaultManager];
  anEnumerator = [self folderEnumerator];
  count = 0;

  pathToFile = [NSString stringWithFormat: @"%@/%@", _path, theName];
  pathToFile = [pathToFile substringToIndex: ([pathToFile length]-[[pathToFile lastPathComponent] length]-1)];
 

  // We verify if the folder with that name does already exist
  while ((aName = [anEnumerator nextObject]))
    {
      if ([aName compare: theName  options: NSCaseInsensitiveSearch] == NSOrderedSame)
	{
	  POST_NOTIFICATION(PantomimeFolderCreateFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
	  PERFORM_SELECTOR_2(self, @selector(folderCreateFailed:), PantomimeFolderCreateFailed, theName, @"Name");
	  return;
	}
    }
  
  // Ok, the folder doesn't already exist.
  // Check if we want to create a simple folder/directory.
  if (theType == PantomimeFormatFolder)
    {
      NSString *aString;

      aString = [NSString stringWithFormat: @"%@/%@", _path, theName];
      b = [aFileManager createDirectoryAtPath:aString withIntermediateDirectories:NO attributes:nil error:NULL];
      
      if (b)
	{
	  NSDictionary *info;
	  
	  [[NSFileManager defaultManager] enforceMode: 0700  atPath: aString];
	  [self _rebuildFolderEnumerator];

	  info = [NSDictionary dictionaryWithObjectsAndKeys: theName, @"Name", [NSNumber numberWithInteger:0], @"Count", nil];
	  POST_NOTIFICATION(PantomimeFolderCreateCompleted, self, info);
	  PERFORM_SELECTOR_3(self, @selector(folderCreateCompleted:), PantomimeFolderCreateCompleted, info);
	}
      else
	{
	  POST_NOTIFICATION(PantomimeFolderCreateFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
	  PERFORM_SELECTOR_2(self, @selector(folderCreateFailed:), PantomimeFolderCreateFailed, theName, @"Name");
	}
      
      return;
    }
  
  b = NO;

  // We want to create a mailbox store; check if it already exists.
  if ([aFileManager fileExistsAtPath: pathToFile  isDirectory: &is_dir])
    {
      NSInteger size;
      
      size = [[[aFileManager attributesOfItemAtPath:pathToFile error:NULL] objectForKey: NSFileSize] integerValue];
      
      // If we got an empty file or simply a directory...
      if (size == 0 || is_dir)
	{
	  NSString *aString;
	  
	  // If the size is 0, that means we have an empty file. We first convert this
	  // file to a directory. We also remove the cache file.
	  if (size == 0)
	    {
	      [aFileManager removeItemAtPath:
			      [NSString stringWithFormat: @"%@/.%@.cache",
					[pathToFile substringToIndex: ([pathToFile length]-[[pathToFile lastPathComponent] length]-1)],
					[pathToFile lastPathComponent]]  error:NULL];
	      [aFileManager removeItemAtPath: pathToFile  error:NULL];
	      [aFileManager createDirectoryAtPath:pathToFile withIntermediateDirectories:NO attributes:nil error:NULL];
	    }
	  
	  // We can now proceed with the creation of our store.
	  // Check the type of store we want to create
	  switch (theType)
	    {
	    case PantomimeFormatMaildir:
	      // Create the main maildir directory
	      aString = [NSString stringWithFormat: @"%@/%@", _path, theName];  
	      b = [aFileManager createDirectoryAtPath:aString withIntermediateDirectories:NO attributes:nil error:NULL];
	      [[NSFileManager defaultManager] enforceMode: 0700  atPath: aString];
								    
	      // Now create the cur, new, and tmp sub-directories.
	      aString = [NSString stringWithFormat: @"%@/%@/cur", _path, theName];
	      b = b & [aFileManager createDirectoryAtPath:aString withIntermediateDirectories:NO attributes:nil error:NULL];
	      [[NSFileManager defaultManager] enforceMode: 0700  atPath: aString];
	      
	      // new
	      aString = [NSString stringWithFormat: @"%@/%@/new", _path, theName];
	      b = b & [aFileManager createDirectoryAtPath:aString withIntermediateDirectories:NO attributes:nil error:NULL];
	      [[NSFileManager defaultManager] enforceMode: 0700  atPath: aString];

	      // tmp
	      aString = [NSString stringWithFormat: @"%@/%@/tmp", _path, theName];
	      b = b & [aFileManager createDirectoryAtPath:aString withIntermediateDirectories:NO attributes:nil error:NULL];
	      [[NSFileManager defaultManager] enforceMode: 0700  atPath: aString];
	      break;
	      
	    case PantomimeFormatMbox:
	    default:
	      b = [aFileManager createFileAtPath: [NSString stringWithFormat: @"%@/%@", _path, theName]
				contents: theContents
				attributes: nil];
	      
	      count = [CWLocalFolder numberOfMessagesFromData: theContents];
	      
	      // We now enforce the mode (0600) on this new mailbox
	      [[NSFileManager defaultManager] enforceMode: 0600
					      atPath: [NSString stringWithFormat: @"%@/%@", _path, theName]];
	      break;				  
	    }
	  
	  // rebuild the folder list
	  [self _rebuildFolderEnumerator];
	}
      else
	{
	  b = NO;
	}
    }
  
  if (b)
    {
      NSDictionary *info;

      info = [NSDictionary dictionaryWithObjectsAndKeys: theName, @"Name", [NSNumber numberWithInteger:count], @"Count", nil];
      POST_NOTIFICATION(PantomimeFolderCreateCompleted, self, info);
      PERFORM_SELECTOR_3(self, @selector(folderCreateCompleted:), PantomimeFolderCreateCompleted, info);
    }
  else
    {
      POST_NOTIFICATION(PantomimeFolderCreateFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
      PERFORM_SELECTOR_2(self, @selector(folderCreateFailed:), PantomimeFolderCreateFailed, theName, @"Name");
    }
}


//
// theName must be the full path of the mailbox.
//
- (void) deleteFolderWithName: (NSString *) theName
{
  NSFileManager *aFileManager;
  BOOL aBOOL, is_dir;
  
  aFileManager = [NSFileManager defaultManager];
  aBOOL = NO;

  if ([aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@", _path, theName]
		    isDirectory: &is_dir])
    {
      if (is_dir)
	{
	  NSEnumerator *theEnumerator;
	  NSArray *theEntries/*, *dirContents*/;
	  
	  theEnumerator = [aFileManager enumeratorAtPath: [NSString stringWithFormat: @"%@/%@",
								    _path, theName]];
	  
	  // FIXME - Verify the Store's path.
	  // If it doesn't contain any mailboxes and it's actually not or Store's path, we remove it.
	  theEntries = [theEnumerator allObjects];
	  /*dirContents = [aFileManager directoryContentsAtPath: [NSString stringWithFormat: @"%@/%@",
									 _path, theName]];*/
	  if ([theEntries count] == 0)
	    {
	      aBOOL = [aFileManager removeItemAtPath: [NSString stringWithFormat: @"%@/%@",
								_path, theName]
				    error:NULL];
	      
	      // Rebuild the folder tree
	      if (aBOOL)
		{
		  [self _rebuildFolderEnumerator];
		  POST_NOTIFICATION(PantomimeFolderDeleteCompleted, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
		  (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteCompleted:), PantomimeFolderDeleteCompleted);
		}
	      else
		{
		  POST_NOTIFICATION(PantomimeFolderDeleteFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
		  (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteFailed:), PantomimeFolderDeleteFailed);
		}

	      return;
	    }
	  // We could also be trying to delete a maildir mailbox which
	  // has a directory structure with 3 sub-directories: cur, new, tmp
	  else if ([aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/cur", _path, theName]
				 isDirectory: &is_dir])
	    {
	      // Make sure that these are the maildir directories and not something else.
	      if (![aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/new", _path, theName]
				 isDirectory: &is_dir])
		{
		  POST_NOTIFICATION(PantomimeFolderDeleteFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
		  (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteFailed:), PantomimeFolderDeleteFailed);
		  return;
		}
	      if (![aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/tmp", _path, theName]
				 isDirectory: &is_dir] )
		{
		  POST_NOTIFICATION(PantomimeFolderDeleteFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
		  (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteFailed:), PantomimeFolderDeleteFailed);
		  return;
		}
	    }
	  else
	    {
	      POST_NOTIFICATION(PantomimeFolderDeleteFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
	      (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteFailed:), PantomimeFolderDeleteFailed);
	      return;
	    }
	}

      // We remove the mbox or maildir store
      aBOOL = [aFileManager removeItemAtPath: [NSString stringWithFormat: @"%@/%@",
							_path, theName]
			    error:NULL];
      
      // We remove the cache, if the store deletion was successful
      if (aBOOL)
	{
	  NSString *aString;

	  aString = [theName lastPathComponent];
	  
	  [[NSFileManager defaultManager] removeItemAtPath: [NSString stringWithFormat: @"%@/%@.%@.cache",
								      _path,
								      [theName substringToIndex: ([theName length]-[aString length])],
								      aString]
					  error:NULL];
	}

      // Rebuild the folder tree
      [self _rebuildFolderEnumerator];
    }
  
  if (aBOOL)
    {
      POST_NOTIFICATION(PantomimeFolderDeleteCompleted, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
      (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteCompleted:), PantomimeFolderDeleteCompleted);
    }
  else
    {
      POST_NOTIFICATION(PantomimeFolderDeleteFailed, self, [NSDictionary dictionaryWithObject: theName  forKey: @"Name"]);
      (void)PERFORM_SELECTOR_1(self, @selector(folderDeleteFailed:), PantomimeFolderDeleteFailed);
    }
}


//
// theName and theNewName MUST be the full path of those mailboxes.
// If they begin with the folder separator (ie., '/'), the character is
// automatically stripped.
//
// This method supports renaming mailboxes that are open.
//
- (void) renameFolderWithName: (NSString *) theName
                       toName: (NSString *) theNewName
{
  NSFileManager *aFileManager;
  NSDictionary *info;
  BOOL aBOOL, is_dir;
  
  aFileManager = [NSFileManager defaultManager];
  aBOOL = NO;
  
  theName = [theName stringByDeletingFirstPathSeparator: [self folderSeparator]];
  theNewName = [theNewName stringByDeletingFirstPathSeparator: [self folderSeparator]]; 
  info = [NSDictionary dictionaryWithObjectsAndKeys: theName, @"Name", theNewName, @"NewName", nil];

  // We do basic verifications on the passed parameters. We also verify if the destination path exists.
  // If it does, we abort the rename operation since we don't want to overwrite the folder.
  if (!theName || !theNewName || 
      [[theName stringByTrimmingWhiteSpaces] length] == 0 ||
      [[theNewName stringByTrimmingWhiteSpaces] length] == 0 ||
      [aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@", _path, theNewName]])
    {
      POST_NOTIFICATION(PantomimeFolderRenameFailed, self, info);
      PERFORM_SELECTOR_3(self, @selector(folderRenameFailed:), PantomimeFolderRenameFailed, info);
      return;
    }

  // We verify if the source path is valid
  if ([aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@", _path, theName]
		    isDirectory: &is_dir])
    {
      CWLocalFolder *aFolder;

      if (is_dir)
	{
	  NSEnumerator *theEnumerator;
	  NSArray *theEntries;
	  
	  theEnumerator = [aFileManager enumeratorAtPath: [NSString stringWithFormat: @"%@/%@",
								    _path, theName]];
	  
	  // FIXME - Verify the Store's path.
	  // If it doesn't contain any mailboxes and it's actually not or Store's path, we rename it.
	  theEntries = [theEnumerator allObjects];
	  
	  if ([theEntries count] == 0)
	    {
	      aBOOL = [aFileManager moveItemAtPath: [NSString stringWithFormat: @"%@/%@",_path, theName]
				    toPath: [NSString stringWithFormat: @"%@/%@",  _path, theNewName]
				    error:NULL];
	      if (aBOOL)
		{
		  POST_NOTIFICATION(PantomimeFolderRenameCompleted, self, info);
		  PERFORM_SELECTOR_3(self, @selector(folderRenameCompleted:), PantomimeFolderRenameCompleted, info);
		}
	      else
		{
		  POST_NOTIFICATION(PantomimeFolderRenameFailed, self, info);
		  PERFORM_SELECTOR_3(self, @selector(folderRenameFailed:), PantomimeFolderRenameFailed, info);
		}
	    }
	  // We could also be trying to delete a maildir mailbox which
	  // has a directory structure with 3 sub-directories: cur, new, tmp
	  else if ([aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/cur", _path, theName]
				 isDirectory: &is_dir])
	    {
	      // Make sure that these are the maildir directories and not something else.
	      if (![aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/new", _path, theName]
				 isDirectory: &is_dir])
		{
		  POST_NOTIFICATION(PantomimeFolderRenameFailed, self, info);
		  PERFORM_SELECTOR_3(self, @selector(folderRenameFailed:), PantomimeFolderRenameFailed, info);
		  return;
		}
	      if (![aFileManager fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/tmp", _path, theName]
				 isDirectory: &is_dir])
		{
		  POST_NOTIFICATION(PantomimeFolderRenameFailed, self, info);
		  PERFORM_SELECTOR_3(self, @selector(folderRenameFailed:), PantomimeFolderRenameFailed, info);
		  return;
		}
	  }
	  else
	    {
	      POST_NOTIFICATION(PantomimeFolderRenameFailed, self, info);
	      PERFORM_SELECTOR_3(self, @selector(folderRenameFailed:), PantomimeFolderRenameFailed, info);
	      return;
	    }
	}
      
      // If the mailbox is open, we "close" it first.
      aFolder = [_openFolders objectForKey: theName];

      if (aFolder)
	{
	  if ([aFolder type] == PantomimeFormatMbox)
	    {
	      [aFolder close_mbox];
	    }
	  [[aFolder cacheManager] synchronize];
	}
      

      // We rename the mailbox
      aBOOL = [aFileManager moveItemAtPath: [NSString stringWithFormat: @"%@/%@", _path, theName]
			    toPath: [NSString stringWithFormat: @"%@/%@", _path, theNewName]
			    error:NULL];
      
      // We rename the cache, if the store rename was successful
      if (aBOOL)
	{
	  NSString *str1, *str2;
	  
	  str1 = [theName lastPathComponent];
	  str2 = [theNewName lastPathComponent];
	  
	  [[NSFileManager defaultManager] moveItemAtPath: [NSString stringWithFormat: @"%@/%@.%@.cache",
							      _path,
							      [theName substringToIndex:
									 ([theName length] - [str1 length])],
							      str1]
					  toPath: [NSString stringWithFormat: @"%@/%@.%@.cache",
							    _path,
							    [theNewName substringToIndex:
									  ([theNewName length] - [str2 length])],
							    str2]
					  error:NULL];
	}
      
      // If the folder was open, we must re-open and re-lock the mbox file,
      // recache the folder, adjust some paths and more.
      if (aFolder)
	{
	  // We update its name and path
	  [aFolder setName: theNewName];
	  [aFolder setPath: [NSString stringWithFormat: @"%@/%@", _path, theNewName]];

	  [[aFolder cacheManager] setPath: [NSString stringWithFormat: @"%@/%@.%@.cache",
						     _path,
						     [theNewName substringToIndex: ([theNewName length] - [[theNewName lastPathComponent] length])],
						     [theNewName lastPathComponent]]];
	  // We recache the mailbox with its new name.
	  [_openFolders removeObjectForKey: theName];
	  [_openFolders setObject: aFolder  forKey: theNewName];

	  // We now open and lock the mbox file. If we use maildir, we must adjust the "mail filename"
	  // of every message in the maildir.
	  if ([aFolder type] == PantomimeFormatMbox)
	    {
	      [aFolder open_mbox];
	    }
	}

      // Rebuild the folder tree
      [self _rebuildFolderEnumerator];
    }
  
  if (aBOOL)
    {
      POST_NOTIFICATION(PantomimeFolderRenameCompleted, self, info);
      PERFORM_SELECTOR_3(self, @selector(folderRenameCompleted:), PantomimeFolderRenameCompleted, info);
    }
  else
    {
      POST_NOTIFICATION(PantomimeFolderRenameFailed, self, info);
      PERFORM_SELECTOR_3(self, @selector(folderRenameFailed:), PantomimeFolderRenameFailed, info);
    }
}

@end


//
// Private interface
//
@implementation CWLocalStore (Private)

- (void) _enforceFileAttributes
{
    NSEnumerator *anEnumerator;
    NSString *aString;
    
    @autoreleasepool
    {
        
        //
        // We verify if our Store path's mode is 0700
        //
        [[NSFileManager defaultManager] enforceMode: 0700  atPath: _path];
        
        //
        // We ensure that all subdirectories are using mode 0700 and files are using mode 0600
        //
        anEnumerator = [self folderEnumerator];
        
        while ((aString = [anEnumerator nextObject]))
        {
            BOOL is_dir;
            
            aString = [NSString stringWithFormat: @"%@/%@", _path, aString];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath: aString
                                                     isDirectory: &is_dir])
            {
                if ( is_dir )
                {
                    [[NSFileManager defaultManager] enforceMode: 0700
                                                         atPath: aString];
                }
                else
                {
                    [[NSFileManager defaultManager] enforceMode: 0600
                                                         atPath: aString];
                }
            }
        } 
        
    }
}


//
// Rebuild the folder hierarchy
//
- (NSEnumerator *) _rebuildFolderEnumerator
{
  NSString *aString;	
  NSEnumerator *tmpEnumerator;
  NSArray *tmpArray;
  NSInteger i;
  
  // Clear out our cached folder structure and refresh from the file system
  [_folders removeAllObjects];
  [_folders setArray: [[[NSFileManager defaultManager] enumeratorAtPath: _path] allObjects]];
  
  //
  // We iterate through our array. If mbox A and .A.summary (or .A.cache) exists, we
  // remove .A.summary (or .A.cache) from our mutable array.
  // We do this in two runs:
  // First run: remove maildir sub-directory structure so that is appears as a regular folder.
  // Second run: remove other stuff like *.cache, *.summary
  //
  for (i = 0; i < [_folders count]; i++)
    {
      BOOL bIsMailDir;
      
      aString = [_folders objectAtIndex: i];
      
      // NSString *lastPathComponent = [aString lastPathComponent];
      // NSString *pathToFolder = [aString substringToIndex: ([aString length] - [lastPathComponent length])];
    
      //
      // First run:
      // If this is a maildir directory, remove its sub-directory structure from the list,
      // so that the maildir store appears just like a regular mail store.
      //
      if ([[NSFileManager defaultManager] fileExistsAtPath: [NSString stringWithFormat: @"%@/%@/cur", 
								      _path, aString] 
					  isDirectory: &bIsMailDir] && bIsMailDir)
	{
	  NSArray *subpaths;
	
	  // Wust ensure 700 mode un cur/new/tmp folders and 600 on all files (ie., messages)
	  [[NSFileManager defaultManager] enforceMode: 0700
		atPath: [NSString stringWithFormat: @"%@/%@/cur", _path, aString]];

	  [[NSFileManager defaultManager] enforceMode: 0700
		atPath: [NSString stringWithFormat: @"%@/%@/new", _path, aString]];
	  
	  [[NSFileManager defaultManager] enforceMode: 0700
		atPath: [NSString stringWithFormat: @"%@/%@/tmp", _path, aString]];
	  
	  
	  // Get all the children of this directory an remove them from our mutable array.
	  /*NSDirectoryEnumerator *maildirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath: 
								[NSString stringWithFormat: @"%@/%@", 
									  _path, aString]];*/
	  
	  subpaths = [[NSFileManager defaultManager] subpathsAtPath: [NSString stringWithFormat: @"%@/%@", 
									       _path, aString]];
	  [_folders removeObjectsInRange: NSMakeRange(i+1,[subpaths count])];
	}
    }
  
  //
  // Second Run: Get rid of cache, summary and OS specific stuff
  //
  tmpArray = [[NSArray alloc] initWithArray: _folders];
  tmpEnumerator = [tmpArray objectEnumerator];
  
  while ((aString = [tmpEnumerator nextObject]))
    {
      NSString *lastPathComponent = [aString lastPathComponent];
      NSString *pathToFolder = [aString substringToIndex: ([aString length] - [lastPathComponent length])];
      
      // We remove Netscape/Mozilla summary file.
      [_folders removeObject: [NSString stringWithFormat: @"%@.%@.summary", pathToFolder, lastPathComponent]];
      
      // We remove Pantomime's cache file. Before doing so, we ensure it's 600 mode.
      [_folders removeObject: [NSString stringWithFormat: @"%@.%@.cache", pathToFolder, lastPathComponent]];
      [[NSFileManager defaultManager] enforceMode: 0600
				      atPath: [NSString stringWithFormat: @"%@/%@.%@.cache", _path, pathToFolder, lastPathComponent]];

      // We also remove Apple Mac OS X .DS_Store directory
      [_folders removeObject: [NSString stringWithFormat: @"%@.DS_Store", pathToFolder]];
    }
  
  return [_folders objectEnumerator];
}

@end