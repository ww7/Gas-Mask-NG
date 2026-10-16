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

#import "AbstractHostsController.h"
#import "Preferences.h"
#import "PrivilegedActions.h"
#import "FileUtil.h"
#import "Util.h"
#import "NetworkStatus.h"

@interface AbstractHostsController (Private)

- (void)updateGroupOnlineStatus:(NSNotification *)notification;

@end


@implementation AbstractHostsController

@synthesize hostsFiles;

-(id)init
{
	self = [super init];
	
	hostsFiles = [NSMutableArray new];
	hostsGroup = [[HostsGroup alloc] initWithName: [self groupName]];
	
	return self;
}

- (void)setDelegate:(NSObject<HostsControllerDelegateProtocol>*)delegateValue
{
	delegate = delegateValue;
}

- (NSString*)name
{
	return nil;
}

- (Hosts*)createHostsFromURL:(NSURL*)url
{
	return nil;
}

- (void)loadFiles
{}

- (HostsGroup*)hostsGroup
{
	return hostsGroup;
}

- (Hosts*)createNewHostsFile
{
	return nil;
}

- (Hosts*)createNewHostsFileWithContents:(NSString*)contents
{
	return nil;
}

- (Hosts*)createHostsFileWithName:(NSString*)name contents:(NSString*)contents
{
	return nil;
}

- (void)saveHosts:(Hosts*)hosts
{
    [self saveHosts:hosts allowAuthorization:NO];
}

- (void)saveHosts:(Hosts*)hosts allowAuthorization:(BOOL)interactive
{
    [hosts save];
    if (![hosts saved]) return;
    [hosts setExists:YES];
    if ([hosts active]) {
        // The cache is saved independently of system authorization. Pending
        // describes system state; it must not pretend the cache is unsaved.
        [self saveHostsFileToOriginalLocation:hosts allowAuthorization:interactive];
    }
    if ([hosts saved]) [[NSNotificationCenter defaultCenter] postNotificationName:HostsFileSavedNotification object:hosts];
}

- (BOOL)rename:(Hosts*)hosts to:(NSString*)name
{
    if (!name.length || [name isEqual:@"."] || [name isEqual:@".."] ||
        [name rangeOfString:@"/"].location != NSNotFound ||
        [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return NO;
	NSMutableString *newPath = [NSMutableString new];
	[newPath appendString:[[hosts path] stringByDeletingLastPathComponent]];
	[newPath appendString:@"/"];
	[newPath appendString:name];
	[newPath appendString:@"."];
	[newPath appendString:HostsFileExtension];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL success = [manager moveItemAtPath:[hosts path] toPath:newPath error:NULL];
	if (success) {
		logDebug(@"Moving file from \"%@\" to \"%@\"", [hosts path], newPath);
		[hosts setPath:newPath];
	}
	else {
		logDebug(@"Can't rename hosts file: \"%@\"", [hosts name]);
	}
	
	return success;
}

- (BOOL)restoreHostsToOriginalLocation:(Hosts*)hosts
{
    BOOL result = [self writeSystemContents:[hosts systemContentsOnDisk] allowAuthorization:NO];
    [hosts setSystemApplyPending:!result];
    return result;
}

- (Hosts*)activeHostsFile
{
	for (int i=0; i<[hostsFiles count]; i++) {
		Hosts *hosts = [hostsFiles objectAtIndex:i];
		if ([hosts active]) {
			return hosts;
		}
	}
	
	return nil;
}

- (void)removeHostsFile:(Hosts*)hosts moveToTrash:(BOOL)moveToTrash
{	
	if (moveToTrash) {
		logDebug(@"Moving hosts file to the trash: \"%@\"", [hosts name]);
		[FileUtil moveToTrash:[hosts path]];
	}
	else {
		logDebug(@"Removing hosts file: \"%@\"", [hosts name]);
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeItemAtPath:[hosts path] error:NULL];
	}
	
	[hostsFiles removeObject:hosts];
}

- (BOOL)activateHostsFile:(Hosts*)hosts
{
	BOOL saved = [self saveHostsFileToOriginalLocation:hosts allowAuthorization:YES];
	 if (!saved) {
		 logError(@"Failed to save hosts file: \"%@\"", [hosts name]);
		 return NO;
	 }
	 
	[hosts setActive:YES];
	[Preferences setActiveHostsFile:[hosts path]];

	return YES;
}

- (BOOL)hostsFileWithURLExists:(NSURL*)url
{
	return NO;
}

- (Hosts*)hostsFileByFileName:(NSString*)name
{
	for (Hosts *hosts in hostsFiles) {
		if ([[hosts fileName] isEqual:name]) {
			return hosts;
		}
	}
	return nil;
}

- (BOOL)canCreateHostsFromLocalURL:(NSURL*)url
{
	return NO;
}

- (BOOL)canCreateHostsFromURL:(NSURL*)url
{
	return NO;
}

- (Hosts*)createHostsFromLocalURL:(NSURL*)url
{
	return nil;
}

#pragma mark -
#pragma mark Protected

- (BOOL)hostsExists:(NSString*)name
{
	for (int i=0; i<[hostsFiles count]; i++) {
		if ([[[hostsFiles objectAtIndex:i] name] isEqualToString: name]) {
			return YES;
		}
	}
	return NO;
}

- (NSString*)generateName:(NSString*)prefix
{
	if (![self hostsExists:prefix]) {
		return prefix;
	}
	
	NSString *name;
	int i=2;
	while (YES) {
		NSMutableString *newName = [NSMutableString new];
		[newName appendString: prefix];
		[newName appendString: @" "];
		[newName appendString: [[NSNumber numberWithInt:i] stringValue]];
		
		if (![self hostsExists:newName]) {
			name = newName;
			break;
		}
		
		i++;
	}
	
	return name;
}

- (NSString*)constructPath:(NSString*)directory withName:(NSString*)name
{
	NSMutableString *path = [NSMutableString new];
	[path appendString:directory];
	[path appendString:name];
	[path appendString:@"."];
	[path appendString:HostsFileExtension];
	
	return path;
}

- (void)enableGroupOfflineBadge
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(updateGroupOnlineStatus:) name:NetworkStatusChangedNotification object:nil];
}

