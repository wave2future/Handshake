//
//  HSKFileBrowser.m
//  Handshake
//
//  Created by Kyle on 11/6/08.
//  Copyright 2008 Dragon Forged Software. All rights reserved.
//

#import "HSKFileBrowser.h"
#import "HSKFileViewerViewController.h"
#import "HSKFilePicturePreviewController.h"
#import "HSKFileTextViewController.h"
#import "HSKFileAdditonalDetailsView.h"

@implementation HSKFileBrowser

@synthesize rootDocumentPath, workingDirectory, fileArray, selectedArray, selectedImage, unselectedImage;

-(id)initWithDirectory:(NSString *)directory
{
	self = [super initWithNibName:@"FileBrowserViewController" bundle:nil];
	self.workingDirectory = directory;
	
	for(int x = 0; x < 6; x++)
		[[NSFileManager defaultManager] createDirectoryAtPath: [NSString stringWithFormat:@"%@/folder%i", self.workingDirectory, x] attributes:nil];
	
	
	[[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"html" ofType:@"html"] toPath:[self.workingDirectory stringByAppendingString:@"/html.html"] error:nil];
	[[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"pdf" ofType:@"pdf"] toPath:[self.workingDirectory stringByAppendingString:@"/pdf.pdf"] error:nil];
	
	
	[[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"digg" ofType:@"html"] toPath:[self.workingDirectory stringByAppendingString:@"/digg.html"] error:nil];
	[[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"arc" ofType:@"webarchive"] toPath:[self.workingDirectory stringByAppendingString:@"/arc.webarchive"] error:nil];

	
	
	[[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"rtftest" ofType:@"doc"] toPath:[self.workingDirectory stringByAppendingString:@"/rtftest.doc"] error:nil];

	return self;
}

// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad 
{
	diskSpaceLabel.hidden = FALSE;
	sendButton.hidden = TRUE;
	deleteButton.hidden = TRUE;
	inMassSelectMode = FALSE;
	
    [super viewDidLoad];
	
	self.fileArray = [NSMutableArray arrayWithArray: [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.workingDirectory error:NULL]];
	self.navigationItem.title = [self.workingDirectory lastPathComponent];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Select" style:UIBarButtonItemStylePlain target:self action:@selector(selectMass)] autorelease];
	
	//clear out the selected database
	[self populateSelectedArray];
	self.selectedImage = [UIImage imageNamed:@"selected.png"];
	self.unselectedImage = [UIImage imageNamed:@"unselected.png"];
	
	
	
	NSNumber *freeSpaceBytes =  [[[NSFileManager defaultManager] fileSystemAttributesAtPath: self.workingDirectory] objectForKey: @"NSFileSystemFreeSize"]; 
	
	if([freeSpaceBytes doubleValue] < 1048576)
		diskSpaceLabel.text = [NSString stringWithFormat: @"%0.0f KBs Available", [freeSpaceBytes doubleValue]/1024];
	else if ([freeSpaceBytes doubleValue] < 1073741824)
		diskSpaceLabel.text = [NSString stringWithFormat: @"%0.2f MBs Available", [freeSpaceBytes doubleValue]/1024/1024];
	else
		diskSpaceLabel.text = [NSString stringWithFormat: @"%0.2f GBs Available", [freeSpaceBytes doubleValue]/1024/1024/1024];
	
	
	
}

