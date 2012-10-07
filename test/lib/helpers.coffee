fs                  = require 'fs'
http                = require 'http'
https               = require 'https'
async               = require 'async'
requestLib          = require 'request'
assert              = require 'assert'
simpleProxy         = require '../../lib/simple-proxy'

HTTP_TARGET_PORT    = 5555
HTTPS_TARGET_PORT   = 6443
PROXY_PORT          = 7777
PROXY_BASE_URL      = "http://localhost:#{PROXY_PORT}"
DUMMY_RESPONSE_BODY       = JSON.stringify ok: 'yes'

servers =
  mockHttp: null
  mockHttps: null
  simpleProxy: null

HTTPS_OPTIONS =
  key                 : fs.readFileSync("#{__dirname}/../myssl.key").toString()
  cert                : fs.readFileSync("#{__dirname}/../myssl.crt").toString()


module.exports =

  startTestServers: (callback, options = {}) ->
    {protocol} = options
    throw new TypeError('Bad protocol')  unless /https?:/.test(protocol)

    async.series [
      (next) -> startTestSimpleProxyServer(next, protocol),
      if protocol == 'https:'
        (next) -> startMockHttpsServer(next)
      else
        (next) -> startMockHttpServer(next)
    ], callback


  stopTestServers: (callback) ->
    for own name, server of servers
      if server
        server.close()
        delete servers[name]
    callback()


  assertRequestProxied: ({path, method, title, expect, request}) ->
    path            or= '/foo/bar'
    method          or= 'POST'
    title           or= "proxies #{method} request"
    request         or= {}
    request.url     or= "#{PROXY_BASE_URL}#{path}"
    request.headers or= {}
    expect          or= {}
    expect.body     or= DUMMY_RESPONSE_BODY  unless method == 'HEAD'
    expect.headers  or= 'content-type': 'application/json'
    expect.code     or= 200

    request.headers['Content-Type'] or= 'application/json'  if request.body

    it title, (done) ->
      m = method.toLowerCase().replace('delete', 'del')
      requestLib[m] request, (err, res, body) ->
        assert.equal err, null
        for header, value of expect.headers
          assert.equal res.headers[header], value
        assert.equal res.statusCode, expect.code  if expect.code
        assert.deepEqual body, expect.body  if expect.body
        done()



#
# Internal
#

startTestSimpleProxyServer = (next, protocol = 'http:', port = PROXY_PORT) ->
  targetPort = if protocol == 'https:'
    HTTPS_TARGET_PORT
  else
    HTTP_TARGET_PORT
  servers.simpleProxy = http.createServer(
    simpleProxy.proxyPass("#{protocol}//localhost:#{targetPort}"))
  servers.simpleProxy.listen port
  next()


startMockHttpServer = (next) ->
  servers.mockHttp = http.createServer dummyResponse
  servers.mockHttp.listen HTTP_TARGET_PORT
  next()


startMockHttpsServer = (next) ->
  servers.mockHttps = https.createServer HTTPS_OPTIONS, dummyResponse
  servers.mockHttps.listen HTTPS_TARGET_PORT
  next()


dummyResponse = (req, res) ->
  @data = ''
  req.on 'data', (chunk) =>
    @data += chunk
  req.on 'end', =>
    response = if @data
      JSON.stringify(received: JSON.parse(@data))
    else
      DUMMY_RESPONSE_BODY

    res.writeHead 200,
      'Content-Type': 'application/json'
      'Content-Length': response.length

    res.end response
