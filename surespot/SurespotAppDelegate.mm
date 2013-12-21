//
//  SurespotAppDelegate.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotAppDelegate.h"
#import "SurespotMessage.h"
#import "ChatController.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "SurespotLogFormatter.h"
#import "UIUtils.h"
#import "TestFlight.h"
#import "IdentityController.h"
#import "UIUtils.h"
#import "AGWindowView.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@implementation SurespotAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TestFlight takeOff:@"b1b351a8-07ad-4433-8889-701d2775c64d"];
    
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound) ];
    if  (launchOptions) {
        DDLogVerbose(@"received launch options: %@", launchOptions);
    }
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance]setLogFormatter: [SurespotLogFormatter new]];
    [UIUtils setAppAppearances];
    
    //show create if we don't have any identities, otherwise login
    
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    UINavigationController *rootViewController = [storyboard instantiateViewControllerWithIdentifier:@"navigationController"];
    self.window.rootViewController = rootViewController;
    
    
    
    if ([[[IdentityController sharedInstance] getIdentityNames ] count] == 0 ) {
        
        [rootViewController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"], [storyboard instantiateViewControllerWithIdentifier:@"signupViewController"]]];
    }
    else {
        [rootViewController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"]]];
    }
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [[NSUserDefaults standardUserDefaults] setObject:appVersionString forKey:@"version_preference"];
    
    
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    [[NSUserDefaults standardUserDefaults] setObject:appBuildString forKey:@"build_preference"];
    
    
    [self.window makeKeyAndVisible];

    _overlayView = [[AGWindowView alloc] initAndAddToKeyWindow];
    _overlayView.supportedInterfaceOrientations = AGInterfaceOrientationMaskAll;
    _overlayView.userInteractionEnabled = NO;
        
    return YES;
}

//launch from smart banner or url
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if (!url) {  return NO; }
    
    [self setUrl:url];
    return YES;
    
}



-(void) setUrl: (NSURL*) url {
    DDLogInfo(@"set url %@", url);
    
    if ([url.scheme isEqualToString:@"surespot"]) {
        if ([[url host] isEqualToString:@"autoinvite"]) {
            NSString * username = [[url path] substringFromIndex:1];
            
            
            if (username) {
                DDLogInfo(@"adding autoinvite for %@",  username);
                //get autoinvite users
                
                
                NSMutableArray * autoinvites  = [NSMutableArray arrayWithArray: [[NSUserDefaults standardUserDefaults] stringArrayForKey: @"autoinvites"]];
                [autoinvites addObject: username];
                [[NSUserDefaults standardUserDefaults] setObject: autoinvites forKey: @"autoinvites"];
                //fire event
                [[NSNotificationCenter defaultCenter] postNotificationName:@"autoinvites" object:nil ];
            }
        }
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    DDLogInfo(@"received remote notification: %@, applicationstate: %d", userInfo, [application applicationState]);
    
    //todo download and add the message or just move to tab and tell it to load
    switch ([application applicationState]) {
        case UIApplicationStateActive:
        {
            //application was running when we received
            //if we're not on the tap, show notification
            NSString * notificationType =[userInfo valueForKeyPath:@"aps.alert.loc-key" ] ;
            if ([notificationType isEqualToString:@"notification_message"] ||
                [notificationType isEqualToString:@"notification_invite"]  ||
                [notificationType isEqualToString:@"notification_invite_accept"]) {
                //if we're not logged in as the user add a local notifcation and show a toast
                
                NSArray * locArgs =[userInfo valueForKeyPath:@"aps.alert.loc-args" ] ;
                NSString * to =[locArgs objectAtIndex:0];
                if (![to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]] &&
                    [[[IdentityController sharedInstance] getIdentityNames] containsObject:to]) {
                    
                    NSString * from =[locArgs objectAtIndex:1];
                    [UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(notificationType, nil), to, from] duration:1];
                    
                    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
                    localNotification.fireDate = nil;
                    localNotification.alertBody = [NSString stringWithFormat: NSLocalizedString(notificationType, nil), to, from];
                    localNotification.alertAction = NSLocalizedString(@"notification_title", nil);
                    localNotification.soundName = UILocalNotificationDefaultSoundName;
                    [application scheduleLocalNotification:localNotification];
                }
            }
        }
            
            break;
            
        case UIApplicationStateInactive:
        case UIApplicationStateBackground:
            //     [notificationData setObject:@"inactive" forKey:@"applicationState"];
            
            //started application from notification, move to correct tab
            
            break;
    }
    
    // [[NSNotificationCenter defaultCenter] postNotificationName:@"pushNotification" object:notificationData ];
}
//
//- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
//{
//
//}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    //   DDLogVerbose(@"background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    //  DDLogVerbose(@"foreground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    DDLogVerbose(@"application will terminate");
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken {
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:devToken forKey:@"apnToken"];
    
    //todo set token on server
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    DDLogVerbose(@"Error in registration. Error: %@", err);
}


@end
