//
//  DefaultSHKConfigurationDelegate.m
//  ShareKit
//
//  Created by Edward Dale on 10/16/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SurespotSHKConfigurator.h"
#import "SHKFile.h"
#import "SurespotConstants.h"

@implementation SurespotSHKConfigurator

/* 
 App Description 
 ---------------
 These values are used by any service that shows 'shared from XYZ'
 */
- (NSString*)appName {
	return @"surespot";
}

- (NSString*)appURL {
	return @"https://www.surespot.me";
}

/*
 API Keys
 --------
 This is the longest step to getting set up, it involves filling in API keys for the supported services.
 It should be pretty painless though and should hopefully take no more than a few minutes.
 
 Each key below as a link to a page where you can generate an api key.  Fill in the key for each service below.
 
 A note on services you don't need:
 If, for example, your app only shares URLs then you probably won't need image services like Flickr.
 In these cases it is safe to leave an API key blank.
 
 However, it is STRONGLY recommended that you do your best to support all services for the types of sharing you support.
 The core principle behind ShareKit is to leave the service choices up to the user.  Thus, you should not remove any services,
 leaving that decision up to the user.
 */

// Facebook - https://developers.facebook.com/apps
// SHKFacebookAppID is the Application ID provided by Facebook
// SHKFacebookLocalAppID is used if you need to differentiate between several iOS apps running against a single Facebook app. Useful, if you have full and lite versions of the same app,
// and wish sharing from both will appear on facebook as sharing from one main app. You have to add different suffix to each version. Do not forget to fill both suffixes on facebook developer ("URL Scheme Suffix"). Leave it blank unless you are sure of what you are doing. 
// The CFBundleURLSchemes in your App-Info.plist should be "fb" + the concatenation of these two IDs.
// Example: 
//    SHKFacebookAppID = 555
//    SHKFacebookLocalAppID = lite
// 
//    Your CFBundleURLSchemes entry: fb555lite
- (NSString*)facebookAppId {
	return FACEBOOK_APP_ID;
}

- (NSString*)facebookLocalAppId {
	return @"";
}

//Change if your app needs some special Facebook permissions only. In most cases you can leave it as it is.

// new with the 3.1 SDK facebook wants you to request read and publish permissions separatly. If you don't
// you won't get a smooth login/auth flow. Since ShareKit does not require any read permissions.
- (NSArray*)facebookWritePermissions {    
    return [NSArray arrayWithObjects:@"publish_actions", nil];
}
- (NSArray*)facebookReadPermissions {    
    return nil;	// this is the defaul value for the SDK and will afford basic read permissions
}

/*
 If you want to force use of old-style, posting path that does not use the native sheet. One of the troubles
 with the native sheet is that it gives IOS6 props on facebook instead of your app. This flag has no effect
 on the auth path. It will try to use native auth if availible.
 */
- (NSNumber*)forcePreIOS6FacebookPosting {
	return [NSNumber numberWithBool:false];
}

/*
 Create a project on Google APIs console,
 https://code.google.com/apis/console . Under "API Access", create a
 client ID as "Installed application" with the type "iOS", and
 register the bundle ID of your application.
 */
- (NSString*)googlePlusClientId {
    return GOOGLE_CLIENT_ID;
}


// Tumblr - http://www.tumblr.com/docs/en/api/v2
- (NSString*)tumblrConsumerKey {
	return TUMBLR_CONSUMER_KEY;
}

- (NSString*)tumblrSecret {
	return TUMBLR_SECRET;
}

//you can put whatever here. It must be the same you entered in tumblr app registration, eg tumblr.sharekit.com
- (NSString*)tumblrCallbackUrl {
	return TUMBLR_CALLBACK_URL;
}

/*
 UI Configuration : Basic
 ------------------------
 These provide controls for basic UI settings.  For more advanced configuration see below.
 */

/*
 For sharers supported by Social.framework you can choose to present Apple's UI (SLComposeViewController) or ShareKit's UI (you can customize ShareKit's UI). Note that SLComposeViewController has only limited sharing capabilities, e.g. for file sharing on Twitter (photo files, video files, large UIImages) ShareKit's UI will be used anyway.
 */
- (NSNumber *)useAppleShareUI {
    return @YES;
}

// Toolbars
- (NSString*)barStyle {
	return @"UIBarStyleDefault";// See: http://developer.apple.com/iphone/library/documentation/UIKit/Reference/UIKitDataTypesReference/Reference/reference.html#//apple_ref/c/econst/UIBarStyleDefault
}

- (UIColor*)barTintForView:(UIViewController*)vc {
    return nil;
}

// Forms
- (UIColor *)formFontColor {
    return nil;
}

- (UIColor*)formBackgroundColor {
    return nil;
}

// iPad views. You can change presentation style for different sharers
- (NSString *)modalPresentationStyleForController:(UIViewController *)controller {
	return @"UIModalPresentationFormSheet";// See: http://developer.apple.com/iphone/library/documentation/UIKit/Reference/UIViewController_Class/Reference/Reference.html#//apple_ref/occ/instp/UIViewController/modalPresentationStyle
}

- (NSString*)modalTransitionStyleForController:(UIViewController *)controller {
	return @"UIModalTransitionStyleCoverVertical";// See: http://developer.apple.com/iphone/library/documentation/UIKit/Reference/UIViewController_Class/Reference/Reference.html#//apple_ref/occ/instp/UIViewController/modalTransitionStyle
}
// ShareMenu Ordering
- (NSNumber*)shareMenuAlphabeticalOrder {
	return [NSNumber numberWithInt:0];// Setting this to 1 will show list in Alphabetical Order, setting to 0 will follow the order in SHKShares.plist
}

