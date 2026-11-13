const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const AdminLoginTicket = require('../models/AdminLoginTicket');
const User = require('../models/User');
const userController = require('../controllers/userController');

function response() {
  return {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    }
  };
}

test('admin ticket creation stores only a short-lived hash', async () => {
  const originalDeleteMany = AdminLoginTicket.deleteMany;
  const originalCreate = AdminLoginTicket.create;
  let storedTicket;
  let cleanupFilter;
  AdminLoginTicket.deleteMany = async (filter) => {
    cleanupFilter = filter;
  };
  AdminLoginTicket.create = async (ticket) => {
    storedTicket = ticket;
  };

  try {
    const res = response();
    await userController.createAdminLoginTicket({
      user: { _id: 'admin-id', role: 'admin', status: 'active' }
    }, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.success, true);
    assert.match(res.body.ticket, /^[a-f0-9]{64}$/);
    assert.notEqual(storedTicket.ticketHash, res.body.ticket);
    assert.equal(
      storedTicket.ticketHash,
      crypto.createHash('sha256').update(res.body.ticket).digest('hex')
    );
    assert.equal(storedTicket.userId, 'admin-id');
    assert.ok(storedTicket.expiresAt.getTime() > Date.now());
    assert.ok(storedTicket.expiresAt.getTime() <= Date.now() + 60_000);
    assert.ok(cleanupFilter.expiresAt.$lte instanceof Date);
  } finally {
    AdminLoginTicket.deleteMany = originalDeleteMany;
    AdminLoginTicket.create = originalCreate;
  }
});

test('non-admin accounts cannot create an admin login ticket', async () => {
  const originalCreate = AdminLoginTicket.create;
  AdminLoginTicket.create = () => assert.fail('must not create a ticket');

  try {
    const res = response();
    await userController.createAdminLoginTicket({
      user: { _id: 'client-id', role: 'client', status: 'active' }
    }, res);

    assert.equal(res.statusCode, 403);
    assert.equal(res.body.success, false);
  } finally {
    AdminLoginTicket.create = originalCreate;
  }
});

test('ticket consumption is one-time and issues an admin JWT', async () => {
  const originalFindOneAndDelete = AdminLoginTicket.findOneAndDelete;
  const originalFindById = User.findById;
  const originalSecret = process.env.JWT_SECRET;
  const ticket = 'a'.repeat(64);
  let lookup;
  process.env.JWT_SECRET = 'test-secret-with-at-least-32-characters';
  AdminLoginTicket.findOneAndDelete = async (filter) => {
    lookup = filter;
    return { userId: 'admin-id' };
  };
  User.findById = async () => ({
    _id: 'admin-id',
    role: 'admin',
    status: 'active'
  });

  try {
    const res = response();
    await userController.consumeAdminLoginTicket({ body: { ticket } }, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.success, true);
    assert.equal(
      lookup.ticketHash,
      crypto.createHash('sha256').update(ticket).digest('hex')
    );
    assert.ok(lookup.expiresAt.$gt instanceof Date);
    assert.equal(jwt.verify(res.body.token, process.env.JWT_SECRET).role, 'admin');
  } finally {
    AdminLoginTicket.findOneAndDelete = originalFindOneAndDelete;
    User.findById = originalFindById;
    if (originalSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = originalSecret;
  }
});

test('invalid or previously consumed tickets are rejected', async () => {
  const originalFindOneAndDelete = AdminLoginTicket.findOneAndDelete;
  let queryCount = 0;
  AdminLoginTicket.findOneAndDelete = async () => {
    queryCount += 1;
    return null;
  };

  try {
    const invalid = response();
    await userController.consumeAdminLoginTicket({ body: { ticket: 'invalid' } }, invalid);
    assert.equal(invalid.statusCode, 400);
    assert.equal(queryCount, 0);

    const consumed = response();
    await userController.consumeAdminLoginTicket({
      body: { ticket: 'b'.repeat(64) }
    }, consumed);
    assert.equal(consumed.statusCode, 401);
    assert.equal(consumed.body.success, false);
    assert.equal(queryCount, 1);
  } finally {
    AdminLoginTicket.findOneAndDelete = originalFindOneAndDelete;
  }
});
