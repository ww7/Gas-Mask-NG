/***************************************************************************
 *   Copyright (C) 2009-2018 by Siim Raud   *
 *   siim@clockwise.ee   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

#import "ApplicationController.h"
#import "StructureConverter.h"
#import "Preferences.h"
#import "HostsMenu.h"
#import "HostsTextView.h"
#import "Gas_Mask-Swift.h"
#import "LocalHostsController.h"
#import "RemoteHostsController.h"
#import "NotificationHelper.h"
#import <Sparkle/Sparkle.h>
#import <math.h>

@interface ApplicationController ()
{
	__weak NSWindow *_editorWindow;
}
- (void)installEditorMenuItems;
- (void)adjustEditorTextSize:(CGFloat)delta;
@end

@interface ApplicationController(Private)
- (void)initStructure;
- (void)initEditorWindow;
- (void)notifyHostsChange:(Hosts*)hosts;
- (void)showApplicationInDock;
- (void)hideApplicationFromDock;
- (void)orderEditorWindowFront;
- (void)editorWindowWillClose:(NSNotification *)notification;
- (void)createHostsFileFromLocalURL:(NSURL*)url;
@end

@implementation ApplicationController


static ApplicationController *sharedInstance = nil;

+ (ApplicationController*)defaultInstance
{
	return sharedInstance;
}

- (id)init
{
    if (sharedInstance) {
        return sharedInstance;
    }
	if (self = [super init]) {
		shouldQuit = YES;

		BOOL isTesting = NSClassFromString(@"XCTestCase") != nil;
		BOOL forkBuild = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"WW7ForkBuild"] boolValue];
		if (!isTesting && !forkBuild) {
			_updaterController = [[SPUStandardUpdaterController alloc]
								  initWithStartingUpdater:YES
								  updaterDelegate:nil
								  userDriverDelegate:nil];
		}

		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(activatePreviousFile:) name:ActivatePreviousFileNotification object:nil];
		[nc addObserver:self selector:@selector(activateNextFile:) name:ActivateNextFileNotification object:nil];
        [nc addObserver:self selector:@selector(notifyOfFileRestored:) name:RestoredHostsFileNotification object:nil];

		sharedInstance = self;
		return self;
	}
    return sharedInstance;
}

- (SPUUpdater *)updater
{
	return _updaterController.updater;
}

-(IBAction)openPreferencesWindow:(id)sender
{
    [self showApplicationInDock];
	[PreferencesPresenter showPreferences];
}

- (IBAction)displayAboutBox:(id)sender
{
	[AboutBoxPresenter show];
}

- (IBAction)reportBugs:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:IssueTrackerURL]];
}

- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:DonateURL]];
}

-(IBAction)quit:(id)sender
{
	[[NSApplication sharedApplication] terminate:self];
}

- (IBAction)openEditorWindow:(id)sender
{
	if (!editorWindowOpened) {
		if (_editorWindow) {
			editorWindowOpened = YES;
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(editorWindowWillClose:)
														 name:NSWindowWillCloseNotification
													   object:_editorWindow];
		} else {
			[self initEditorWindow];
		}
	}

	[self showApplicationInDock];
	[self orderEditorWindowFront];
}

- (IBAction)closeEditorWindow:(id)sender
{
	[self hideApplicationFromDock];
}

- (void)installEditorMenuItems
{
    NSMenu *editMenu = [[NSApp.mainMenu itemWithTitle:@"Edit"] submenu];
    NSMenu *findMenu = [[editMenu itemWithTitle:@"Find"] submenu];
    for (NSMenuItem *item in findMenu.itemArray) {
        if (item.action == @selector(performFindPanelAction:)) {
            item.target = self;
            item.action = @selector(findInEditor:);
        }
    }
    if (findMenu && ![findMenu itemWithTitle:@"Find in All Lists…"]) {
        [findMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Find in All Lists…" action:@selector(findInAllProfiles:) keyEquivalent:@"f"];
        item.target = self;
        item.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
        [findMenu addItem:item];
    }
    if (editMenu && ![editMenu itemWithTitle:@"Toggle Comment"]) {
        [editMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Toggle Comment" action:@selector(toggleComment:) keyEquivalent:@"/"];
        item.target = nil;
        item.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        [editMenu addItem:item];
    }
    NSMenu *helpMenu = [[NSApp.mainMenu itemWithTitle:@"Help"] submenu];
    NSMenuItem *help = [helpMenu itemWithTitle:@"Gas Mask Help"];
    help.target = self;
    help.action = @selector(showEditorHelp:);
    NSMenu *viewMenu = [[NSApp.mainMenu itemWithTitle:@"View"] submenu];
    if (viewMenu && ![viewMenu itemWithTitle:@"Increase Text Size"]) {
        [viewMenu addItem:[NSMenuItem separatorItem]];
        NSArray *titles = @[@"Increase Text Size", @"Decrease Text Size", @"Actual Text Size"];
        NSArray *keys = @[@"+", @"-", @"0"];
        SEL actions[] = {@selector(increaseEditorTextSize:), @selector(decreaseEditorTextSize:), @selector(resetEditorTextSize:)};
        for (NSUInteger i = 0; i < titles.count; i++) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:titles[i] action:actions[i] keyEquivalent:keys[i]];
            item.keyEquivalentModifierMask = NSEventModifierFlagCommand;
            item.target = self;
            [viewMenu addItem:item];
        }
        // Support the unshifted = key as well as + through native menu matching.
        NSMenuItem *alias = [[NSMenuItem alloc] initWithTitle:@"Increase Text Size" action:@selector(increaseEditorTextSize:) keyEquivalent:@"="];
        alias.target = self;
        alias.keyEquivalentModifierMask = NSEventModifierFlagCommand;
        alias.hidden = YES;
        alias.allowsKeyEquivalentWhenHidden = YES;
        [viewMenu addItem:alias];
    }
    NSMenu *fileMenu = [[NSApp.mainMenu itemWithTitle:@"File"] submenu];
    if (fileMenu && ![fileMenu itemWithTitle:@"Update Remote Files"]) {
        [fileMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Update Remote Files" action:@selector(updateAndSynchronize:) keyEquivalent:@""];
        item.target = self;
        item.image = [NSImage imageWithSystemSymbolName:@"icloud.and.arrow.down" accessibilityDescription:@"Update Remote Files"];
        [GlobalShortcuts configureUpdateMenuItem:item];
        [fileMenu addItem:item];
    }
}

- (IBAction)findInEditor:(id)sender {
    [self openEditorWindow:nil];
    [EditorWindowPresenter findInEditor:sender];
}
- (IBAction)findInAllProfiles:(id)sender {
    [self openEditorWindow:nil];
    [EditorWindowPresenter showGlobalSearch];
}
- (IBAction)showEditorHelp:(id)sender {
    [self openEditorWindow:nil];
    [EditorWindowPresenter showHelp];
}

- (IBAction)increaseEditorTextSize:(id)sender { [self adjustEditorTextSize:1]; }
- (IBAction)decreaseEditorTextSize:(id)sender { [self adjustEditorTextSize:-1]; }
- (IBAction)resetEditorTextSize:(id)sender {
    [[NSUserDefaults standardUserDefaults] setDouble:11 forKey:EditorFontSizePrefKey];
}

- (void)adjustEditorTextSize:(CGFloat)delta
{
    NSNumber *saved = [[NSUserDefaults standardUserDefaults] objectForKey:EditorFontSizePrefKey];
    CGFloat size = saved ? saved.doubleValue : 11;
    size = isfinite(size) ? MIN(40, MAX(8, size)) : 11;
    [[NSUserDefaults standardUserDefaults] setDouble:MIN(40, MAX(8, size + delta)) forKey:EditorFontSizePrefKey];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if (item.action == @selector(increaseEditorTextSize:) || item.action == @selector(decreaseEditorTextSize:) ||
        item.action == @selector(resetEditorTextSize:)) {
        return [EditorWindowPresenter editorWindowVisible];
    }
    if (item.action == @selector(updateAndSynchronize:)) {
        return [hostsController hostsFilesExistForControllerClass:[RemoteHostsController class]];
    }
    return YES;
}

- (IBAction)addFromURL:(id)sender
{
	[URLSheetPresenter presentInWindow:nil];
}

- (IBAction)openHostsFile:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
    NSArray *fileTypes = [NSArray arrayWithObject:HostsFileExtension];
    [panel setAllowedFileTypes:fileTypes];
    int result = [panel runModal];
    if (result == NSOKButton) {
		[self createHostsFileFromLocalURL:[[panel URLs] lastObject]];
	}
}

- (IBAction)updateAndSynchronize:(id)sender
{
	logDebug(@"Update & synchronize");
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:UpdateAndSynchronizeNotification object:nil];
}

- (BOOL)editorWindowOpened
{
	return editorWindowOpened;
}

#pragma mark - Application Delegate

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    [self openEditorWindow:nil];
    return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [self installEditorMenuItems];
	// The test host must not load/migrate real profiles, start downloads, or request permissions.
	if (NSClassFromString(@"XCTestCase") != nil) {
		return;
	}
    [AppAppearance applyPreference];
	[NotificationHelper initNotificationCenter];
	(void)[GlobalShortcuts shared]; // Register global hotkeys

	checkForUpdatesMenuItem.target = _updaterController;
	checkForUpdatesMenuItem.action = @selector(checkForUpdates:);

	[NSApp setServicesProvider:self];

	[self initStructure];

	[hostsController load];

	if (!openedAtLogin() && [Preferences showEditorWindow]) {
		[self openEditorWindow:nil];
	}
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if (reopened() && [filename isEqual:@"#reopen#"]) {
		return NO;
	}
	
	logDebug(@"Opening file \"%@\"", filename);
	
	if ([[filename pathExtension] isEqual:HostsFileExtension]) {
		NSURL *url = [NSURL fileURLWithPath:filename];
		[self createHostsFileFromLocalURL:url];
		return YES;
	}
	
	return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	shouldQuit = YES;
	if (!editorWindowOpened) {
		[self hideApplicationFromDock];
	}
	return NO;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (!shouldQuit) {
		[self hideApplicationFromDock];
	}
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	return [HostsMenu new];
}

#pragma mark -
#pragma mark CrashReportSenderDelegate

- (void) showMainApplicationWindow
{
	[[NSApp mainWindow] makeFirstResponder: nil];
	[[NSApp mainWindow] makeKeyAndOrderFront: nil];
}

#pragma mark -
#pragma mark Service Provider

-(void)createNewHostsFile:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
	logDebug(@"Creating new hosts file from dropped data");
    NSString * data = [pboard stringForType:NSPasteboardTypeString];
    
	NSURL *url = [NSURL URLWithString:data];
	if (url == nil) {
		[hostsController createNewHostsFileWithContents:data];
	}
	else {
		BOOL created = [hostsController createHostsFromURL:url forControllerClass:[RemoteHostsController class]];
		if (!created) {
			[hostsController createHostsFromURL:url forControllerClass:[LocalHostsController class]];
		}
	}
}

@end

@implementation ApplicationController(Private)

- (void)initStructure
{
	logDebug(@"Init structure");
	StructureConverter *structureConverter = [StructureConverter new];
	[structureConverter convertToCurrent];
}

- (void)initEditorWindow
{
	logDebug(@"Initializing editor window");
	_editorWindow = [EditorWindowPresenter createEditorWindow];
	editorWindowOpened = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(editorWindowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:_editorWindow];
}

- (void)activatePreviousFile:(NSNotification *)note
{
	Hosts *hosts = [hostsController activatePrevious];
    [self notifyHostsChange:hosts];
}

- (void)activateNextFile:(NSNotification *)note
{
	Hosts *hosts = [hostsController activateNext];
    [self notifyHostsChange:hosts];
}

- (void)notifyOfFileRestored:(NSNotification *)note
{    
    [NotificationHelper notify:@"Hosts File Restored"
                       message:@"External application has changed the hosts file.\nGas Mask restored previous state."];
}

- (void)notifyHostsChange:(Hosts*)hosts
{
    [NotificationHelper notify:@"Hosts File Activated" message:[hosts name]];
}

- (void)showApplicationInDock
{
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	if (@available(macOS 14.0, *)) {
		[NSApp activate];
	} else {
		[NSApp activateIgnoringOtherApps:YES];
	}
}

- (void)hideApplicationFromDock
{
	[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
	[Preferences setShowEditorWindow:NO];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowWillCloseNotification
												  object:_editorWindow];
	[_editorWindow orderOut:nil];
	editorWindowOpened = NO;
}

- (void)orderEditorWindowFront
{
    if (_editorWindow.isMiniaturized) { [_editorWindow deminiaturize:nil]; }
	[_editorWindow makeKeyAndOrderFront:nil];
}

- (void)editorWindowWillClose:(NSNotification *)notification
{
	if (editorWindowOpened) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSWindowWillCloseNotification
													  object:[notification object]];
		[self hideApplicationFromDock];
	}
}

- (void)createHostsFileFromLocalURL:(NSURL*)url
{
	if ([hostsController hostsFileWithLocalURLExists:url]) {
		Hosts *hosts = [hostsController hostsFileWithLocalURL:url];
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:HostsFileShouldBeSelectedNotification object:hosts];
	}
	else {
		[hostsController createHostsFromLocalURL:url forControllerClass:[LocalHostsController class]];
	}
}

@end
