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

#import "CombinedHosts.h"
#import "HostsMainController.h"

@interface CombinedHosts (Private)

- (void)populateContentsWithFiles;

@end

@implementation CombinedHosts

- (id)initWithPath:(NSString*)pathValue allHostsFiles:(NSArray*)allHosts
{
    self = [super initWithPath:pathValue];
    [self setEditable:NO];
    files = [NSMutableArray new];
    
    NSString *data = [self contentsOnDisk];
    NSArray *lines = [data componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSArray *parts = [line componentsSeparatedByString:@"/"];
        if ([parts count] == 2) {
            NSString *type = [parts objectAtIndex:0];
            NSString *name = [parts objectAtIndex:1];
            logDebug(@"Type: %@, name: %@", type, name);
            
            for (Hosts *hosts in allHosts) {
                if ([[hosts type] isEqualTo:type] && [[hosts name] isEqualTo:name]) {
                    [files addObject:hosts];
                    break;
                }
            }
        }
    }
    
    return self;
}

- (void)setHostsFiles:(NSArray*)hostsFiles
{
    files = [NSMutableArray arrayWithArray:hostsFiles];
    [self populateContentsWithFiles];
    [self setSaved:NO];
}

- (void)removeHostsFile:(Hosts*)file
{
    [files removeObject:file];
    [self populateContentsWithFiles];
}

- (void)hostsFileRenamed:(Hosts*)file
{
    [self populateContentsWithFiles];
}

- (void)hostsFileSaved:(Hosts*)file
{
    [self populateContentsWithFiles];
}

- (NSArray*)hostsFiles
{
    return files;
}

-(NSString *)contents
{
	if (contents == nil) {
		[self populateContentsWithFiles];
	}
	if (contents == nil) {
		contents = @"";
	}
	return contents;
}

- (void) save
{
    NSMutableString *data = [NSMutableString new];
    for (Hosts *hosts in files) {
        [data appendFormat:@"%@/%@\n", [hosts type], [hosts name]];
    }
    
    BOOL success = [data writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [self setSaved:success];
}

- (NSString*)systemContentsOnDisk
{
    // The .hst file stores source references, not hosts mappings. Restore the
    // saved composition and saved source text, never an unsaved editor buffer.
    NSArray *candidates = [[[HostsMainController defaultInstance] allHostsFiles] arrayByAddingObjectsFromArray:files] ?: files;
    NSMutableString *result = [NSMutableString new];
    for (NSString *reference in [[super contentsOnDisk] componentsSeparatedByString:@"\n"]) {
        if (!reference.length) continue;
        NSArray *parts = [reference componentsSeparatedByString:@"/"];
        if (parts.count != 2) return nil;
        Hosts *found = nil;
        for (Hosts *source in candidates) {
            if (![source isKindOfClass:CombinedHosts.class] && [[source type] isEqual:parts[0]] && [[source name] isEqual:parts[1]]) { found = source; break; }
        }
        NSString *text = [found contentsOnDisk];
        if (!text) return nil;
        [result appendFormat:@"# Hosts File: %@\n\n%@\n\n", [found name], text];
    }
    return result;
}

- (NSString*)type
{
	return @"Combined";
}

@end

@implementation CombinedHosts (Private)

- (void)populateContentsWithFiles
{
    NSMutableString *result = [NSMutableString new];
    for (Hosts *hosts in files) {
        [result appendFormat:@"# Hosts File: %@\n\n", [hosts name]];
        [result appendString:[hosts contents]];
        [result appendString:@"\n\n"];
    }
    [self setContents:result];
    [self setSaved:YES];
}

@end
