/* eslint-disable no-console */
/* eslint-disable class-methods-use-this */
/* eslint-disable no-param-reassign */

const url = require('url');
const http = require('http');
const https = require('https');
const events = require('events');

class Proxy extends events.EventEmitter {
  constructor(proxyURI, options = {}) {
    super();
    this.logging = options.logging != null ? options.logging : false;
    this.timeout = options.timeout != null ? options.timeout : 0;
    this.agent = options.agent != null ? options.agent : undefined;
    this.preserveHost =
      options.preserveHost != null ? options.preserveHost : false;
    this.rejectUnauthorized =
      options.rejectUnauthorized != null ? options.rejectUnauthorized : true;

    const { protocol, hostname, port, pathname } = url.parse(proxyURI);

    this.protocol = protocol;
    this.hostname = hostname;
    this.port = port;

    // We concatenate with req.url later; no trailing slash is desired:
    this.pathname = pathname.replace(/\/$/, '');

    if (this.protocol === 'https:') {
      this.requestLib = https;
      if (!this.port) {
        this.port = 443;
      }
    } else if (this.protocol === 'http:') {
      this.requestLib = http;
      if (!this.port) {
        this.port = 80;
      }
    } else {
      throw new Error(`Unsupported protocol: ${this.protocol}`);
    }
  }

  server(req, res) {
    const options = {
      host: this.hostname,
      path: this.pathname + req.url,
      port: this.port,
      method: req.method,
      headers: req.headers,
      agent: this.agent,
      rejectUnauthorized: this.rejectUnauthorized,
    };

    if (!this.preserveHost) {
      options.headers.host = this.hostname;
    }

    const proxyRequest = this.requestLib.request(options, proxyResponse =>
      this.onProxyResponse(proxyResponse, res, options),
    );

    if (this.timeout) {
      proxyRequest.setTimeout(this.timeout, error => {
        error = `Request timed out after ${this.timeout} ms.`;
        this.emit('proxyTimeout', error, options);
        this.onProxyTimeout(error, options, res);
        proxyRequest.abort();
      });
    }

    proxyRequest.on('error', error => {
      this.emit('proxyError', error, options);
      this.onProxyError(error, options, res);
    });

    if (req.headers['content-length']) {
      this.processRequestData(proxyRequest, req, options);
    } else {
      proxyRequest.end();
    }
  }

  processRequestData(proxyRequest, req, options) {
    let requestData = '';

    req.on('data', chunk => {
      requestData += chunk;
      proxyRequest.write(chunk, 'binary');
    });

    req.on('end', () => {
      this.emit('requestEnd', requestData, options);
      proxyRequest.end();
    });
  }

  onProxyResponse(proxyResponse, res, options) {
    res.writeHead(proxyResponse.statusCode, proxyResponse.headers);
    let responseData = '';

    proxyResponse.on('data', chunk => {
      responseData += chunk;
      res.write(chunk, 'binary');
    });

    proxyResponse.on('end', () => {
      if (this.logging) {
        console.error(`Proxy end: ${responseData}`);
      }
      this.emit('proxyResponse', responseData, options);
      res.end();
    });
  }

  onProxyTimeout(err, options, res) {
    if (this.logging) {
      console.error(`Proxy timeout: ${err}`);
    }
    res.writeHead(504, 'Gateway Timeout');
    res.end();
  }

  onProxyError(err, options, res) {
    if (this.logging) {
      console.error(`Proxy error: ${err}, ${JSON.stringify(options)}`);
    }
    res.writeHead(502, 'Bad Gateway');
    res.end();
  }
}

function proxyPass(proxyURI, options = {}) {
  const p = new Proxy(proxyURI, options);

  return p.server.bind(p);
}

module.exports = {
  proxyPass,
  Proxy,
};
