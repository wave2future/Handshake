//
//  HSKViewController.m
//  Handshake
//
//  Created by Kyle on 9/24/08.
//  Copyright Dragon Forged Software 2008. All rights reserved.
//

#import "HSKMainViewController.h"
#import "NSString+SKPPhoneAdditions.h"
#import "CJSONSerializer.h"
#import "CJSONDeserializer.h"
#import "UIImage+ThumbnailExtensions.h"
#import "HSKUnknownPersonViewController.h"
#import "HSKFlipsideController.h"
#import "HSKPicturePreviewViewController.h"
#import "HSKNavigationController.h"

@interface HSKMainViewController ()

@property(nonatomic, retain) id lastMessage;
@property(nonatomic, retain) id lastPeer;
@property(nonatomic, retain) UIButton *frontButton;
@property(nonatomic, retain) NSString *dataToSend;
@property(nonatomic, retain) NSMutableArray *messageArray;

- (void)showOverlayView:(NSString *)prompt;
- (void)hideOverlayView;
- (void)handleConnectFail;

@end

@implementation HSKMainViewController

@synthesize lastMessage, lastPeer, frontButton, dataToSend, messageArray;

#pragma mark -
#pragma mark FlipView Functions 


-(IBAction)flipView
{
	userBusy = YES;
	[flipsideController refreshOwnerData];
	[UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationTransition: UIViewAnimationTransitionFlipFromRight forView:self.view cache:YES];
	[self.view addSubview: flipView];
    [frontView removeFromSuperview];
	self.navigationItem.title = @"Settings";

	[UIView commitAnimations];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationTransition: UIViewAnimationTransitionFlipFromRight forView:self.frontButton cache:YES];
	
    [self.frontButton setBackgroundImage:[UIImage imageNamed:@"Done.png"] forState:UIControlStateNormal];
    [self.frontButton addTarget:self action:@selector(flipBack) forControlEvents:UIControlEventTouchUpInside];
    
    [UIView commitAnimations];
}

-(void)flipBack; 
{ 	
	userBusy = NO;
	[UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:1];
    [UIView setAnimationTransition: UIViewAnimationTransitionFlipFromLeft forView:self.view cache:YES];
	[flipView removeFromSuperview];
    [self.view addSubview:frontView];
	self.navigationItem.title = @"Select an Action";

	[UIView commitAnimations];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.75];
    [UIView setAnimationTransition: UIViewAnimationTransitionFlipFromLeft forView:self.frontButton cache:YES];
	
    [self.frontButton setBackgroundImage:[UIImage imageNamed:@"Wrench.png"] forState:UIControlStateNormal];
    [self.frontButton addTarget:self action:@selector(flipView) forControlEvents:UIControlEventTouchUpInside];
    
    [UIView commitAnimations];
    	
    // Check the info and reconnect
	[self verifyOwnerCard];
	
	[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];

}

#pragma mark -
#pragma mark View Handlers 

- (void)dismissModals
{
    [self dismissModalViewControllerAnimated:YES];	
	[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	self.view.backgroundColor =[UIColor blackColor];
    
	self.messageArray = [[NSMutableArray alloc] init];
    self.view.autoresizesSubviews = YES;
    
    self.frontButton = [[[UIButton alloc] initWithFrame:CGRectMake(0,0,50,29)] autorelease];
    [self.frontButton setBackgroundImage:[UIImage imageNamed:@"Wrench.png"] forState:UIControlStateNormal];
    [self.frontButton addTarget:self action:@selector(flipView) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(popToSelf:)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:self.frontButton] autorelease];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];
	NSLog(@"Not Busy");
	
    userBusy = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
	NSLog(@"Busy");
	userBusy = YES;
}

- (void)popToSelf:(id)sender
{
    [self.navigationController popToViewController:self animated:YES];
}

#pragma mark -
#pragma mark Private methods

- (void)showOverlayView:(NSString *)prompt
{
    overlayLabel.text = prompt;
    
    [self.view addSubview:overlayView];
    [self.view bringSubviewToFront:overlayView];
    
    overlayView.frame = self.view.bounds;
    
    [overlayActivityIndicatorView startAnimating];
}

- (void)hideOverlayView
{
    [overlayActivityIndicatorView stopAnimating];
    
    [overlayView removeFromSuperview];
}

- (void)handleConnectFail
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
                                                        message:@"Unable to connect to the server, retry?" 
                                                       delegate:self 
                                              cancelButtonTitle:@"Quit" 
                                              otherButtonTitles:@"Retry",nil];
    alertView.tag = 1;
    [alertView show];
    [alertView release];
}


