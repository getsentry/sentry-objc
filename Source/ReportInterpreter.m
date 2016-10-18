//
//  ReportInterpreter.m
//  Sentry
//
//  Created by Karl on 2016-07-11.
//

#import "ReportInterpreter.h"
#import "Container+DeepSearch.h"

@interface ReportInterpreter ()
@property NSDictionary *report;
@property NSInteger crashedThreadIndex;
@property NSDictionary *exceptionContext;
@property NSArray *binaryImages;
@property NSArray *threads;
@property NSDictionary *systemContext;
@property NSDictionary *reportContext;
@property NSString *platform;

- (NSDictionary *)stackTraceForThreadIndex:(NSInteger)threadIndex showRegisters:(BOOL)showRegisters;
- (NSDictionary *)crashedThread;
- (NSMutableArray *)stackFramesForThreadIndex:(NSInteger)threadIndex showRegisters:(BOOL)showRegisters;
- (NSDictionary *)makeExceptionInterfaceWithType:(NSString *)type
                                           value:(NSString *)value
                                      stackTrace:(NSDictionary *)stackTrace;

@end

@interface NSExceptionReportInterpreter : ReportInterpreter

@end

@implementation NSExceptionReportInterpreter

- (NSDictionary *)exceptionInterface
{
    return [self makeExceptionInterfaceWithType:self.exceptionContext[@"nsexception"][@"name"]
                                          value:self.exceptionContext[@"reason"]
                                     stackTrace:[self stackTraceForThreadIndex:self.crashedThreadIndex showRegisters:YES]];
}

@end

@interface CPPExceptionReportInterpreter : ReportInterpreter

@end

@implementation CPPExceptionReportInterpreter

- (NSDictionary *)exceptionInterface
{
    return [self makeExceptionInterfaceWithType:self.exceptionContext[@"cpp_exception"][@"name"]
                                          value:self.exceptionContext[@"reason"]
                                     stackTrace:[self stackTraceForThreadIndex:self.crashedThreadIndex showRegisters:YES]];
}

@end

@interface MachExceptionReportInterpreter : ReportInterpreter

@end

@implementation MachExceptionReportInterpreter

- (NSDictionary *)exceptionInterface
{
    return [self makeExceptionInterfaceWithType:self.exceptionContext[@"mach"][@"exception_name"]
                                          value:[NSString stringWithFormat:@"Exception %@, Code %@, Subcode %@",
                                                 self.exceptionContext[@"mach"][@"exception"],
                                                 self.exceptionContext[@"mach"][@"code"],
                                                 self.exceptionContext[@"mach"][@"subcode"]]
                                     stackTrace:[self stackTraceForThreadIndex:self.crashedThreadIndex showRegisters:YES]];
}

@end

@interface SignalExceptionReportInterpreter : ReportInterpreter

@end

@implementation SignalExceptionReportInterpreter

- (NSDictionary *)exceptionInterface
{
    return [self makeExceptionInterfaceWithType:self.exceptionContext[@"signal"][@"name"]
                                          value:[NSString stringWithFormat:@"Signal %@, Code %@",
                                                 self.exceptionContext[@"signal"][@"signal"],
                                                 self.exceptionContext[@"signal"][@"code"]]
                                     stackTrace:[self stackTraceForThreadIndex:self.crashedThreadIndex showRegisters:YES]];
}

@end

@interface UserExceptionReportInterpreter : ReportInterpreter

@end

@implementation UserExceptionReportInterpreter

- (NSMutableArray *)userStacktrace
{
    NSArray *backtrace = self.exceptionContext[@"user_reported"][@"backtrace"];
    NSMutableArray *stackTrace = [NSMutableArray new];
    for(int i = (int)backtrace.count - 1; i >= 0; i--)
    {
        [stackTrace addObject:backtrace[(NSUInteger)i]];
    }
    return stackTrace;
}

