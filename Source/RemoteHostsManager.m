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

#import "RemoteHostsManager.h"
#import "RemoteHosts.h"
#import "Preferences+Remote.h"
#import "Network.h"
#import "NetworkStatus.h"
#import "Error.h"
#import "NotificationHelper.h"

#define URLKey @"url"
#define UpdatedKey @"updated"
#define LastModifiedKey @"lastModified"

@interface RemoteHostsManager (Private)

- (void)saveRemoteHostsProperties;
- (void)startTimer;
- (void)update;
- (void)downloadHosts:(RemoteHosts*)hosts;
- (void)updateByNotification;
- (void)changeTimerState:(NSNotification *)notification;
- (void)changeTimerInterval;
- (BOOL)haveNonExistingHostsFiles;
- (IBAction)hostsFileRenamed:(NSNotification *)notification;

@end


@implementation RemoteHostsManager

- (id)initWithHostsController:(NSObject<HostsControllerProtocol>*)hostsControllerValue
{
	self = [super initWithHostsController:hostsControllerValue];
	firstUpdate = YES;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(hostsFileRenamed:) name:HostsFileRenamedNotification object:nil];
	
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	[self changeTimerInterval];
}

- (void)loadRemoteHostsProperties
{
	logDebug(@"Loading remote hosts properties");
	
	NSDictionary *properties = [Preferences remoteHostsFilesProperties];
	
	NSArray *hostsFiles = [hostsController hostsFiles];
	for (RemoteHosts *hosts in hostsFiles) {
		
		NSDictionary *dict = [properties objectForKey:[hosts name]];
		NSString *source = [dict valueForKey:URLKey];
        [hosts setUrl:[source isKindOfClass:NSString.class] ? [NSURL URLWithString:source] : nil];
		[hosts setUpdated:(NSDate*)[dict valueForKey:UpdatedKey]];
		
		NSString *lastModified = [dict valueForKey:LastModifiedKey];
		if (lastModified) {
			[hosts setLastModified:lastModified];
		}
	}
}

- (void)startUpdater
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(changeTimerState:) name:NetworkStatusChangedNotification object:nil];
	[nc addObserver:self selector:@selector(updateByNotification) name:UpdateAndSynchronizeNotification object:nil];
	
	[[Preferences instance] addObserver:self
							 forKeyPath:RemoteHostsUpdateIntervalValuesKey
								options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
								context:NULL];
	
	if ([[hostsController hostsFiles] count] == 0) {
		return;
	}
	
	// Application is re-opened, there is no need for
	// immediate update 
	if (reopened()) {
		[self startTimer];
	}
	else {
		[self update];
	}
}

#pragma mark -
#pragma mark Override

- (BOOL)updateHosts:(RemoteHosts*)hosts
{
    // Context-menu refresh targets this exact managed object, independent of
    // editor selection. Share the normal downloader/save/notification lifecycle.
    if (!hosts || ![hosts url] ||
        [[hostsController hostsFiles] indexOfObjectIdenticalTo:hosts] == NSNotFound ||
        [self numberOfDownloaders] > 0 || ![[Network defaultInstance] online]) {
        return NO;
    }
    [timer invalidate];
    timer = nil;
    firstUpdate = NO;
    [self downloadHosts:hosts];
    return YES;
}

- (void)hostsDownloaded:(HostsDownloader*)downloader
{
    [self decreaseActiveDownloadsCount];
    RemoteHosts *hosts = (RemoteHosts*)downloader.hosts;
    NSString *previous = [hosts contents];
    NSString *previousModified = hosts.lastModified;
    BOOL existed = hosts.exists;
    [hosts setEnabled:YES];
    [hosts setContents:downloader.response];
    hosts.lastModified = downloader.lastModified;
    [hostsController saveHosts:hosts];
    if ([hosts saved]) {
        [hosts setError:nil];
        hosts.updated = NSDate.date;
        if (!downloader.initialLoad) [NotificationHelper notify:@"Hosts File Updated" message:hosts.name];
    } else {
        [hosts setContents:previous];
        [hosts setSaved:existed];
        hosts.lastModified = previousModified;
        Error *failure = [[Error alloc] initWithType:FailedToDownload];
        failure.description = @"The validated download could not be saved. The previous cache and successful-update time were retained.";
        [hosts setError:failure];
    }
    [self removeDownloader:downloader];
    [self saveRemoteHostsProperties];
}

