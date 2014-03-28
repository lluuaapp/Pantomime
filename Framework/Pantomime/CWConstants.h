/*
**  CWConstants.h
**
**  Copyright (c) 2001-2007
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

@class NSString;

//
// The current version of Pantomime.
//
#define PANTOMIME_VERSION @"1.2.0"

//
// Useful macros that we must define ourself on OS X.
//
#ifdef MACOSX 
#define ASSIGN(object,value)    object = value
#define DESTROY(object) object = nil
#define _(X) NSLocalizedString (X, @"")
#endif

//
// Some macros, to minimize the code.
//
#define PERFORM_SELECTOR_1(del, sel, name) ({ \
\
BOOL aBOOL; \
\
aBOOL = NO; \
\
if (del && [del respondsToSelector:sel]) \
{ \
  (void)[del performSelector:sel \
				  withObject:[NSNotification notificationWithName:name \
														   object:self]]; \
  aBOOL = YES; \
} \
\
aBOOL; \
})

#define PERFORM_SELECTOR_2(del, sel, name, obj, key) \
if (del && [del respondsToSelector: sel]) \
{ \
  (void)[del performSelector:sel \
		          withObject:[NSNotification notificationWithName:name \
														   object:self \
														 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:obj, key, nil]]]; \
}

#define PERFORM_SELECTOR_3(del, sel, name, info) \
if (del && [del respondsToSelector: sel]) \
{ \
  (void)[del performSelector:sel \
                  withObject:[NSNotification notificationWithName:name \
														   object:self \
													     userInfo:info]]; \
}

#define AUTHENTICATION_COMPLETED(del, s) \
POST_NOTIFICATION(PantomimeAuthenticationCompleted, self, [NSDictionary dictionaryWithObject: ((id)s?(id)s:(id)@"")  forKey:  @"Mechanism"]); \
PERFORM_SELECTOR_2(del, @selector(authenticationCompleted:), PantomimeAuthenticationCompleted, ((id)s?(id)s:(id)@""), @"Mechanism");


#define AUTHENTICATION_FAILED(del, s) \
POST_NOTIFICATION(PantomimeAuthenticationFailed, self, [NSDictionary dictionaryWithObject: ((id)s?(id)s:(id)@"")  forKey:  @"Mechanism"]); \
PERFORM_SELECTOR_2(del, @selector(authenticationFailed:), PantomimeAuthenticationFailed, ((id)s?(id)s:(id)@""), @"Mechanism");

#define POST_NOTIFICATION(name, obj, info) \
[[NSNotificationCenter defaultCenter] postNotificationName: name \
  object: obj \
  userInfo: info]

/*!
  @typedef PantomimeEncoding
  @abstract Supported encodings.
  @discussion This enum lists the supported Content-Transfer-Encoding
              values. See RFC 2045 - 6. Content-Transfer-Encoding Header Field
	      (all all sub-sections) for a detailed description of the
	      possible values.
  @constant PantomimeEncodingNone No encoding.
  @constant PantomimeEncoding7bit No encoding, same value as PantomimeEncodingNone.
  @constant PantomimeEncodingQuotedPrintable The quoted-printable encoding.
  @constant PantomimeEncodingBase64 The base64 encoding.
  @constant PantomimeEncoding8bit Identity encoding.
  @constant PantomimeEncodingBinary Identity encoding.
*/
typedef NS_ENUM(NSInteger, PantomimeEncoding)
{
  PantomimeEncodingNone = 0,
  PantomimeEncoding7bit = 0,
  PantomimeEncodingQuotedPrintable = 1,
  PantomimeEncodingBase64 = 2,
  PantomimeEncoding8bit = 3,
  PantomimeEncodingBinary = 4
};


