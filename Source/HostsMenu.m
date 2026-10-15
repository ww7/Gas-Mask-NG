/***************************************************************************
 *   Copyright (C) 2009-2010 by Clockwise   *
 *   copyright@clockwise.ee   *
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

#import "HostsMenu.h"
#import "HostsMainController.h"
#import "ApplicationController.h"
#import "RemoteHostsController.h"
#import "Pair.h"
#import "CombinedHosts.h"

@interface HostsMenu (Private)
- (void)createItems;
- (void)createItemsFromHosts:(NSArray*)hostsArray indentation:(BOOL)indentation;
- (void)createItemsFromHosts:(NSArray*)hostsArray withTitle:(NSString*)title;
- (void)createExtraItems;
- (BOOL)haveItemsInOneGroup:(NSArray*)goupPairs;
@end

@implementation HostsMenu

- (id)init
{
	self = [super init];
	
	[self createItems];
	
	return self;
}

- (id)initWithExtras
{
	self = [self init];
	[self createExtraItems];
	
	return self;
}

@end

@implementation HostsMenu (Private)

-(IBAction)activateHostsFile:(id)sender
{
    Hosts *hosts = (Hosts*)[sender representedObject];
    if (![hosts active]) {
        [[HostsMainController defaultInstance] activateHostsFile:hosts];
    }
}

- (void)createItems
{
	NSArray *groups = [[HostsMainController defaultInstance] allHostsFilesGrouped];
    // Menu order only: keep the sidebar and profile-switching order unchanged.
    NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:groups.count];
    for (Pair *pair in groups) {
        if ([[(NSArray *)pair.right firstObject] isKindOfClass:[CombinedHosts class]]) {
            [pairs addObject:pair];
        }
    }
    for (Pair *pair in groups) {
        if (![[(NSArray *)pair.right firstObject] isKindOfClass:[CombinedHosts class]]) {
            [pairs addObject:pair];
        }
    }
	
	if ([self haveItemsInOneGroup:pairs]) {
		for (int i=0; i<[pairs count]; i++) {
			[self createItemsFromHosts:(NSArray*)[[pairs objectAtIndex:i] right] indentation:NO];
		}
	}
	else {
		for (int i=0; i<[pairs count]; i++) {
			Pair *pair = [pairs objectAtIndex:i];
			[self createItemsFromHosts:(NSArray*)[pair right] withTitle:(NSString*)[pair left]];
		}
	}
}

- (void)createItemsFromHosts:(NSArray*)hostsArray indentation:(BOOL)indentation
{
	for (Hosts *hosts in hostsArray) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[hosts name] action:NULL keyEquivalent:@""];
		[item setRepresentedObject:hosts];
		if (indentation) {
			[item setIndentationLevel:1];
		}
		
		if ([hosts selectable]) {
			[item setAction:@selector(activateHostsFile:)];
			[item setTarget:self];
		}
		
		if ([hosts active]) {
			[item setState:NSOnState];
		}
		
		[self addItem:item];
	}
}
 
- (void)createItemsFromHosts:(NSArray*)hostsArray withTitle:(NSString*)title
{
	if ([hostsArray count] > 0) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""];
		[self addItem:item];

	}
	[self createItemsFromHosts:hostsArray indentation:YES];
}

- (void)createExtraItems
{
    BOOL hasProfiles = self.numberOfItems > 0;
	ApplicationController *controller = [ApplicationController defaultInstance];
	NSMenuItem *item;
	
	if ([controller editorWindowOpened]) {
		item = [[NSMenuItem alloc] initWithTitle:@"Close Editor Window" action:NULL keyEquivalent:@""];
		[item setAction:@selector(closeEditorWindow:)];
	}
	else {
		item = [[NSMenuItem alloc] initWithTitle:@"Show Editor Window" action:NULL keyEquivalent:@""];
		[item setAction:@selector(openEditorWindow:)];
	}
	[item setTarget:controller];
    [self insertItem:item atIndex:0];
    [self insertItem:[NSMenuItem separatorItem] atIndex:1];
    if (hasProfiles) {
        [self addItem:[NSMenuItem separatorItem]];
    }
	
    if ([[HostsMainController defaultInstance] hostsFilesExistForControllerClass:[RemoteHostsController class]]) {
        item = [[NSMenuItem alloc] initWithTitle:@"Update Remote Files" action:@selector(updateAndSynchronize:) keyEquivalent:@""];
        [item setTarget:controller];
        [self addItem:item];
    }

    item = [[NSMenuItem alloc] initWithTitle:@"Settings…" action:@selector(openPreferencesWindow:) keyEquivalent:@""];
    [item setTarget:controller];
    [self addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:@"Quit Gas Mask" action:NULL keyEquivalent:@""];
	[item setAction:@selector(quit:)];
	[item setTarget:controller];
	[self addItem:item];
}

- (BOOL)haveItemsInOneGroup:(NSArray*)goupPairs
{
	BOOL haveInGroup = NO;
	
	for (int i=0; i<[goupPairs count]; i++) {
		NSArray *items = (NSArray*)[[goupPairs objectAtIndex:i] right];
		if ([items count] > 0) {
			if (haveInGroup) {
				return NO;
			}
			else {
				haveInGroup = YES;
			}
		}
	}
	return haveInGroup;
}
 
 @end