//
//  SKPStreamingJSONParser.m
//  StreamingJSON
//
//  Created by Ian Baird on 11/29/08.
//  Copyright 2008 Skorpiostech, Inc. All rights reserved.
//
//  This is a wrapper around yajl.
//

#import "SKPStreamingJSONParser.h"

@interface SKPStreamingJSONParser ()

@property(nonatomic, assign) yajl_handle yajlHandle;
@property(nonatomic, assign, readwrite) CFReadStreamRef readStream;
@property(nonatomic, assign) BOOL isFinished;
@property(nonatomic, assign) BOOL isParsing;
@property(nonatomic, retain, readwrite) NSError *parserError;

@end

#pragma mark -
#pragma mark yajl callbacks

static int skp_json_null(void * ctx)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parserFoundNull:)])
    {
        return [inst.delegate parserFoundNull:inst] ? 1 : 0;
    }
    
    return 1;
}

static int skp_json_boolean(void * ctx, int boolean)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parser:foundBool:)])
    {
        return [inst.delegate parser:inst foundBool:(boolean == 1)] ? 1 : 0;
    }
    
    return 1;
}

static int skp_json_number(void * ctx, const char * s, unsigned int l)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parser:foundNumber:)])
    {
        NSString *numberStr = [[NSString alloc] initWithBytesNoCopy:(void *)s length:l encoding:NSUTF8StringEncoding freeWhenDone:NO];
        NSDecimalNumber *decimalNumber = [[NSDecimalNumber alloc] initWithString:numberStr];
        [numberStr release];
        
        int continueParse = [inst.delegate parser:inst foundNumber:decimalNumber] ? 1 : 0;
        
        [decimalNumber release];
        
        return continueParse;
    }
    
    return 1;
}

static int skp_json_string(void * ctx, const unsigned char * stringVal,
                    unsigned int stringLen)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parser:foundString:)])
    {
        NSString *newStr = [[NSString alloc] initWithBytes:stringVal length:stringLen encoding:NSUTF8StringEncoding];
        
        int continueParse = [inst.delegate parser:inst foundString:newStr] ? 1 : 0;
        
        [newStr release];
        
        return continueParse;
    }
    
    return 1;
}

static int skp_json_map_key(void * ctx, const unsigned char * stringVal,
                     unsigned int stringLen)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parser:foundKey:)])
    {
        NSString *newStr = [[NSString alloc] initWithBytes:stringVal length:stringLen encoding:NSUTF8StringEncoding];
        
        int continueParse = [inst.delegate parser:inst foundKey:newStr] ? 1 : 0;
        
        [newStr release];
        
        return continueParse;
    }
    
    return 1;
}

static int skp_json_start_map(void * ctx)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parserDidStartDictionary:)])
    {
        return [inst.delegate parserDidStartDictionary:inst] ? 1 : 0;
    }
    
    return 1;
}


static int skp_json_end_map(void * ctx)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parserDidEndDictionary:)])
    {
        return [inst.delegate parserDidEndDictionary:inst] ? 1 : 0;
    }
    
    return 1;
}

static int skp_json_start_array(void * ctx)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parserDidStartArray:)])
    {
        return [inst.delegate parserDidStartArray:inst] ? 1 : 0;
    }
    
    return 1;
}

static int skp_json_end_array(void * ctx)
{
    SKPStreamingJSONParser *inst = (SKPStreamingJSONParser *) ctx;
    
    if ([inst.delegate respondsToSelector:@selector(parserDidEndArray:)])
    {
        return [inst.delegate parserDidEndArray:inst] ? 1 : 0;
    }
    
    return 1;
}

#pragma mark -
#pragma mark CFReadStream client callback

#define READ_JSON_BUFFER_SIZE 4096

