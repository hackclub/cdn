const B2 = require('backblaze-b2');
const logger = require('./config/logger');

const b2 = new B2({
    applicationKeyId: process.env.B2_APP_KEY_ID,
    applicationKey: process.env.B2_APP_KEY
});

async function uploadToBackblaze(userDir, uniqueFileName, buffer) {
    try {
        await b2.authorize();
        const {data} = await b2.getUploadUrl({
            bucketId: process.env.B2_BUCKET_ID
        });

        await b2.uploadFile({
            uploadUrl: data.uploadUrl,
            uploadAuthToken: data.authorizationToken,
            fileName: `${userDir}/${uniqueFileName}`,
            data: buffer
        });

        return true;
    } catch (error) {
        logger.error('B2 upload failed:', error.message);
        return false;
    }
}

module.exports = {uploadToBackblaze};

// So easy i love it!