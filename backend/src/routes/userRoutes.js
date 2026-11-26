const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/authMiddleware');
const {
  getProfileHandler,
  updateProfileHandler,
  updatePreferencesHandler,
  getContactsHandler,
  addContactHandler,
  deleteContactHandler,
  deleteAccountHandler,
} = require('../controllers/userController');

router.use(requireAuth);

router.get('/profile', getProfileHandler);
router.put('/profile', updateProfileHandler);
router.put('/preferences', updatePreferencesHandler);
router.get('/contacts', getContactsHandler);
router.post('/contacts', addContactHandler);
router.delete('/contacts/:contactId', deleteContactHandler);
router.delete('/account', deleteAccountHandler);

module.exports = router;