#pragma mark -
#pragma mark Owner Functions
-(void)verifyOwnerCard 
{ 
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *myPhoneNumber = [[[defaults dictionaryRepresentation] objectForKey: @"SBFormattedPhoneNumber"] numericOnly];
	NSString *phoneNumber;
	BOOL foundOwner = FALSE;
	
	NSLog(@"We have retrieved %@ from the device as the primary number", myPhoneNumber);
	
	ABAddressBookRef addressBook = ABAddressBookCreate();
	
	//no entries in AB
	if(ABAddressBookGetPersonCount(addressBook) == 0)
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
															message:@"You need to have at least 1 contact in your address book to use Handshake, you can create new contacts in the contact app." 
														   delegate:self 
												  cancelButtonTitle:@"Quit" 
												  otherButtonTitles: nil];
		alertView.tag = 2;
		[alertView show];
		[alertView release];
		foundOwner = TRUE; //trick system into state we want it in, we are going to exit anyways
	}
	
	if( [[NSUserDefaults standardUserDefaults] integerForKey: @"ownerRecordRef"])
	{
		foundOwner = TRUE;
		ownerRecord = [[NSUserDefaults standardUserDefaults] integerForKey:@"ownerRecordRef"];
		
		ABRecordRef ownerCard =  ABAddressBookGetPersonWithRecordID(ABAddressBookCreate(), ownerRecord);
		
		if(ownerCard == nil)
			foundOwner = FALSE;
		else
			[self ownerFound];
	}
	
	if(!foundOwner)
	{
		
		NSArray *addresses = (NSArray *) ABAddressBookCopyArrayOfAllPeople(addressBook);
		NSInteger addressesCount = [addresses count];
		
		for (int i = 0; i < addressesCount; i++)
		{
			ABRecordRef record = [addresses objectAtIndex:i];
			NSString *firstName = (NSString *)ABRecordCopyValue(record, kABPersonFirstNameProperty);
			NSString *lastName = (NSString *)ABRecordCopyValue(record, kABPersonLastNameProperty);
			
			NSArray *people = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook); 
			
			for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue([people objectAtIndex: i] , kABPersonPhoneProperty)) > x); x++)
			{
				//get phone number and strip out anything that isnt a number
				phoneNumber = [(NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue([people objectAtIndex: i] ,kABPersonPhoneProperty) , x) numericOnly];
				
				//compares the phone numbers by suffix incase user is using a 11, 10, or 7 digit number
				if([myPhoneNumber hasSuffix: phoneNumber] && [phoneNumber length] >= 7) //want to make sure we arent testing for numbers that are too short to be real
				{
					UIActionSheet *alert = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat: @"Welcome to Handshake! You will need to select your own contact card before we can begin. We believe you are %@ %@, is this correct?", firstName, lastName] delegate:self cancelButtonTitle:@"No, I Will Select Myself" destructiveButtonTitle:nil otherButtonTitles:[NSString stringWithFormat: @" Yes I am %@", firstName], nil];
					[alert showInView:self.view];
					ownerRecord = ABRecordGetRecordID (record);
					
					alert.tag = 1;
					
					foundOwner = TRUE;
				}
				
				if(foundOwner)
					break;
			}
			
			[firstName release];
			[lastName release];
			
			if(foundOwner)
				break;
		}
		
		if(!foundOwner)
		{
			//unable to find owner, user wil have to select
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to Determine Owner" message:@"Welcome to Handshake! We are unable to determine which contact information is yours. You will need to select yourself before we can begin." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
			[alert show];
			[alert release];
			
			primaryCardSelecting = TRUE;
			
			ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
			picker.peoplePickerDelegate = self;
			picker.navigationBarHidden=YES; //gets rid of the nav bar
			
			HSKNavigationController *navController = [[HSKNavigationController alloc] initWithRootViewController:picker];
			navController.navigationBarHidden = YES;
			[self presentModalViewController:navController animated:YES];
			[navController release];
			[picker release];
		}
		
	}
}


- (void)ownerFound
{
	ABRecordRef ownerCard =  ABAddressBookGetPersonWithRecordID(ABAddressBookCreate(), ownerRecord);
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setInteger: ownerRecord forKey:@"ownerRecordRef"];
	
	
	UIImage *avatar;
	
	if([[NSUserDefaults standardUserDefaults] objectForKey: @"avatarData"] == nil)
	{
		avatar = ABPersonHasImageData (ownerCard) ? [UIImage imageWithData: (NSData *)ABPersonCopyImageData(ownerCard)] : [UIImage imageNamed: @"defaultavatar.png"];
	}
	else
	{
		avatar = [UIImage imageWithData: [[NSUserDefaults standardUserDefaults] objectForKey: @"avatarData"]];
	}
	
	[[RPSNetwork sharedNetwork] setDelegate:self];
	RPSNetwork *network = [RPSNetwork sharedNetwork];
	
	
	if([[NSUserDefaults standardUserDefaults] stringForKey: @"ownerNameString"] != nil)
	{
		network.handle = [[NSUserDefaults standardUserDefaults] stringForKey: @"ownerNameString"] ;
	}
	else
	{
		network.handle = [NSString stringWithFormat:@"%@ %@", (NSString *)ABRecordCopyValue(ownerCard, kABPersonFirstNameProperty),(NSString *)ABRecordCopyValue(ownerCard, kABPersonLastNameProperty)];
	}
	
	network.bot = TRUE;
    network.avatarData = UIImagePNGRepresentation([avatar thumbnail:CGSizeMake(64.0, 64.0)]);	
    
    // Occlude the UI.
    [self showOverlayView:@"Connecting to the server…"];
    
    if ([[RPSNetwork sharedNetwork] isConnected])
    {
        [[RPSNetwork sharedNetwork] disconnect];
    }
    
    if (![[RPSNetwork sharedNetwork] connect])
    {
        // TODO: fail better here
        [self handleConnectFail];
    }
}


#pragma mark -
#pragma mark Send & Receive 

