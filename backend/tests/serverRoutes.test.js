const test = require('node:test');
const assert = require('node:assert/strict');
const { app } = require('../server');

test('integrated vehicle writes and reservation creation require authentication', async (context) => {
  const server = app.listen(0);
  context.after(() => new Promise((resolve) => server.close(resolve)));
  await new Promise((resolve) => server.once('listening', resolve));

  const { port } = server.address();
  for (const [path, method] of [
    ['/api/users/profile/email', 'PUT'],
    ['/api/reservations/admin', 'GET'],
    ['/api/vehicles', 'POST'],
    ['/api/vehicles/507f1f77bcf86cd799439011', 'PUT'],
    ['/api/reservations', 'POST']
  ]) {
    const response = await fetch(`http://127.0.0.1:${port}${path}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      ...(method === 'GET' ? {} : { body: '{}' })
    });
    assert.equal(response.status, 401, `${method} ${path} must require a JWT`);
  }
});

test('password reset endpoints are public and validate their input', async (context) => {
  const server = app.listen(0);
  context.after(() => new Promise((resolve) => server.close(resolve)));
  await new Promise((resolve) => server.once('listening', resolve));

  const { port } = server.address();
  const invalidRequests = [
    ['/api/users/password-reset-codes', { email: 'not-an-email' }],
    ['/api/users/password-resets', {}]
  ];

  for (const [path, body] of invalidRequests) {
    const response = await fetch(`http://127.0.0.1:${port}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    assert.equal(response.status, 400, `${path} should validate before database access`);
  }
});
