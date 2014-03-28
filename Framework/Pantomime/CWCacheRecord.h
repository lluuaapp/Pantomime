//
//  CWCacheRecord.h
//  SalesParser
//
//  Created by Paul Hecker on 07.10.11.
//  Copyright (c) 2011 iwascoding GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

//
// Simple macro used to initialize a record to some
// default values. Faster than a memset().
//
#define CLEAR_CACHE_RECORD(r) \
    r.date = 0; \
    r.flags = 0; \
    r.position = 0; \
    r.size = 0; \
    r.imap_uid = 0; \
    r.pop3_uid = nil;\
    r.from = nil; \
    r.in_reply_to = nil; \
    r.message_id = nil; \
    r.references = nil; \
    r.subject = nil; \
    r.to = nil; \
    r.cc = nil;

@interface CWCacheRecord : NSObject
{
@private
    NSUInteger date;
    NSUInteger flags;
    NSUInteger position;   // For mbox based cache files
    NSUInteger size;
    NSUInteger imap_uid;   // For IMAP
    char *filename;          // For maildir base cache files
    NSString *pop3_uid;      // For POP3
    NSData *from;
    NSData *in_reply_to;
    NSData *message_id;
    NSData *references;
    NSData *subject;
    NSData *to;
    NSData *cc;
}

@property (assign) NSUInteger date;
@property (assign) NSUInteger flags;
@property (assign) NSUInteger position;
@property (assign) NSUInteger size;
@property (assign) NSUInteger imap_uid;
@property (assign) char *filename;
@property (strong) NSString *pop3_uid;
@property (strong) NSData *from;
@property (strong) NSData *in_reply_to;
@property (strong) NSData *message_id;
@property (strong) NSData *references;
@property (strong) NSData *subject;
@property (strong) NSData *to;
@property (strong) NSData *cc;

@end
