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

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature              successBlock:(JSONSuccessBlock) successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) addUser: (NSString *) username derivedPassword:  (NSString *)derivedPassword dhKey: (NSString *)encodedDHKey dsaKey: (NSString *)encodedDSAKey signature: (NSString *)signature version: (NSString *) version successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock ;
-(void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) getPublicKeysForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) getLatestDataSinceUserControlId: (NSInteger) latestUserControlId spotIds: (NSArray *) spotIds successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock;
-(void) logout;
-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) deleteMessagesUTAI:(NSInteger) utaiId name: (NSString *) name successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) userExists: (NSString *) username successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock;
-(void) setUnauthorized;
@end
