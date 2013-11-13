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

static const int ddLogLevel = LOG_LEVEL_OFF;

@implementation SurespotAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
      [TestFlight takeOff:@"477c73c2-7b09-4198-a7a8-95b5d3581f91"];
    
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIReturnKeyDefault) ];
    if  (launchOptions) {
        DDLogVerbose(@"received launch options: %@", launchOptions);
    }
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance]setLogFormatter: [SurespotLogFormatter new]];
    [UIUtils setAppAppearances];
    return YES;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    DDLogVerbose(@"received remote notification: %@, applicationstate: %d", userInfo, [application applicationState]);
    
    // id apsDict = [userInfo objectForKey:@"aps" ];
    // NSDictionary * alertDict = [apsDict objectForKey:@"alert" ];
    // NSString * type = [[alertDict objectForKey:@"loc-key"] copy];
    
    NSMutableDictionary *notificationData = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    
    //todo download and add the message or just move to tab and tell it to load
    switch ([application applicationState]) {
        case UIApplicationStateActive:
            //application was running when we received
            //if we're not on the tap, show notification
            
            //            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"MyAlertView"
            //                                                                message:@"Local notification was received"
            //                                                               delegate:self cancelButtonTitle:@"OK"
            //                                                      otherButtonTitles:nil];
            //            [alertView show];
            
                   [notificationData setObject:@"active" forKey:@"applicationState"];
//            if ([[userInfo valueForKeyPath:@"aps.alert.loc-key" ] isEqualToString:@"notification_message"]) {
//
//                
//                NSString * to =[ userInfo objectForKey:@"to"];
//                NSString * from =[ userInfo objectForKey:@"from"];
//                
//                UILocalNotification* localNotification = [[UILocalNotification alloc] init];
//                localNotification.fireDate = nil;
//                localNotification.alertBody = [NSString stringWithFormat: NSLocalizedString(@"notification_message", nil), to, from];
//                localNotification.alertAction = NSLocalizedString(@"notification_title", nil);
//                localNotification.soundName = UILocalNotificationDefaultSoundName;
//                [application scheduleLocalNotification:localNotification];
//            }
            
            
            break;
        case UIApplicationStateInactive:
        case UIApplicationStateBackground:
            [notificationData setObject:@"inactive" forKey:@"applicationState"];
            
            //started application from notification, move to correct tab
            
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pushNotification" object:notificationData ];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    
}

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
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    DDLogVerbose(@"Error in registration. Error: %@", err);
}


@end
