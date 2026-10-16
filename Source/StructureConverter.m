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

#import "StructureConverter.h"
#import <sys/stat.h>
#import "PrivilegedActions.h"
#import "FileUtil.h"
#import "Preferences.h"

#define Version04DataDirectory @"/etc/gasmask/"
#define HostsOriginalLocation @"/etc/hosts"

@interface StructureConverter(Private)
- (BOOL)isVersion04Structure;
- (BOOL)isOriginalStructure;
- (void)copy04FilesToDataDirectory;
- (void)createDataFolders;
- (void)createDataFolder:(NSString*)path;
- (void)copyOriginalHostsFileToDataDirectory;
@end

@implementation StructureConverter

- (id)init
{
	self = [super init];
	return self;
}

- (void)convertToCurrent
{
	BOOL originalStructure = [self isOriginalStructure];
	
	[self createDataFolders];
	
	if ([self isVersion04Structure]) {
		logDebug(@"Has version 0.4 structure");
		
        [self copy04FilesToDataDirectory];
        if (originalStructure) [self copyOriginalHostsFileToDataDirectory];
        // Legacy /etc/gasmask and any system symlink are left untouched.
        // Activation requires a regular root-owned hosts file; repair an old
        // system symlink manually instead of issuing generic root commands.

	}
	else if (originalStructure) {
		logDebug(@"Original structure");
		[self copyOriginalHostsFileToDataDirectory];
	}
}

@end

@implementation StructureConverter(Private)

- (BOOL)isVersion04Structure
{
	NSFileManager *manager = [NSFileManager defaultManager];
	return [manager fileExistsAtPath:Version04DataDirectory];
}

- (BOOL)isOriginalStructure
{
	NSFileManager *manager = [NSFileManager defaultManager];
	return ![manager fileExistsAtPath:[FileUtil dataDirectory]];
}

- (void)copy04FilesToDataDirectory
{
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *file in [manager contentsOfDirectoryAtPath:Version04DataDirectory error:nil]) {
        NSString *source = [Version04DataDirectory stringByAppendingPathComponent:file];
        struct stat info;
        if (lstat(source.fileSystemRepresentation, &info) || !S_ISREG(info.st_mode) || info.st_nlink != 1 || info.st_size > 32*1024*1024) continue;
        NSString *destination = [[[FileUtil localHostFilesDirectory] stringByAppendingPathComponent:file] stringByAppendingPathExtension:HostsFileExtension];
        // copyItem refuses to overwrite existing profiles on subsequent launches.
        [manager copyItemAtPath:source toPath:destination error:nil];
    }
}

- (void)createDataFolders
{	
	[self createDataFolder:[FileUtil localHostFilesDirectory]];
	[self createDataFolder:[FileUtil remoteHostFilesDirectory]];
    [self createDataFolder:[FileUtil combinedHostsFilesDirectory]];
}

- (void)createDataFolder:(NSString*)path
{
	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager fileExistsAtPath:path]) {
		logDebug(@"Creating directory \"%@\"", path);
		[manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	}
}

- (void)copyOriginalHostsFileToDataDirectory
{
	NSMutableString *destination = [NSMutableString new];
	[destination appendString:[FileUtil localHostFilesDirectory]];
	[destination appendString:@"Original File."];
	[destination appendString:HostsFileExtension];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	if ([manager fileExistsAtPath:destination]) return;
    NSString *text = [PrivilegedActions currentSystemContents];
    if (!text || ![text writeToFile:destination atomically:YES encoding:NSUTF8StringEncoding error:nil]) return;
	
	[Preferences setActiveHostsFile:destination];
}

@end
