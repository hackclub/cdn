// Make the CDN URL

function generateFileUrl(userDir, uniqueFileName) {
    const cdnUrl = process.env.AWS_CDN_URL;
    return `${cdnUrl}/${userDir}/${uniqueFileName}`;
}

module.exports = {generateFileUrl};