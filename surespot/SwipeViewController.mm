//
//  SwipeViewController.m
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SwipeViewController.h"
#import "NetworkController.h"
#import "ChatController.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "MessageProcessor.h"
#import <UIKit/UIKit.h>
#import "OurMessageView.h"
//#import <QuartzCore/CATransaction.h>

@interface SwipeViewController ()
@property (nonatomic, strong) NSString * currentChat;
@property (nonatomic, strong) dispatch_queue_t dateFormatQueue;
@property (nonatomic, strong) NSDateFormatter * dateFormatter;
@end


@implementation SwipeViewController


- (void)viewDidLoad
{
    NSLog(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    _dateFormatQueue = dispatch_queue_create("date format queue", NULL);
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _chats = [[NSMutableDictionary alloc] init];
    
    //configure swipe view
    _swipeView.alignment = SwipeViewAlignmentCenter;
    _swipeView.pagingEnabled = YES;
    _swipeView.wrapEnabled = NO;
    _swipeView.truncateFinalPage =NO ;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    //configure page control
    //_pageControl.numberOfPages = _swipeView.numberOfPages;
    //_pageControl.defersCurrentPageDisplay = YES;
    
    _textField.enablesReturnKeyAutomatically = NO;
    [self registerForKeyboardNotifications];
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"menu" style:UIBarButtonItemStylePlain target:self action:@selector(refreshPropertyList:)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    self.navigationItem.title = [@"surespot/" stringByAppendingString:[[IdentityController sharedInstance] getLoggedInUser]];
    
    //    UIView * tlg = (id) self.topLayoutGuide;
    //  UIScrollView * scrollView = _swipeView.scrollView;
    //    NSDictionary * viewsDictionary = NSDictionaryOfVariableBindings(scrollView, tlg);
    
    
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    // Set the constraints for the scroll view and the image view.
    //  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[scrollView]|" options:0 metrics: 0 views:viewsDictionary]];
    // [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[tlg][scrollView]" options:0 metrics: 0 views:viewsDictionary]];
    
    //make sure chat controller loaded
    [ChatController sharedInstance];
    
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    
    
    
    NSLog(@"keyboardWasShown");
    
    
    UITableView * tableView =(UITableView *)_friendView;
    
    KeyboardState * keyboardState = [[KeyboardState alloc] init];
    keyboardState.contentInset = tableView.contentInset;
    keyboardState.indicatorInset = tableView.scrollIndicatorInsets;
    
    
    UIEdgeInsets contentInsets =  tableView.contentInset;
    NSLog(@"pre move originy %f,content insets bottom %f, view height: %f", _textField.frame.origin.y, contentInsets.bottom, tableView.frame.size.height);
    
    NSDictionary* info = [aNotification userInfo];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    
    CGRect textFieldFrame = _textField.frame;
    textFieldFrame.origin.y -= keyboardRect.size.height;
    //    textFieldFrame.size.height -= keyboardRect.size.height;
    _textField.frame = textFieldFrame;
    
    NSLog(@"keyboard height before: %f", keyboardRect.size.height);
    
    keyboardState.keyboardRect = keyboardRect;
    
    
    NSLog(@"after move content insets bottom %f, view height: %f", contentInsets.bottom, tableView.frame.size.height);
    
    
    //  contentInsets.top +=   keyboardState.keyboardRect.size.height;
    contentInsets.bottom = keyboardState.keyboardRect.size.height;
    tableView.contentInset = contentInsets;
    
    
    UIEdgeInsets scrollInsets =tableView.scrollIndicatorInsets;
    // scrollInsets.top += keyboardState.keyboardRect.size.height;
    scrollInsets.bottom = keyboardState.keyboardRect.size.height;
    tableView.scrollIndicatorInsets = scrollInsets;
    
    
    NSLog(@"new content insets bottom %f", contentInsets.bottom);
    
    keyboardState.offset = tableView.contentOffset;
    
    for (UITableView *tableView in [_chats allValues]) {
        tableView.contentInset = contentInsets;
        tableView.scrollIndicatorInsets = scrollInsets;
    }
    
    self.keyboardState = keyboardState;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSLog(@"keyboardWillBeHidden");
    [self handleKeyboardHide];
    
}

- (void) handleKeyboardHide {
    
    
    if (self.keyboardState) {
        CGSize kbSize = self.keyboardState.keyboardRect.size;
        
        
        CGRect textFieldFrame = _textField.frame;
        textFieldFrame.origin.y += kbSize.height;
        // textFieldFrame.size.height -= kbSize.height;
        _textField.frame = textFieldFrame;
        
        
        
        
        //reset all table view states
        
        [_friendView setContentOffset:self.keyboardState.offset animated:YES];
        
        _friendView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
        _friendView.contentInset = self.keyboardState.contentInset;
        for (UITableView *tableView in [_chats allValues]) {
            tableView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
            tableView.contentInset = self.keyboardState.contentInset;
            
        }
        
        self.keyboardState = nil;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    NSLog(@"will animate, setting table view framewidth/height %f,%f",_swipeView.frame.size.width,_swipeView.frame.size.height);
    
    //    _friendView.frame = _swipeView.frame;
    //       for (UITableView *tableView in [_chats allValues]) {
    //        tableView.frame=_swipeView.frame;
    //
    //    }
    
    //   [_swipeView updateLayout];
    //[_swipeView layOutItemViews];
    
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    return 1 + [_chats count];
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    NSLog(@"view for item at index %d", index);
    if (index == 0) {
        if (!_friendView) {
            NSLog(@"creating friend view");
            
            _friendView = [[UITableView alloc] initWithFrame:swipeView.frame style: UITableViewStylePlain];
            [_friendView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
            _friendView.delegate = self;
            _friendView.dataSource = self;
            
            [[NetworkController sharedInstance] getFriendsSuccessBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"get friends response: %d",  [response statusCode]);
                self.friends = [[NSMutableArray alloc] initWithArray: [((NSDictionary *) JSON) objectForKey:@"friends"]];
                
                [_friendView reloadData];
                
            } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
                NSLog(@"response failure: %@",  Error);
                
            }];
        }
        
        NSLog(@"returning friend view %@", _friendView);
        //return view
        return _friendView;
        
        
    }
    else {
        NSLog(@"returning chat view");
        NSArray *keys = [_chats allKeys];
        id aKey = [keys objectAtIndex:index -1];
        id anObject = [_chats objectForKey:aKey];
        
        return anObject;
    }
    
}