- (void)notifyDelegateNewHostsFileAdded:(Hosts*)hosts
{
	SEL selector = @selector(newHostsFileAdded:controller:);
	if (delegate && [delegate respondsToSelector:selector]) {
        SuppressPerformSelectorLeakWarning(
            [delegate performSelector:selector withObject:hosts withObject:self]);
	}
}

- (void)notifyDelegateHostsFileRemoved:(Hosts*)hosts
{
	SEL selector = @selector(hostsFileRemoved:controller:);
	if (delegate && [delegate respondsToSelector:selector]) {
        SuppressPerformSelectorLeakWarning(
            [delegate performSelector:selector withObject:hosts withObject:self]);
	}
}

// Overridable for fixture-based tests; production always writes the system hosts file.
- (NSString*)systemHostsFilePath
{
    return HostsFileLocation;
}

- (BOOL)writeSystemContents:(NSString*)text allowAuthorization:(BOOL)interactive
{
    if (!text) return NO;
    NSString *result = [text stringByAppendingString:@"\n\n"];
    NSError *error = nil;
    BOOL success;
    NSString *target = [self systemHostsFilePath];
    if (![target isEqualToString:HostsFileLocation] && ![target isEqualToString:@"/private/etc/hosts"]) {
        // Subclasses used by tests write only their temporary fixture target.
        success = [result writeToFile:target atomically:YES encoding:NSUTF8StringEncoding error:&error];
    } else {
        success = [PrivilegedActions writeHostsContents:result allowAuthorization:interactive error:&error];
    }
    if (!success && interactive && error.code != NSUserCancelledError) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"System Hosts Were Not Changed";
        alert.informativeText = error.localizedDescription ?: @"Activate again to approve this change.";
        [alert runModal];
    }
    if (success && [target isEqualToString:HostsFileLocation]) [Util flushDirectoryServiceCache];
    return success;
}

- (BOOL)saveHostsFileToOriginalLocation:(Hosts*)hosts
{
    return [self saveHostsFileToOriginalLocation:hosts allowAuthorization:NO];
}

- (BOOL)saveHostsFileToOriginalLocation:(Hosts*)hosts allowAuthorization:(BOOL)interactive
{
    NSString *requested = [[hosts contents] copy];
    BOOL result = [self writeSystemContents:requested allowAuthorization:interactive];
    // Administrator approval may run a nested event loop. A background download
    // can save a newer cache while this older snapshot is being authorized.
    [hosts setSystemApplyPending:!result || ![requested isEqualToString:[hosts contents]]];
    return result;
}

- (NSString*)groupName
{
	return nil;
}

@end

@implementation AbstractHostsController (Private)

- (void)updateGroupOnlineStatus:(NSNotification *)notification
{
	BOOL online = [(NetworkStatus*)[notification object] reachable];
	[hostsGroup setOnline:online];
}

@end

