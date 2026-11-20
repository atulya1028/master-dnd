const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/authMiddleware');
const {
  getProfilesHandler,
  createProfileHandler,
  updateProfileHandler,
  deleteProfileHandler,
  toggleMasterDndHandler,
  getRulesHandler,
  getInsightsHandler,
} = require('../controllers/dndController');

router.use(requireAuth);

router.get('/profiles', getProfilesHandler);
router.post('/profiles', createProfileHandler);
router.put('/profiles/:id', updateProfileHandler);
router.delete('/profiles/:id', deleteProfileHandler);

router.post('/toggle', toggleMasterDndHandler);
router.get('/rules', getRulesHandler);
router.get('/insights', getInsightsHandler);

module.exports = router;
