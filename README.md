# URLProtocol
URL拦截器


[网络优化](https://blog.cnbang.net/category/tech/)
[劫持](http://www.sohu.com/a/52971352_132010)
[劫持场景](https://www.sojson.com/blog/281.html)
[劫持场景](http://www.itts-union.com/2706.html)


[protocol包括官方代码](https://github.com/Draveness/analyze/blob/master/contents/OHHTTPStubs/iOS%20%E5%BC%80%E5%8F%91%E4%B8%AD%E4%BD%BF%E7%94%A8%20NSURLProtocol%20%E6%8B%A6%E6%88%AA%20HTTP%20%E8%AF%B7%E6%B1%82.md)

[NSURLSession使用说明及后台工作流程分析](https://www.cnblogs.com/biosli/p/iOS_Network_URL_Session.html)


####步骤
1. 注册拦截`[NSURLProtocol registerClass:self];` 
2. 过滤请求: YES下一步 `+canInitWithRequest:`  `+canInitWithTask:`
3. 规范化请求: `+canonicalRequestForRequest:`
4. 初始化NSURLProtocol: `-initWithRequest:cachedResponse:client:`
5. 发请求: `-startLoading`
6. `-stopLoading`
7. `-dealloc`