- (void)swipeViewCurrentItemIndexDidChange:(SwipeView *)swipeView
{
    NSInteger currPage =swipeView.currentPage;
    //update page control page
    NSLog(@"swipeview index changed to %d", currPage);
    //   _pageControl.currentPage = swipeView.currentPage;
    //  [_swipeView reloadData];
    UITableView * tableview;
    if (currPage == 0) {
        tableview = _friendView;
    }
    else {
        tableview = [_chats allValues][swipeView.currentPage-1];
    }
    [tableview reloadData];
    
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index
{
    NSLog(@"Selected item at index %i", index);
}

- (IBAction)pageControlTapped
{
    //update swipe view page
    [_swipeView scrollToPage:_pageControl.currentPage duration:0.4];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSLog(@"number of sections");
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger index = [[_chats allValues] indexOfObject:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    else {
        index++;
    }
    NSLog(@"number of rows in section, index: %d", index);
    // Return the number of rows in the section
    if (index == 0) {
        if (!_friends) {
            NSLog(@"returning 0 rows");
            return 0;
        }
        
        return [_friends count];
    }
    else {
        NSInteger chatIndex = index-1;
        
        NSArray *keys = [_chats allKeys];
        if(chatIndex >= 0 && chatIndex < keys.count ) {
            id aKey = [keys objectAtIndex:chatIndex];
            NSString * username = aKey;
            return  [[ChatController sharedInstance] getDataSourceForFriendname: username].messages.count;
        }
    }
    
    return 0;
    
}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//
//    NSInteger index = [_swipeView indexOfItemViewOrSubview:tableView];
//    NSLog(@"height for row, index: %d, indexPath: %@", index, indexPath);
//    if (index == NSNotFound) {
//        return 0;
//    }
//
//
//    if (index == 0) {
//           }
//    else {
//    }
//    return 44;
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    NSInteger index = [_swipeView indexOfItemViewOrSubview:tableView];
    NSLog(@"cell for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        static NSString *CellIdentifier = @"Cell";
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        return cell;
    }
    
    
    if (index == 0) {
        static NSString *CellIdentifier = @"Cell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        // Configure the cell...
        cell.textLabel.text = [(NSDictionary *)[_friends objectAtIndex:indexPath.row] objectForKey:@"name"];
        
        return cell;
    }
    else {
        static NSString *CellIdentifier = @"OurMessageView";
        
        
        OurMessageView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        NSArray *keys = [_chats allKeys];
        id aKey = [keys objectAtIndex:index -1];
        
        NSString * username = aKey;
        NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
        if (messages.count > 0) {
            
            
            SurespotMessage * message =[messages objectAtIndex:indexPath.row];
            NSString * plainData = [message plaindata];
            
            
            cell.messageStatusLabel.text = @"loading and decrypting...";
            cell.messageSentView.backgroundColor = [UIColor blackColor];
            
            __block UITableView * blockView = tableView;
            if (!plainData){
                if (![message isLoading] && ![message isLoaded]) {
                    [message setLoaded:NO];
                    [message setLoading:YES];
                    NSLog(@"decrypting data for iv: %@", [message iv]);
                    [[MessageProcessor sharedInstance] decryptMessage:message completionCallback:^(SurespotMessage  * message){
                        
                        NSLog(@"data decrypted, reloading row for iv %@", [message iv]);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //                        [tableView reloadData];
                            [blockView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                            [message setLoading:NO];
                            [message setLoaded:YES];
                        });
                    }];
                    
                }
            }
            else {
                NSLog(@"setting text for iv: %@ to: %@", [message iv], plainData);
                cell.messageLabel.text = plainData;
                cell.messageStatusLabel.text = [self stringFromDate:[message dateTime]];
                cell.messageSentView.backgroundColor = [UIColor lightGrayColor];
                
            }
            
        }
        
        return cell;
        
    }}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    NSLog(@"selected, on page: %d", page);
    
    if (page == 0) {
        
        // Configure the cell...
        NSString * friendname =[(NSDictionary *)[_friends objectAtIndex:indexPath.row] objectForKey:@"name"];
        
        [self showChat:friendname];
    }
}

