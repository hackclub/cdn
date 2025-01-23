const logger = require('../config/logger');

const getCdnUrl = () => process.env.AWS_CDN_URL;

const generateUrl = (version, fileName) => {
    return `${getCdnUrl()}/${version}/${fileName}`;
};

const validateToken = (req) => {
    const token = req.headers.authorization?.split('Bearer ')[1];
    if (!token || token !== process.env.API_TOKEN) {
        return {
            status: 401,
            body: {error: 'Unauthorized - Invalid or missing API token'}
        };
    }
    return {status: 200};
};

const validateRequest = (req) => {
    // First check token
    const tokenCheck = validateToken(req);
    if (tokenCheck.status !== 200) {
        return tokenCheck;
    }

    // Then check method (copied the thing from old api maybe someone is insane and uses the status and not the code)
    if (req.method === 'OPTIONS') {
        return {status: 204, body: {status: 'YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED.'}};
    }
    if (req.method !== 'POST') {
        return {
            status: 405,
            body: {error: 'Method not allowed, use POST'}
        };
    }
    return {status: 200};
};

module.exports = {
    validateRequest,
    validateToken,
    generateUrl,
    getCdnUrl
};
