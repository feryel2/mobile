const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const User = require('../models/User');
const PasswordResetCode = require('../models/PasswordResetCode');
const controller = require('../controllers/passwordResetController');

function stub(t, object, name, implementation) {
  const original = object[name];
  object[name] = implementation;
  t.after(() => {
    object[name] = original;
  });
}

function setEnvironment(t, name, value) {
  const original = process.env[name];
  process.env[name] = value;
  t.after(() => {
    if (original === undefined) delete process.env[name];
    else process.env[name] = original;
  });
}

function response() {
  return {
    statusCode: 200,
    body: null,
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

function makeHash(email, code, secret) {
  return crypto.createHmac('sha256', secret)
    .update(`${email}:${code}`)
    .digest('hex');
}

test('password reset request does not reveal whether an account exists', async (t) => {
  setEnvironment(t, 'SMTP_HOST', 'smtp.test');
  setEnvironment(t, 'SMTP_PORT', '587');
  setEnvironment(t, 'SMTP_USER', 'test@example.com');
  setEnvironment(t, 'SMTP_PASS', 'test-password');
  stub(t, User, 'exists', async () => null);
  stub(t, PasswordResetCode, 'findOneAndUpdate', async () => {
    assert.fail('must not create a reset code for an unknown account');
  });

  const res = response();
  await controller.sendCode({
    ip: `unknown-${crypto.randomUUID()}`,
    body: { email: 'missing@example.com' }
  }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.match(res.body.message, /Si un compte correspond/);
});

test('incorrect password reset code increments its attempt count', async (t) => {
  const email = 'client@example.com';
  const secret = 'unit-test-password-reset-secret';
  setEnvironment(t, 'PASSWORD_RESET_SECRET', secret);
  const record = {
    _id: 'reset-id',
    codeHash: makeHash(email, '123456', secret),
    expiresAt: new Date(Date.now() + 60_000),
    attempts: 0
  };
  stub(t, PasswordResetCode, 'findOne', async () => record);
  let update;
  stub(t, PasswordResetCode, 'updateOne', async (...args) => {
    update = args;
    return { modifiedCount: 1 };
  });

  const res = response();
  await controller.resetPassword({
    body: { email, code: '654321', newPassword: 'new-password' }
  }, res);

  assert.equal(res.statusCode, 400);
  assert.equal(update[1].$inc.attempts, 1);
});

test('valid password reset code changes the password and is consumed', async (t) => {
  const email = 'client@example.com';
  const code = '123456';
  const secret = 'unit-test-password-reset-secret';
  setEnvironment(t, 'PASSWORD_RESET_SECRET', secret);
  const record = {
    _id: 'reset-id',
    codeHash: makeHash(email, code, secret),
    expiresAt: new Date(Date.now() + 60_000),
    attempts: 0
  };
  const user = {
    password: 'old-password',
    async save() {
      this.saved = true;
    }
  };
  stub(t, PasswordResetCode, 'findOne', async () => record);
  stub(t, User, 'findOne', async () => user);
  let consumedQuery;
  stub(t, PasswordResetCode, 'deleteOne', async (query) => {
    consumedQuery = query;
    return { deletedCount: 1 };
  });

  const res = response();
  await controller.resetPassword({
    body: { email, code, newPassword: 'new-password' }
  }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(user.password, 'new-password');
  assert.equal(user.saved, true);
  assert.equal(consumedQuery._id, record._id);
});
