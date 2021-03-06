//
//  SKPStreamingJSONParser.m
//  StreamingJSON
//
//  Created by Ian Baird on 11/29/08.
//  Copyright (c) 2009, Skorpiostech, Inc.
//  All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//      * Neither the name of the Skorpiostech, Inc. nor the
//        names of its contributors may be used to endorse or promote products
//        derived from this software without specific prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY SKORPIOSTECH, INC. ''AS IS'' AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL SKORPIOSTECH, INC. BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  This is a wrapper around yajl.
//

#import "SKPStreamingJSONParser.h"

@interface SKPStreamingJSONParser ()

@property(nonatomic, assign) yajl_handle yajlHandle;
@property(nonatomic, retain, readwrite) NSInputStream *inputStream;
@property(nonatomic, assign) BOOL isFinished;
@property(nonatomic, assign) BOOL isParsing;
@property(nonatomic, assign) BOOL isAsync;
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

@implementation SKPStreamingJSONParser

@synthesize yajlHandle, inputStream, isFinished, isParsing, delegate, parserError, isAsync;

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

- (id)initWithInputStream:(NSInputStream *)aStream
{
    if (self = [super init])
    {
        yajl_parser_config cfg = { 1 , 1 };
        
        self.inputStream = aStream;
        self.yajlHandle = yajl_alloc(&callbacks, &cfg, (void *)self);
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"*** json parser dealloc'd");
    
    self.inputStream = nil;
    yajl_free(self.yajlHandle);
    self.yajlHandle = NULL;
    self.parserError = nil;
    
    [super dealloc];
}

- (BOOL)parse
{
    NSAssert(!isFinished && !isParsing, @"Already started!");
    
    self.isParsing = YES;
    
    [inputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [inputStream open];
    
    while (!isFinished)
    {
        NSLog(@"*** waiting on runloop");
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, true);
    }
    
    [inputStream close];
    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [inputStream setDelegate:nil];
    
    self.inputStream = nil;
    self.isParsing = NO;
    
    return (self.parserError == nil);
}

- (void)startAsynchronousParsing
{
    NSAssert(!isFinished && !isParsing, @"Already started!");
    
    self.isParsing = YES;
    self.isAsync = YES;
    
    
    [inputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [inputStream open];
}

- (void)stopAsynchronousParsing
{
    NSAssert(isParsing && isAsync, @"async parsing is not occurring");
    
    [inputStream close];
    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [inputStream setDelegate:nil];
    
    self.inputStream = nil;
    self.isParsing = NO;
    self.isAsync = NO;
}

#define READ_JSON_BUFFER_SIZE 4096

- (void)stream:(NSInputStream *)stream handleEvent:(NSStreamEvent)streamEvent
{    
    switch(streamEvent)
    {
        case NSStreamEventHasBytesAvailable:
        {
            UInt8 dataBuffer[READ_JSON_BUFFER_SIZE + 1];
            memset(dataBuffer, 0, sizeof(dataBuffer));
            CFIndex bytesRead = [stream read:dataBuffer maxLength:READ_JSON_BUFFER_SIZE];
            if (bytesRead < 0)
            {
                // TODO: Do something with the error
                self.isFinished = YES;
                NSDictionary *errorDict = [[NSDictionary alloc] initWithObjectsAndKeys:@"Error reading stream!",NSLocalizedDescriptionKey,nil];
                self.parserError = [NSError errorWithDomain:@"SKPStreamingJSONParserException" code:-1 userInfo:errorDict];
                [errorDict release];
                
                if (isAsync)
                {
                    [self stopAsynchronousParsing];
                }
                
                if ([delegate respondsToSelector:@selector(parser:didFail:)])
                {
                    [delegate parser:self didFail:self.parserError];
                }
            }
            else if (bytesRead == 0)
            {
                self.isFinished = YES;
                
                if (isAsync)
                {
                    [self stopAsynchronousParsing];
                }
                
                if ([delegate respondsToSelector:@selector(parserDidComplete:)])
                {
                    [delegate parserDidComplete:self];
                }
            }
            else if (bytesRead > 0)
            {
                // parse the data
                yajl_status stat;
                unsigned int offset = 0;
                UInt8 *dataBufferPtr = dataBuffer;
                NSInteger dataBufferLen = bytesRead;
                while (dataBufferLen > 0)
                {
                    NSLog(@"*** parsing string: %@", [[[NSString alloc] initWithBytesNoCopy:dataBufferPtr length:dataBufferLen encoding:NSUTF8StringEncoding freeWhenDone:NO] autorelease]);
                    stat = yajl_parse(self.yajlHandle, dataBufferPtr, dataBufferLen, &offset);
                    if (stat == yajl_status_ok)
                    {
                        dataBufferLen -= offset;
                        dataBufferPtr += offset;    
                        
                        yajl_reset(self.yajlHandle);
                    }
                    else if (stat == yajl_status_insufficient_data)
                    {
                        // no reset
                        dataBufferLen -= offset;
                        dataBufferPtr += offset;  
                    }
                    else if ( (stat != yajl_status_ok) && (stat != yajl_status_insufficient_data) )
                    {
                        unsigned char *errorMsg = yajl_get_error(self.yajlHandle, 1, dataBuffer, bytesRead);
                        NSString *errorStr = [[NSString alloc] initWithBytes:errorMsg length:strlen((char *)errorMsg) encoding:NSUTF8StringEncoding];
                        NSDictionary *errorDict = [[NSDictionary alloc] initWithObjectsAndKeys:errorStr,NSLocalizedDescriptionKey,nil];
                        self.parserError = [NSError errorWithDomain:@"SKPStreamingJSONParserException" code:-1 userInfo:errorDict];
                        
                        [errorStr release];
                        [errorDict release];
                        yajl_free_error(errorMsg);
                        
                        // Stop parsing
                        dataBufferLen = 0;
                        
                        yajl_reset(self.yajlHandle);
                        
                        if (isAsync)
                        {
                            [self stopAsynchronousParsing];
                        }
                        
                        if ([delegate respondsToSelector:@selector(parser:didFail:)])
                        {
                            [delegate parser:self didFail:self.parserError];
                        }
                        
                        break;
                    }
                    
                    
                }
            }
            break;
        }
        case NSStreamEventEndEncountered:
        {
            self.isFinished = YES;
            
            if (isAsync)
            {
                [self stopAsynchronousParsing];
            }
            
            if ([delegate respondsToSelector:@selector(parserDidComplete:)])
            {
                [delegate parserDidComplete:self];
            }
            
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            // TODO: Do something with the error
            self.isFinished = YES;
            NSDictionary *errorDict = [[NSDictionary alloc] initWithObjectsAndKeys:@"Error reading stream!",NSLocalizedDescriptionKey,nil];
            self.parserError = [NSError errorWithDomain:@"SKPStreamingJSONParserException" code:-1 userInfo:errorDict];
            [errorDict release];
            
            if (isAsync)
            {
                [self stopAsynchronousParsing];
            }
            
            if ([delegate respondsToSelector:@selector(parser:didFail:)])
            {
                [delegate parser:self didFail:self.parserError];
            }
            
            break;
        }
    }
}

@end
