const express = require('express');
const multer = require('multer');
const router = express.Router();
const upload = multer({dest: 'uploads/'});

router.post('/upload', upload.single('file'), (req, res) => {
    if (!req.file) {
        return res.status(400).send('No file uploaded.');
    }

    // Handle the uploaded file
    console.log('Uploaded file:', req.file);

    res.send('File uploaded successfully.');
});

module.exports = router;