- (NSMutableArray *)systemStacktrace
{
    NSArray *stackFrames = [self stackFramesForThreadIndex:self.crashedThreadIndex showRegisters:YES];
    NSMutableArray *stackTrace = [NSMutableArray new];
    for(NSDictionary *frame in stackFrames)
    {
        NSMutableDictionary *mutableFrame = [frame mutableCopy];
        mutableFrame[@"in_app"] = @NO;
        [stackTrace addObject:mutableFrame];
    }
    return stackTrace;
}

- (NSDictionary *)exceptionInterface
{
    NSMutableArray *stackTrace = [self userStacktrace];
    NSArray *systemStackTrace = [self systemStacktrace];
    [stackTrace addObjectsFromArray:systemStackTrace];
    return [self makeExceptionInterfaceWithType:self.exceptionContext[@"user_reported"][@"name"]
                                          value:self.exceptionContext[@"reason"]
                                     stackTrace:@{@"frames": stackTrace}];
}

@end

static NSDictionary *g_interpreterClasses;


@implementation ReportInterpreter

+ (instancetype)interpreterForReport:(NSDictionary *)report
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_interpreterClasses = @{@"nsexception": [NSExceptionReportInterpreter class],
                                 @"cpp_exception": [CPPExceptionReportInterpreter class],
                                 @"mach": [MachExceptionReportInterpreter class],
                                 @"signal": [SignalExceptionReportInterpreter class],
                                 @"user": [UserExceptionReportInterpreter class],
                                 };
    });
    NSDictionary *crashContext = report[@"crash"];
    NSDictionary *exceptionContext = crashContext[@"error"];
    NSString *type = exceptionContext[@"type"];;
    Class interpreterClass = g_interpreterClasses[type];
    return [[interpreterClass alloc] initWithReport:report];
}

- (instancetype)initWithReport:(NSDictionary *)report
{
    if((self = [super init]))
    {
        self.report = report;
        self.platform = @"cocoa";
        self.binaryImages = report[@"binary_images"];
        self.systemContext = report[@"system"];
        self.reportContext = report[@"report"];
        NSDictionary *crashContext = report[@"crash"];
        self.exceptionContext = crashContext[@"error"];
        self.threads = crashContext[@"threads"];
        for(NSUInteger i = 0; i < self.threads.count; i++)
        {
            NSDictionary *thread = self.threads[i];
            if(thread[@"crashed"])
            {
                self.crashedThreadIndex = (NSInteger)i;
                break;
            }
        }
    }
    return self;
}

static inline NSString *hexAddress(NSNumber *value)
{
    return [NSString stringWithFormat:@"0x%016llx", value.unsignedLongLongValue];
}

- (BOOL) isCustomReport
{
    NSString *reportType = [self.report objectForKeyPath:@"report/type"];
    return [reportType isEqualToString:@"custom"];
}

- (NSString *)deviceName
{
    return nil; // TODO
}

- (NSString *)family
{
    NSString *systemName = self.systemContext[@"system_name"];
    NSArray *components = [systemName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return components[0];
}

- (NSString *)model
{
    return self.systemContext[@"machine"];
}

- (NSString *)modelID
{
    return self.systemContext[@"model"];
}

- (NSString *)batteryLevel
{
    return nil; // Not recording this yet
}

- (NSString *)orientation
{
    return nil; // Not recording this yet
}

- (NSDictionary *)deviceContext
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"name"] = self.deviceName;
    result[@"family"] = self.family;
    result[@"model"] = self.model;
    result[@"model_id"] = self.modelID;
    result[@"architecture"] = self.systemContext[@"cpu_arch"];
    result[@"battery_level"] = self.batteryLevel;
    result[@"orientation"] = self.orientation;
    return result;
}

- (NSDictionary *)osContext
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"name"] = self.systemContext[@"system_name"];
    result[@"version"] = self.systemContext[@"system_version"];
    result[@"build"] = self.systemContext[@"os_version"];
    result[@"kernel_version"] = self.systemContext[@"kernel_version"];
    result[@"rooted"] = self.systemContext[@"jailbroken"];
    return result;
}