-(void)recievedVCard: (NSString *)string
{
	BOOL specialData = FALSE;
	userBusy = TRUE;
	
	NSError *error = nil;
	NSData *JSONData = [string dataUsingEncoding: NSUTF8StringEncoding];
	
	NSDictionary *incomingData = [[CJSONDeserializer deserializer] deserialize:JSONData error: &error];
	NSDictionary *VcardDictionary = [incomingData objectForKey: @"data"]; 
	
	if(!VcardDictionary || error)
	{
		NSLog(@"%@", [error localizedDescription]);
	}
	else
	{		
		CFErrorRef *ABError = NULL;
		ABRecordRef newPerson = ABPersonCreate();
		
		//ADDRESS HANDLERS
		ABMutableMultiValueRef addressMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*ADDRESS_$!<Home>!$_"] != nil)
			ABMultiValueAddValueAndLabel(addressMultiValue, [VcardDictionary objectForKey: @"*ADDRESS_$!<Home>!$_"], kABHomeLabel, NULL);
		if([VcardDictionary objectForKey: @"*ADDRESS_$!<Work>!$_"] != nil)
			ABMultiValueAddValueAndLabel(addressMultiValue, [VcardDictionary objectForKey: @"*ADDRESS_$!<Work>!$_"], kABWorkLabel, NULL);
		if([VcardDictionary objectForKey: @"*ADDRESS_$!<Other>!$_"] != nil)
			ABMultiValueAddValueAndLabel(addressMultiValue, [VcardDictionary objectForKey: @"*ADDRESS_$!<Other>!$_"], kABOtherLabel, NULL);
		
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*ADDRESS"])
			{
				ABMultiValueAddValueAndLabel(addressMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*ADDRESS" withString: @""] , NULL);	
			}
		}
		
		
		ABRecordSetValue(newPerson, kABPersonAddressProperty, addressMultiValue, ABError);
		
		//IM HANDLERS
		ABMutableMultiValueRef IMMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*IM_$!<Home>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(IMMultiValue, [VcardDictionary objectForKey: @"*IM_$!<Home>!$_"], kABHomeLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*IM_$!<Work>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(IMMultiValue, [VcardDictionary objectForKey: @"*IM_$!<Work>!$_"], kABWorkLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*IM_$!<Other>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(IMMultiValue, [VcardDictionary objectForKey: @"*IM_$!<Other>!$_"], kABOtherLabel, NULL);
			specialData = TRUE;
		}
		
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*IM"])
			{
				ABMultiValueAddValueAndLabel(IMMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*IM" withString: @""] , NULL);	
				specialData = TRUE;
			}
		}
		
		
		ABRecordSetValue(newPerson, kABPersonInstantMessageProperty, IMMultiValue, ABError);
		
		//EMAIL BUTTON
		ABMutableMultiValueRef emailMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*EMAIL_$!<Home>!$_"] != nil)
			ABMultiValueAddValueAndLabel(emailMultiValue, [VcardDictionary objectForKey: @"*EMAIL_$!<Home>!$_"], kABHomeLabel, NULL);
		if([VcardDictionary objectForKey: @"*EMAIL_$!<Work>!$_"] != nil)
			ABMultiValueAddValueAndLabel(emailMultiValue, [VcardDictionary objectForKey: @"*EMAIL_$!<Work>!$_"], kABWorkLabel, NULL);
		if([VcardDictionary objectForKey: @"*EMAIL_$!<Other>!$_"] != nil)
			ABMultiValueAddValueAndLabel(emailMultiValue, [VcardDictionary objectForKey: @"*EMAIL_$!<Other>!$_"], kABOtherLabel, NULL);
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*EMAIL"])
			{
				ABMultiValueAddValueAndLabel(emailMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*EMAIL" withString: @""] , NULL);	
			}
		}
		
		ABRecordSetValue(newPerson, kABPersonEmailProperty, emailMultiValue, ABError);
		
		//RELATED HANDLERS
		ABMutableMultiValueRef relatedMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*RELATED_$!<Mother>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Mother>!$_"], kABPersonMotherLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Father>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Father>!$_"], kABPersonFatherLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Parent>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Parent>!$_"], kABPersonParentLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Sister>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Sister>!$_"], kABPersonSisterLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Brother>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Brother>!$_"], kABPersonBrotherLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Child>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Child>!$_"], kABPersonChildLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Friend>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Friend>!$_"], kABPersonFriendLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Partner>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Partner>!$_"], kABPersonPartnerLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Manager>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Manager>!$_"], kABPersonManagerLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Assistant>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Assistant>!$_"], kABPersonAssistantLabel, NULL);
			specialData = TRUE;
		}
		if([VcardDictionary objectForKey: @"*RELATED_$!<Spouse>!$_"] != nil)
		{
			ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: @"*RELATED_$!<Spouse>!$_"], kABPersonSpouseLabel, NULL);
			specialData = TRUE;
		}
		
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*RELATED"])
			{
				ABMultiValueAddValueAndLabel(relatedMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*RELATED" withString: @""] , NULL);	
				specialData = TRUE;
			}
		}
		
		
		ABRecordSetValue(newPerson, kABPersonRelatedNamesProperty, relatedMultiValue, ABError);
		
		//PHONE HANDLERS
		ABMutableMultiValueRef phoneMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*PHONE_$!<Home>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<Home>!$_"], kABHomeLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<Work>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<Work>!$_"], kABWorkLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<Other>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<Other>!$_"], kABOtherLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<Mobile>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<Mobile>!$_"], kABPersonPhoneMobileLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<Main>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<Main>!$_"], kABPersonPhoneMainLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<WorkFAX>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<WorkFAX>!$_"], kABPersonPhoneWorkFAXLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<Pager>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<Pager>!$_"], kABPersonPhonePagerLabel, NULL);
		if([VcardDictionary objectForKey: @"*PHONE_$!<HomeFAX>!$_"] != nil)
			ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: @"*PHONE_$!<HomeFAX>!$_"], kABPersonPhoneHomeFAXLabel, NULL);
		
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*PHONE"])
			{
				ABMultiValueAddValueAndLabel(phoneMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*PHONE" withString: @""] , NULL);	
			}
		}
		
		ABRecordSetValue(newPerson, kABPersonPhoneProperty, phoneMultiValue, ABError);
		
		//URL HANDLERS
		ABMutableMultiValueRef URLMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*URL_$!<Home>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*URL_$!<Home>!$_"], kABHomeLabel, NULL);
		if([VcardDictionary objectForKey: @"*URL_$!<Work>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*URL_$!<Work>!$_"], kABWorkLabel, NULL);
		if([VcardDictionary objectForKey: @"*URL_$!<Other>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*URL_$!<Other>!$_"], kABOtherLabel, NULL);
		if([VcardDictionary objectForKey: @"*URL_$!<HomePage>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*URL_$!<HomePage>!$_"], kABPersonHomePageLabel, NULL);	
		
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*URL"])
			{
				ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*URL" withString: @""] , NULL);	
			}
		}
		
		ABRecordSetValue(newPerson, kABPersonURLProperty, URLMultiValue, ABError);
		
		//Date HANDLERS
		ABMutableMultiValueRef DateMultiValue =  ABMultiValueCreateMutable(kABStringPropertyType);
		if([VcardDictionary objectForKey: @"*DATE_$!<Home>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*DATE_$!<Home>!$_"], kABHomeLabel, NULL);
		if([VcardDictionary objectForKey: @"*DATE_$!<Work>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*DATE_$!<Work>!$_"], kABWorkLabel, NULL);
		if([VcardDictionary objectForKey: @"*DATE_$!<Other>!$_"] != nil)
			ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: @"*DATE_$!<Other>!$_"], kABOtherLabel, NULL);		
		
		
		for(int x = 0; x < [[VcardDictionary allKeys] count]; x++)
		{			
			if([[[VcardDictionary allKeys] objectAtIndex: x] rangeOfString: @"$!<"].location == NSNotFound && [[[VcardDictionary allKeys] objectAtIndex: x] hasPrefix:@"*DATE"])
			{
				ABMultiValueAddValueAndLabel(URLMultiValue, [VcardDictionary objectForKey: [[VcardDictionary allKeys] objectAtIndex: x]],  (CFStringRef)[[[VcardDictionary allKeys] objectAtIndex: x] stringByReplacingOccurrencesOfString: @"*DATE" withString: @""] , NULL);	
			}
		}
		
		ABRecordSetValue(newPerson, kABPersonDateProperty, DateMultiValue, ABError);
		
		
		ABRecordSetValue(newPerson, kABPersonFirstNameProperty, [VcardDictionary objectForKey: @"FirstName"], ABError);
		ABRecordSetValue(newPerson, kABPersonLastNameProperty, [VcardDictionary objectForKey: @"LastName"], ABError);
		ABRecordSetValue(newPerson, kABPersonMiddleNameProperty, [VcardDictionary objectForKey: @"MiddleName"], ABError);
		ABRecordSetValue(newPerson, kABPersonOrganizationProperty, [VcardDictionary objectForKey: @"OrgName"], ABError);
		ABRecordSetValue(newPerson, kABPersonJobTitleProperty, [VcardDictionary objectForKey: @"JobTitle"], ABError);
		ABRecordSetValue(newPerson, kABPersonDepartmentProperty, [VcardDictionary objectForKey: @"Department"], ABError);
		ABRecordSetValue(newPerson, kABPersonPrefixProperty, [VcardDictionary objectForKey: @"Prefix"], ABError);
		ABRecordSetValue(newPerson, kABPersonSuffixProperty, [VcardDictionary objectForKey: @"Suffix"], ABError);
		ABRecordSetValue(newPerson, kABPersonNicknameProperty, [VcardDictionary objectForKey: @"Nickname"], ABError);
		ABPersonSetImageData (newPerson, (CFDataRef)[NSData decodeBase64ForString: [VcardDictionary objectForKey: @"contactImage"]], ABError);
		
		NSDate *today = [[NSDate alloc] init];
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateFormat:@"MM-dd-yyyy"];
		
		if([VcardDictionary objectForKey: @"NotesText"] != nil)
		{
			ABRecordSetValue(newPerson, kABPersonNoteProperty, [[VcardDictionary objectForKey: @"NotesText"] stringByAppendingString: [NSString stringWithFormat: @"\n*This contact was sent through Handshake by %@ on %@", lastPeerHandle, [dateFormatter stringFromDate:today]]], ABError);
		}
		else
		{
			ABRecordSetValue(newPerson, kABPersonNoteProperty, [NSString stringWithFormat: @"*This contact was sent through Handshake by %@ on %@", lastPeerHandle, [dateFormatter stringFromDate:today]], ABError);
		}
		
		[dateFormatter release];
		[today release];
		
		
		HSKUnknownPersonViewController *unknownPersonViewController = [[HSKUnknownPersonViewController alloc] init];
		unknownPersonViewController.unknownPersonViewDelegate = self;
		unknownPersonViewController.addressBook = ABAddressBookCreate();
		unknownPersonViewController.displayedPerson = newPerson;
		unknownPersonViewController.allowsActions = NO;
		unknownPersonViewController.allowsAddingToAddressBook = YES;
		
        HSKNavigationController *navController = [[HSKNavigationController alloc] initWithRootViewController:unknownPersonViewController];
        [self presentModalViewController: navController animated:YES];
        [navController release];
		
		
		CFRelease(newPerson);
		[unknownPersonViewController release];
		
		if(specialData)
		{
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
																message:@"This card contains additional details that the iPhone can not display, to view the entire card sync it back with your computer." 
															   delegate:nil 
													  cancelButtonTitle:nil 
													  otherButtonTitles:@"Dismiss",nil];
			[alertView show];
			[alertView release];
		}
			
	}
}


