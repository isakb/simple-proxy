fs                  = require 'fs'
http                = require 'http'
https               = require 'https'
requestLib          = require 'request'
assert              = require 'assert'
simpleProxy         = require '../../lib/simple-proxy'


PROXY_PORT          = 7777
PROXY_BASE_URL      = "http://localhost:#{PROXY_PORT}"
DUMMY_RESPONSE_BODY = JSON.stringify ok: 'yes'

TARGET_PORT         =
  http              : 5555
  https             : 6443

HTTPS_OPTIONS =
  key                 : fs.readFileSync("#{__dirname}/../myssl.key").toString()
  cert                : fs.readFileSync("#{__dirname}/../myssl.crt").toString()


module.exports = self =

  proxyPort: -> PROXY_PORT

  startTargetServer: (protocol) ->
    throw new Error("Bad protocol #{protocol}")  unless /https?/.test(protocol)

    port = TARGET_PORT[protocol]

    s = if protocol == 'https'
      https.createServer HTTPS_OPTIONS, self.dummyResponse
    else
      http.createServer self.dummyResponse

    s.listen(port)


  request: makeRequest = ({path, method, request}, callback) ->
    path            or= '/foo/bar'
    method          or= 'POST'
    request         or= {}
    request.url     or= "#{PROXY_BASE_URL}#{path}"
    request.headers or= {}

    request.headers['Content-Type'] or= 'application/json'  if request.body

    m = method.toLowerCase().replace('delete', 'del')
    requestLib[m] request, callback #(err, res, body)


  assertRequestProxied: ({path, method, title, expect, request}) ->
    title           or= "proxies #{method} request"
    expect          or= {}
    expect.body     or= DUMMY_RESPONSE_BODY  unless method == 'HEAD'
    expect.headers  or= 'content-type': 'application/json'
    expect.code     or= 200

    it title, (done) ->
      makeRequest {path, method, request}, (err, res, body) ->
        assert.equal err, null
        for header, value of expect.headers
          assert.equal res.headers[header], value
        assert.equal res.statusCode, expect.code  if expect.code
        assert.deepEqual body, expect.body  if expect.body
        done()


  dummyResponseBody: -> DUMMY_RESPONSE_BODY

  dummyResponse: (req, res) ->
    @data = ''
    req.on 'data', (chunk) =>
      @data += chunk
    req.on 'end', =>
      response = if @data
        try
          d = JSON.parse(@data)
        catch e
          d = @data
        JSON.stringify(received: d)
      else
        DUMMY_RESPONSE_BODY

      res.writeHead 200,
        'Content-Type': 'application/json'
        'Content-Length': response.length

      res.end response
