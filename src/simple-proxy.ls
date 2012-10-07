url    = require \url
http   = require \http
https  = require \https
events = require \events


exports.proxyPass = (proxyURI, options={}) ->
  new Proxy(proxyURI, options).server


class exports.Proxy extends events.EventEmitter
  (proxyURI, {timeout = 0, agent = false}) ->
    @timeout = timeout
    @agent   = agent

    @{protocol, hostname, port, pathname} = url.parse(proxyURI)

    # We concatenate with req.url later; no trailing slash is desired:
    @pathname .= replace /\/$/, ''

    if @protocol == 'https:'
      @requestLib = https
      @port or= 443
    else if @protocol == 'http:'
      @requestLib = http
      @port or= 80
    else
      throw new Error "Unsupported protocol: #{@protocol}"


  server: (req, res, next) ~>
    options =
      host    : @hostname
      path    : @pathname + req.url
      port    : @port
      method  : req.method
      headers : req.headers
      agent   : @agent

    proxyRequest = @requestLib.request options, (proxyResponse) ~>
      @onProxyResponse proxyResponse, res

    if @timeout
      proxyRequest.setTimeout @timeout, (error) ~>
        @emit \proxyTimeout, error, options
        @onProxyTimeout error, options, res
        proxyRequest.abort!
        return

    proxyRequest.on \error, (error) ~>
      @emit \proxyError, error, options
      @onProxyError error, options, res

    proxyRequest.on \close, ->
      @emit \proxyClose, null, options
      @onProxyError 'close', options

    if req.headers['content-length']
      requestData = ''

      req.on \data, (chunk) ~>
        requestData += chunk
        proxyRequest.write chunk, \binary

      req.on \end, ~>
        @emit \requestEnd, requestData, options
        proxyRequest.end requestData

    else
      proxyRequest.end!


  onProxyResponse: !(proxyResponse, res) ->
    res.writeHead proxyResponse.statusCode, proxyResponse.headers
    responseData = ''

    proxyResponse.on \data, (chunk) ->
      responseData += chunk
      res.write chunk, \binary

    proxyResponse.on \end, ->
      @emit \proxyResponse, responseBody: responseData
      res.end!


  onProxyTimeout: !(err, options, res) ->
    console.error "Proxy timeout. #err"
    res.writeHead 504, 'Gateway Timeout'
    res.end!


  onProxyError: !(err, options, res) ~>
    console.error err, options
    res.writeHead 502, 'Bad Gateway'
    res.end!
