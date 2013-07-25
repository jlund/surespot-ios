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
typedef void (^HTTPSuccessBlock) (AFHTTPRequestOperation *operation , id responseObject);
typedef void (^HTTPFailureBlock) (AFHTTPRequestOperation *operation , NSError *error );

@interface NetworkController : AFHTTPClient

+(NetworkController*)sharedInstance;
//send an API command to the server
-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature;
-(void) addUser: (NSString *) username derivedPassword:  (NSString *)derivedPassword dhKey: (NSString *)encodedDHKey dsaKey: (NSString *)encodedDSAKey signature: (NSString *)signature version: (NSString *) version successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;

-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
@end