-(void) showChat:(NSString *) username {
    NSLog(@"showChat, %@", username);
    //get existing view if there is one
    UITableView * chatView = [_chats objectForKey:username];
    if (!chatView) {
        
        chatView = [[UITableView alloc] initWithFrame:_swipeView.frame];
        [chatView setDelegate:self];
        [chatView setDataSource: self];
        [chatView setScrollsToTop:NO];
        [chatView setDirectionalLockEnabled:YES];
        
        [_chats setObject:chatView forKey:username];
        //listen for rolead notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadMessages:) name:@"reloadMessages" object:username];
        
        
        //   [chatView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ChatCell"];
        [chatView registerNib:[UINib nibWithNibName:@"OurMessageCell" bundle:nil] forCellReuseIdentifier:@"OurMessageView"];
        
        NSInteger index = _chats.count;
        NSLog(@"creating and scrolling to index: %d", index);
        
        [_swipeView loadViewAtIndex:index];
        [_swipeView updateItemSizeAndCount];
        [_swipeView updateScrollViewDimensions];
        [_swipeView scrollToPage:index duration:0.500];
        
    }
    
    else {
        NSInteger index = [[_chats allKeys] indexOfObject:username] + 1;
        NSLog(@"scrolling to index: %d", index);
        [_swipeView scrollToPage:index duration:0.500];
        
        
    }
    _currentChat = username;
    //  [_swipeView reloadData];
    [_textField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField text].length > 0) {
        
        
        if ([_swipeView currentPage] == 0) {
            [self inviteUser:[textField text]];
            [textField resignFirstResponder];
        }
        else {
            [self send];
            
        }
        
        [textField setText:nil];
        
    }
    else {
        [textField resignFirstResponder];
    }
    return NO;
}

- (void) send {
    NSString* message = self.textField.text;
    
    if (message.length == 0) return;
    
    NSArray *keys = [_chats allKeys];
    id friendname = [keys objectAtIndex:[_swipeView currentItemIndex] -1];
    
    [[ChatController sharedInstance] sendMessage: message toFriendname:friendname];
    UITableView * chatView = [_chats objectForKey:friendname];
    [chatView reloadData];
}

- (void)reloadMessages:(NSNotification *)notification
{
    NSLog(@"reloadMessages");
    NSString * username = notification.object;
    
    id tableView = [_chats objectForKey:username];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [tableView reloadData];
        NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:([tableView numberOfRowsInSection:([tableView numberOfSections] - 1)] - 1) inSection:([tableView numberOfSections] - 1)];
        [tableView scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    });
    
    
}

- (void) inviteUser: (NSString *) username {
    NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
    if ([username isEqualToString:loggedInUser]) {
        //todo tell user they can't invite themselves
        return;
    }
    
    [[NetworkController sharedInstance]
     inviteFriend:username
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         NSLog(@"invite friend response: %d",  [operation.response statusCode]);
         NSDictionary * f = [NSDictionary dictionaryWithObjectsAndKeys:username,@"name",[NSNumber numberWithInt:2],@"flags", nil];
         [_friends addObject:f];
         [_friendView reloadData];
     }
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         
         NSLog(@"response failure: %@",  Error);
         
     }];
}


- (NSString *)stringFromDate:(NSDate *)date
{
    __block NSString *string = nil;
    dispatch_sync(_dateFormatQueue, ^{
        string = [_dateFormatter stringFromDate:date ];
    });
    return string;
}

@end