- (void)bounceMyVcard
{
	ABRecordRef ownerCard =  ABAddressBookGetPersonWithRecordID(ABAddressBookCreate(), ownerRecord);
	NSMutableDictionary *VcardDictionary = [[NSMutableDictionary alloc] init];
	
	//single value objects
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonFirstNameProperty) forKey: @"FirstName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonMiddleNameProperty) forKey: @"MiddleName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonLastNameProperty) forKey: @"LastName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonOrganizationProperty) forKey: @"OrgName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonJobTitleProperty) forKey: @"JobTitle"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonDepartmentProperty) forKey: @"Department"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonPrefixProperty) forKey: @"Prefix"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonSuffixProperty) forKey: @"Suffix"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonNicknameProperty) forKey: @"Nickname"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonNoteProperty) forKey: @"NotesText"];
    
    // Re-encode the image
    UIImage *contactImage = [UIImage imageWithData:(NSData *)ABPersonCopyImageData(ownerCard)];
    if (contactImage)
    {
        [VcardDictionary setValue: [UIImageJPEGRepresentation(contactImage, 0.5) encodeBase64ForData] forKey: @"contactImage"];
    }
    else
    {
        [VcardDictionary setValue: nil forKey: @"contactImage"];
    }
    
	
	//phone
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonPhoneProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonPhoneProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*PHONE%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonPhoneProperty) , x)]];
	}
	
	//email
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonEmailProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonEmailProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*EMAIL%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonEmailProperty) , x)]];
	}
	
	//address
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonAddressProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonAddressProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*ADDRESS%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonAddressProperty) , x)]];
	}
	
	//URLs
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonURLProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonURLProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*URL%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonURLProperty) , x)]];
	}
	
	//IM
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonInstantMessageProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonInstantMessageProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*IM%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonInstantMessageProperty) , x)]];
	}
	
	//dates
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonDateProperty)) > x); x++)
	{
		//need to convert to string to play nice with JSON
		[VcardDictionary setValue: [(NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonDateProperty) , x) description] 
						   forKey: [NSString stringWithFormat: @"*DATE%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonDateProperty) , x)]];		
	}
	
	//relatives 
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonRelatedNamesProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonRelatedNamesProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*RELATED%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonRelatedNamesProperty) , x)]];
	}
	
	NSMutableDictionary *completedDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
	[completedDictionary setValue:VcardDictionary forKey:@"data"];
	[completedDictionary setValue: @"1.0" forKey:@"version"];
	[completedDictionary setValue: @"vcard_bounced" forKey:@"type"];
	
	self.dataToSend = [[CJSONSerializer serializer] serializeDictionary: completedDictionary];
	
	RPSNetwork *network = [RPSNetwork sharedNetwork];
	[network sendMessage: dataToSend toPeer: lastPeer];
	
	[completedDictionary release];
}

