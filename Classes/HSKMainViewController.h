//
//  HSKViewController.h
//  Handshake
//
//  Created by Kyle on 9/24/08.
//  Copyright Dragon Forged Software 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "RPSBrowserViewController.h"
#import "RPSNetwork.h"
#import "RPSNetworkPeer.h"
#import "RPSNetworkPeersList.h"
#import "NSData+Base64Additions.h"

@class HSKFlipsideController;

@interface HSKMainViewController : UIViewController <UIActionSheetDelegate,
													ABPeoplePickerNavigationControllerDelegate,
													UITableViewDelegate,
													UIImagePickerControllerDelegate,
													UINavigationControllerDelegate, 
													RPSBrowserViewControllerDelegate, 
													RPSNetworkDelegate, 
													ABUnknownPersonViewControllerDelegate>
{
	ABRecordID ownerRecord;
	ABRecordID otherRecord;

	BOOL primaryCardSelecting;   //we need some kind of flag to know if we are selecting a primary user or another vcard
	IBOutlet UITableView *mainTable;
	IBOutlet UIView *flipView;
    IBOutlet UIView *frontView;
    
    IBOutlet UIView *overlayView;
    IBOutlet UIActivityIndicatorView *overlayActivityIndicatorView;
    IBOutlet UILabel *overlayLabel;
    IBOutlet UIButton *overlayRetryButton;
    
	IBOutlet UILabel *queueNumberLabel;
    
    IBOutlet UIActivityIndicatorView *messageSendIndicatorView;
    IBOutlet UILabel *messageSendLabel;
	
	IBOutlet HSKFlipsideController *flipsideController;
	
	NSDictionary* objectToSend;	
	NSMutableArray *messageArray;
	
	id lastMessage;
	id lastPeer;
	NSString *lastPeerHandle;
	
	BOOL userBusy;
    BOOL isFlipped;
    
    UIButton *frontButton;
    
    NSTimer *overlayTimer;
}


- (void)sendMyVcard;
- (void)sendOtherVcard:(ABPeoplePickerNavigationController *)picker;
- (void)bounceMyVcard;
-(void)recievedVCard: (NSDictionary *)vCardDictionary;
-(void)recievedPict:(NSDictionary *)pictDictionary;
-(void)verifyOwnerCard;
-(void)ownerFound;
-(IBAction)flipView;
-(void)flipBack;
- (void)checkQueueForMessages;
-(void)formatForVcard:(NSDictionary *)dictionary;

- (IBAction)retryConnection:(id)sender;
- (IBAction)helpMe:(id)sender;

@end

