#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>

/// Callback type: receives an array of resolved file paths.
typedef void (*FilePromiseCallback)(const char *const *paths, int count, void *context);

/// Context for FSEventStream watcher.
typedef struct {
    FSEventStreamRef stream;
    CFRunLoopRef runLoop;
    NSString *watchDir;
    NSSet<NSString *> *existingFiles;
    NSInteger expectedCount;
    FilePromiseCallback callback;
    void *callbackContext;
    BOOL emitted;
} WatchContext;

static void fsevents_callback(ConstFSEventStreamRef, void *, size_t, void *,
                               const FSEventStreamEventFlags[],
                               const FSEventStreamEventId[]);
static void safety_timer_fired(CFRunLoopTimerRef, void *);
static void emit_new_files(WatchContext *);
static void cleanup_watch(WatchContext *);

/// Resolve file promises from a drag pasteboard.
/// Watches the destination directory with FSEventStream for new .eml/.msg files.
void resolve_file_promises(
    id pasteboard,
    const char *dest_dir_path,
    FilePromiseCallback callback,
    void *context
) {
    NSArray<NSFilePromiseReceiver *> *receivers =
        [pasteboard readObjectsForClasses:@[[NSFilePromiseReceiver class]]
                                  options:@{}];

    if (!receivers || receivers.count == 0) {
        callback(NULL, 0, context);
        return;
    }

    NSString *dirPath = @(dest_dir_path);
    NSURL *destURL = [NSURL fileURLWithPath:dirPath];

    // Snapshot existing files.
    NSArray<NSString *> *existing = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:dirPath error:nil];
    NSSet<NSString *> *existingSet = existing
        ? [NSSet setWithArray:existing]
        : [NSSet set];

    NSLog(@"[objc_helper] existing: %lu, receivers: %lu",
          (unsigned long)existingSet.count, (unsigned long)receivers.count);

    // Set up watch context.
    WatchContext *ctx = (WatchContext *)calloc(1, sizeof(WatchContext));
    ctx->watchDir = dirPath;
    ctx->existingFiles = existingSet;
    ctx->expectedCount = (NSInteger)receivers.count;
    ctx->callback = callback;
    ctx->callbackContext = context;
    ctx->emitted = NO;

    // Create FSEventStream.
    CFArrayRef pathsToWatch = (__bridge CFArrayRef)@[dirPath];
    FSEventStreamContext streamCtx = {0, ctx, NULL, NULL, NULL};

    ctx->stream = FSEventStreamCreate(
        NULL, &fsevents_callback, &streamCtx, pathsToWatch,
        kFSEventStreamEventIdSinceNow, 0.1,
        kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes);

    // Run on a dedicated thread with its own run loop.
    NSThread *thread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            ctx->runLoop = CFRunLoopGetCurrent();
            FSEventStreamScheduleWithRunLoop(
                ctx->stream, ctx->runLoop, kCFRunLoopDefaultMode);
            FSEventStreamStart(ctx->stream);

            // Safety timeout: 10 seconds.
            CFRunLoopTimerContext tCtx = {0, ctx, NULL, NULL, NULL};
            CFRunLoopTimerRef timer = CFRunLoopTimerCreate(
                NULL, CFAbsoluteTimeGetCurrent() + 10.0,
                0, 0, 0, &safety_timer_fired, &tCtx);
            CFRunLoopAddTimer(ctx->runLoop, timer, kCFRunLoopDefaultMode);
            CFRelease(timer);

            CFRunLoopRun();
        }
    }];
    thread.name = @"jp.nlink.mail-analyzer-gui.fswatch";
    [thread start];

    // Trigger promise resolution (Apple Mail writes files to destURL).
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    for (NSFilePromiseReceiver *receiver in receivers) {
        [receiver receivePromisedFilesAtDestination:destURL
                                            options:@{}
                                     operationQueue:queue
                                             reader:^(NSURL *fileURL, NSError *error) {
            // Apple Mail bug: this may not be called. FSEventStream handles it.
            if (error) {
                NSLog(@"[objc_helper] reader error (non-critical): %@",
                      error.localizedDescription);
            }
        }];
    }
}

/// FSEventStream callback.
static void fsevents_callback(
    ConstFSEventStreamRef streamRef, void *clientInfo,
    size_t numEvents, void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[]
) {
    WatchContext *ctx = (WatchContext *)clientInfo;
    if (ctx->emitted) return;

    NSLog(@"[objc_helper] fsevents: %zu events", numEvents);
    emit_new_files(ctx);
}

/// Safety timeout.
static void safety_timer_fired(CFRunLoopTimerRef timer, void *info) {
    WatchContext *ctx = (WatchContext *)info;
    if (ctx->emitted) return;
    NSLog(@"[objc_helper] safety timeout — emitting what we have");
    emit_new_files(ctx);
}

/// Check for new files and emit if expectedCount is met (or on timeout).
static void emit_new_files(WatchContext *ctx) {
    NSArray<NSString *> *current = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:ctx->watchDir error:nil];

    NSMutableArray<NSString *> *newFiles = [NSMutableArray new];
    for (NSString *file in current) {
        if ([ctx->existingFiles containsObject:file]) continue;
        NSString *ext = file.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"eml"] || [ext isEqualToString:@"msg"]) {
            [newFiles addObject:[ctx->watchDir stringByAppendingPathComponent:file]];
        }
    }

    NSLog(@"[objc_helper] new files: %lu (expecting %ld)",
          (unsigned long)newFiles.count, (long)ctx->expectedCount);

    if ((NSInteger)newFiles.count >= ctx->expectedCount) {
        ctx->emitted = YES;
        int count = (int)newFiles.count;
        const char **c_paths = (const char **)malloc(sizeof(const char *) * count);
        for (int i = 0; i < count; i++) {
            c_paths[i] = newFiles[i].UTF8String;
        }
        ctx->callback(c_paths, count, ctx->callbackContext);
        free(c_paths);
        cleanup_watch(ctx);
    }
}

/// Cleanup.
static void cleanup_watch(WatchContext *ctx) {
    if (ctx->stream) {
        FSEventStreamStop(ctx->stream);
        FSEventStreamInvalidate(ctx->stream);
        FSEventStreamRelease(ctx->stream);
        ctx->stream = NULL;
    }
    if (ctx->runLoop) {
        CFRunLoopStop(ctx->runLoop);
        ctx->runLoop = NULL;
    }
}
