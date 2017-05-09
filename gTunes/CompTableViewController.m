//
//  CompTableViewController.m
//  gTunes
//
//  Created by kyab on 2017/04/14.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import "CompTableViewController.h"

@implementation CompTableViewController{
    NSMutableArray *_dataArray;
}

- (id)init{
    
    self = [super init];
    if (self){
//        _dataArray = [[NSMutableArray alloc] init];
//        for (int i = 0; i < 10; i++) {
//            NSDictionary *data = @{@"title": [NSString stringWithFormat:@"title-%d", i],
//                                   @"description": [NSString stringWithFormat:@"description-%d", i]};
//            [_dataArray addObject:data];
//        }
    }
    return self;
}


- (void)loadFile:(NSString *)jsonPath{
    _path = [jsonPath copy];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL exist = [fileManager fileExistsAtPath:_path];
    if (!exist){
        _dbTopObj = [[NSMutableDictionary alloc] init];
        [_dbTopObj setObject:@"1.0" forKey:@"version"];
        _db = [[NSMutableArray alloc] init];
        [_dbTopObj setObject:_db forKey:@"database"];
        NSLog(@"loadFile not found at:%@", _path);
        return;
    }
    //read side.
    NSInputStream *inFile = [NSInputStream inputStreamWithFileAtPath:_path];
    [inFile open];
    _dbTopObj = [NSJSONSerialization JSONObjectWithStream:inFile
                                                                     options:NSJSONReadingMutableContainers|NSJSONReadingMutableLeaves
                                                                       error:nil];
    NSLog(@"loadFile result:%@",_dbTopObj);
    _db = [_dbTopObj objectForKey:@"database"];
    
    
}

//please call reload data
- (void)setCurrentSong:(NSString *)title artist:(NSString *)artist{
    _title = title;
    _artist = artist;
    _compFiles = nil;
    for (int i = 0; i < _db.count ;i++){
        NSDictionary *item = (NSDictionary *)[_db objectAtIndex:i];
        if ([[item objectForKey:@"title"] isEqualToString:_title] &&
            [[item objectForKey:@"artist"] isEqualToString:_artist]){
            _compFiles = [item objectForKey:@"companion"];
            break;
        }
    }
}

//- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{
//    return _dataArray.count;
//}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{
    if (_compFiles){
        return _compFiles.count;
    }else{
        return 0;
    }
}

//- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex{
//    
//    NSDictionary *data = [_dataArray objectAtIndex:rowIndex];
//    if ([[aTableColumn identifier] isEqualToString:@"TITLE"]){
//        return [data objectForKey:@"title"];
//    }else{
//        return [data objectForKey:@"description"];
//    }
//}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex{
    
    if (_compFiles){
        return [_compFiles objectAtIndex:rowIndex];
    }else{
        return nil;
    }
    
}



//- (void)addItemForSong:(NSString *)title forArtist:(NSString *)artist path:(NSString *)path{
//    NSDictionary *data = @{@"title":path, @"description":path};
//    [_dataArray addObject:data];
//}

- (void)addItem:(NSString *)path{
    if (_compFiles){
        [_compFiles addObject:path];
    }else{
        NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
        [item setObject:[NSUUID UUID].UUIDString forKey:@"id"];
        [item setObject:_artist forKey:@"artist"];
        [item setObject:_title forKey:@"title"];
        
        _compFiles = [[NSMutableArray alloc] init];
        [_compFiles addObject:path];
        [item setObject:_compFiles forKey:@"companion"];
        
        [_db addObject:item];
    }
    [self updateJSON];
}

- (NSString *)itemAtRow:(NSInteger)rowIndex{
    if (_compFiles){
        return [_compFiles objectAtIndex:rowIndex];
    }else{
        return nil;
    }
}

- (void)updateJSON{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_dbTopObj options:NSJSONWritingPrettyPrinted error:nil];
    
    //avoid sirry escape for "/" in path
    //http://stackoverflow.com/questions/19651009/how-to-prevent-nsjsonserialization-from-adding-extra-escapes-in-url
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    jsonStr = [jsonStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL exist = [fileManager fileExistsAtPath:_path];
    if (!exist){
        [fileManager createFileAtPath:_path contents:nil attributes:nil];
    }else{
        [fileManager removeItemAtPath:_path error:nil];
        [fileManager createFileAtPath:_path contents:nil attributes:nil];
    }
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:_path];
    NSData *writeData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    [fileHandle writeData:writeData];
    [fileHandle closeFile];
    
}


@end