/*!
  @typedef PantomimeFolderFormat
  @abstract The supported folder formats.
  @discussion Pantomime supports various local folder formats. Currently,
              the mbox and maildir formats are supported. Also, a custom
	      format is defined to represent folder which holds folders
	      (ie., not messages).
  @constant PantomimeFormatMbox The mbox format.
  @constant PantomimeFormatMaildir The maildir format.
  @constant PantomimeFormatMailSpoolFile The mail spool file, in mbox format but without cache synchronization.
  @constant PantomimeFormatFolder Custom format.
*/
typedef NS_ENUM(NSInteger, PantomimeFolderFormat)
{
  PantomimeFormatMbox = 0,
  PantomimeFormatMaildir = 1,
  PantomimeFormatMailSpoolFile = 2,
  PantomimeFormatFolder = 3
};


/*!
  @typedef PantomimeMessageFormat
  @abstract The format of a message.
  @discussion Pantomime supports two formats when encoding
              plain/text parts. The formats are described in RFC 2646.
  @constant PantomimeFormatUnknown Unknown format.
  @constant PantomimeFormatFlowed The "format=flowed" is used.
*/
typedef NS_ENUM(NSInteger, PantomimeMessageFormat)
{
  PantomimeFormatUnknown = 0,
  PantomimeFormatFlowed = 1
};


/*!
  @typedef PantomimeFlag
  @abstract Valid message flags.
  @discussion This enum lists valid message flags. Flags can be combined
              using a bitwise OR.
  @constant PantomimeAnswered The message has been answered.
  @constant PantomimeDraft The message is an unsent, draft message.
  @constant PantomimeFlagged The message is flagged.
  @constant PantomimeRecent The message has been recently received.
  @constant PantomimeSeen The message has been read.
  @constant PantomimeDeleted The message is marked as deleted.
*/
typedef NS_ENUM(NSInteger, PantomimeFlag)
{
  PantomimeAnswered = 1,
  PantomimeDraft = 2,
  PantomimeFlagged = 4,
  PantomimeRecent = 8,
  PantomimeSeen = 16,
  PantomimeDeleted = 32
};


/*!
  @typedef PantomimeFolderType
  @abstract Flags/name attributes for mailboxes/folders.
  @discussion This enum lists the potential mailbox / folder
              flags which some IMAP servers can enforce.
	      Those flags have few meaning for POP3 and
	      Local mailboxes. Flags can be combined using
	      a bitwise OR.
  @constant PantomimeHoldsFolders The folder holds folders.
  @constant PantomimeHoldsMessages The folder holds messages.
  @constant PantomimeNoInferiors The folder has no sub-folders.
  @constant PantomimeNoSelect The folder can't be opened.
  @constant PantomimeMarked The folder is marked as "interesting".
  @constant PantomimeUnmarked The folder does not contain any new
                              messages since the last time it has been open.
*/
typedef NS_ENUM(NSInteger, PantomimeFolderType)
{
  PantomimeHoldsFolders = 1,
  PantomimeHoldsMessages = 2,
  PantomimeNoInferiors = 4,
  PantomimeNoSelect = 8,
  PantomimeMarked = 16,
  PantomimeUnmarked = 32
};


/*!
  @typedef PantomimeSearchMask
  @abstract Mask for Folder: -search: mask: options:
  @discussion This enum lists the possible values of the
              search mask. Values can be combined using
	      a bitwise OR.
  @constant PantomimeFrom Search in the "From:" header value.
  @constant PantomimeTo Search in the "To:" header value.
  @constant PantomimeSubject Search in the "Subject:" header value.
  @constant PantomimeContent Search in the message content.
*/
typedef NS_ENUM(NSInteger, PantomimeSearchMask)
{
  PantomimeFrom = 1,
  PantomimeTo = 2,
  PantomimeSubject = 4,
  PantomimeContent = 8
};


