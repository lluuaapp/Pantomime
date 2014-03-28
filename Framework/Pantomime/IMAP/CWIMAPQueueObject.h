//
//  CWIMAPQueueObject.h
//  SalesParser
//
//  Created by Paul Hecker on 28.03.14.
//
//

#import "CWIMAPStore.h"

@interface CWIMAPQueueObject : NSObject

@property IMAPCommand command;
@property NSString *arguments;
@property NSData *tag;
@property NSMutableDictionary *info;
@property NSInteger literal;

- (id) initWithCommand:(IMAPCommand)theCommand
             arguments:(NSString *)theArguments
                   tag:(NSData *)theTag
                  info:(NSDictionary *)theInfo;
@end
