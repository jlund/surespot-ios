//
//  NetworkController.h
//  surespot
//
//  Created by Adam on 6/16/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "AFHTTPClient.h"
#import"AFNetworking.h"

typedef void (^JSONResponseBlock) (NSDictionary* json);
typedef void (^JSONSuccessBlock) (NSURLRequest *request, NSHTTPURLResponse *response, id JSON);
typedef void (^JSONFailureBlock) (NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON);


@interface NetworkController : AFHTTPClient

+(NetworkController*)sharedInstance;
//send an API command to the server
-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature;
-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
@end
