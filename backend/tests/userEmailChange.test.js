const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const User = require('../models/User');
const EmailVerification = require('../models/EmailVerification');
const userController = require('../controllers/userController');

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

function makeVerification(email, code, secret) {
  return {
    _id: 'verification-id',
    codeHash: makeHash(email, code, secret),
    expiresAt: new Date(Date.now() + 60_000),
    attempts: 0,
    async save() {
      this.saved = true;
    }
  };
}

test('email change verifies the new address before updating the account', async (t) => {
  const email = 'new@example.com';
  const code = '123456';
  const secret = 'email-change-test-secret';
  setEnvironment(t, 'EMAIL_VERIFICATION_SECRET', secret);
  const verification = makeVerification(email, code, secret);
  const user = {
    _id: 'user-id',
    email: 'old@example.com',
    emailVerified: false,
    async save() {
      this.saved = true;
    }
  };
  stub(t, User, 'findOne', () => ({ select: async () => null }));
  stub(t, EmailVerification, 'findOne', async () => verification);
  let deletedVerification;
  stub(t, EmailVerification, 'deleteOne', async (query) => {
    deletedVerification = query;
    return { deletedCount: 1 };
  });

  const res = response();
  await userController.changeEmail({
    user,
    body: { email: ' New@Example.com ', code }
  }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(user.email, email);
  assert.equal(user.emailVerified, true);
  assert.equal(user.saved, true);
  assert.deepEqual(deletedVerification, { _id: verification._id });
});

test('incorrect email-change code increments attempts without changing the account', async (t) => {
  const email = 'new@example.com';
  const secret = 'email-change-test-secret';
  setEnvironment(t, 'EMAIL_VERIFICATION_SECRET', secret);
  const verification = makeVerification(email, '123456', secret);
  const user = {
    _id: 'user-id',
    email: 'old@example.com',
    async save() {
      this.saved = true;
    }
  };
  stub(t, User, 'findOne', () => ({ select: async () => null }));
  stub(t, EmailVerification, 'findOne', async () => verification);

  const res = response();
  await userController.changeEmail({
    user,
    body: { email, code: '654321' }
  }, res);

  assert.equal(res.statusCode, 400);
  assert.equal(verification.attempts, 1);
  assert.equal(verification.saved, true);
  assert.equal(user.email, 'old@example.com');
  assert.equal(user.saved, undefined);
});

test('profile update cannot bypass email-change verification', async (t) => {
  const user = {
    _id: 'user-id',
    email: 'old@example.com',
    async save() {
      this.saved = true;
    }
  };
  stub(t, User, 'findById', async () => user);

  const res = response();
  await userController.updateProfile({
    user,
    body: { email: 'new@example.com' }
  }, res);

  assert.equal(res.statusCode, 400);
  assert.match(res.body.message, /Vérifiez la nouvelle adresse/);
  assert.equal(user.saved, undefined);
});
