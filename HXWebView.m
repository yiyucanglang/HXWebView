//
//  HXWebView.m
//  ParentDemo
//
//  Created by James on 2019/6/14.
//  Copyright © 2019 DaHuanXiong. All rights reserved.
//

#import "HXWebView.h"
#import <Masonry/Masonry.h>
#import <KVOController/KVOController.h>

@interface HXJSInteractMiddler : NSObject<WKScriptMessageHandler>

@property (nonatomic, weak) id scriptDelegate;

- (instancetype)initWithDelegate:(id)scriptDelegate;

@end

@implementation HXJSInteractMiddler

- (instancetype)initWithDelegate:(id)scriptDelegate
{
    self = [super init];
    if (self) {
        _scriptDelegate = scriptDelegate;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    [self.scriptDelegate userContentController:userContentController didReceiveScriptMessage:message];
}

@end

@interface HXWebViewDelegateInterceptor : NSObject
@property (nonatomic, weak) id originalReceiver;
@property (nonatomic, weak) HXWebView *middleMan;
@end

@implementation HXWebViewDelegateInterceptor

#pragma mark - System Method
- (BOOL)respondsToSelector:(SEL)aSelector {
    
    if ([self.originalReceiver respondsToSelector:aSelector]) {
        return YES;
    }
    if ([self.middleMan respondsToSelector:aSelector]) {
        return YES;
    }
    return [super respondsToSelector:aSelector];
    
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    
    if ([self.originalReceiver respondsToSelector:aSelector]) {
        return self.originalReceiver;
    }
    if ([self.middleMan respondsToSelector:aSelector]) {
        return self.middleMan;
    }
    return self.originalReceiver;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    
    NSString *methodName =NSStringFromSelector(aSelector);
    if ([methodName hasPrefix:@"_"]) {//对私有方法不进行crash日志采集操作
        return nil;
    }
    NSString *crashMessages = [NSString stringWithFormat:@"crashProtect: [%@ %@]: unrecognized selector sent to instance",self,NSStringFromSelector(aSelector)];
    NSMethodSignature *signature = [HXWebViewDelegateInterceptor instanceMethodSignatureForSelector:@selector(crashProtectCollectCrashMessages:)];
    [self crashProtectCollectCrashMessages:crashMessages];
    return signature;//对methodSignatureForSelector 进行重写，不然不会调用forwardInvocation方法
    
}

- (void)forwardInvocation:(NSInvocation *)anInvocation{
    //将此方法进行重写，在里这不进行任何操作，屏蔽会产生crash的方法调用
}


#pragma mark - Private
- (void)crashProtectCollectCrashMessages:(NSString *)crashMessage{
    
//    HXLog(@"%@",crashMessage);
    
}


@end


@interface HXWebView()

@property (nonatomic, strong) HXWebViewDelegateInterceptor *wkUIInterceptor;

@property (nonatomic, strong) HXWebViewDelegateInterceptor *wkNavigationInterceptor;

@property (nonatomic, strong) NSMutableDictionary  *registMethodRelationDic;
@property (nonatomic, copy) NSString  *originalURLStr;

@end

@implementation HXWebView
#pragma mark - Life Cycle

#pragma mark - System Method

#pragma mark - Public Method
- (void)loadURLStr:(NSString *)URLStr {
    if (!URLStr) {
        return;
    }
    self.originalURLStr = URLStr;
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLStr]];
    mutableRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [self loadRequest:mutableRequest];
    [self showProgressView];
}

- (void)registMethodInvokedByWeb:(NSString *)methodName nativeHandler:(WebInvokeNativeHandler)nativeHandler {
    [self unregistMethodInvokedByWeb:methodName];
    
    [self.registMethodRelationDic setValue:[nativeHandler copy] forKey:methodName];
    [self.configuration.userContentController addScriptMessageHandler:[[HXJSInteractMiddler alloc] initWithDelegate:self] name:methodName];
}

- (void)unregistMethodInvokedByWeb:(NSString *)methodName {
    if (self.registMethodRelationDic[methodName]) {
        [self.configuration.userContentController removeScriptMessageHandlerForName:methodName];
    }
    [self.registMethodRelationDic removeObjectForKey:methodName];
}

- (void)unregistAllMethodInvokedByWeb {
    for (NSString *methodName in self.registMethodRelationDic.allKeys) {
        [self unregistMethodInvokedByWeb:methodName];
    }
}

- (void)invokeWebMethod:(NSString *)jsString completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler {
    [self evaluateJavaScript:jsString completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (completionHandler) {
            completionHandler(result, error);
        }
    }];
}


#pragma mark - Override
- (void)setUIDelegate:(id<WKUIDelegate>)UIDelegate {
    self.wkUIInterceptor.originalReceiver = UIDelegate;
    [super setUIDelegate:(id<WKUIDelegate>)self.wkUIInterceptor];
}

