(function(){
  var url, http, https, events, Proxy;
  url = require('url');
  http = require('http');
  https = require('https');
  events = require('events');
  exports.proxyPass = function(proxyURI, options){
    options == null && (options = {});
    return new Proxy(proxyURI, options).server;
  };
  exports.Proxy = Proxy = (function(superclass){
    var prototype = extend$((import$(Proxy, superclass).displayName = 'Proxy', Proxy), superclass).prototype, constructor = Proxy;
    function Proxy(proxyURI, arg$){
      var ref$, timeout, agent;
      timeout = (ref$ = arg$.timeout) != null ? ref$ : 0, agent = (ref$ = arg$.agent) != null ? ref$ : false;
      this.onProxyError = bind$(this, 'onProxyError', prototype);
      this.server = bind$(this, 'server', prototype);
      this.timeout = timeout;
      this.agent = agent;
      ref$ = url.parse(proxyURI), this.protocol = ref$.protocol, this.hostname = ref$.hostname, this.port = ref$.port, this.pathname = ref$.pathname;
      this.pathname = this.pathname.replace(/\/$/, '');
      if (this.protocol === 'https:') {
        this.requestLib = https;
        this.port || (this.port = 443);
      } else if (this.protocol === 'http:') {
        this.requestLib = http;
        this.port || (this.port = 80);
      } else {
        throw new Error("Unsupported protocol: " + this.protocol);
      }
    }
    prototype.server = function(req, res, next){
      var options, proxyRequest, requestData, this$ = this;
      options = {
        host: this.hostname,
        path: this.pathname + req.url,
        port: this.port,
        method: req.method,
        headers: req.headers,
        agent: this.agent
      };
      proxyRequest = this.requestLib.request(options, function(proxyResponse){
        return this$.onProxyResponse(proxyResponse, res);
      });
      if (this.timeout) {
        proxyRequest.setTimeout(this.timeout, function(error){
          this$.emit('proxyTimeout', error, options);
          this$.onProxyTimeout(error, options, res);
          proxyRequest.abort();
        });
      }
      proxyRequest.on('error', function(error){
        this$.emit('proxyError', error, options);
        return this$.onProxyError(error, options, res);
      });
      proxyRequest.on('close', function(){
        this.emit('proxyClose', null, options);
        return this.onProxyError('close', options);
      });
      if (req.headers['content-length']) {
        requestData = '';
        req.on('data', function(chunk){
          requestData += chunk;
          return proxyRequest.write(chunk, 'binary');
        });
        return req.on('end', function(){
          this$.emit('requestEnd', requestData, options);
          return proxyRequest.end(requestData);
        });
      } else {
        return proxyRequest.end();
      }
    };
    prototype.onProxyResponse = function(proxyResponse, res){
      var responseData;
      res.writeHead(proxyResponse.statusCode, proxyResponse.headers);
      responseData = '';
      proxyResponse.on('data', function(chunk){
        responseData += chunk;
        return res.write(chunk, 'binary');
      });
      proxyResponse.on('end', function(){
        this.emit('proxyResponse', {
          responseBody: responseData
        });
        return res.end();
      });
    };
    prototype.onProxyTimeout = function(err, options, res){
      console.error("Proxy timeout. " + err);
      res.writeHead(504, 'Gateway Timeout');
      res.end();
    };
    prototype.onProxyError = function(err, options, res){
      console.error(err, options);
      res.writeHead(502, 'Bad Gateway');
      res.end();
    };
    return Proxy;
  }(events.EventEmitter));
  function bind$(obj, key, target){
    return function(){ return (target || obj)[key].apply(obj, arguments) };
  }
  function extend$(sub, sup){
    function fun(){} fun.prototype = (sub.superclass = sup).prototype;
    (sub.prototype = new fun).constructor = sub;
    if (typeof sup.extended == 'function') sup.extended(sub);
    return sub;
  }
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