- (NSDictionary *)runtimeContext
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"name"] = self.systemContext[@"CFBundleName"];
    result[@"version"] = self.systemContext[@"CFBundleVersion"];
    return result;
}

- (NSArray *) rawStackTraceForThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *thread = self.threads[(NSUInteger)threadIndex];
    return thread[@"backtrace"][@"contents"];
}

- (NSDictionary *) registersForThreadIndex:(NSInteger)threadIndex
{
    NSDictionary *thread = self.threads[(NSUInteger)threadIndex];
    return thread[@"registers"];
}

- (NSDictionary *)binaryImageForAddress:(uintptr_t) address
{
    for(NSDictionary *binaryImage in self.binaryImages)
    {
        uintptr_t imageStart = (uintptr_t)[binaryImage[@"image_addr"] unsignedLongLongValue];
        uintptr_t imageEnd = imageStart + (uintptr_t)[binaryImage[@"image_size"] unsignedLongLongValue];
        if(address >= imageStart && address < imageEnd)
        {
            return binaryImage;
        }
    }
    return nil;
}

- (NSDictionary *)threadAtIndex:(NSInteger)threadIndex includeStacktrace:(BOOL)includeStacktrace
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    NSDictionary *thread = self.threads[(NSUInteger)threadIndex];
    if(includeStacktrace)
    {
        result[@"stacktrace"] = [self stackTraceForThreadIndex:threadIndex showRegisters:NO];
    }
    result[@"id"] = thread[@"index"];
    result[@"crashed"] = thread[@"crashed"];
    result[@"current"] = thread[@"current_thread"];
    result[@"name"] = thread[@"name"];
    if(!result[@"name"])
    {
        result[@"name"] = thread[@"dispatch_queue"];
    }
    return result;
}

- (NSDictionary *)stackFrameAtIndex:(NSInteger)frameIndex inThreadIndex:(NSInteger)threadIndex showRegisters:(BOOL)showRegisters
{
    NSDictionary *frame = [self rawStackTraceForThreadIndex:threadIndex][(NSUInteger)frameIndex];
    uintptr_t instructionAddress = (uintptr_t)[frame[@"instruction_addr"] unsignedLongLongValue];
    NSDictionary *binaryImage = [self binaryImageForAddress:instructionAddress];
    BOOL isAppImage = [binaryImage[@"name"] containsString:@"/Bundle/Application/"];
    NSString *function = frame[@"symbol_name"];
    if(function == nil)
    {
        function = @"<redacted>";
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"function"] = function;
    result[@"package"] = binaryImage[@"name"];
    result[@"image_addr"] = hexAddress(binaryImage[@"image_addr"]);
    result[@"platform"] = self.platform;
    result[@"instruction_addr"] = hexAddress(frame[@"instruction_addr"]);
    result[@"symbol_addr"] = hexAddress(frame[@"symbol_addr"]);
    result[@"in_app"] = [NSNumber numberWithBool:isAppImage];
    if(showRegisters)
    {
        result[@"vars"] = [self registersForThreadIndex:threadIndex];
    }
    return result;
}

- (NSMutableArray *)stackFramesForThreadIndex:(NSInteger)threadIndex showRegisters:(BOOL)showRegisters
{
    int frameCount = (int)[self rawStackTraceForThreadIndex:threadIndex].count;
    if(frameCount <= 0)
    {
        return nil;
    }

    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:(NSUInteger)frameCount];
    for(NSInteger i = frameCount - 1; i >= 0; i--)
    {
        [frames addObject:[self stackFrameAtIndex:i inThreadIndex:threadIndex showRegisters:showRegisters]];
        showRegisters = NO;
    }
    return frames;
}