- (void)sendMyVcard
{	
	ABRecordRef ownerCard =  ABAddressBookGetPersonWithRecordID(ABAddressBookCreate(), ownerRecord);
	NSMutableDictionary *VcardDictionary = [[NSMutableDictionary alloc] init];
	
	//single value objects
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonFirstNameProperty) forKey: @"FirstName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonMiddleNameProperty) forKey: @"MiddleName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonLastNameProperty) forKey: @"LastName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonOrganizationProperty) forKey: @"OrgName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonJobTitleProperty) forKey: @"JobTitle"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonDepartmentProperty) forKey: @"Department"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonPrefixProperty) forKey: @"Prefix"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonSuffixProperty) forKey: @"Suffix"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonNicknameProperty) forKey: @"Nickname"];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey: @"allowNote"])
		[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonNoteProperty) forKey: @"NotesText"];
    
    // Re-encode the image
    UIImage *contactImage = [UIImage imageWithData:(NSData *)ABPersonCopyImageData(ownerCard)];
    if (contactImage)
    {
        [VcardDictionary setValue: [UIImageJPEGRepresentation(contactImage, 0.5) encodeBase64ForData] forKey: @"contactImage"];
    }
    else
    {
        [VcardDictionary setValue: nil forKey: @"contactImage"];
    }
    

	//phone
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonPhoneProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonPhoneProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*PHONE%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonPhoneProperty) , x)]];
	}
	
	//email
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonEmailProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonEmailProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*EMAIL%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonEmailProperty) , x)]];
	}
	
	//address
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonAddressProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonAddressProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*ADDRESS%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonAddressProperty) , x)]];
	}
	
	//URLs
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonURLProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonURLProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*URL%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonURLProperty) , x)]];
	}
	
	//IM
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonInstantMessageProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonInstantMessageProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*IM%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonInstantMessageProperty) , x)]];
	}
	
	//dates
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonDateProperty)) > x); x++)
	{
		//need to convert to string to play nice with JSON
		[VcardDictionary setValue: [(NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonDateProperty) , x) description] 
						   forKey: [NSString stringWithFormat: @"*DATE%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonDateProperty) , x)]];		
	}
	
	//relatives 
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonRelatedNamesProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonRelatedNamesProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*RELATED%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonRelatedNamesProperty) , x)]];
	}
	
	NSMutableDictionary *completedDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
	[completedDictionary setValue:VcardDictionary forKey:@"data"];
	[completedDictionary setValue: @"1.0" forKey:@"version"];
	[completedDictionary setValue: @"vcard" forKey:@"type"];
		
	self.dataToSend = [[CJSONSerializer serializer] serializeDictionary: completedDictionary];

	RPSBrowserViewController *browserViewController = [[RPSBrowserViewController alloc] initWithNibName:@"BrowserViewController" bundle:nil];
	browserViewController.navigationItem.prompt = @"Select a Recipient";
    browserViewController.delegate = self;
    [self.navigationController pushViewController:browserViewController animated:YES];
    [browserViewController release];	
	
	[completedDictionary release];
}

