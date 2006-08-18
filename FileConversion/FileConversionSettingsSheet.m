/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "FileConversionSettingsSheet.h"
#import "FileConversionController.h"
#import "MissingResourceException.h"
#import "UtilityFunctions.h"

enum {
	kAlbumTitleMenuItem				= 1,
	kAlbumArtistMenuItem			= 2,
	kAlbumYearMenuItem				= 3,
	kAlbumGenreMenuItem				= 4,
	kAlbumComposerMenuItem			= 5,
	kTrackTitleMenuItem				= 6,
	kTrackArtistMenuItem			= 7,
	kTrackYearMenuItem				= 8,
	kTrackGenreMenuItem				= 9,
	kTrackComposerMenuItem			= 10,
	kTrackNumberMenuItemTag			= 11,
	kTrackTotalMenuItemTag			= 12,
	kFileFormatMenuItemTag			= 13,
	kDiscNumberMenuItemTag			= 14,
	kDiscTotalMenuItemTag			= 15
};

@interface FileConversionSettingsSheet (Private)
- (void)	didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	updateOutputDirectoryMenuItemImage;
- (void)	selectOutputDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	selectTemporaryDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	updateTemporaryDirectoryMenuItemImage;
@end

@implementation FileConversionSettingsSheet

- (id) initWithSettings:(NSMutableDictionary *)settings
{
	if((self = [super init])) {

		_settings = [settings retain];

		if(NO == [NSBundle loadNibNamed:@"FileConversionSettingsSheet" owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"FileConversionSettingsSheet.nib" forKey:@"filename"]];
		}
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_settings release];
	[super dealloc];
}

- (void) awakeFromNib
{
	NSArray			*patterns			= nil;
	NSArray			*applications		= nil;
	NSDictionary	*application		= nil;
	NSString		*applicationPath	= nil;
	NSDictionary	*applicationEntry	= nil;
	unsigned		i;
	
	// Set the menu item images
	[self updateOutputDirectoryMenuItemImage];
	[self updateTemporaryDirectoryMenuItemImage];
	
	// Select the correct items
	[_outputDirectoryPopUpButton selectItemAtIndex:-1];
	[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
	[_temporaryDirectoryPopUpButton selectItemAtIndex:-1];
	[_temporaryDirectoryPopUpButton selectItemWithTag:([[_settings objectForKey:@"useCustomTemporaryDirectory"] boolValue] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
	
	// Deselect all items in the File Format Specifier NSPopUpButton
	[[_formatSpecifierPopUpButton selectedItem] setState:NSOffState];
	[_formatSpecifierPopUpButton selectItemAtIndex:-1];
	[_formatSpecifierPopUpButton synchronizeTitleAndSelectedItem];
	
	// Set the value to the most recently-saved pattern
	patterns = [_settings objectForKey:@"fileNamingPatterns"];
	if(0 < [patterns count]) {
		[_fileNamingComboBox setStringValue:[patterns objectAtIndex:0]];
	}
	
	// Set up the list of applications for post processing
	applications = [_settings objectForKey:@"postProcessingApplications"];
	for(i = 0; i < [applications count]; ++i) {
		application			= [applications objectAtIndex:i];
		applicationPath		= [application objectForKey:@"path"];
		applicationEntry	= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:applicationPath, [[NSFileManager defaultManager] displayNameAtPath:applicationPath], getIconForFile(applicationPath, NSMakeSize(16, 16)), nil] forKeys:[NSArray arrayWithObjects:@"path", @"displayName", @"icon", nil]];

		[_postProcessingActionsController addObject:applicationEntry];
	}

	// Set the sort descriptor
	[_postProcessingActionsController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES] autorelease],
		nil]];
}

- (void) showSheet
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[[FileConversionController sharedController] window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction) ok:(id)sender
{
	NSArray				*applications			= nil;
	NSMutableArray		*applicationArray		= nil;
	NSDictionary		*currentApplication		= nil;
	NSDictionary		*application			= nil;
	unsigned			i;

	// Save post-processing application paths to defaults
	applications		= [_postProcessingActionsController arrangedObjects];
	applicationArray	= [NSMutableArray arrayWithCapacity:[applications count]];
	for(i = 0; i < [applications count]; ++i) {
		currentApplication	= [applications objectAtIndex:i];
		application			= [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[currentApplication objectForKey:@"path"], nil] forKeys:[NSArray arrayWithObjects:@"path", nil]];

		[applicationArray addObject:application];
	}
	[_settings setValue:applicationArray forKey:@"postProcessingApplications"];
	
	// We're finished
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
	[self autorelease];
}