- (NSDictionary *)stackTraceForThreadIndex:(NSInteger)threadIndex showRegisters:(BOOL)showRegisters
{
    NSArray *frames = [self stackFramesForThreadIndex:threadIndex showRegisters:showRegisters];
    if(frames == nil)
    {
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"frames"] = frames;
    int skipped = (int)[self.threads[(NSUInteger)threadIndex][@"backtrace"][@"skipped"] integerValue];
    if(skipped > 0)
    {
        result[@"frames_omitted"] = @[@"1", [NSString stringWithFormat:@"%d", skipped + 1]];
    }
    return result;
}

- (NSDictionary *)crashedThread
{
    return self.threads[(NSUInteger)self.crashedThreadIndex];
}

- (NSArray *)images
{
    NSMutableArray *result = [NSMutableArray new];
    for(NSDictionary *sourceImage in self.binaryImages)
    {
        NSMutableDictionary *image = [NSMutableDictionary new];
        image[@"type"] = @"apple";
        image[@"cpu_type"] = sourceImage[@"cpu_type"];
        image[@"cpu_subtype"] = sourceImage[@"cpu_subtype"];
        image[@"image_addr"] = hexAddress(sourceImage[@"image_addr"]);
        image[@"image_size"] = sourceImage[@"image_size"];
        image[@"image_vmaddr"] = hexAddress(sourceImage[@"image_vmaddr"]);
        image[@"name"] = sourceImage[@"name"];
        image[@"uuid"] = sourceImage[@"uuid"];
        [result addObject:image];
    }
    return result;
}

- (NSDictionary *)makeExceptionInterfaceWithType:(NSString *)type
                                           value:(NSString *)value
                                      stackTrace:(NSDictionary *)stackTrace
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"type"] = type;
    result[@"value"] = value;
    result[@"stacktrace"] = stackTrace;
    result[@"thread_id"] = self.crashedThread[@"index"];
    return @{@"values": @[result]};
}

- (NSDictionary *)exceptionInterface
{
    return nil;
}

- (NSArray *)threadsInterface
{
    NSMutableArray *result = [NSMutableArray new];
    for(NSInteger threadIndex = 0; threadIndex < (NSInteger)self.threads.count; threadIndex++)
    {
        BOOL includeStacktrace = threadIndex != self.crashedThreadIndex;
        [result addObject:[self threadAtIndex:threadIndex includeStacktrace:includeStacktrace]];
    }
    return result;
}

- (NSDictionary *)contextsInterface
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[@"device"] = self.deviceContext;
    result[@"os"] = self.osContext;
    result[@"runtime"] = self.runtimeContext;
    return result;
}

- (NSDictionary *)breadcrumbsInterface
{
    return [self.report objectForKeyPath:@"user/breadcrumbs"];
}

- (NSDictionary *)debugInterface
{
    NSMutableDictionary *result = [NSMutableDictionary new];
    // TODO: sdk_info - Do outside?
    result[@"images"] = self.images;
    return result;
}

- (NSDictionary *)requiredAttributes
{
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    
    NSString *level;
    
    if(self.isCustomReport)
    {
        level = self.report[@"level"];
    }
    else
    {
        level = @"fatal";
    }
    
    attributes[@"event_id"] = [[self.report objectForKeyPath:@"report/id"] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    attributes[@"timestamp"] = [self.report objectForKeyPath:@"report/timestamp"];
    attributes[@"platform"] = @"cocoa";
    attributes[@"level"] = level;
    
    return attributes;
}

- (NSDictionary *)optionalAttributes
{
    NSString *unset = nil;
    
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    
    attributes[@"logger"] = unset;
    attributes[@"release"] = [self.report objectForKeyPath:@"system/CFBundleVersion"];
    attributes[@"tags"] = [self.report objectForKeyPath:@"user/tags"];
    attributes[@"extra"] = [self.report objectForKeyPath:@"user/extra"];
    attributes[@"fingerprint"] = [self.report objectForKeyPath:@"user/fingerprint"];
    
    return attributes;
}

@end
