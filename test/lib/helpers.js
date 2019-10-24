/* eslint-disable no-param-reassign */

const fs = require('fs');
const http = require('http');
const https = require('https');
const assert = require('assert');

const requestLib = require('request');

const PROXY_PORT = 7777;
const PROXY_BASE_URL = `http://localhost:${PROXY_PORT}`;
const DUMMY_RESPONSE_BODY = JSON.stringify({ ok: 'yes' });

const TARGET_PORT = {
  http: 5555,
  https: 6443,
};

const HTTPS_OPTIONS = {
  key: fs.readFileSync(`${__dirname}/../myssl.key`).toString(),
  cert: fs.readFileSync(`${__dirname}/../myssl.crt`).toString(),
};

function proxyPort() {
  return PROXY_PORT;
}
exports.proxyPort = proxyPort;

function makeRequest({ path, method, request }, callback) {
  if (!path) {
    path = '/foo/bar';
  }
  if (!method) {
    method = 'POST';
  }
  if (!request) {
    request = {};
  }
  if (!request.url) {
    request.url = `${PROXY_BASE_URL}${path}`;
  }
  if (!request.headers) {
    request.headers = {};
  }

  if (request.body) {
    if (!request.headers['Content-Type']) {
      request.headers['Content-Type'] = 'application/json';
    }
  }
  request.headers['dummy-header'] = 'dummy-header';

  const m = method.toLowerCase().replace('delete', 'del');

  return requestLib[m](request, callback);
}

function dummyResponseBody() {
  return DUMMY_RESPONSE_BODY;
}

function makeDummyResponse(responseTime = 0) {
  return function dummeResponse(req, res) {
    let data = '';

    req.on('data', chunk => {
      data += chunk;
    });

    req.on('end', () => {
      const response = (() => {
        if (data) {
          let d;

          try {
            d = JSON.parse(data);
          } catch (e) {
            d = data;
          }

          return JSON.stringify({ received: d });
        }

        return DUMMY_RESPONSE_BODY;
      })();

      function respond() {
        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Content-Length': response.length,
          'dummy-header': 'dummy-header',
        });

        res.end(response);
      }

      setTimeout(respond, responseTime);
    });
  };
}

function startTargetServer(protocol, responseTime) {
  if (!/https?/.test(protocol)) {
    throw new Error(`Bad protocol ${protocol}`);
  }

  const port = TARGET_PORT[protocol];

  const s =
    protocol === 'https'
      ? https.createServer(HTTPS_OPTIONS, makeDummyResponse(responseTime))
      : http.createServer(makeDummyResponse(responseTime));

  return s.listen(port);
}

function assertRequestProxied({ path, method, title, expect, request }) {
  if (!title) {
    title = `proxies ${method} request`;
  }
  if (!expect) {
    expect = {};
  }
  if (method !== 'HEAD') {
    if (!expect.body) {
      expect.body = DUMMY_RESPONSE_BODY;
    }
  }
  if (!expect.headers) {
    expect.headers = { 'content-type': 'application/json' };
  }
  if (!expect.code) {
    expect.code = 200;
  }

  /* global it */
  it(title, done =>
    makeRequest({ path, method, request }, (err, res, body) => {
      assert.equal(err, null);
      Object.values(expect.headers).forEach(header => {
        assert.equal(res.headers[header], expect.headers[header]);
      });
      if (expect.code) {
        assert.equal(res.statusCode, expect.code);
      }
      if (expect.body) {
        assert.deepEqual(body, expect.body);
      }

      done();
    }),
  );
}

module.exports = {
  assertRequestProxied,
  dummyResponseBody,
  makeDummyResponse,
  request: makeRequest,
  proxyPort,
  startTargetServer,
};
