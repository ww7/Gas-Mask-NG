/***************************************************************************
 *   Copyright (C) 2009-2012 by Clockwise   *
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

#import "FileUtil.h"
#import "Preferences.h"

static NSString *dataDirectory = nil;

@interface FileUtil (Migration)
+ (NSString *)dataDirectoryForLibraryDirectory:(NSString *)library defaults:(NSUserDefaults *)defaults;
@end

@implementation FileUtil

+ (NSString*)dataDirectory
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
		dataDirectory = [self dataDirectoryForLibraryDirectory:library defaults:NSUserDefaults.standardUserDefaults];
	});
	return dataDirectory;
}

// Accept a library root and defaults store so migration can be verified in isolation.
+ (NSString *)dataDirectoryForLibraryDirectory:(NSString *)library defaults:(NSUserDefaults *)defaults
{
	NSString *legacy = [[library stringByAppendingPathComponent:@"Gas Mask"] stringByAppendingString:@"/"];
	NSString *destination = [[library stringByAppendingPathComponent:@"Application Support/Gas Mask"] stringByAppendingString:@"/"];
	NSFileManager *manager = NSFileManager.defaultManager;
	BOOL legacyIsDirectory = NO;
	if (![manager fileExistsAtPath:legacy isDirectory:&legacyIsDirectory] || !legacyIsDirectory) {
		return destination;
	}

	NSString *activePath = [defaults stringForKey:ActiveHostsFilePrefKey];
	NSString *migrationKey = @"ww7ApplicationSupportMigrationCompleted";
	BOOL destinationIsDirectory = NO;
	if ([manager fileExistsAtPath:destination isDirectory:&destinationIsDirectory]) {
		if (destinationIsDirectory && ([defaults boolForKey:migrationKey] || [activePath hasPrefix:destination])) {
			return destination;
		}
		logWarn(@"Both data locations exist; keeping legacy profiles until the conflict is resolved.");
		return legacy;
	}

	NSString *parent = [library stringByAppendingPathComponent:@"Application Support"];
	NSString *staging = [parent stringByAppendingPathComponent:
		[@".Gas Mask-migration-" stringByAppendingString:NSUUID.UUID.UUIDString]];
	NSError *error = nil;
	BOOL copied = [manager createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:&error]
		&& [manager copyItemAtPath:legacy.stringByStandardizingPath toPath:staging error:&error]
		&& [manager moveItemAtPath:staging toPath:destination.stringByStandardizingPath error:&error];
	if (!copied) {
		[manager removeItemAtPath:staging error:nil];
		logError(@"Cannot copy profiles to Application Support; continuing with legacy data: %@", error);
		return legacy;
	}

	if ([activePath hasPrefix:legacy]) {
		[defaults setObject:[destination stringByAppendingString:[activePath substringFromIndex:legacy.length]]
			forKey:ActiveHostsFilePrefKey];
	}
	[defaults setBool:YES forKey:migrationKey];
	logInfo(@"Copied profiles to Application Support. Original profiles remain at %@", legacy);
	return destination;
}

+ (NSString*)localHostFilesDirectory
{
	return [[FileUtil dataDirectory] stringByAppendingString:@"Local/"];
}

+ (NSString*)remoteHostFilesDirectory
{
	return [[FileUtil dataDirectory] stringByAppendingString:@"Remote/"];
}

+ (NSString*) combinedHostsFilesDirectory
{
    return [[FileUtil dataDirectory] stringByAppendingString:@"Combined/"];
}

+ (BOOL)moveToTrash:(NSString *)path
{
	NSError *error = nil;
	BOOL moved = [NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:path]
		resultingItemURL:nil error:&error];
	if (!moved) {
		logError(@"Cannot move file to Trash: %@ (%@)", path, error);
	}
	return moved;
}

@end
