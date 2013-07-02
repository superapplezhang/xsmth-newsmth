//
//  SMWritePostViewController.m
//  newsmth
//
//  Created by Maxwin on 13-6-23.
//  Copyright (c) 2013年 nju. All rights reserved.
//

#import "SMWritePostViewController.h"
#import "SMWriteResult.h"

#define USER_DEF_LAST_POST_TITLE    @"last_post_title"
#define USER_DEF_LAST_POST_CONTENT  @"last_post_content"

@interface SMWritePostViewController ()<SMWebLoaderOperationDelegate>
@property (weak, nonatomic) IBOutlet UIView *viewForContainer;
@property (weak, nonatomic) IBOutlet UITextField *textFieldForTitle;
@property (weak, nonatomic) IBOutlet UITextView *textViewForText;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewForTitle;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewForText;


@property (strong, nonatomic) SMWebLoaderOperation *writeOp;
@end

@implementation SMWritePostViewController

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [_writeOp cancel];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发表" style:UIBarButtonItemStyleBordered target:self action:@selector(doPost)];
    
    NSMutableString *quoteString = [[NSMutableString alloc] initWithString:@"\n\n"];
    if (_post.pid != 0) {   // re
        if (_postTitle != nil) {
            _textFieldForTitle.text = [NSString stringWithFormat:@"Re: %@", _postTitle];
        }
        [quoteString appendFormat:@"【 在 %@ (%@) 的大作中提到: 】", _post.author, _post.nick];
        
        NSString *content = _post.content;
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        int quoteLine = 4;
        for (int i = 0; i != lines.count && quoteLine > 0; ++i) {
            NSString *line = lines[i];
            if ([line isEqualToString:@"--"]) {   // qmd start
                break;
            }
            if (![line hasPrefix:@":"]) {
                --quoteLine;
                [quoteString appendFormat:@"\n:%@", line];
            }
        }
    }
    
    // 加载上次未发表的内容
    NSString *savedContent = [[NSUserDefaults standardUserDefaults] objectForKey:USER_DEF_LAST_POST_CONTENT];
    if (savedContent != nil) {
        NSString *str = [NSString stringWithFormat:@"~~~上次未发表的内容~~~\n%@\n~~~~~~~~~~~~\n", savedContent];
        [quoteString insertString:str atIndex:0];
    }
    
    [quoteString appendString:@"\n发自xsmth"];
    _textViewForText.text = quoteString;
    
    // style
    _imageViewForTitle.image = [SMUtils stretchedImage:_imageViewForTitle.image];
    _imageViewForText.image = [SMUtils stretchedImage:_imageViewForText.image];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_textFieldForTitle.text.length == 0) {
        [_textFieldForTitle becomeFirstResponder];
    } else {
        [_textViewForText setSelectedRange:NSMakeRange(0, 0)];
        [_textViewForText becomeFirstResponder];
    }
}

- (void)cancel
{
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def removeObjectForKey:USER_DEF_LAST_POST_TITLE];
    [def removeObjectForKey:USER_DEF_LAST_POST_CONTENT];

    [self dismiss];
}

- (void)dismiss
{
    [self.navigationController dismissModalViewControllerAnimated:YES];
}

- (void)doPost
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding ( kCFStringEncodingMacChineseSimp );
    NSString *title = [_textFieldForTitle.text stringByAddingPercentEscapesUsingEncoding:enc];
    NSString *text = [_textViewForText.text stringByAddingPercentEscapesUsingEncoding:enc];

    NSString *postBody = [NSString stringWithFormat:@"title=%@&text=%@&signature=1", title, text];
    
    NSString *formUrl = [NSString stringWithFormat:@"http://www.newsmth.net/bbssnd.php?board=%@&reid=%d", _post.board.name, _post.pid];
    SMHttpRequest *request = [[SMHttpRequest alloc] initWithURL:[NSURL URLWithString:formUrl]];
    [request setRequestMethod:@"POST"];
    [request addRequestHeader:@"Content-type" value:@"application/x-www-form-urlencoded"];
    [request setPostBody:[[postBody dataUsingEncoding:NSUTF8StringEncoding] mutableCopy]];
    
    _writeOp = [[SMWebLoaderOperation alloc] init];
    _writeOp.delegate = self;
    [self showLoading:@"正在发表..."];
    [_writeOp loadRequest:request withParser:@"bbssnd"];
}

- (void)cancelLoading
{
    [super cancelLoading];
    [_writeOp cancel];
    _writeOp = nil;
}


- (void)onKeyboardWillShow:(NSNotification *)n
{
    NSDictionary* info = [n userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;

    CGRect frame = self.view.bounds;
    frame.size.height -= kbSize.height;
    _viewForContainer.frame = frame;
}

- (void)onKeyboardWillHide:(NSNotification *)n
{
    _viewForContainer.frame = self.view.bounds;
}

- (void)webLoaderOperationFinished:(SMWebLoaderOperation *)opt
{
    [self hideLoading];
    SMWriteResult *result = opt.data;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (result.success) {
        [self toast:@"发表成功"];
        [def removeObjectForKey:USER_DEF_LAST_POST_TITLE];
        [def removeObjectForKey:USER_DEF_LAST_POST_CONTENT];
    } else {
        [self toast:@"发表失败，文章已保存"];
        // save post
        [def setObject:_textFieldForTitle.text forKey:USER_DEF_LAST_POST_TITLE];
        [def setObject:_textViewForText.text forKey:USER_DEF_LAST_POST_CONTENT];
    }
    [self performSelector:@selector(dismiss) withObject:nil afterDelay:TOAST_DURTAION + 0.1];
}

- (void)webLoaderOperationFail:(SMWebLoaderOperation *)opt error:(SMMessage *)error
{
    [self hideLoading];
    [self toast:error.message];
}

@end
