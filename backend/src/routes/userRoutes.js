const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/authMiddleware');
const {
  getProfileHandler,
  updateProfileHandler,
  deleteAccountHandler,
} = require('../controllers/userController');

router.use(requireAuth);

router.get('/profile', getProfileHandler);
router.put('/profile', updateProfileHandler);
router.delete('/account', deleteAccountHandler);

module.exports = router;
