// CORS for the local Flutter history preview only; this is not authentication.
const allowedOrigin = 'http://localhost:7357';

function reservationHistoryCors(req, res, next) {
  if (process.env.NODE_ENV === 'development' && req.method === 'GET') {
    // Include this even for other/no origins so caches keep responses separate.
    res.vary('Origin');
    const address = req.socket.remoteAddress;
    const isLocalRequest = address === '127.0.0.1'
      || address === '::1' || address === '::ffff:127.0.0.1';
    if (isLocalRequest && req.get('Origin') === allowedOrigin) {
      res.set('Access-Control-Allow-Origin', allowedOrigin);
    }
  }
  // Existing controller checks still decide whether the request is permitted.
  next();
}

module.exports = reservationHistoryCors;
