// Make the CDN URL

function generateFileUrl(userDir, uniqueFileName) {
    const cdnUrl = process.env.B2_CDN_URL;
    return `${cdnUrl}/${userDir}/${uniqueFileName}`;
}

module.exports = {generateFileUrl};