//
//  SMPostGroupViewController.m
//  newsmth
//
//  Created by Maxwin on 13-5-30.
//  Copyright (c) 2013年 nju. All rights reserved.
//

#import "SMPostGroupViewController.h"
#import "XPullRefreshTableView.h"
#import "XImageView.h"
#import "SMPost.h"
#import "SMAttach.h"
#import "SMPostGroup.h"

#import "SMPostGroupHeaderCell.h"
#import "SMPostGroupContentCell.h"
#import "SMPostGroupAttachCell.h"

typedef enum {
    CellTypeHeader,
    CellTypeLoading,
    CellTypeFail,
    CellTypeContent,
    CellTypeAttach
}CellType;

////////////////////////////////////////////////
@interface SMPostGroupItem : NSObject
@property (strong, nonatomic) SMPost *post;
@property (strong, nonatomic) SMWebLoaderOperation *op;
@property (assign, nonatomic) BOOL loadFail;
@end
@implementation SMPostGroupItem
@end

////////////////////////////////////////////////

@interface SMPostGroupCellData : NSObject
@property (strong, nonatomic) SMPostGroupItem *item;
@property (assign, nonatomic) CellType type;
@property (strong, nonatomic) SMAttach *attach;
@end

@implementation SMPostGroupCellData
@end

////////////////////////////////////////////////
@interface SMPostGroupViewController ()<UITableViewDataSource, UITableViewDelegate, XPullRefreshTableViewDelegate, SMWebLoaderOperationDelegate, XImageViewDelegate>
@property (weak, nonatomic) IBOutlet XPullRefreshTableView *tableView;

// data
@property (strong, nonatomic) NSArray *postItems;
@property (strong, nonatomic) NSArray *cellDatas;
@property (strong, nonatomic) SMWebLoaderOperation *pageOp; // 分页加载数据用op

@property (assign, nonatomic) NSInteger bid;    // board id
@property (assign, nonatomic) NSInteger tpage;  // total page
@property (assign, nonatomic) NSInteger pno;    // current page

@end

@implementation SMPostGroupViewController

- (id)init
{
    self = [super initWithNibName:@"SMPostGroupViewController" bundle:nil];
    if (self) {
        _pno = 1;
    }
    return self;
}

- (void)dealloc
{
    XLog_d(@"%s", __PRETTY_FUNCTION__);
    // cancel all requests
    [_pageOp cancel];
    [_postItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SMPostGroupItem *item = obj;
        [item.op cancel];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.xdelegate = self;
    [self loadData:NO];
}

- (void)loadData:(BOOL)more
{
    if (!more) {
        _pno = 1;
    } else {
        ++_pno;
    }
    NSString *url = [NSString stringWithFormat:@"http://www.newsmth.net/bbstcon.php?board=%@&gid=%d&start=%d&pno=%d", _board, _gid, _gid, _pno];
    _pageOp = [[SMWebLoaderOperation alloc] init];
    _pageOp.delegate = self;
    [_pageOp loadUrl:url withParser:@"bbstcon"];
}

- (void)setPostItems:(NSArray *)postItems
{
    _postItems = postItems;
    [self makeupCellDatas];
}

- (void)makeupCellDatas
{
    __block NSMutableArray *datas = [[NSMutableArray alloc] initWithCapacity:0];
    [_postItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SMPostGroupItem *item = obj;
        if (item.op.data != nil) {  // post loaded
            item.post = item.op.data;
        }
        
        // header
        SMPostGroupCellData *header = [[SMPostGroupCellData alloc] init];
        header.item = item;
        header.type = CellTypeHeader;
        [datas addObject:header];
        
        // content
        SMPostGroupCellData *content = [[SMPostGroupCellData alloc] init];
        content.item = item;
        if (item.loadFail) {
            content.type = CellTypeFail;
        } else if (item.op.data == nil) {
            content.type = CellTypeLoading;
        } else if (item.op.data) {
            content.type = CellTypeContent;
        }
        [datas addObject:content];
        
        // attaches
        if (item.op.data != nil) {
            SMPost *post = item.op.data;
            [post.attaches enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                SMPostGroupCellData *data = [[SMPostGroupCellData alloc] init];
                data.item = item;
                data.type = CellTypeAttach;
                data.attach = obj;
                
                [datas addObject:data];
            }];
        }
        
    }];
    self.cellDatas = datas;
}

