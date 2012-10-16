http        = require 'http'
assert      = require 'assert'
helpers     = require './lib/helpers'
simpleProxy = require '../lib/simple-proxy'

POST_DATA =
  test: true
  whatever: false
  nested:
    x: 1
    y: 2


{assertRequestProxied, request} = helpers


describe 'simple-proxy', ->

  ['http', 'https'].forEach (protocol) ->

    describe "targeting an #{protocol.toUpperCase()} server", ->
      target = null
      proxyServer = null

      before ->
        target = helpers.startTargetServer(protocol)

      after ->
        target.close()


      describe "#proxyPass() - high-level helper", ->

        before ->
          targetURI = "#{protocol}://localhost:#{target.address().port}"
          proxyServer = http.createServer(simpleProxy.proxyPass(targetURI))
          proxyServer.listen(helpers.proxyPort())

        after ->
          proxyServer.close()

        assertRequestProxied method: 'GET'

        assertRequestProxied method: 'PUT'

        assertRequestProxied method: 'DELETE'

        assertRequestProxied
          method: 'HEAD',
          expect: body: undefined

        assertRequestProxied
          method: 'POST',
          title: "proxies POST request with body"
          request:
            body: JSON.stringify(POST_DATA)
          expect:
            body: JSON.stringify(received: POST_DATA)



      describe "#Proxy() - intance of Proxy class", ->
        proxy = null
        dummyJSON = hello: 'world'
        dummyString = "2434234 foo: 'bar' 32123"

        beforeEach ->
          targetURI = "#{protocol}://localhost:#{target.address().port}"
          proxy = new simpleProxy.Proxy(targetURI)
          proxyServer = http.createServer(proxy.server.bind(proxy))
          proxyServer.listen helpers.proxyPort()

        afterEach ->
          proxyServer.close()


        assertRequestProxied method: 'GET'

        assertRequestProxied method: 'PUT'

        assertRequestProxied method: 'DELETE'

        assertRequestProxied
          method: 'HEAD',
          expect: body: undefined

        assertRequestProxied
          method: 'POST',
          title: "proxies POST request with body"
          request:
            body: JSON.stringify(POST_DATA)
          expect:
            body: JSON.stringify(received: POST_DATA)


        describe "events", ->
          it 'triggers requestEnd event after posting data', (done) ->

            proxy.on 'requestEnd', (requestBody) ->
              assert.equal(requestBody, dummyString)
              done()

            request
              method: 'POST'
              request:
                headers: 'content-type': 'text/plain'
                body: dummyString
            , ->

          it 'triggers proxyResponse event after received data', (done) ->
            proxy.on 'proxyResponse', (responseBody) ->
              assert.deepEqual(responseBody, helpers.dummyResponseBody())
              done()
            request method: 'GET', ->


        describe "hooks", ->
          it 'calls processRequestData when posting data', (done) ->
            proxy.processRequestData = ->
              done()

            request
              method: 'POST'
            , ->

          it 'calls onProxyResponse when receiving data', (done) ->
            proxy.onProxyResponse = -> done()
            request method: 'GET', ->


      describe "targeting a server that doesn't exist", ->
        before ->
          targetURI = "#{protocol}://99.99.99.99:9999"
          fun = simpleProxy.proxyPass(targetURI, {timeout: 10})
          proxyServer = http.createServer(fun)
          proxyServer.listen(helpers.proxyPort())

        after ->
          proxyServer.close()

        assertRequestProxied
        it 'responds with HTTP 504 - Gateway Timeout', (done) ->
          request method: 'GET', (err, res, body) ->
            assert.equal(res.statusCode, 504)
            done()
