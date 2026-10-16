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

#import "HostsDownloader.h"
#import "RemoteHosts.h"
#import "Hosts.h"
#import "Error.h"
#import <arpa/inet.h>

static const NSUInteger GMMaximumDownloadBytes = 32 * 1024 * 1024;

@implementation HostsDownloader
@synthesize hosts, response, lastModified, error, initialLoad;

+ (NSUInteger)maximumDownloadBytes { return GMMaximumDownloadBytes; }

+ (BOOL)isAllowedURL:(NSURL*)value
{
    if (!value) return NO;
    NSURLComponents *parts = [NSURLComponents componentsWithURL:value resolvingAgainstBaseURL:NO];
    return parts && [parts.scheme.lowercaseString isEqualToString:@"https"] &&
        parts.host.length > 0 && !parts.user && !parts.password && !parts.fragment &&
        (!parts.port || (parts.port.integerValue > 0 && parts.port.integerValue <= 65535));
}

- (id)initWithHosts:(Hosts*)value url:(NSURL*)source
{
    return [self initWithHosts:value url:source sessionConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
}

- (id)initWithHosts:(Hosts*)value url:(NSURL*)source sessionConfiguration:(NSURLSessionConfiguration*)config
{
    self = [super init];
    if (self) { hosts = value; url = source; configuration = [config copy]; }
    return self;
}

- (void)setDelegate:(NSObject<HostsDownloaderDelegate>*)value { delegate = value; }

- (void)download
{
    NSAssert([NSThread isMainThread], @"Model access starts on the main thread");
    [delegate hostsDownloadingStarted:self];
    if (![[self class] isAllowedURL:url]) {
        [self fail:@"Remote sources must use HTTPS, with a host and no embedded credentials or fragment."];
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    request.HTTPMethod = @"GET";
    [request setValue:@"text/plain, application/octet-stream;q=0.8" forHTTPHeaderField:@"Accept"];
    NSString *modified = [hosts isKindOfClass:[RemoteHosts class]] ? [(RemoteHosts*)hosts lastModified] : nil;
    if (modified.length > 0 && modified.length <= 256 &&
        [modified rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location == NSNotFound &&
        [[NSFileManager defaultManager] fileExistsAtPath:hosts.path]) {
        [request setValue:modified forHTTPHeaderField:@"If-Modified-Since"];
        sentConditional = YES;
        lastModified = modified;
    }
    configuration.URLCache = nil;
    configuration.HTTPCookieStorage = nil;
    configuration.URLCredentialStorage = nil;
    configuration.HTTPShouldSetCookies = NO;
    configuration.timeoutIntervalForRequest = 30;
    configuration.timeoutIntervalForResource = 90;
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    queue.qualityOfService = NSQualityOfServiceUserInitiated;
    receivedData = [NSMutableData new];
    session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    [[session dataTaskWithRequest:request] resume];
}

- (BOOL)sameOrigin:(NSURL*)candidate
{
    NSInteger a = url.port ? url.port.integerValue : 443;
    NSInteger b = candidate.port ? candidate.port.integerValue : 443;
    return [[self class] isAllowedURL:candidate] &&
        [candidate.host caseInsensitiveCompare:url.host] == NSOrderedSame && a == b;
}

- (void)URLSession:(NSURLSession*)sender task:(NSURLSessionTask*)task
    willPerformHTTPRedirection:(NSHTTPURLResponse*)redirect newRequest:(NSURLRequest*)request
    completionHandler:(void (^)(NSURLRequest*))completion
{
    if (++redirects > 5 || ![self sameOrigin:request.URL]) {
        completion(nil);
        [self fail:@"The redirect was blocked. Use the final HTTPS URL; redirects must stay on the original host and port (maximum five)."];
    } else {
        NSMutableURLRequest *next = [request mutableCopy];
        next.HTTPMethod = @"GET";
        next.HTTPShouldHandleCookies = NO;
        [next setValue:nil forHTTPHeaderField:@"Authorization"];
        completion(next);
    }
}

- (void)URLSession:(NSURLSession*)sender dataTask:(NSURLSessionDataTask*)task
    didReceiveResponse:(NSURLResponse*)reply completionHandler:(void (^)(NSURLSessionResponseDisposition))completion
{
    if (finished) { completion(NSURLSessionResponseCancel); return; }
    if (![reply isKindOfClass:[NSHTTPURLResponse class]] || ![self sameOrigin:reply.URL]) {
        completion(NSURLSessionResponseCancel); [self fail:@"Invalid or insecure HTTP response."]; return;
    }
    httpResponse = (NSHTTPURLResponse*)reply;
    NSInteger status = httpResponse.statusCode;
    if (status == 304 && sentConditional) {
        upToDate = YES;
        completion(NSURLSessionResponseAllow);
        return;
    }
    NSString *mime = reply.MIMEType.lowercaseString;
    if (status != 200 || reply.expectedContentLength > (int64_t)GMMaximumDownloadBytes ||
        !([mime isEqualToString:@"text/plain"] || [mime isEqualToString:@"application/octet-stream"])) {
        completion(NSURLSessionResponseCancel);
        [self fail:status != 200 ? @"The server did not return a hosts file (HTTP 200 required, or a conditional 304)." :
            @"The response must be plain text and no larger than 32 MiB."];
        return;
    }
    completion(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession*)sender dataTask:(NSURLSessionDataTask*)task didReceiveData:(NSData*)data
{
    if (finished) { return; }
    if (upToDate || data.length > GMMaximumDownloadBytes - receivedData.length) {
        [self fail:@"The response exceeded the 32 MiB limit or included an invalid 304 body."];
        return;
    }
    [receivedData appendData:data];
}

+ (BOOL)isHostsText:(NSString*)text
{
    if (!text.length || [text rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound) { return NO; }
    __block BOOL valid = YES;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByLines
        usingBlock:^(NSString *line, NSRange range, NSRange enclosingRange, BOOL *stop) {
            if ([line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 65536) { valid = NO; *stop = YES; return; }
            NSString *body = [[line componentsSeparatedByString:@"#"] firstObject];
            NSArray *words = [[body componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *word, NSDictionary *bindings) { return word.length > 0; }]];
            if (words.count == 0) { return; }
            struct in6_addr address;
            const char *ip = [words[0] UTF8String];
            if (words.count < 2 || (inet_pton(AF_INET, ip, &address) != 1 && inet_pton(AF_INET6, ip, &address) != 1)) {
                valid = NO; *stop = YES;
            }
            NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"] invertedSet];
            for (NSString *name in [words subarrayWithRange:NSMakeRange(MIN((NSUInteger)1, words.count), words.count > 0 ? words.count-1 : 0)]) {
                if (name.length > 253 || [name rangeOfCharacterFromSet:invalid].location != NSNotFound) { valid = NO; *stop = YES; break; }
                NSString *absolute = [name hasSuffix:@"."] ? [name substringToIndex:name.length-1] : name;
                for (NSString *label in [absolute componentsSeparatedByString:@"."]) {
                    if (!label.length || label.length > 63) { valid = NO; *stop = YES; break; }
                }
            }
        }];
    return valid;
}

- (void)URLSession:(NSURLSession*)sender task:(NSURLSessionTask*)task didCompleteWithError:(NSError*)failure
{
    if (finished) { return; }
    if (failure || !httpResponse) { [self fail:@"The HTTPS download failed. The previous successful file was retained."]; return; }
    lastModified = [httpResponse valueForHTTPHeaderField:@"Last-Modified"] ?: (upToDate ? lastModified : nil);
    NSString *text = upToDate ? nil : [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    if ([text hasPrefix:@"\uFEFF"]) { text = [text substringFromIndex:1]; }
    if (!upToDate && ![[self class] isHostsText:text]) {
        [self fail:@"The response is not a valid UTF-8 hosts file (mappings/comments only, no NUL bytes, maximum 64 KiB per line)."];
        return;
    }
    response = [text mutableCopy];
    finished = YES;
    [session finishTasksAndInvalidate];
    session = nil;
    receivedData = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (upToDate || [response isEqualToString:[hosts contents]]) { [delegate hostsUpToDate:self]; }
        else { [delegate hostsDownloaded:self]; }
    });
}

- (void)fail:(NSString*)message
{
    if (finished) { return; }
    finished = YES;
    error = [[Error alloc] initWithType:FailedToDownload];
    [error setDescription:message];
    // The source URL may contain a token in its query. Do not copy it into logs
    // or error URLs; the owner can inspect the source in the profile itself.
    [session invalidateAndCancel];
    session = nil;
    receivedData = nil;
    dispatch_async(dispatch_get_main_queue(), ^{ [delegate hostsDownloadFailed:self]; });
}
@end