static void ReadStreamCB (CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo)
{
    SKPStreamingJSONParser *parser = (SKPStreamingJSONParser *)clientCallBackInfo;
    
    switch(eventType)
    {
        case kCFStreamEventHasBytesAvailable:
        {
            UInt8 dataBuffer[READ_JSON_BUFFER_SIZE + 1];
            memset(dataBuffer, 0, sizeof(dataBuffer));
            CFIndex bytesRead = CFReadStreamRead(stream, dataBuffer, READ_JSON_BUFFER_SIZE);
            if (bytesRead < 0)
            {
                // TODO: Do something with the error
                parser.isFinished = YES;
                NSDictionary *errorDict = [[NSDictionary alloc] initWithObjectsAndKeys:@"Error reading stream!",NSLocalizedDescriptionKey,nil];
                parser.parserError = [NSError errorWithDomain:@"SKPStreamingJSONParserException" code:-1 userInfo:errorDict];
                [errorDict release];
            }
            else if (bytesRead > 0)
            {
                // parse the data
                yajl_status stat;
                stat = yajl_parse(parser.yajlHandle, dataBuffer, bytesRead);
                if ( (stat != yajl_status_ok) && (stat != yajl_status_insufficient_data) )
                {
                    unsigned char *errorMsg = yajl_get_error(parser.yajlHandle, 1, dataBuffer, bytesRead);
                    NSString *errorStr = [[NSString alloc] initWithBytes:errorMsg length:strlen((char *)errorMsg) encoding:NSUTF8StringEncoding];
                    NSDictionary *errorDict = [[NSDictionary alloc] initWithObjectsAndKeys:errorStr,NSLocalizedDescriptionKey,nil];
                    parser.parserError = [NSError errorWithDomain:@"SKPStreamingJSONParserException" code:-1 userInfo:errorDict];
                    [errorStr release];
                    [errorDict release];
                    yajl_free_error(errorMsg);
                }
            }
            break;
        }
        case kCFStreamEventEndEncountered:
        {
            parser.isFinished = YES;
            break;
        }
        case kCFStreamEventErrorOccurred:
        {
            // TODO: Do something with the error
            parser.isFinished = YES;
            NSDictionary *errorDict = [[NSDictionary alloc] initWithObjectsAndKeys:@"Error reading stream!",NSLocalizedDescriptionKey,nil];
            parser.parserError = [NSError errorWithDomain:@"SKPStreamingJSONParserException" code:-1 userInfo:errorDict];
            [errorDict release];
            break;
        }
    }
}

@implementation SKPStreamingJSONParser

@synthesize yajlHandle, readStream, isFinished, isParsing, delegate, parserError;

static yajl_callbacks callbacks = {
    skp_json_null,
    skp_json_boolean,
    NULL,
    NULL,
    skp_json_number,
    skp_json_string,
    skp_json_start_map,
    skp_json_map_key,
    skp_json_end_map,
    skp_json_start_array,
    skp_json_end_array
};

- (id)initWithReadStream:(CFReadStreamRef)aStream
{
    if (self = [super init])
    {
        yajl_parser_config cfg = { 1 , 1 };
        
        self.readStream = aStream;
        self.yajlHandle = yajl_alloc(&callbacks, &cfg, (void *)self);
    }
    
    return self;
}

- (void)dealloc
{
    self.readStream = NULL;
    yajl_free(self.yajlHandle);
    self.yajlHandle = NULL;
    self.parserError = nil;
    
    [super dealloc];
}

- (BOOL)parse
{
    NSAssert(!isFinished && !isParsing, @"Already started!");
    
    self.isParsing = YES;
    
    CFStreamClientContext client;
    memset(&client, 0, sizeof(client));
    client.info = (void *)self;
    
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred, ReadStreamCB, &client);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamOpen(readStream);
    
    while (!isFinished)
    {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, true);
    }
    
    CFReadStreamClose(readStream);
    CFReadStreamUnscheduleFromRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred, NULL, NULL);
    
    self.readStream = NULL;
    
    return (self.parserError == nil);
}

- (void)setReadStream:(CFReadStreamRef)aStream
{
    if (readStream != aStream)
    {
        if (readStream)
        {
            CFRelease(readStream);
        }
        
        readStream = (aStream != NULL) ? (CFReadStreamRef)CFRetain(aStream) : NULL;
    }
}

@end