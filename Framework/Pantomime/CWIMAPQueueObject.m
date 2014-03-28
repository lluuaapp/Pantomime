//
//  CWIMAPQueueObject.m
//  SalesParser
//
//  Created by Paul Hecker on 28.03.14.
//
//

#import "CWIMAPQueueObject.h"

@implementation CWIMAPQueueObject

- (id) initWithCommand:(IMAPCommand)theCommand
             arguments:(NSString *)theArguments
                   tag:(NSData *)theTag
                  info:(NSDictionary *)theInfo;
{
    self = [super init];
    if (self)
    {
        _command = theCommand;
        _literal = 0;
        _arguments = theArguments;
        _tag = theTag;
        
        if (theInfo)
        {
            _info = [[NSMutableDictionary alloc] initWithDictionary: theInfo];
        }
        else
        {
            _info = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%ld %@", (long)self.command, self.arguments];
}

@end
