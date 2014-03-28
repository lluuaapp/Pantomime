/*
**  CWMD5.m
**
**  Copyright (c) 2002-2006
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

#import "CWMD5.h"
#import "CWConstants.h"
#import "NSData+CWExtensions.h"

#include <CommonCrypto/CommonDigest.h>

#define word32 NSUInteger

void md5_hmac(unsigned char *digest, const unsigned char* text, int text_len, const unsigned char* key, int key_len);

//
//
//
@implementation CWMD5

- (id) initWithData: (NSData *) theData
{
    self = [super init];
    if (self)
    {
        _data = theData;
        _has_computed_digest = NO;
    }
    return self;
}

//
//
//
- (void) computeDigest
{
  
  // If we already have computed the digest
  if (_has_computed_digest)
    {
      return;
    }

    unsigned char *bytes = (unsigned char *)[_data bytes];
    NSUInteger len = [_data length];

    // new version
    CC_MD5_CTX c;
    CC_MD5_Init(&c);
    CC_MD5_Update(&c, bytes, len);
    CC_MD5_Final(_digest, &c);

  _has_computed_digest = YES;
}


//
//
//
- (NSData *) digest
{
  if (!_has_computed_digest)
    {
      return nil;
    }
  
  return [NSData dataWithBytes: _digest  length: 16];
}


//
//
//
- (NSString *) digestAsString
{
  if (!_has_computed_digest)
    {
      return nil;
    }
  else
    {
      NSMutableString *aMutableString;
      NSInteger i;

      aMutableString = [[NSMutableString alloc] init];
      
      for (i = 0; i < 16; i++)
	{
	  [aMutableString appendFormat: @"%02lx", (NSUInteger)_digest[i]];
	}
      
      return aMutableString;
    }
}


//
// The challenge phrase used is the one that has been initialized
// with this object. The digest MUST have been computed first.
//
- (NSString *) hmacAsStringUsingPassword: (NSString *) thePassword
{
  if (!_has_computed_digest)
    {
      return nil;
    }
  else
    {
      NSMutableString *aMutableString;
      unsigned char result[16];
      unsigned char *s;
      NSInteger i;

      s = (unsigned char*)[_data cString];
      md5_hmac(result, s, strlen((char*)s), (unsigned char*)[thePassword UTF8String], [thePassword length]);
      
      aMutableString = [[NSMutableString alloc] init];

      for (i = 0; i < 16; i++)
	{
	  [aMutableString appendFormat: @"%02x", (int)result[i]];
	}
      
      return aMutableString;
    }
}

@end

/*
** Function: md5_hmac
** Taken from the file RFC2104
** Written by Martin Schaaf <mascha@ma-scha.de>, modified by Ludovic Marcotte <ludovic@Sophos.ca>
*/
void
md5_hmac(unsigned char *digest,
	 const unsigned char* text, int text_len,
	 const unsigned char* key, int key_len)
{
	CC_MD5_CTX context;
	unsigned char k_ipad[64];    /* inner padding -
								  * key XORd with ipad
								  */
	unsigned char k_opad[64];    /* outer padding -
								  * key XORd with opad
								  */
	/* unsigned char tk[16]; */
	int i;
	
	/* start out by storing key in pads */
	memset(k_ipad, 0, sizeof k_ipad);
	memset(k_opad, 0, sizeof k_opad);
	
	if (key_len > 64)
    {
		/* if key is longer than 64 bytes reset it to key=MD5(key) */
		CC_MD5_CTX tctx;
		
		CC_MD5_Init(&tctx);
		CC_MD5_Update(&tctx, key, key_len);
		CC_MD5_Final(k_ipad, &tctx);
		CC_MD5_Final(k_opad, &tctx);
    } 
	else
    {
		memcpy(k_ipad, key, key_len);
		memcpy(k_opad, key, key_len);
    }
	
	/*
	 * the HMAC_MD5 transform looks like:
	 *
	 * MD5(K XOR opad, MD5(K XOR ipad, text))
	 *
	 * where K is an n byte key
	 * ipad is the byte 0x36 repeated 64 times
	 * opad is the byte 0x5c repeated 64 times
	 * and text is the data being protected
	 */
	
	
	/* XOR key with ipad and opad values */
	for (i = 0; i < 64; i++)
    {
		k_ipad[i] ^= 0x36;
		k_opad[i] ^= 0x5c;
    }
	
	/*
	 * perform inner MD5
	 */
	CC_MD5_Init(&context);		       /* init context for 1st
									* pass */
	CC_MD5_Update(&context, k_ipad, 64);     /* start with inner pad */
	CC_MD5_Update(&context, text, text_len); /* then text of datagram */
	CC_MD5_Final(digest, &context);	       /* finish up 1st pass */
	
	/*
	 * perform outer MD5
	 */
	CC_MD5_Init(&context);		       /* init context for 2nd
									* pass */
	CC_MD5_Update(&context, k_opad, 64);     /* start with outer pad */
	CC_MD5_Update(&context, digest, 16);     /* then results of 1st
										   * hash */
	CC_MD5_Final(digest, &context);	       /* finish up 2nd pass */
}
