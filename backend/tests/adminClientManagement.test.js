const test = require('node:test');
const assert = require('node:assert/strict');
const User = require('../models/User');
const userController = require('../controllers/userController');

function stub(t, object, name, implementation) {
  const original = object[name];
  object[name] = implementation;
  t.after(() => {
    object[name] = original;
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

function client() {
  return {
    fullname: 'Alex Martin',
    phone: '+33123456789',
    role: 'client',
    status: 'active',
    driverLicense: { number: '' },
    async save() {
      this.saved = true;
    }
  };
}

test('admin client update validates and persists editable fields', async (t) => {
  const user = client();
  stub(t, User, 'findOne', async () => user);

  const res = response();
  await userController.updateClientByAdmin({
    params: { id: '507f1f77bcf86cd799439011' },
    body: {
      fullname: '  Alex Martin  ',
      phone: '+33 (6) 12-34-56-78',
      driverLicenseNumber: ' DL-123 '
    }
  }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(user.fullname, 'Alex Martin');
  assert.equal(user.phone, '+33 (6) 12-34-56-78');
  assert.equal(user.driverLicense.number, 'DL-123');
  assert.equal(user.status, 'pending_approval');
  assert.equal(user.saved, true);
});

test('admin client update refuses email changes outside the verification flow', async (t) => {
  let queried = false;
  stub(t, User, 'findOne', async () => {
    queried = true;
    return client();
  });

  const res = response();
  await userController.updateClientByAdmin({
    params: { id: '507f1f77bcf86cd799439011' },
    body: { email: 'new@example.com' }
  }, res);

  assert.equal(res.statusCode, 400);
  assert.equal(queried, false);
  assert.match(res.body.message, /vérification/i);
});

test('admin client update rejects malformed phone numbers', async (t) => {
  const user = client();
  stub(t, User, 'findOne', async () => user);

  const res = response();
  await userController.updateClientByAdmin({
    params: { id: '507f1f77bcf86cd799439011' },
    body: { phone: '123456abc' }
  }, res);

  assert.equal(res.statusCode, 400);
  assert.equal(user.saved, undefined);
});

test('admin client creation validates fields before querying the database', async (t) => {
  let queried = false;
  stub(t, User, 'findOne', async () => {
    queried = true;
    return null;
  });

  const res = response();
  await userController.createClientByAdmin({
    body: {
      fullname: 'A',
      email: 'not-an-email',
      password: '123',
      phone: '123456abc'
    }
  }, res);

  assert.equal(res.statusCode, 400);
  assert.equal(queried, false);
});
