const express = require('express');
const router = express.Router();
const { authAdmin } = require('../middleware/auth');
const adminServersController = require('../controllers/admin-servers');

router.get('/servers-profiles', authAdmin, adminServersController.getServerProfiles);
router.get('/servers-profiles/:id', authAdmin, adminServersController.getServerById);
router.post('/servers-profiles', authAdmin, adminServersController.createServerProfile);
router.patch('/servers-profiles/:id', authAdmin, adminServersController.updateServerProfile);
router.delete('/servers-profiles/:id', authAdmin, adminServersController.deleteServerProfile);

module.exports = router;