- (void)setNavigationDelegate:(id<WKNavigationDelegate>)navigationDelegate {
    self.wkNavigationInterceptor.originalReceiver = navigationDelegate;
    [super setNavigationDelegate:(id<WKNavigationDelegate>)self.wkNavigationInterceptor];
}

- (void)removeFromSuperview {
    [super removeFromSuperview];
    [self.KVOControllerNonRetaining unobserveAll];
    [self unregistAllMethodInvokedByWeb];
}

#pragma mark - Private Method

- (void)_hxReload {
    if (self.URL.absoluteString.length) {
        [self reload];
        return;
    }
    [self loadURLStr:self.originalURLStr];
}

#pragma mark Tool
- (void)showProgressView {
    self.progressView.hidden = NO;
    [self bringSubviewToFront:self.progressView];
}

- (void)hiddenProgressView {
    self.progressView.hidden = YES;
}

- (UIViewController *)hxViewController {
    for (UIView *view = self; view; view = view.superview) {
        UIResponder *nextResponder = [view nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)nextResponder;
        }
    }
    return nil;
}

- (void)addView:(UIView *)sourceView targetView:(UIView *)targetView {
    [targetView addSubview:sourceView];
    [sourceView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(targetView);
        make.size.equalTo(targetView);
    }];
    
}

#pragma mark - Delegate
#pragma mark WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [self.hxViewController presentViewController:alertController animated:YES completion:nil];
    
}

// this method handle the problem in the following
//WKWebView 加载完链接后点击内部链接无法跳转，是因为<a href = "xxx" target = "_black"> 中的target = "_black" 是打开新的页面，所以无法在当前页面打开，需要在当前页重新加载url
//a 超连接中target的意思
//　　_blank -- 在新窗口中打开链接
//　　_parent -- 在父窗体中打开链接
//　　_self -- 在当前窗体打开链接,此为默认值
//　　_top -- 在当前窗体打开链接，并替换当前的整个窗体(框架页)
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

#pragma mark WKWebViewDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    _loadSuccessFlag = NO;
    [self addView:self.hudView targetView:self];
    [self showProgressView];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    _loadSuccessFlag = YES;
    [self hiddenProgressView];
    [self.failView removeFromSuperview];
    [self.hudView removeFromSuperview];
    if (self.LoadFinishHandler) {
        self.LoadFinishHandler(YES);
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    _loadSuccessFlag = NO;
    [self.hudView removeFromSuperview];
    [self hiddenProgressView];
    [self addView:self.failView targetView:self];
    if (self.LoadFinishHandler) {
        self.LoadFinishHandler(NO);
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    if (!webView.title.length) {
        [webView reload];
    }
}



#pragma mark WeakScriptMessageDelegate
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if (self.registMethodRelationDic[message.name]) {((WebInvokeNativeHandler)self.registMethodRelationDic[message.name])(message);
    }
}




#pragma mark - Setter And Getter
- (NSMutableDictionary *)registMethodRelationDic {
    if (!_registMethodRelationDic) {
        _registMethodRelationDic = [[NSMutableDictionary alloc] init];
    }
    return _registMethodRelationDic;
}

- (void)setHudView:(UIView *)hudView {
    [_hudView removeFromSuperview];
    _hudView = hudView;
}

- (void)setFailView:(UIView *)failView {
    [_failView removeFromSuperview];
    _failView = failView;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_hxReload)];
    [failView addGestureRecognizer:tap];
}

- (void)setProgressView:(UIProgressView *)progressView {
    
    [progressView removeFromSuperview];
    _progressView = progressView;
    [self addSubview:progressView];
    [progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.equalTo(self);
        make.height.equalTo(@(2));
    }];
    __weak typeof(self) w_self = self;
    [self.KVOControllerNonRetaining unobserveAll];
    [self.KVOControllerNonRetaining observe:self keyPath:FBKVOClassKeyPath(WKWebView, estimatedProgress) options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        progressView.progress = w_self.estimatedProgress;
        
        if (w_self.progressView.progress >= 1) {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                progressView.hidden = YES;
            } completion:nil];
            
        }
    }];
    
}

- (HXWebViewDelegateInterceptor *)wkUIInterceptor {
    if (!_wkUIInterceptor) {
        _wkUIInterceptor = [[HXWebViewDelegateInterceptor alloc] init];
        _wkUIInterceptor.middleMan = self;
    }
    return _wkUIInterceptor;
}

- (HXWebViewDelegateInterceptor *)wkNavigationInterceptor {
    if (!_wkNavigationInterceptor) {
        _wkNavigationInterceptor = [[HXWebViewDelegateInterceptor alloc] init];
        _wkNavigationInterceptor.middleMan = self;
    }
    return _wkNavigationInterceptor;
}

#pragma mark - Dealloc
@end