- (void)viewDidAppear:(BOOL)animated
{
	
	[self.fileArray removeAllObjects];
	self.fileArray = [NSMutableArray arrayWithArray: [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingDirectory error:NULL]];
	[fileBrowserTableView reloadData];
	[super viewDidAppear:animated];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return [fileArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *MyIdentifier = @"MyIdentifier";
	
	UIImage *folderImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"folder" ofType:@"png"]];
	UIImage *fileImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *excelImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *docImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *powerpointImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *numbersImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *keynoteImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *pagesImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *webImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *textImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *imagesImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *moviesImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *audioImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];
	UIImage *pdfImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"files" ofType:@"png"]];

	
	BOOL isDirectory = FALSE;
	[[NSFileManager defaultManager] fileExistsAtPath:[self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] isDirectory:&isDirectory];

	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) 
	{
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
		
		[cell setSelectionStyle: UITableViewCellSelectionStyleNone];
		
		UILabel *dateLabel = [[UILabel alloc] initWithFrame:kDateRect];
		dateLabel.tag = kCellDateTag;
		[dateLabel setFont: [UIFont systemFontOfSize: 12]];
		[dateLabel setTextColor: [UIColor grayColor]];
		[cell.contentView addSubview:dateLabel];
		[dateLabel release];
		
		UILabel *label = [[UILabel alloc] initWithFrame:kLabelRect];
		label.tag = kCellLabelTag;
		[cell.contentView addSubview:label];
		[label release];
		
		UILabel *sizeLabel = [[UILabel alloc] initWithFrame:kSizeLabel];
		sizeLabel.tag = kCellSizeTag;
		[sizeLabel setFont: [UIFont systemFontOfSize: 10]];
		[sizeLabel setTextAlignment: UITextAlignmentRight];
		[sizeLabel setTextColor: [UIColor grayColor]];
		[cell.contentView addSubview:sizeLabel];
		[sizeLabel release];
		
		UIImageView *imageView = [[UIImageView alloc] initWithImage:unselectedImage];
		imageView.frame = CGRectMake(5.0, 22.0, 23.0, 23.0);
		[cell.contentView addSubview:imageView];
		imageView.hidden = !inMassSelectMode;
		imageView.tag = kCellImageViewTag;
		[imageView release];
		
		UIImageView *iconView = [[UIImageView alloc] initWithImage: nil];
		iconView.frame = kIconRect;
		[cell.contentView addSubview:iconView];
		iconView.tag = kCellIconTag;
		[iconView release];
	}
	
	[UIView beginAnimations:@"cell shift" context:nil];
	
	UILabel *label = (UILabel *)[cell.contentView viewWithTag:kCellLabelTag];
	label.text = [self.fileArray objectAtIndex: [indexPath row]];
	label.frame = (inMassSelectMode) ? kLabelIndentedRect : kLabelRect;
	label.opaque = NO;
	
	UIImageView *iconView = (UIImageView *)[cell.contentView viewWithTag:kCellIconTag];
	iconView.frame = (inMassSelectMode) ? kIconIndet : kIconRect;
	
	NSString *fileType = [[[self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] pathExtension] lowercaseString];
	fileType = [fileType stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	fileType = [fileType stringByReplacingOccurrencesOfString:@" " withString:@""];
	
	if([fileType isEqualToString:@"xls"])
		iconView.image = excelImage;
	else if([fileType isEqualToString:@"doc"])
		iconView.image = docImage;
	else if([fileType isEqualToString:@"ppt"])
		iconView.image = powerpointImage;
	else if([fileType isEqualToString:@"pages"])
		iconView.image = pagesImage;
	else if([fileType isEqualToString:@"numbers"])
		iconView.image = numbersImage;
	else if([fileType isEqualToString:@"keynote"])
		iconView.image = keynoteImage;
	else if([fileType isEqualToString:@"html"] || [fileType isEqualToString:@"htm"] || [fileType isEqualToString:@"php"] || [fileType isEqualToString:@"css"] || [fileType isEqualToString:@"webarchive"])
		iconView.image = webImage;
	else if([fileType isEqualToString:@"txt"] || [fileType isEqualToString:@"log"])
		iconView.image = textImage;
	else if([fileType isEqualToString:@"jpg"] || [fileType isEqualToString:@"jpeg"] || [fileType isEqualToString:@"tiff"] || [fileType isEqualToString:@"gif"] || [fileType isEqualToString:@"png"]|| [fileType isEqualToString:@"pict"])
		iconView.image = imagesImage;
	else if([fileType isEqualToString:@"mov"] || [fileType isEqualToString:@"mpg"] || [fileType isEqualToString:@"mpeg"] || [fileType isEqualToString:@"mv4"] || [fileType isEqualToString:@"mp4"])
		iconView.image = moviesImage;
	else if([fileType isEqualToString:@"mp3"] || [fileType isEqualToString:@"caf"] || [fileType isEqualToString:@"aac"] || [fileType isEqualToString:@"aiff"]|| [fileType isEqualToString:@"wav"])
		iconView.image = audioImage;
	else if([fileType isEqualToString:@"pdf"])
		iconView.image = pdfImage;
	else if(isDirectory)
		iconView.image = folderImage;
	else
		iconView.image = fileImage;
	
	

	
	UILabel *dateLabel = (UILabel *)[cell.contentView viewWithTag:kCellDateTag];
	NSDate *fileDate = [[[NSFileManager defaultManager] fileAttributesAtPath: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] traverseLink:NO] objectForKey: @"NSFileModificationDate"];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"MMM dd, yyyy HH:MM"];
	dateLabel.text = [NSString stringWithFormat:@"%@", [dateFormatter stringFromDate: fileDate]];
	dateLabel.frame = (inMassSelectMode) ? kDateIndentedRect : kDateRect;
	dateLabel.opaque = NO;
	
	[dateFormatter release];

	UILabel *sizeLabel;
	
	if(!isDirectory)
	{
		sizeLabel = (UILabel *)[cell.contentView viewWithTag:kCellSizeTag];
		NSNumber *fileSize = [[[NSFileManager defaultManager] fileAttributesAtPath: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] traverseLink:NO] objectForKey: @"NSFileSize"];
		
		if([fileSize doubleValue] < 1023)
			sizeLabel.text = [NSString stringWithFormat: @"%f Bytes", fileSize] ;
		else if([fileSize doubleValue] < 1048576)
		{
			double convertedSize = [fileSize doubleValue] / 1024;
			sizeLabel.text = [NSString stringWithFormat: @"%0.1f KBs", convertedSize] ;
		}
		else
		{
			double convertedSize = [fileSize doubleValue] / 1024 / 1024;
			sizeLabel.text = [NSString stringWithFormat: @"%0.1f MBs", convertedSize] ;
		}
		
		sizeLabel.opaque = NO;
	}
	
	else
	{
		sizeLabel = (UILabel *)[cell.contentView viewWithTag:kCellSizeTag];
		sizeLabel.text = [NSString stringWithFormat: @"%i Items", [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] error: nil] count]];
		sizeLabel.opaque = NO;	
	}
	
	UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kCellImageViewTag];
	NSNumber *selected = [selectedArray objectAtIndex:[indexPath row]];
	imageView.image = ([selected boolValue]) ? selectedImage : unselectedImage;
	imageView.hidden = !inMassSelectMode;
	
	if(inMassSelectMode)
	{
		
		cell.accessoryType = UITableViewCellAccessoryNone;
		[UIView commitAnimations];

		
		if(imageView.image == selectedImage)
		{
			UIImageView *backgroundImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed: @"cellBackground.png"]];
			cell.backgroundView = backgroundImage;
			sizeLabel.backgroundColor = [UIColor clearColor];
			dateLabel.backgroundColor = [UIColor clearColor];
			label.backgroundColor = [UIColor clearColor];

			
			[backgroundImage release];
		}
		else
		{
			cell.backgroundView = nil;
			sizeLabel.backgroundColor = [UIColor whiteColor];
			dateLabel.backgroundColor = [UIColor whiteColor];
			label.backgroundColor = [UIColor whiteColor];

		}
		
	}
	
	else
	{
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
		[UIView commitAnimations];
		cell.backgroundView = nil;

	}
		
	[folderImage release];
	[fileImage release];	
	[excelImage release];
	[docImage release];
	[powerpointImage release];
	[numbersImage release];
	[keynoteImage release];
	[pagesImage release];
	[webImage release];
	[textImage release];
	[imagesImage release];
	[moviesImage release];
	[audioImage release];
	
	// Configure the cell
	return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	HSKFileAdditonalDetailsView *additionalDetailView = [[HSKFileAdditonalDetailsView alloc] initWithFile: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]]];		
	[self.navigationController pushViewController:additionalDetailView animated: YES];
	[additionalDetailView release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	
	if (inMassSelectMode)
	{
		BOOL selected = [[selectedArray objectAtIndex:[indexPath row]] boolValue];
		[selectedArray replaceObjectAtIndex:[indexPath row] withObject:[NSNumber numberWithBool:!selected]];
		
		if(!selected)
			numObjectsSelected++;
		else
			numObjectsSelected--;
		
		[sendButton setTitle:[NSString stringWithFormat:@"Send (%i)", numObjectsSelected] forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];
		[deleteButton setTitle:[NSString stringWithFormat:@"Delete (%i)", numObjectsSelected] forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];
		
		
		if(numObjectsSelected > 0)
		{
			[sendButton setEnabled: YES];
			[deleteButton setEnabled: YES];
		}
		
		else
		{
			[sendButton setEnabled: NO];
			[deleteButton setEnabled: NO];	
			
			[sendButton setTitle:@"Send" forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];
			[deleteButton setTitle:@"Delete" forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];
		}
		
		[tableView reloadData];
	}
	
	else
	{
		BOOL isDirectory = FALSE;

		[tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow] animated: NO];

		if([[NSFileManager defaultManager] fileExistsAtPath: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] isDirectory:&isDirectory])
		{
			if(isDirectory)
			{
				HSKFileBrowser *fileBrowserViewController = [[HSKFileBrowser alloc] initWithDirectory: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]]];		
				[self.navigationController pushViewController:fileBrowserViewController animated: YES];
				[fileBrowserViewController release];
			}
			
			//we have selected a file
			else
			{
				NSString *fileType = [[[self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]] pathExtension] lowercaseString];
				fileType = [fileType stringByReplacingOccurrencesOfString:@"\n" withString:@""];
				fileType = [fileType stringByReplacingOccurrencesOfString:@" " withString:@""];
				
				//handle in webview
				if([fileType isEqualToString:@"html"] || [fileType isEqualToString:@"htm"] || [fileType isEqualToString:@"pdf"] || [fileType isEqualToString:@"xls"] || [fileType isEqualToString:@"doc"] || [fileType isEqualToString:@"zip"] || [fileType isEqualToString:@"txt"]|| [fileType isEqualToString:@"webarchive"]|| [fileType isEqualToString:@"php"]|| [fileType isEqualToString:@"css"])
				{
					HSKFileViewerViewController *fileBrowserViewController = [[HSKFileViewerViewController alloc] initWithFile: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]]];		
					[self.navigationController pushViewController:fileBrowserViewController animated: YES];
					[fileBrowserViewController release];
					
				}
				
				//handle with UIImage
				else if ([fileType isEqualToString:@"png"] || [fileType isEqualToString:@"jpg"] || [fileType isEqualToString:@"pict"] || [fileType isEqualToString:@"gif"] || [fileType isEqualToString:@"jpeg"] || [fileType isEqualToString:@"tiff"])
				{
				
					HSKFilePicturePreviewController *picPreviewController = [[HSKFilePicturePreviewController alloc] initWithFile:[self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]]];
					[self.navigationController pushViewController:picPreviewController animated: YES];
					[picPreviewController release];
				}
				
				//handle with movie player
				else if ([fileType isEqualToString:@"mov"] ||[fileType isEqualToString:@"mp3"] ||[fileType isEqualToString:@"mpg"] || [fileType isEqualToString:@"mpeg"] || [fileType isEqualToString:@"caf"] || [fileType isEqualToString:@"aiff"] || [fileType isEqualToString:@"wav"] ||[fileType isEqualToString:@"m4v"]||[fileType isEqualToString:@"aac"]||[fileType isEqualToString:@"mp4"])
				{
					moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:  [NSURL fileURLWithPath: [self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]]]];
					moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
					moviePlayer.movieControlMode = MPMovieControlModeDefault;
					moviePlayer.backgroundColor = [UIColor blackColor];
					
				
					[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(movieDidFinishLoading) name: MPMoviePlayerContentPreloadDidFinishNotification object: moviePlayer];
					[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(moviePlayBackDidFinish) name: MPMoviePlayerPlaybackDidFinishNotification object: moviePlayer];
				}
				
				//handle with UIText
				else if ([fileType isEqualToString:@"log"])
				{
					HSKFileTextViewController *textViewController = [[HSKFileTextViewController alloc] initWithFile:[self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@", [fileArray objectAtIndex: [indexPath row]]]]];
					[self.navigationController pushViewController:textViewController animated: YES];
					[textViewController release];
				}
				
				
				else
				{
					NSLog(@"Rejected File Type:*%@*",fileType);
					
					UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@""
																		message:NSLocalizedString(@"This file type does not support previewing in Handshake.", @"warning on unknown filetype preview") 
																	   delegate:nil 
															  cancelButtonTitle:nil 
															  otherButtonTitles:NSLocalizedString(@"Okay", @"Out of memory warning action"),nil];
					[alertView show];
					[alertView release];	
				}
			}
		}
	}
	
	[tableView reloadData];
}

