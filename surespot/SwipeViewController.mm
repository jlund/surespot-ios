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
#import "MessageView.h"
#import "ChatUtils.h"
#import "HomeCell.h"
#import "SurespotControlMessage.h"
#import "FriendDelegate.h"
#import "UIUtils.h"
#import "LoginViewController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

//#import <QuartzCore/CATransaction.h>

@interface SwipeViewController ()
@property (nonatomic, strong) dispatch_queue_t dateFormatQueue;
@property (nonatomic, strong) NSDateFormatter * dateFormatter;
@property (nonatomic, weak) HomeDataSource * homeDataSource;
@property (nonatomic, strong) UIViewPager * viewPager;
@property (nonatomic, strong) NSMutableDictionary * needsScroll;
@end


@implementation SwipeViewController


- (void)viewDidLoad
{
    DDLogVerbose(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    _needsScroll = [NSMutableDictionary new];
    
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
    _swipeView.delaysContentTouches = YES;
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    _textField.enablesReturnKeyAutomatically = NO;
    [self registerForKeyboardNotifications];
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:@"menu" style:UIBarButtonItemStylePlain target:self action:@selector(showMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    self.navigationItem.title = [@"surespot/" stringByAppendingString:[[IdentityController sharedInstance] getLoggedInUser]];
    
    
    //don't swipe to back stack
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    //
    self.navigationItem.hidesBackButton = YES;
    
    
    //listen for refresh notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMessages:) name:@"refreshMessages" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshHome:) name:@"refreshHome" object:nil];
    
    //listen for push notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushNotification:) name:@"pushNotification" object:nil];
    
    _homeDataSource = [[ChatController sharedInstance] getHomeDataSource];
    
    //show currently open tab immediately
    //    NSString * currentChat = _homeDataSource.currentChat;
    //    if (currentChat) {
    //        [self showChat:currentChat];
    //    }
    
    _viewPager = [[UIViewPager alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 30)];
    _viewPager.autoresizingMask =UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_viewPager];
    _viewPager.delegate = self;
    
    
    //open active tabs
    for (Friend * afriend in [_homeDataSource friends]) {
        if ([afriend isChatActive]) {
            [self loadChat:[afriend name] show:NO availableId: [afriend availableMessageId]];
        }
    }
    
    //setup the button
    _theButton.layer.cornerRadius = 35;
    _theButton.layer.borderColor = [[UIUtils surespotBlue] CGColor];
    _theButton.layer.borderWidth = 3.0f;
    _theButton.backgroundColor = [UIColor whiteColor];
    _theButton.opaque = YES;
    [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
    [_theButton setTintColor:[UIUtils surespotBlue]];
    
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
    
    
    
    DDLogVerbose(@"keyboardWasShown");
    
    
    UITableView * tableView =(UITableView *)_friendView;
    
    KeyboardState * keyboardState = [[KeyboardState alloc] init];
    keyboardState.contentInset = tableView.contentInset;
    keyboardState.indicatorInset = tableView.scrollIndicatorInsets;
    
    
    UIEdgeInsets contentInsets =  tableView.contentInset;
    DDLogVerbose(@"pre move originy %f,content insets bottom %f, view height: %f", _textField.frame.origin.y, contentInsets.bottom, tableView.frame.size.height);
    
    NSDictionary* info = [aNotification userInfo];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = [UIUtils keyboardHeightAdjustedForOrientation:keyboardRect.size];
    
    CGRect textFieldFrame = _textField.frame;
    textFieldFrame.origin.y -= keyboardHeight;
    
    _textField.frame = textFieldFrame;
    
    DDLogVerbose(@"keyboard height before: %f", keyboardHeight);
    
    keyboardState.keyboardHeight = keyboardHeight;
    
    
    DDLogVerbose(@"after move content insets bottom %f, view height: %f", contentInsets.bottom, tableView.frame.size.height);
    
    contentInsets.bottom = keyboardHeight;
    tableView.contentInset = contentInsets;
    
    
    UIEdgeInsets scrollInsets =tableView.scrollIndicatorInsets;
    scrollInsets.bottom = keyboardHeight;
    tableView.scrollIndicatorInsets = scrollInsets;
    
    
    DDLogVerbose(@"new content insets bottom %f", contentInsets.bottom);
    
    keyboardState.offset = tableView.contentOffset;
    
    @synchronized (_chats) {
        for (UITableView *tableView in [_chats allValues]) {
            tableView.contentInset = contentInsets;
            tableView.scrollIndicatorInsets = scrollInsets;
        }
    }
    
    
    CGRect buttonFrame = _theButton.frame;
    buttonFrame.origin.y -= keyboardHeight;
    _theButton.frame = buttonFrame;
    
    self.keyboardState = keyboardState;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    DDLogVerbose(@"keyboardWillBeHidden");
    [self handleKeyboardHide];
    
}

- (void) handleKeyboardHide {
    
    
    if (self.keyboardState) {
        
        
        CGRect textFieldFrame = _textField.frame;
        textFieldFrame.origin.y += self.keyboardState.keyboardHeight;
        _textField.frame = textFieldFrame;
        
        
        
        
        //reset all table view states
        
        [_friendView setContentOffset:self.keyboardState.offset animated:YES];
        
        _friendView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
        _friendView.contentInset = self.keyboardState.contentInset;
        @synchronized (_chats) {
            
            for (UITableView *tableView in [_chats allValues]) {
                tableView.scrollIndicatorInsets = self.keyboardState.indicatorInset;
                tableView.contentInset = self.keyboardState.contentInset;
                
            }
        }
        CGRect buttonFrame = _theButton.frame;
        buttonFrame.origin.y += self.keyboardState.keyboardHeight;
        _theButton.frame = buttonFrame;
        
        self.keyboardState = nil;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    DDLogVerbose(@"will animate, setting table view framewidth/height %f,%f",_swipeView.frame.size.width,_swipeView.frame.size.height);
    
    //    _friendView.frame = _swipeView.frame;
    //       for (UITableView *tableView in [_chats allValues]) {
    //        tableView.frame=_swipeView.frame;
    //
    //    }
    
    //   [_swipeView updateLayout];
    //[_swipeView layOutItemViews];
    
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                duration:(NSTimeInterval)duration
{
    DDLogVerbose(@"will rotate");
    _swipeView.suppressScrollEvent = YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation
{
    DDLogVerbose(@"did rotate");
    _swipeView.suppressScrollEvent= NO;
}

- (void) swipeViewDidScroll:(SwipeView *)scrollView {
    DDLogVerbose(@"swipeViewDidScroll");
    [_viewPager scrollViewDidScroll: scrollView.scrollView];
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(void) switchToPageIndex:(NSInteger)page {
    [_swipeView scrollToPage:page duration:0.5f];
}

-(NSInteger) currentPage {
    return [_swipeView currentPage];
}

-(NSInteger) pageCount {
    return [self numberOfItemsInSwipeView:nil];
}

-(NSString * ) titleForLabelForPage:(NSInteger)page {
    DDLogVerbose(@"titleForLabelForPage %d", page);
    if (page == 0) {
        return @"home";
    }
    else {
        return [self nameForPage:page];    }
    
    return nil;
}

-(NSString * ) nameForPage:(NSInteger)page {
    
    if (page == 0) {
        return nil;
    }
    else {
        @synchronized (_chats) {
            if ([_chats count] > 0) {
                return [[_chats allKeys] objectAtIndex:page-1];
            }
        }
    }
    
    return nil;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    @synchronized (_chats) {
        
        return 1 + [_chats count];
    }
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    DDLogVerbose(@"view for item at index %d", index);
    if (index == 0) {
        if (!_friendView) {
            DDLogVerbose(@"creating friend view");
            
            _friendView = [[UITableView alloc] initWithFrame:swipeView.frame style: UITableViewStylePlain];
            [_friendView registerNib:[UINib nibWithNibName:@"HomeCell" bundle:nil] forCellReuseIdentifier:@"HomeCell"];
            _friendView.delegate = self;
            _friendView.dataSource = self;
        }
        
        DDLogVerbose(@"returning friend view %@", _friendView);
        //return view
        return _friendView;
        
        
    }
    else {
        DDLogVerbose(@"returning chat view");
        @synchronized (_chats) {
            
            NSArray *keys = [_chats allKeys];
            id aKey = [keys objectAtIndex:index -1];
            id anObject = [_chats objectForKey:aKey];
            
            return anObject;
        }
    }
    
}

- (void)swipeViewCurrentItemIndexDidChange:(SwipeView *)swipeView
{
    NSInteger currPage =swipeView.currentPage;
    //update page control page
    
    //   _pageControl.currentPage = swipeView.currentPage;
    //  [_swipeView reloadData];
    UITableView * tableview;
    if (currPage == 0) {
        [[ChatController sharedInstance] setCurrentChat:nil];
        tableview = _friendView;
    }
    else {
        @synchronized (_chats) {
            
            tableview = [_chats allValues][swipeView.currentPage-1];
            [[ChatController sharedInstance] setCurrentChat: [_chats allKeys][currPage-1]];
        }
        
    }
    DDLogVerbose(@"swipeview index changed to %d", currPage);
    [tableview reloadData];
    
    //scroll if we need to
    NSString * name =[self nameForPage:currPage];
    @synchronized (_needsScroll ) {
        id needsit = [_needsScroll  objectForKey:name];
        if (needsit) {
            [self scrollTableViewToBottom:tableview];
            [_needsScroll removeObjectForKey:name];
        }
    }
    
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index
{
    DDLogVerbose(@"Selected item at index %i", index);
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    DDLogVerbose(@"number of sections");
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger index =  NSNotFound;
    
    @synchronized (_chats) {
        index = [[_chats allValues] indexOfObject:tableView];
    }
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    else {
        index++;
    }
    DDLogVerbose(@"number of rows in section, index: %d", index);
    // Return the number of rows in the section
    if (index == 0) {
        if (![[ChatController sharedInstance] getHomeDataSource]) {
            DDLogVerbose(@"returning 0 rows");
            return 0;
        }
        
        return [[[ChatController sharedInstance] getHomeDataSource].friends count];
    }
    else {
        NSInteger chatIndex = index-1;
        NSString * username;
        @synchronized (_chats) {
            
            NSArray *keys = [_chats allKeys];
            if(chatIndex >= 0 && chatIndex < keys.count ) {
                id aKey = [keys objectAtIndex:chatIndex];
                username = aKey;
            }
        }
        if (username) {
            return  [[ChatController sharedInstance] getDataSourceForFriendname: username].messages.count;
        }
    }
    
    return 0;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger index = [_swipeView indexOfItemViewOrSubview:tableView];
    
    //  DDLogVerbose(@"height for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        return 0;
    }
    
    
    if (index == 0) {
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        if ([afriend isInviter] ) {
            return 70;
        }
        else {
            return 44;
        }
        
    }
    else {
        @synchronized (_chats) {
            
            NSArray *keys = [_chats allKeys];
            id aKey = [keys objectAtIndex:index -1];
            
            NSString * username = aKey;
            NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
            if (messages.count > 0) {
                SurespotMessage * message =[messages objectAtIndex:indexPath.row];
                if (message.rowHeight > 0) {
                    return message.rowHeight;
                }
                
                else {
                    return 44;
                }
            }
            else {
                return 0;
            }
        }
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    NSInteger index = [_swipeView indexOfItemViewOrSubview:tableView];
    //  DDLogVerbose(@"cell for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        static NSString *CellIdentifier = @"Cell";
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        return cell;
    }
    
    
    if (index == 0) {
        static NSString *CellIdentifier = @"HomeCell";
        HomeCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        // Configure the cell...
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        cell.friendLabel.text = afriend.name;
        cell.friendName = afriend.name;
        cell.friendDelegate = [ChatController sharedInstance];
        
        BOOL isInviter =[afriend isInviter];
        
        [cell.ignoreButton setHidden:!isInviter];
        [cell.acceptButton setHidden:!isInviter];
        [cell.blockButton setHidden:!isInviter];
        
        cell.activeStatus.backgroundColor = [afriend isChatActive] ? [UIUtils surespotBlue] : [UIColor clearColor];
        
        return cell;
    }
    else {
        id aKey;
        @synchronized (_chats) {
            NSArray *keys = [_chats allKeys];
            aKey = [keys objectAtIndex:index -1];
        }
        NSString * username = aKey;
        NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
        if (messages.count > 0) {
            
            
            SurespotMessage * message =[messages objectAtIndex:indexPath.row];
            NSString * plainData = [message plainData];
            static NSString *OurCellIdentifier = @"OurMessageView";
            static NSString *TheirCellIdentifier = @"TheirMessageView";
            
            NSString * cellIdentifier;
            BOOL ours = NO;
            
            if ([ChatUtils isOurMessage:message]) {
                ours = YES;
                cellIdentifier = OurCellIdentifier;
                
            }
            else {
                cellIdentifier = TheirCellIdentifier;
            }
            MessageView *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
            
            cell.messageStatusLabel.text = NSLocalizedString(@"message_loading_and_decrypting",nil);
            cell.messageLabel.text = @"";
            
            // __block UITableView * blockView = tableView;
            if (!plainData){
                if (![message isLoading] && ![message isLoaded]) {
                    if (ours) {
                        
                        cell.messageSentView.backgroundColor = [UIColor blackColor];
                    }
                    else {
                        cell.messageSentView.backgroundColor = UIUtils.surespotBlue;
                    }
                    
                    
                    //                    [message setLoaded:NO];
                    //                    [message setLoading:YES];
                    //                    //    DDLogVerbose(@"decrypting data for iv: %@", [message iv]);
                    //                    [[MessageProcessor sharedInstance] decryptMessage:message width: tableView.frame.size.width completionCallback:^(SurespotMessage  * message){
                    //
                    //                        //   DDLogVerbose(@"data decrypted, reloading row for iv %@", [message iv]);
                    //                        dispatch_async(dispatch_get_main_queue(), ^{
                    //                            //  [tableView reloadData];
                    //                            [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    //                            [message setLoading:NO];
                    //                            [message setLoaded:YES];
                    //                        });
                    //                    }];
                    
                }
            }
            else {
                //   DDLogVerbose(@"setting text for iv: %@ to: %@", [message iv], plainData);
                cell.messageLabel.text = plainData;
                cell.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
                cell.messageStatusLabel.text = [self stringFromDate:[message dateTime]];
                
                if (ours) {
                    cell.messageSentView.backgroundColor = [UIColor lightGrayColor];
                }
                else {
                    //TODO use constant
                    cell.messageSentView.backgroundColor =[UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:1.0];
                }
                
                
            }
            return cell;
        }
        else {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            return cell;
            
        }
        
        
        
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    DDLogVerbose(@"selected, on page: %d", page);
    
    if (page == 0) {
        
        // Configure the cell...
        NSString * friendname =[[[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row] name];
        [self showChat:friendname];
    }
}

-(void) loadChat:(NSString *) username show: (BOOL) show  availableId: (NSInteger) availableId {
    //get existing view if there is one
    UITableView * chatView;
    @synchronized (_chats) {
        chatView = [_chats objectForKey:username];
    }
    if (!chatView) {
        
        chatView = [[UITableView alloc] initWithFrame:_swipeView.frame];
        [chatView setDelegate:self];
        [chatView setDataSource: self];
        [chatView setScrollsToTop:NO];
        [chatView setDirectionalLockEnabled:YES];
        
        
        //create the data source
        [[ChatController sharedInstance] createDataSourceForFriendname:username availableId: availableId];
        
        NSInteger index = 0;
        @synchronized (_chats) {
            
            [_chats setObject:chatView forKey:username];
            index = [[_chats allKeys] indexOfObject:username] + 1          ;
            
        }
        
        DDLogInfo(@"creatingindex: %d", index);
        
        //   [chatView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ChatCell"];
        [chatView registerNib:[UINib nibWithNibName:@"OurMessageCell" bundle:nil] forCellReuseIdentifier:@"OurMessageView"];
        [chatView registerNib:[UINib nibWithNibName:@"TheirMessageCell" bundle:nil] forCellReuseIdentifier:@"TheirMessageView"];
        
        [_swipeView loadViewAtIndex:index];
        [_swipeView updateItemSizeAndCount];
        [_swipeView updateScrollViewDimensions];
        
        if (show) {
            [_swipeView scrollToPage:index duration:0.500];
            [[ChatController sharedInstance] setCurrentChat: username];
        }
        
    }
    
    else {
        if (show) {
            [[ChatController sharedInstance] setCurrentChat: username];
            NSInteger index;
            @synchronized (_chats) {
                index = [[_chats allKeys] indexOfObject:username] + 1;
            }
            
            DDLogInfo(@"scrolling to index: %d", index);
            [_swipeView scrollToPage:index duration:0.500];
        }
    }
}

-(void) showChat:(NSString *) username {
    DDLogInfo(@"showChat, %@", username);
    
    Friend * afriend = [_homeDataSource getFriendByName:username];
    
    [self loadChat:username show:YES availableId:[afriend availableMessageId]];
    [_textField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self handleTextAction];
    return NO;
}

- (void) handleTextAction {
    if ([_textField text].length > 0) {
        if (!_homeDataSource.currentChat) {
            [[ChatController sharedInstance] inviteUser:[_textField text]];
            [_textField resignFirstResponder];
            [_textField setText:nil];
        }
        else {
            [self send];
        }
    }
    else {
        [_textField resignFirstResponder];
    }
}


- (void) send {
    NSString* message = self.textField.text;
    
    if ([UIUtils stringIsNilOrEmpty:message]) return;
    id friendname;
    @synchronized (_chats) {
        NSArray *keys = [_chats allKeys];
        friendname = [keys objectAtIndex:[_swipeView currentItemIndex] -1];
    }
    
    [[ChatController sharedInstance] sendMessage: message toFriendname:friendname];
    [_textField setText:nil];
}

- (void)refreshMessages:(NSNotification *)notification {
    NSString * username = notification.object;
    DDLogVerbose(@"username: %@, currentchat: %@", username, _homeDataSource.currentChat);
    
    if ([username isEqualToString: _homeDataSource.currentChat]) {
        
        UITableView * tableView;
        @synchronized (_chats) {
            tableView = [_chats objectForKey:username];
            
        }
        @synchronized (_needsScroll) {
            [_needsScroll removeObjectForKey:username];
        }
        
        if (tableView) {
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [tableView reloadData];
                [self scrollTableViewToBottom:tableView];
            });
            
            
        }
    }
    else {
        @synchronized (_needsScroll) {
            [_needsScroll setObject:@"yourmama" forKey:username];
        }
    }
}

- (void) scrollTableViewToBottom: (UITableView *) tableView {
    NSInteger numRows =[tableView numberOfRowsInSection:0];
    if (numRows > 0) {
        DDLogVerbose(@"scrolling to row: %d", numRows);
        NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:(numRows - 1) inSection:0];
        [tableView scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)refreshHome:(NSNotification *)notification
{
    DDLogVerbose(@"refreshHome");
    
    if (_friendView) {
        [_friendView reloadData];
    }
    
}


-(void) removeFriend: (Friend *) afriend {
    [[[ChatController sharedInstance] getHomeDataSource] removeFriend:afriend withRefresh:YES];
}


- (NSString *)stringFromDate:(NSDate *)date
{
    __block NSString *string = nil;
    dispatch_sync(_dateFormatQueue, ^{
        string = [_dateFormatter stringFromDate:date ];
    });
    return string;
}



- (void)pushNotification:(NSNotification *)notification
{
    DDLogVerbose(@"pushNotification");
    NSDictionary * notificationData = notification.object;
    
    NSString * from =[ notificationData objectForKey:@"from"];
    if (![from isEqualToString:[[ChatController sharedInstance] getCurrentChat]]) {
        [UIUtils showNotificationToastView:[self view] data:notificationData];
    }
    
}

-(void) showMenu {
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:nil
                                  delegate:self
                                  cancelButtonTitle:nil
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:nil];
    
    
    if (_homeDataSource.currentChat) {
        [actionSheet addButtonWithTitle: @"close tab"];
    }
    [actionSheet addButtonWithTitle: @"logout"];
    [actionSheet addButtonWithTitle: @"cancel"];
    actionSheet.cancelButtonIndex = actionSheet.numberOfButtons - 1;
    
    [actionSheet showInView:self.view];
}

-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    DDLogVerbose(@"menu click: %@", buttonTitle);
    
    if ([buttonTitle isEqualToString:@"close tab"]) {
        [self closeTab];
        return;
    }
    if ([buttonTitle isEqualToString:@"logout"]) {
        
        [self logout];
        return;
    }
}


- (void)willPresentActionSheet:(UIActionSheet *)actionSheet
{
    UIColor *customTitleColor = [UIUtils surespotBlue];
    for (UIView *subview in actionSheet.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            
            [button setTitleColor:customTitleColor forState:UIControlStateHighlighted];
            [button setTitleColor:customTitleColor forState:UIControlStateNormal];
            [button setTitleColor:customTitleColor forState:UIControlStateSelected];
        }
    }
}

-(void) closeTab {
    if (_homeDataSource.currentChat) {
        [[ChatController sharedInstance] destroyDataSourceForFriendname: _homeDataSource.currentChat];
        [[_homeDataSource getFriendByName:_homeDataSource.currentChat] setChatActive:NO];
        @synchronized (_chats) {
            [_chats removeObjectForKey:_homeDataSource.currentChat];
        }
        [_swipeView reloadData];
        
        NSInteger page = [_swipeView currentPage];
        
        if (page >= _swipeView.numberOfPages) {
            page = _swipeView.numberOfPages - 1;
        }
        DDLogInfo(@"page after close: %d", page);
        NSString * name = [self nameForPage:page];
        DDLogInfo(@"name after close: %@", name);
        [_homeDataSource setCurrentChat:name];
        [_swipeView scrollToPage:page duration:0.2];
    }
}
-(void) logout {
    
    //blow the views away
    
    _friendView = nil;
    
    [[NetworkController sharedInstance] logout];
    [[ChatController sharedInstance] logout];
    @synchronized (_chats) {
        [_chats removeAllObjects];
    }
    [self performSegueWithIdentifier: @"returnToLogin" sender: self ];
    
}
- (IBAction)buttonTouchUpInside:(id)sender {
    if (_textField.text.length > 0) {
        [self handleTextAction];
    }else {
        [_swipeView scrollToPage:0 duration:0.5];
    }
}
@end