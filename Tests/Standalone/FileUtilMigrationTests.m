#import <Cocoa/Cocoa.h>
#import "FileUtil.h"
#import "Preferences.h"

@interface FileUtil (MigrationTests)
+ (NSString *)dataDirectoryForLibraryDirectory:(NSString *)library defaults:(NSUserDefaults *)defaults;
@end

// Keep the standalone executable independent of the application and its logging setup.
void privateLogDebug(NSString *format, const char *method, ...) {}
void privateLogInfo(NSString *format, const char *method, ...) {}
void privateLogWarn(NSString *format, const char *method, ...) {}
void privateLogError(NSString *format, const char *method, ...) {}

static NSUInteger assertions = 0;
static void expect(BOOL condition, NSString *message)
{
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message.UTF8String);
        exit(1);
    }
}

static void writeFile(NSString *path, NSString *contents)
{
    NSError *error = nil;
    expect([NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:&error], @"create fixture directory");
    expect([contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error], @"write fixture");
}

static NSString *readFile(NSString *path)
{
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

int main(void)
{
    @autoreleasepool {
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [@"gasmask-migration-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        NSString *suite = [@"work.ww7.gasmask.migration-tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSFileManager *manager = NSFileManager.defaultManager;
        NSString *library = [root stringByAppendingPathComponent:@"Library"];
        NSString *legacy = [library stringByAppendingString:@"/Gas Mask/"];
        NSString *destination = [library stringByAppendingString:@"/Application Support/Gas Mask/"];

        expect([[FileUtil dataDirectoryForLibraryDirectory:library defaults:defaults] isEqual:destination], @"fresh installs use Application Support");
        NSString *local = @"Local/Original File.hst";
        NSString *remote = @"Remote/Remote.hst";
        NSString *combined = @"Combined/Combined.hst";
        writeFile([legacy stringByAppendingString:local], @"127.0.0.1 localhost\n");
        writeFile([legacy stringByAppendingString:remote], @"0.0.0.0 example.test\n");
        writeFile([legacy stringByAppendingString:combined], @"Local/Original File\nRemote/Remote\n");
        [defaults setObject:[legacy stringByAppendingString:remote] forKey:ActiveHostsFilePrefKey];
        NSDictionary *remoteMetadata = @{@"Remote": @{@"url": @"https://example.test/hosts", @"lastModified": @"yesterday"}};
        [defaults setObject:remoteMetadata forKey:@"remoteHostsFiles"];
        expect([[FileUtil dataDirectoryForLibraryDirectory:library defaults:defaults] isEqual:destination], @"legacy profiles migrate");
        for (NSString *relative in @[local, remote, combined]) {
            expect([readFile([legacy stringByAppendingString:relative]) isEqual:readFile([destination stringByAppendingString:relative])], @"all profile bytes are copied and originals retained");
        }
        expect([[defaults stringForKey:ActiveHostsFilePrefKey] isEqual:[destination stringByAppendingString:remote]], @"active profile path is rebased");
        expect([[defaults dictionaryForKey:@"remoteHostsFiles"] isEqual:remoteMetadata], @"remote URLs and metadata remain unchanged");
        writeFile([destination stringByAppendingString:local], @"updated profile\n");
        expect([[FileUtil dataDirectoryForLibraryDirectory:library defaults:defaults] isEqual:destination], @"subsequent launches use migrated data");
        expect([readFile([destination stringByAppendingString:local]) isEqual:@"updated profile\n"], @"migration never overwrites edits on a later launch");

        [defaults removePersistentDomainForName:suite];
        [defaults setObject:[legacy stringByAppendingString:local] forKey:ActiveHostsFilePrefKey];
        expect([[FileUtil dataDirectoryForLibraryDirectory:library defaults:defaults] isEqual:legacy], @"conflicting directories keep the legacy active profile");
        expect([readFile([destination stringByAppendingString:local]) isEqual:@"updated profile\n"], @"conflicts never overwrite destination files");
        [defaults setObject:[destination stringByAppendingString:local] forKey:ActiveHostsFilePrefKey];
        expect([[FileUtil dataDirectoryForLibraryDirectory:library defaults:defaults] isEqual:destination], @"an existing active destination remains authoritative");

        library = [root stringByAppendingPathComponent:@"BlockedLibrary"];
        legacy = [library stringByAppendingString:@"/Gas Mask/"];
        writeFile([legacy stringByAppendingString:local], @"keep me\n");
        writeFile([library stringByAppendingPathComponent:@"Application Support"], @"blocking file");
        [defaults setObject:[legacy stringByAppendingString:local] forKey:ActiveHostsFilePrefKey];
        expect([[FileUtil dataDirectoryForLibraryDirectory:library defaults:defaults] isEqual:legacy], @"copy failure falls back to legacy profiles");
        expect([[defaults stringForKey:ActiveHostsFilePrefKey] isEqual:[legacy stringByAppendingString:local]], @"failed migration preserves active path");
        expect([readFile([legacy stringByAppendingString:local]) isEqual:@"keep me\n"], @"failed migration preserves original bytes");

        [defaults removePersistentDomainForName:suite];
        expect([manager removeItemAtPath:root error:nil], @"remove only this test's temporary fixtures");
        printf("PASS: %lu storage migration assertions\n", (unsigned long)assertions);
    }
    return 0;
}