- (IBAction) selectOutputDirectory:(id)sender
{
	NSOpenPanel		*panel			= nil;
	int				returnCode		= 0;
	NSArray			*filesToOpen;
	NSString		*dirname;
	unsigned		count, i;
	
	switch([[sender selectedItem] tag]) {
		case kCurrentDirectoryMenuItemTag:
			[[NSWorkspace sharedWorkspace] selectFile:[[_settings objectForKey:@"outputDirectory"] stringByExpandingTildeInPath] inFileViewerRootedAtPath:nil];
			[_settings setValue:[NSNumber numberWithBool:NO] forKey:@"convertInPlace"];
			break;
			
		case kChooseDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			returnCode = [panel runModalForTypes:nil];
			
			switch(returnCode) {
				
				case NSOKButton:
					filesToOpen		= [panel filenames];
					count			= [filesToOpen count];
					
					for(i = 0; i < count; ++i) {
						dirname = [filesToOpen objectAtIndex:i];
						[_settings setValue:[dirname stringByAbbreviatingWithTildeInPath] forKey:@"outputDirectory"];
						[self updateOutputDirectoryMenuItemImage];
					}
						
					[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
					break;
					
				case NSCancelButton:
					[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
					break;
			}
				
			break;
			
		case kSameAsSourceFileMenuItemTag:
			[_settings setValue:[NSNumber numberWithBool:YES] forKey:@"convertInPlace"];
			break;
	}
}

- (IBAction) insertFileNamingFormatSpecifier:(id)sender
{
	NSString		*string;
	NSText			*fieldEditor;
	
	switch([[sender selectedItem] tag]) {
		case kAlbumTitleMenuItem:			string = @"{albumTitle}";		break;
		case kAlbumArtistMenuItem:			string = @"{albumArtist}";		break;
		case kAlbumYearMenuItem:			string = @"{albumYear}";		break;
		case kAlbumGenreMenuItem:			string = @"{albumGenre}";		break;
		case kAlbumComposerMenuItem:		string = @"{albumComposer}";	break;
		case kTrackTitleMenuItem:			string = @"{trackTitle}";		break;
		case kTrackArtistMenuItem:			string = @"{trackArtist}";		break;
		case kTrackYearMenuItem:			string = @"{trackYear}";		break;
		case kTrackGenreMenuItem:			string = @"{trackGenre}";		break;
		case kTrackComposerMenuItem:		string = @"{trackComposer}";	break;
		case kTrackNumberMenuItemTag:		string = @"{trackNumber}";		break;
		case kTrackTotalMenuItemTag:		string = @"{trackTotal}";		break;
		case kFileFormatMenuItemTag:		string = @"{fileFormat}";		break;
		case kDiscNumberMenuItemTag:		string = @"{discNumber}";		break;
		case kDiscTotalMenuItemTag:			string = @"{discTotal}";		break;
		default:							string = @"";					break;
	}
	
	fieldEditor = [_fileNamingComboBox currentEditor];
	if(nil == fieldEditor) {
		[_fileNamingComboBox setStringValue:string];
		[_fileNamingComboBox sendAction:[_fileNamingComboBox action] to:[_fileNamingComboBox target]];
	}
	else if([_fileNamingComboBox textShouldBeginEditing:fieldEditor]) {
		[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
		[_fileNamingComboBox textShouldEndEditing:fieldEditor];
	}
}

- (IBAction) saveFileNamingFormat:(id)sender
{
	NSString		*pattern	= [_fileNamingComboBox stringValue];
	NSMutableArray	*patterns	= nil;
	
	patterns = [[[_settings objectForKey:@"fileNamingPatterns"] mutableCopy] autorelease];
	if(nil == patterns) {
		patterns = [NSMutableArray array];
	}
	
	if([patterns containsObject:pattern]) {
		// Keep pattern from being released (it belongs to the combo box)
		[patterns removeObject:[pattern retain]];
	}	
	
	[patterns insertObject:pattern atIndex:0];
	
	while(10 < [patterns count]) {
		[patterns removeLastObject];
	}
	
	[_settings setValue:pattern forKey:@"fileNamingPattern"];	
	[_settings setValue:patterns forKey:@"fileNamingPatterns"];	
}	

- (IBAction) selectTemporaryDirectory:(id)sender
{
	NSOpenPanel		*panel			= nil;
	int				returnCode		= 0;
	NSArray			*filesToOpen;
	NSString		*dirname;
	int				count, i;
	
	switch([[sender selectedItem] tag]) {
		case kDefaultTempDirectoryMenuItemTag:
			[_settings setValue:[NSNumber numberWithBool:NO] forKey:@"useCustomTemporaryDirectory"];
			break;
			
		case kCurrentTempDirectoryMenuItemTag:
			if([[_settings objectForKey:@"useCustomTemporaryDirectory"] boolValue]) {
				[[NSWorkspace sharedWorkspace] selectFile:[_settings objectForKey:@"temporaryDirectory"] inFileViewerRootedAtPath:nil];
			}
			else {
				[_settings setValue:[NSNumber numberWithBool:YES] forKey:@"useCustomTemporaryDirectory"]; 
			}
			break;
			
		case kChooseTempDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			returnCode = [panel runModalForTypes:nil];
	
			switch(returnCode) {
				
				case NSOKButton:
					filesToOpen		= [panel filenames];
					count			= [filesToOpen count];
					
					for(i = 0; i < count; ++i) {
						dirname = [filesToOpen objectAtIndex:i];
						[_settings setValue:[NSNumber numberWithBool:YES] forKey:@"useCustomTemporaryDirectory"]; 
						[_settings setValue:[dirname stringByAbbreviatingWithTildeInPath] forKey:@"temporaryDirectory"];
						[self updateTemporaryDirectoryMenuItemImage];
					}
						
						[_temporaryDirectoryPopUpButton selectItemWithTag:kCurrentTempDirectoryMenuItemTag];	
					break;
					
				case NSCancelButton:
					[_temporaryDirectoryPopUpButton selectItemWithTag:([[_settings objectForKey:@"useCustomTemporaryDirectory"] boolValue] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
					break;
			}	
			break;
	}
}

- (void) updateOutputDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [[_settings objectForKey:@"outputDirectory"] stringByExpandingTildeInPath];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_outputDirectoryPopUpButton itemAtIndex:[_outputDirectoryPopUpButton indexOfItemWithTag:kCurrentDirectoryMenuItemTag]];	
	
	if(nil != path) {
		[menuItem setTitle:[path lastPathComponent]];
		[menuItem setImage:image];
	}
	else {
		[menuItem setTitle:@"Not Specified"];
		[menuItem setImage:nil];
	}
}

- (void) updateTemporaryDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [_settings objectForKey:@"temporaryDirectory"];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_temporaryDirectoryPopUpButton itemAtIndex:[_temporaryDirectoryPopUpButton indexOfItemWithTag:kCurrentTempDirectoryMenuItemTag]];
	
	if(nil != path) {
		[menuItem setTitle:[path lastPathComponent]];
		[menuItem setImage:image];
	}
	else {
		[menuItem setTitle:@"Not Specified"];
		[menuItem setImage:nil];
	}
}

- (IBAction) addPostProcessingApplication:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	
	if(NSOKButton == [panel runModalForTypes:[NSArray arrayWithObject:@"app"]]) {
		NSArray				*applications		= [panel filenames];
		NSDictionary		*application		= nil;
		NSString			*applicationPath	= nil;
		unsigned			i;
		
		for(i = 0; i < [applications count]; ++i) {
			applicationPath = [applications objectAtIndex:i];
			application		= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:applicationPath, [[NSFileManager defaultManager] displayNameAtPath:applicationPath], getIconForFile(applicationPath, NSMakeSize(16, 16)), nil] forKeys:[NSArray arrayWithObjects:@"path", @"displayName", @"icon", nil]];

			// Don't add existing items
			if(0 == [[[_postProcessingActionsController arrangedObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"path == %@", applicationPath]] count]) {
				[_postProcessingActionsController addObject:application];
			}			
		}
	}
}

@end