- (void)hostsUpToDate:(HostsDownloader*)downloader
{
    // A successful check is useful even when no content changed. Keep the
    // existing persisted key so older profiles retain their update history.
    RemoteHosts *hosts = (RemoteHosts*)[downloader hosts];
    [hosts setUpdated:[NSDate date]];
    [hosts setLastModified:[downloader lastModified]];
    [self saveRemoteHostsProperties];
    [super hostsUpToDate:downloader];
}

- (void)removeDownloader:(HostsDownloader*)downloader
{
	[super removeDownloader:downloader];
	if ([self numberOfDownloaders] == 0) {
		[self startTimer];
	}
}

@end

@implementation RemoteHostsManager (Private)

- (void)saveRemoteHostsProperties
{
	logDebug(@"Saving remote hosts properties");
	
	NSMutableDictionary *properties = [NSMutableDictionary new];
	
	NSArray *hostsFiles = [hostsController hostsFiles];
	for (RemoteHosts *hosts in hostsFiles) {
		NSMutableDictionary *dict = [NSMutableDictionary new];
		
		[dict setValue:[[hosts url] description] forKey:URLKey];
		[dict setValue:[hosts updated] forKey:UpdatedKey];
		
		if ([hosts lastModified]) {
			[dict setValue:[hosts lastModified] forKey:LastModifiedKey];
		}
		
		[properties setObject:dict forKey:[hosts name]];
	}

	
	[Preferences setRemoteHostsFilesProperties:properties];
}

- (void)startTimer
{	
    if ([self numberOfDownloaders] > 0 || [[hostsController hostsFiles] count] == 0 ||
        ![[Network defaultInstance] online]) { return; }
	if(timer != nil && [timer isValid]) {
		return;
	}
	
	int interval = [Preferences remoteHostsUpdateInterval];
	logDebug(@"Starting timer for remote hosts files. Interval: %d minutes", interval);
	
    timer = [NSTimer timerWithTimeInterval:60.0 * MAX(1, interval) target:self selector:@selector(update) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)update
{
    [timer invalidate];
	timer = nil;
	
	if (![[Network defaultInstance] online]) {
		logDebug(@"Can't start updater, network connection is down");
		return;
	}
	if ([self numberOfDownloaders] > 0) {
		logDebug(@"Can't start updater, there are %d active download(s)", [self numberOfDownloaders]);
		return;
	}
	
	firstUpdate = NO;
	
	logInfo(@"Starting updater");
	
	NSArray *files = [hostsController hostsFiles];
	
	for (RemoteHosts *hosts in files) {
		logDebug(@"Searching updates for \"%@\"", [hosts name]);
		
        [self downloadHosts:hosts];
	}
}

- (void)downloadHosts:(RemoteHosts*)hosts
{
    HostsDownloader *downloader = [self makeDownloaderForHosts:hosts url:[hosts url]];
    [self addDownloader:downloader];
    [downloader setDelegate:self];
    [downloader download];
}

- (void)updateByNotification
{
	logDebug(@"Updating remote hosts");
	if ([self numberOfDownloaders] > 0) {
		return;
	}
		
	if ([timer isValid]) {
		logDebug(@"Invalidating");
		[timer invalidate];
		timer = nil;
	}
	[self update];
}

- (void)changeTimerState:(NSNotification *)notification
{
	BOOL online = [(NetworkStatus*)[notification object] reachable];
	
	if (online) {
		if (firstUpdate || [self haveNonExistingHostsFiles]) {
			[self update];
		}
		else {
			[self startTimer];
		}
	}
	else if ([timer isValid]) {
		[timer invalidate];
		timer = nil;
	}
}

- (void)changeTimerInterval
{
    [timer invalidate];
    timer = nil;
    [self startTimer];
}

- (BOOL)haveNonExistingHostsFiles
{
	NSArray *hostsFiles = [hostsController hostsFiles];
	for (int i=0; i<[hostsFiles count]; i++) {
		Hosts *hosts = [hostsFiles objectAtIndex:i];
		if (![hosts exists]) {
			return YES;
		}
	}
	
	return NO;
}

- (IBAction)hostsFileRenamed:(NSNotification *)notification
{
    Hosts *renamedHosts = [notification object];

    for (RemoteHosts *hosts in [hostsController hostsFiles]) {
        if ([hosts isEqualTo:renamedHosts]) {
            [self saveRemoteHostsProperties];
            break;
        }
    }
}

@end