/* Name of the plist file that defines the class names of the sharers to use. Usually should not be changed, but this allows you to subclass a sharer and have the subclass be used. Also helps, if you want to exclude some sharers - you can create your own plist, and add it to your project. This way you do not need to change original SHKSharers.plist, which is a part of subproject - this allows you upgrade easily as you did not change ShareKit itself 
 
    You can specify also your own bundle here, if needed. For example:
 return [[[NSBundle mainBundle] pathForResource:@"Vito" ofType:@"bundle"] stringByAppendingPathComponent:@"VKRSTestSharers.plist"]
 */
- (NSString*)sharersPlistName {
	return @"SurespotSHKSharers.plist";
}

// SHKActionSheet settings
- (NSNumber*)showActionSheetMoreButton {
	return [NSNumber numberWithBool:false];// Setting this to true will show More... button in SHKActionSheet, setting to false will leave the button out.
}

/*
 Favorite Sharers
 ----------------
 These values are used to define the default favorite sharers appearing on ShareKit's action sheet.
 */
- (NSArray*)defaultFavoriteURLSharers {
    return [NSArray arrayWithObjects:@"SHKCopy", @"SHKMail", @"SHKTextMessage", @"SHKTwitter",@"SHKFacebook", @"SHKGooglePlus", @"SHKTumblr", nil];
}
- (NSArray*)defaultFavoriteImageSharers {
    return [NSArray arrayWithObjects:@"SHKMail",@"SHKFacebook", @"SHKCopy", nil];
}
- (NSArray*)defaultFavoriteTextSharers {
    return [NSArray arrayWithObjects:@"SHKCopy", @"SHKMail", @"SHKTextMessage", @"SHKTwitter",@"SHKFacebook", @"SHKGooglePlus", @"SHKTumblr", nil];
}

//ShareKit will remember last used sharers for each particular mime type.

- (NSArray *)defaultFavoriteSharersForFile:(SHKFile *)file {
    
    NSMutableArray *result = [NSMutableArray arrayWithObjects:@"SHKMail", nil];
    if ([file.mimeType hasPrefix:@"video/"] || [file.mimeType hasPrefix:@"audio/"] || [file.mimeType hasPrefix:@"image/"]) {
        [result addObject:@"SHKTumblr"];
    }
    return result;
}

- (NSArray*)defaultFavoriteSharersForMimeType:(NSString *)mimeType {
    return [self defaultFavoriteSharersForFile:nil];
}

- (NSArray *)defaultFavoriteFileSharers {
    return [self defaultFavoriteSharersForFile:nil];
}

//by default, user can see last used sharer on top of the SHKActionSheet. You can switch this off here, so that user is always presented the same sharers for each SHKShareType.
- (NSNumber*)autoOrderFavoriteSharers {
    return [NSNumber numberWithBool:false];
}

/*
 UI Configuration : Advanced
 ---------------------------
 If you'd like to do more advanced customization of the ShareKit UI, like background images and more,
 check out http://getsharekit.com/customize. To use a subclass, you can create your own, and let ShareKit know about it in your configurator, overriding one (or more) of these methods.
 */

- (Class)SHKShareMenuSubclass {    
    return NSClassFromString(@"SHKShareMenu");
}

- (Class)SHKShareMenuCellSubclass {
    return NSClassFromString(@"UITableViewCell");
}

///You can override methods from Configuration section (see SHKFormController.h) to use your own cell subclasses.
- (Class)SHKFormControllerSubclass {
    return NSClassFromString(@"SHKFormController");
}

/*
 Advanced Configuration
 ----------------------
 These settings can be left as is.  This only need to be changed for uber custom installs.
 */

- (NSNumber*)maxFavCount {
	return [NSNumber numberWithInt:3];
}

- (NSString*)favsPrefixKey {
	return @"SHK_FAVS_";
}

- (NSString*)authPrefix {
	return @"SHK_AUTH_";
}

- (NSNumber*)allowOffline {
	return [NSNumber numberWithBool:true];
}

- (NSNumber*)allowAutoShare {
	return [NSNumber numberWithBool:true];
}

/* 
 Debugging settings
 ------------------
 see Debug.h
 */

/*
 SHKItem sharer specific values defaults
 -------------------------------------
 These settings can be left as is. SHKItem is what you put your data in and inject to ShareKit to actually share. Some sharers might be instructed to share the item in specific ways, e.g. SHKPrint's print quality, SHKMail's send to specified recipients etc. Sometimes you need to change the default behaviour - you can do it here globally, or per share during share item (SHKItem) composing. Example is in the demo app - ExampleShareLink.m - share method */


/* SHKMail */

//You can use this to prefill recipients. User enters them in MFMailComposeViewController by default. Should be array of NSStrings.
- (NSArray *)mailToRecipients {
	return nil;
}

- (NSNumber*)isMailHTML {
    return [NSNumber numberWithInt:1];
}

//used only if you share image. Values from 1.0 to 0.0 (maximum compression).
- (NSNumber*)mailJPGQuality {
    return [NSNumber numberWithFloat:1];
}

// append 'Sent from <appName>' signature to Email
- (NSNumber*)sharedWithSignature {
	return [NSNumber numberWithInt:0];
}

/* SHKFacebook */

//when you share URL on Facebook, FBDialog scans the page and fills picture and description automagically by default. Use these item properties to set your own.
- (NSString *)facebookURLSharePictureURI {
    return nil;
}

- (NSString *)facebookURLShareDescription {
    return nil;
}

/* SHKTextMessage */

//You can use this to prefill recipients. User enters them in MFMessageComposeViewController by default. Should be array of NSStrings.
- (NSArray *)textMessageToRecipients {
  return nil;
}

-(NSString*) popOverSourceRect;
 {
  return NSStringFromCGRect(CGRectZero);
}

@end