- (void)setCellDatas:(NSArray *)cellDatas
{
    _cellDatas = cellDatas;
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource/Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _cellDatas.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMPostGroupCellData *data = _cellDatas[indexPath.row];
    
    if (_pno != _tpage && indexPath.row == _cellDatas.count - 1) {    // last row
        [self loadData:YES];
    }
    
    switch (data.type) {
        case CellTypeHeader:
            return [self cellForTitle:data];
        case CellTypeFail:
            return [self cellForFail:data];
        case CellTypeLoading:
            return [self cellForLoading:data];
        case CellTypeContent:
            return [self cellForContent:data];
        case CellTypeAttach:
            return [self cellForAttach:data];
        default:
            break;
    }
    return nil; // !
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMPostGroupCellData *data = _cellDatas[indexPath.row];
    switch (data.type) {
        case CellTypeHeader:
            return [SMPostGroupHeaderCell cellHeight];
        case CellTypeFail:
            return 44.0f;
        case CellTypeLoading:
            return 44.0f;
        case CellTypeContent:
            return [SMPostGroupContentCell cellHeight:data.item.post];
        case CellTypeAttach:
            return [SMPostGroupAttachCell cellHeight:[self getAttachUrl:data]];
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)cellForTitle:(SMPostGroupCellData *)data
{
    NSString *cellid = @"title_cell";
    SMPostGroupHeaderCell *cell = (SMPostGroupHeaderCell *)[self.tableView dequeueReusableCellWithIdentifier:cellid];
    if (cell == nil) {
        cell = [[SMPostGroupHeaderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    cell.post = data.item.post;
    return cell;
}

- (UITableViewCell *)cellForLoading:(SMPostGroupCellData *)data
{
    NSString *cellid = @"loading_cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellid];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    cell.textLabel.text = @"Loading...";
    return cell;
}

- (UITableViewCell *)cellForFail:(SMPostGroupCellData *)data
{
    NSString *cellid = @"fail_cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellid];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    cell.textLabel.text = @"Fail";
    return cell;
}

- (UITableViewCell *)cellForContent:(SMPostGroupCellData *)data
{
    NSString *cellid = @"content_cell";
    SMPostGroupContentCell *cell = (SMPostGroupContentCell *)[self.tableView dequeueReusableCellWithIdentifier:cellid];
    if (cell == nil) {
        cell = [[SMPostGroupContentCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    cell.post = data.item.post;
    return cell;
}

- (UITableViewCell *)cellForAttach:(SMPostGroupCellData *)data
{
    NSString *cellid = @"attach_cell";
    SMPostGroupAttachCell *cell = (SMPostGroupAttachCell *)[self.tableView dequeueReusableCellWithIdentifier:cellid];
    if (cell == nil) {
        cell = [[SMPostGroupAttachCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    cell.imageViewForAttach.delegate = self;
    cell.url = [self getAttachUrl:data];
    return cell;
}

- (NSString *)getAttachUrl:(SMPostGroupCellData *)data
{
    return [NSString stringWithFormat:@"http://att.newsmth.net/nForum/att/%@/%d/%d/large", _board, data.item.post.pid, data.attach.pos];
}

#pragma mark - XPullRefreshTableViewDelegate
- (void)tableViewDoRefresh:(XPullRefreshTableView *)tableView
{
    [self loadData:NO];
}

#pragma mark - XImageViewDelegate
- (void)xImageViewDidLoad:(XImageView *)imageView
{
    [_tableView reloadData];
}

#pragma mark - SMWebLoaderOperationDelegate
- (void)webLoaderOperationFinished:(SMWebLoaderOperation *)opt
{
    if (opt == _pageOp) {
        // add post to postOps
        SMPostGroup *postGroup = opt.data;
        _tpage = postGroup.tpage;
        
        if (_pno != _tpage) {
            [_tableView setLoadMoreShow];
        } else {
            [_tableView setLoadMoreHide];
        }
        
        NSMutableArray *tmp;
        if (_pno == 1) {    // first page
            [self.tableView endRefreshing:YES];
            tmp = [[NSMutableArray alloc] initWithCapacity:0];
            _bid = postGroup.bid;
        } else {
            tmp = [_postItems mutableCopy];
        }
        [postGroup.posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SMPost *post = obj;
            NSString *url = [NSString stringWithFormat:@"http://www.newsmth.net/bbscon.php?bid=%d&id=%d", _bid, post.pid];
            SMWebLoaderOperation *op = [[SMWebLoaderOperation alloc] init];
            op.delegate = self;
            [op loadUrl:url withParser:@"bbscon"];
            
            SMPostGroupItem *item = [[SMPostGroupItem alloc] init];
            item.op = op;
            item.post = post;
            [tmp addObject:item];
        }];
        self.postItems = tmp;
    } else {
        [self makeupCellDatas];
    }
}

- (void)webLoaderOperationFail:(SMWebLoaderOperation *)opt error:(SMMessage *)error
{
    XLog_e(@"%@", error);
}


@end