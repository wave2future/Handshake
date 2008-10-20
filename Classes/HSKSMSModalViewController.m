//
//  SKPSMSModalView.m
//  CDBIPhone
//
//  Created by Ian Baird on 7/15/08.
//  Copyright 2008 Skorpiostech, Inc.. All rights reserved.
//

#import "HSKSMSModalViewController.h"
#import "NSString+SKPPhoneAdditions.h"

@interface HSKSMSModalViewController ()

@property(nonatomic, retain) NSString *phoneNumber;

- (void)formatTypedPhoneNumber:(UITextField *)aTextField;

@end

@implementation HSKSMSModalViewController

@synthesize tableView, delegate, phoneNumber, textField, sendButton;

- (id)init
{
    if (self = [super initWithNibName:@"SMSModalView" bundle:nil])
    {
        self.phoneNumber = @"";
        self.title = @"Share";
    }
    
    return self;
}    

- (void)dealloc 
{
    
    self.tableView = nil;
    self.delegate = nil;
    self.phoneNumber = nil;
    self.textField = nil;
    self.sendButton = nil;
    
	[super dealloc];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
	return 2;
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    return (indexPath.section == 0) ? 55.0 : 44.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *title = nil;
        
    if (section == 0)
    {
        title = @"Send the Handhake App Store link to a mobile phone in the US or Canada.";
    }
    
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *MyIdentifier = @"SMSIdentifier";
	
	UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) 
    {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
	}
    
	// Configure the cell
    if (indexPath.section == 0)
    {
        UITextField *numberField = [[UITextField alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 12.0, 8.0)];
        numberField.placeholder = @"Phone";
        numberField.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        numberField.clearButtonMode = UITextFieldViewModeWhileEditing;
        numberField.opaque = YES;
        numberField.keyboardType = UIKeyboardTypeNumberPad;
        numberField.backgroundColor = [UIColor whiteColor];
        numberField.text = self.phoneNumber;
        numberField.font = [UIFont systemFontOfSize:36];
        numberField.textColor = [UIColor colorWithRed:58.0/255.0 green:86.0/255.0 blue:138.0/255.0 alpha:1.0];
        numberField.delegate = self;

        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.contentView.autoresizesSubviews = YES;
        cell.contentView.opaque = YES;
        [cell.contentView addSubview:numberField];
        
        self.textField = numberField;
        
        [numberField release];
    }
    else
    {
        cell.text = @"Address Book";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if (indexPath.section == 1)
    {
        self.phoneNumber = self.textField.text;
        
        ABPeoplePickerNavigationController *picker =
        [[ABPeoplePickerNavigationController alloc] init];
        picker.peoplePickerDelegate = self;
        picker.displayedProperties = [NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:kABPersonPhoneProperty]];
        [self presentModalViewController:picker animated:YES];
        [picker release];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.sendButton = [[[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(send:)] autorelease];
    
    self.navigationItem.rightBarButtonItem = sendButton;
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)] autorelease];
    
    sendButton.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
    
    // Remove any existing selection.
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    if (indexPath.row != NSNotFound)
    {
        [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
    
    self.tableView.sectionFooterHeight = 0.0;
    self.tableView.sectionHeaderHeight = 14.0;
    
    // Redisplay the data.
    [self.tableView reloadData];
    
    // set the status bar style
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}

- (void)viewDidAppear:(BOOL)animated 
{
	[super viewDidAppear:animated];
    
    // Set the focus
    [self.textField becomeFirstResponder];
    
    // format any text (enable/disable the send button)
    [self formatTypedPhoneNumber:self.textField];
}

#pragma mark -
#pragma mark UITextFieldDelegate methods

- (BOOL)textField:(UITextField *)aTextField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self performSelector:@selector(formatTypedPhoneNumber:) withObject:aTextField afterDelay:0.0];
    
    return (([[aTextField.text numericOnly] length] + [[string numericOnly] length]) < 11);
}

- (BOOL)textFieldShouldClear:(UITextField *)aTextField
{
    [self performSelector:@selector(formatTypedPhoneNumber:) withObject:aTextField afterDelay:0.0];
    
    return YES;
}

#pragma mark -
#pragma mark timer methods

- (void)formatTypedPhoneNumber:(UITextField *)aTextField
{
    aTextField.text = [aTextField.text formattedUSPhoneNumber];
    
    sendButton.enabled = ([[aTextField.text numericOnly] length] == 10);
}

#pragma mark -
#pragma mark ABPeoplePickerNavigationController delegate methods

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker 
{
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    return YES;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    ABMultiValueRef mvRef = ABRecordCopyValue(person, kABPersonPhoneProperty);
    CFStringRef aPhoneNumber = ABMultiValueCopyValueAtIndex(mvRef, identifier);
    
    self.phoneNumber = [(NSString *)aPhoneNumber formattedUSPhoneNumber];
    textField.text = self.phoneNumber;
    
    sendButton.enabled = YES;
    
    CFRelease(aPhoneNumber);
    CFRelease(mvRef);
    
    [self dismissModalViewControllerAnimated:YES];
    
    return NO;
}

#pragma mark -
#pragma mark event methods

- (IBAction)cancel:(id)sender
{
    if (self.delegate)
    {
        [delegate smsModalViewWasCancelled:self];
    }
}

- (IBAction)send:(id)sender
{
    if (self.delegate)
    {
        self.phoneNumber = self.textField.text;
        
        [delegate smsModalView:self enteredPhoneNumber:[self.phoneNumber numericOnly]];
    }
}

@end