- (void)sendOtherVcard
{
	ABRecordRef ownerCard =  ABAddressBookGetPersonWithRecordID(ABAddressBookCreate(), otherRecord);

	NSMutableDictionary *VcardDictionary = [[NSMutableDictionary alloc] init];
	
	
	//single value objects
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonFirstNameProperty) forKey: @"FirstName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonMiddleNameProperty) forKey: @"MiddleName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonLastNameProperty) forKey: @"LastName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonOrganizationProperty) forKey: @"OrgName"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonJobTitleProperty) forKey: @"JobTitle"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonDepartmentProperty) forKey: @"Department"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonPrefixProperty) forKey: @"Prefix"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonSuffixProperty) forKey: @"Suffix"];
	[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonNicknameProperty) forKey: @"Nickname"];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey: @"allowNote"])
		[VcardDictionary setValue: (NSString *)ABRecordCopyValue(ownerCard, kABPersonNoteProperty) forKey: @"NotesText"];
    
	// Re-encode the image
    UIImage *contactImage = [UIImage imageWithData:(NSData *)ABPersonCopyImageData(ownerCard)];
    if (contactImage)
    {
        [VcardDictionary setValue: [UIImageJPEGRepresentation(contactImage, 0.5) encodeBase64ForData] forKey: @"contactImage"];
    }
    else
    {
        [VcardDictionary setValue: nil forKey: @"contactImage"];
    }
	
	//phone
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonPhoneProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonPhoneProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*PHONE%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonPhoneProperty) , x)]];
	}
	
	//email
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonEmailProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonEmailProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*EMAIL%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonEmailProperty) , x)]];
	}
	
	//address
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonAddressProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonAddressProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*ADDRESS%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonAddressProperty) , x)]];
	}
	
	//URLs
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonURLProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonURLProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*URL%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonURLProperty) , x)]];
	}
	
	//IM
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonInstantMessageProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonInstantMessageProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*IM%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonInstantMessageProperty) , x)]];
	}
	
	//dates
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonDateProperty)) > x); x++)
	{
		//need to convert to string to play nice with JSON
		[VcardDictionary setValue: [(NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonDateProperty) , x) description] 
						   forKey: [NSString stringWithFormat: @"*DATE%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonDateProperty) , x)]];		
	}
	
	//relatives 
	for (int x = 0; (ABMultiValueGetCount(ABRecordCopyValue(ownerCard , kABPersonRelatedNamesProperty)) > x); x++)
	{
		[VcardDictionary setValue: (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(ownerCard ,kABPersonRelatedNamesProperty) , x) 
						   forKey: [NSString stringWithFormat: @"*RELATED%@", (NSString *)ABMultiValueCopyLabelAtIndex(ABRecordCopyValue(ownerCard ,kABPersonRelatedNamesProperty) , x)]];
	}
	
	NSMutableDictionary *completedDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
	[completedDictionary setValue:VcardDictionary forKey:@"data"];
	[completedDictionary setValue: @"1.0" forKey:@"version"];
	[completedDictionary setValue: @"vcard" forKey:@"type"];
	
	self.dataToSend = [[CJSONSerializer serializer] serializeDictionary: completedDictionary];
	
	RPSBrowserViewController *browserViewController = [[RPSBrowserViewController alloc] initWithNibName:@"BrowserViewController" bundle:nil];
	browserViewController.navigationItem.prompt = @"Select a Peer";
    browserViewController.delegate = self;
    [self.navigationController pushViewController:browserViewController animated:YES];
    [browserViewController release];	
	
	[completedDictionary release];

}

-(void)recievedPict:(NSString *)string;
{	
	userBusy = TRUE;
	
	NSError *error = nil;
	NSData *JSONData = [string dataUsingEncoding: NSUTF8StringEncoding];
	
	NSDictionary *incomingData = [[CJSONDeserializer deserializer] deserialize:JSONData error: &error];
	NSData *data = [NSData decodeBase64ForString:[incomingData objectForKey: @"data"]]; 
	
    UIImage *receivedImage = [UIImage imageWithData: data];
    
    HSKPicturePreviewViewController *picPreviewController = [[HSKPicturePreviewViewController alloc] initWithNibName:@"PicturePreviewViewController" bundle:nil];
    [picPreviewController view];
    picPreviewController.pictureImageView.image = receivedImage;
    HSKNavigationController *navController = [[HSKNavigationController alloc] initWithRootViewController:picPreviewController];
    [self presentModalViewController:navController animated:YES];
    [navController release];
    [picPreviewController release];
}

- (void)sendPicture:(UIImage *)pict
{
	
	NSData *data = UIImageJPEGRepresentation(pict, 0.5);

	NSMutableDictionary *completedDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
	[completedDictionary setValue:[data encodeBase64ForData] forKey:@"data"];
	[completedDictionary setValue: @"1.0" forKey:@"version"];
	[completedDictionary setValue: @"img" forKey:@"type"];
	
	self.dataToSend = [[CJSONSerializer serializer] serializeDictionary: completedDictionary];
	
	RPSBrowserViewController *browserViewController = [[RPSBrowserViewController alloc] initWithNibName:@"BrowserViewController" bundle:nil];
	browserViewController.navigationItem.prompt = @"Select a Recipient";
    browserViewController.delegate = self;
    [self.navigationController pushViewController:browserViewController animated:YES];
    [browserViewController release];
}

