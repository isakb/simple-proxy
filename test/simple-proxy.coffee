helpers = require './lib/helpers'

POST_DATA =
  test: true
  whatever: false
  nested:
    x: 1
    y: 2

{assertRequestProxied} = helpers

describe 'simple-proxy', ->
  ['http:', 'https:'].forEach (protocol) ->

    describe "proxy-passing to a dummy #{protocol} server", ->

      before (done) -> helpers.startTestServers done, protocol: protocol

      after (done) -> helpers.stopTestServers done

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