-(void) moviePlayBackDidFinish
{
	NSLog(@"Releasing Movie Player");
	[moviePlayer release];

}

-(void) selectMass
{
	[self populateSelectedArray];
	inMassSelectMode = !inMassSelectMode;

	diskSpaceLabel.hidden = inMassSelectMode;
	sendButton.hidden = !inMassSelectMode;
	deleteButton.hidden = !inMassSelectMode;
	
	[sendButton setTitle:@"Send" forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];
	[deleteButton setTitle:@"Delete" forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];

	
	[sendButton setEnabled: NO];
	[deleteButton setEnabled: NO];
	
	if(inMassSelectMode)
	{
		self.navigationItem.rightBarButtonItem.title = @"Cancel";
		self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStyleDone;
		self.navigationItem.hidesBackButton = TRUE;
	}

	else
	{
		self.navigationItem.rightBarButtonItem.title = @"Select";
		self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStylePlain;
		self.navigationItem.hidesBackButton = FALSE;
	}
		
	[fileBrowserTableView reloadData];
	
}

- (IBAction)massSend:(id)sender
{
	
	
}

- (IBAction)massDelete:(id)sender
{	
	NSMutableArray *indexArray = [[NSMutableArray alloc] init];	
	for(int x = 0; x < [self.selectedArray count]; x++)
	{		
		if([[self.selectedArray objectAtIndex: x] boolValue] == TRUE)
		{
			[[NSFileManager defaultManager] removeItemAtPath:[self.workingDirectory stringByAppendingString: [NSString stringWithFormat: @"/%@",  [self.fileArray objectAtIndex:x]]] error:nil];
			[indexArray addObject:[NSIndexPath indexPathForRow:x inSection:0]];
					
		}
	}
	
	[self.fileArray removeAllObjects];
	self.fileArray = [NSMutableArray arrayWithArray: [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingDirectory error:NULL]];
	
	[self populateSelectedArray];


	[fileBrowserTableView beginUpdates];
	[fileBrowserTableView deleteRowsAtIndexPaths: indexArray  withRowAnimation: UITableViewRowAnimationFade];
	[fileBrowserTableView endUpdates];
	
	[indexArray release];
	[fileBrowserTableView reloadData];
		
	[sendButton setTitle:@"Send" forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];
	[deleteButton setTitle:@"Delete" forState:UIControlStateNormal | UIControlStateHighlighted | UIControlStateSelected];

	[sendButton setEnabled: NO];
	[deleteButton setEnabled: NO];
}

- (void)populateSelectedArray
{
	numObjectsSelected = 0;
	
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[fileArray count]];
	for (int i=0; i < [fileArray count]; i++)
		[array addObject:[NSNumber numberWithBool:NO]];
	self.selectedArray = array;
	
	[array release]; 
} 



-(void) movieDidFinishLoading
{
	[moviePlayer play];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc 
{
	self.rootDocumentPath = nil;
	self.workingDirectory = nil;
	self.fileArray = nil;
	self.selectedArray = nil;
	self.selectedImage = nil;
	self.unselectedImage = nil;
	
	[super dealloc];
}


@end