- (void)checkQueueForMessages
{
	if(!userBusy)
	{		
		//if we have a message in queue handle it
		if([self.messageArray count] > 0)
		{
			[self messageReceived:[RPSNetwork sharedNetwork] fromPeer:[[self.messageArray objectAtIndex:0] objectForKey:@"peer"] message:[[self.messageArray objectAtIndex:0] objectForKey:@"message"]];
			
			//done with it so trash it
			[self.messageArray removeObjectAtIndex: 0];
			
			queueNumberLabel.hidden = FALSE;
			
			if([self.messageArray count] == 1)
			{
				queueNumberLabel.text = @"You have 1 message awaiting action";
			}
			else
			{
				queueNumberLabel.text = [NSString stringWithFormat:@"You have %i messages waiting for action", [self.messageArray count]];
			}
			
			//NSLog(@"%@", self.messageArray);
			//[[NSUserDefaults standardUserDefaults] setObject: self.messageArray forKey:@"storedMessages"];
		}	
		
		else
		{
			queueNumberLabel.hidden = TRUE;
			
		}
	} 
}

#pragma mark -
#pragma mark Alerts 


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	
	//boot message to select new owner.
	if (actionSheet.tag == 1)
    {
		if(buttonIndex == 0)
		{
			//we have found the correct user
			primaryCardSelecting = FALSE;
			[self ownerFound];
		}
		
		//we missed the mark for correct owner, user will select
		else if(buttonIndex == 1)
		{
			primaryCardSelecting = TRUE;
			
			ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
			picker.peoplePickerDelegate = self;
			picker.navigationBarHidden=YES; //gets rid of the nav bar
			[self presentModalViewController:picker animated:YES];
			[picker release];
		}
	}
	
	//new card recieved
	if (actionSheet.tag == 2)
    {
		//preview and bounce
		if(buttonIndex == 0)
		{
			[self bounceMyVcard];
			[self recievedVCard: lastMessage];
		}
		
		//preview
		else if(buttonIndex == 1)
		{
			[self recievedVCard: lastMessage];
		}
		
		//discard
		else if(buttonIndex == 2)
		{
			//do nothing
			userBusy = FALSE;
		}
		
		[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];
	}
	
	//bounce card recieved
	if (actionSheet.tag == 3)
    {
		if(buttonIndex == 0)
		{
			[self recievedVCard: lastMessage];
		}
		
		else if(buttonIndex == 1)
		{
			//do nothing
			userBusy = FALSE;
		}

		[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];
	}
	
	
	//picture received
	if (actionSheet.tag == 4)
    {
		if(buttonIndex == 0)
		{
			//preview
			[self recievedPict: self.lastMessage];
			
		}
		
		else if(buttonIndex == 1)
		{
			//save without preview
			userBusy = TRUE;
			
			NSError *error = nil;
			NSData *JSONData = [self.lastMessage dataUsingEncoding: NSUTF8StringEncoding];
			
			NSDictionary *incomingData = [[CJSONDeserializer deserializer] deserialize:JSONData error: &error];
			NSData *data = [NSData decodeBase64ForString:[incomingData objectForKey: @"data"]]; 
						
			UIImageWriteToSavedPhotosAlbum([UIImage imageWithData: data], nil, nil, nil);
		}
		
		else if(buttonIndex == 2)
		{
			//discard Do Nothing
			userBusy = FALSE;
		}
		
		
		[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{	
	//yes add to our photo album
    if (alertView.tag == 0)
    {
        if(buttonIndex == 1)
        {
            [self recievedPict: self.lastMessage];
        }
    }
    else if (alertView.tag == 1)
    {
        if (buttonIndex == 0)
        {
            exit(0);
        }
        else
        {
            if ([[RPSNetwork sharedNetwork] connect])
            {
                [self showOverlayView:@"Connecting to the server…"];
            }
            else
            {
                // utilize the run loop to prevent recursion and weirdness
                [self performSelector:@selector(handleConnectFail) withObject:nil afterDelay:0.0];
            }
        }
    }
	
	//no contacts in AB book
	else if (alertView.tag == 2)
    {
		exit(0);
	}

}

#pragma mark -
#pragma mark People Picker Functions


- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker 
{
	userBusy = NO;

	
	[self dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
	userBusy = NO;
	[self dismissModalViewControllerAnimated:YES];
	
	if(primaryCardSelecting)
	{
		ownerRecord = ABRecordGetRecordID(person);
		[self ownerFound];
	}
	else
	{
		otherRecord = ABRecordGetRecordID(person);
		[self sendOtherVcard];
	}
	
	//self.ownerCard = (id)person;
	
	

	
    return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
	//we should never get here anyways
	userBusy = NO;

	
    return NO;
}
#pragma mark -
#pragma mark image picker 


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
	userBusy = NO;
	[self dismissModalViewControllerAnimated:YES];
	[self sendPicture: image];
	
	
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	userBusy = NO;
	[self dismissModalViewControllerAnimated:YES];
	
	
}


#pragma mark -
#pragma mark Table Functions


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 73.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @" ";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{

	return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	
	static NSString *MyIdentifier = @"MyIdentifier";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
	}
	
	if([indexPath section] == 0)
	{
		if([indexPath row] == 0)
		{
			cell.text = @"Send My Card";
			[cell setImage:  [UIImage imageNamed: @"vcard.png"]];
		}
		else if ([indexPath row] == 1)
		{
			cell.text = @"Send Another Card";
			[cell setImage:  [UIImage imageNamed: @"ab.png"]];
		}
		else if ([indexPath row] == 2)
		{
			cell.text = @"Send a Picture";
			[cell setImage:  [UIImage imageNamed: @"pict.png"]];
		}
	}
	
		
	//adds the disclose indictator. 
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	// Configure the cell
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	userBusy = YES;
	//do that HIG glow thing that apple likes so much
	[tableView deselectRowAtIndexPath: indexPath animated: YES];
	
	//send my vCard
	if ([indexPath row] == 0)
	{
		[self sendMyVcard];
	}
	
	//send someone elses card
	if ([indexPath row] == 1)
	{
		primaryCardSelecting = FALSE;
		ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
        picker.peoplePickerDelegate = self;
		picker.navigationBarHidden=NO;
        [self presentModalViewController:picker animated:YES];
        [picker release];	
	}
	
	if([indexPath row] == 2)
	{
		UIImagePickerController *picker = [[UIImagePickerController alloc] init];
		[picker setDelegate:self];
		picker.navigationBarHidden=YES; 
		
		if([[NSUserDefaults standardUserDefaults] boolForKey: @"allowImageEdit"])
			picker.allowsImageEditing = YES;
		else
			picker.allowsImageEditing = NO;
		
		[self presentModalViewController:picker animated:YES];
        [picker release];	
	}
}

#pragma mark -
#pragma mark RPSNetworkDelegate methods

- (void)connectionFailed:(RPSNetwork *)sender
{
	[self handleConnectFail];
}

- (void)connectionSucceeded:(RPSNetwork *)sender
{
    [self hideOverlayView];
}

- (void)messageReceived:(RPSNetwork *)sender fromPeer:(RPSNetworkPeer *)peer message:(id)message
{	
	//not a ping lets handle it
    if(![message isEqual:@"PING"])
	{
		
		
		NSData *JSONData = [message dataUsingEncoding: NSUTF8StringEncoding];
		NSDictionary *incomingData = [[CJSONDeserializer deserializer] deserialize:JSONData error: nil]; //need error hanndling here
		
		if(!userBusy)
		{
			//client sees	
			self.lastMessage = message;
			self.lastPeer = peer;
			lastPeerHandle = peer.handle;
			
			userBusy = TRUE;
			//App will not let user proceed if if is about to post a message but if you hit it spot
			//on it will highlight the row and lock it
			[mainTable deselectRowAtIndexPath: [mainTable indexPathForSelectedRow] animated: YES];
			
			if([[incomingData objectForKey: @"type"] isEqualToString:@"vcard"])
			{
				
				
				UIActionSheet *alert = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@ has sent you a card", peer.handle]
																   delegate:self
														  cancelButtonTitle:@"Discard"
													 destructiveButtonTitle:nil
														  otherButtonTitles:@"Preview and Exchange", @"Preview" ,  nil];

				alert.tag = 2;
				[alert showInView:self.view];
				[alert release];
			}
			
			//vcard was returned
			else if([[incomingData objectForKey: @"type"] isEqualToString:@"vcard_bounced"])
			{
				UIActionSheet *alert = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@ has sent you a card in exchange for your card", peer.handle]
																   delegate:self
														  cancelButtonTitle:@"Discard"
													 destructiveButtonTitle:nil
														  otherButtonTitles:@"Preview", nil];
				
				alert.tag = 3;
				[alert showInView:self.view];
				[alert release];
			}
			
			else if([[incomingData objectForKey: @"type"] isEqualToString:@"img"])
			{
				UIActionSheet *alert = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@ has sent you a picture", peer.handle]
																   delegate:self
														  cancelButtonTitle:@"Discard"
													 destructiveButtonTitle:nil
														  otherButtonTitles:@"Preview", @"Save to Photo Library" ,  nil];
				
				alert.tag = 4;
				[alert showInView:self.view];
				[alert release];
			}
		}
		
		else
		{
			[self.messageArray addObject:[NSDictionary dictionaryWithObjectsAndKeys: peer, @"peer", message, @"message", nil]];
		}
	}
}