/*!
  @typedef PantomimSearchOption
  @abstract Options for Folder: -search: mask: options:
  @discussion This enum lists the possible options when
              performing a search.
  @constant PantomimeCaseInsensitiveSearch Don't consider the case when performing a search operation.
  @constant PantomimeRegularExpression The search criteria represents a regular expression.
*/
typedef NS_ENUM(NSInteger, PantomimeSearchOption)
{
  PantomimeCaseInsensitiveSearch = 1,
  PantomimeRegularExpression = 2
};


/*!
  @typedef PantomimeFolderMode
  @abstract Valid modes for folder.
  @discussion This enum lists the valid mode to be used when
              opening a folder.
  @constant PantomimeUnknownMode Unknown mode.
  @constant PantomimeReadOnlyMode The folder will be open in read-only.
  @constant PantomimeReadWriteMode The folder will be open in read-write.
*/
typedef NS_ENUM(NSInteger, PantomimeFolderMode)
{
  PantomimeUnknownMode = 1,
  PantomimeReadOnlyMode = 2,
  PantomimeReadWriteMode = 3
};

/*!
  @typedef PantomimeForwardMode
  @abstract Valid modes when forwarding a message.
  @discussion This enum lists the valid mode to be
              used when forwarding a message.
  @constant PantomimeAttachmentForwardMode The message will be attached.
  @constant PantomimeInlineForwardMode The text parts of the message will be
                                       extracted and included inline in the
				       forwarded response.
*/
typedef NS_ENUM(NSInteger, PantomimeForwardMode)
{
  PantomimeAttachmentForwardMode = 1,
  PantomimeInlineForwardMode = 2
};


/*!
  @typedef PantomimeContentDisposition
  @abstract Valid modes when setting a Content-Disposition.
  @discussion This enum lists the valid Content-Disposition
              as stated in the RFC2183 standard.
  @constant PantomimeAttachmentDisposition The part is separated from the mail body.
  @constant PantomimeInlineDisposition The part is part of the mail body.
*/
typedef NS_ENUM(NSInteger, PantomimeContentDisposition)
{
  PantomimeAttachmentDisposition = 1,
  PantomimeInlineDisposition = 2
};

/*!
  @typedef PantomimeReplyMode
  @abstract Valid modes when replying to a message.
  @discussion This enum lists the valid modes to be
              used when replying to a message. Those
	      modes are to be used with CWMessage: -reply:
	      PantomimeSimpleReplyMode and PantomimeNormalReplyMode
	      can NOT be combined but can be individually combined
	      with PantomimeReplyAllMode.
  @constant PantomimeSimpleReplyMode Reply to the sender, without a message content
  @constant PantomimeNormalReplyMode Reply to the sender, with a properly build message content.
  @constant PantomimeReplyAllMode Reply to all recipients.
*/
typedef NS_ENUM(NSInteger, PantomimeReplyMode)
{
  PantomimeSimpleReplyMode = 1,
  PantomimeNormalReplyMode = 2,
  PantomimeReplyAllMode = 4
};


/*!
  @typedef PantomimeRecipientType
  @abstract Valid recipient types.
  @discussion This enum lists the valid kind of recipients
              a message can have.
  @constant PantomimeToRecipient Recipient which will appear in the "To:" header value.
  @constant PantomimeCcRecipient Recipient which will appear in the "Cc:" header value.
  @constant PantomimeBccRecipient Recipient which will obtain a black carbon copy of the message.
  @constant PantomimeResentToRecipient Recipient which will appear in the "Resent-To:" header value.
  @constant PantomimeResentCcRecipient Recipient which will appear in the "Resent-Cc:" header value.
  @constant PantomimeResentBccRecipient Recipient which will obtain a black carbon copy of the message
                                        being redirected.
*/
typedef NS_ENUM(NSInteger, PantomimeRecipientType)
{
  PantomimeToRecipient = 1,
  PantomimeCcRecipient = 2,
  PantomimeBccRecipient = 3,
  PantomimeResentToRecipient = 4,
  PantomimeResentCcRecipient = 5,
  PantomimeResentBccRecipient = 6
};

