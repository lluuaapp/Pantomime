/*
**  CWFolderInformation.h
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

/*!
  @class CWFolderInformation
  @discussion This class provides a container to cache folder information like
              the number of messages and unread messages the folder holds, and
	      its total size. Normally you won't use this class directly but
	      CWFolder's subclasses return instances of this class, when
	      calling -folderStatus on a CWFolder instance.
*/      
@interface CWFolderInformation : NSObject

@property (nonatomic, assign) NSUInteger nbOfMessages;
@property (nonatomic, assign) NSUInteger nbOfUnreadMessages;
@property (nonatomic, assign) NSUInteger size;

@end