#pragma mark -
#pragma mark RPSBrowserViewControllerDelegate methods

- (void)browserViewController:(RPSBrowserViewController *)sender selectedPeer:(RPSNetworkPeer *)peer
{
    RPSNetwork *network = [RPSNetwork sharedNetwork];
	
	[self performSelector:@selector(checkQueueForMessages) withObject:nil afterDelay:1.0];

	
    sender.selectedPeer = peer;
    
    [messageSendIndicatorView startAnimating];
    messageSendLabel.hidden = NO;
    
    @try
    {
        [network sendMessage:self.dataToSend toPeer:peer];
    }
    @catch(NSException *e)
    {
        NSLog(@"Unable to send message: %@", [e reason]);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" 
                                                        message:@"Unable to send message. The message was too large." 
                                                       delegate:nil 
                                              cancelButtonTitle:nil 
                                              otherButtonTitles:@"Dismiss", nil];
        [alert show];
        [alert release];
        
        [messageSendIndicatorView stopAnimating];
        messageSendLabel.hidden = YES;
    }
    
    [self.navigationController popToViewController:self animated:YES];
}

- (void)messageSuccess:(RPSNetwork *)sender contextHandle:(NSUInteger)context
{
    // nothing
    
    // FIXME: remove after testing
    [NSThread sleepForTimeInterval:2.0];
    
    [messageSendIndicatorView stopAnimating];
    messageSendLabel.hidden = YES;
}

- (void)messageFailed:(RPSNetwork *)sender contextHandle:(NSUInteger)context
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
                                                        message:@"Error sending message to the the remote device."
                                                       delegate:nil
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
    
    [messageSendIndicatorView stopAnimating];
    messageSendLabel.hidden = YES;
}


#pragma mark -
#pragma mark ABUnknownPersonViewControllerDelegate methods 

- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownPersonViewController didResolveToPerson:(ABRecordRef)person 
{
	userBusy = NO;
	[self.navigationController dismissModalViewControllerAnimated: NO];	
}

#pragma mark -
#pragma mark UIViewController methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)dealloc 
{
	self.lastMessage = nil;
	self.frontButton = nil;
    self.dataToSend = nil;
	self.messageArray = nil;
    
    [super dealloc];
}

@end
