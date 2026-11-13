const router = require('express').Router();
const controller = require('../controllers/vehicleController');
const { protect, authorizeAdmin } = require('../middlewares/auth');

router.get('/available', controller.listAvailable);
router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.post('/', protect, authorizeAdmin, controller.create);
router.put('/:id', protect, authorizeAdmin, controller.update);
router.delete('/:id', protect, authorizeAdmin, controller.remove);

module.exports = router;
