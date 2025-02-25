const messages = {
    success: {
        singleFile: "Hey <@{userId}>, here's your link:",
        multipleFiles: "Hey <@{userId}>, here are your links:",
        alternateSuccess: [
            "thanks!",
            "thanks, i'm gonna sell these to adfly!",
            "tysm!",
            "file away!"
        ]
    },
    fileTypes: {
        gif: [
            "_gif_ that file to me and i'll upload it",
            "_gif_ me all all your files!"
        ],
        heic: [
            "What the heic???"
        ],
        mov: [
            "I'll _mov_ that to a permanent link for you"
        ],
        html: [
            "Oh, launching a new website?",
            "uwu, what's this site?",
            "WooOOAAah hey! Are you serving a site?",
            "h-t-m-ello :wave:"
        ],
        rar: [
            ".rawr xD",
            "i also go \"rar\" sometimes!"
        ]
    },
    errors: {
        tooBig: {
            messages: [
                "File too big!",
                "That's a chonky file!",
                "_orpheus struggles to lift the massive file_",
                "Sorry, that file's too thicc for me to handle!"
            ],
            images: [
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/2too_big_4.png",
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/3too_big_2.png",
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/4too_big_1.png",
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/6too_big_5.png",
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/7too_big_3.png"
            ]
        },
        generic: {
            messages: [
                "_orpheus sneezes and drops the files on the ground before blowing her nose on a blank jpeg._",
                "_orpheus trips and your files slip out of her hands and into an inconveniently placed sewer grate._",
                "_orpheus accidentally slips the files into a folder in her briefcase labeled \"homework\". she starts sweating profusely._"
            ],
            images: [
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/0generic_3.png",
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/1generic_2.png",
                "https://cloud-3tq9t10za-hack-club-bot.vercel.app/5generic_1.png"
            ]
        }
    }
};

function getRandomItem(array) {
    return array[Math.floor(Math.random() * array.length)];
}

function getFileTypeMessage(fileExtension) {
    const ext = fileExtension.toLowerCase();
    return messages.fileTypes[ext] ? getRandomItem(messages.fileTypes[ext]) : null;
}

function formatErrorMessage(failedFiles, isSizeError = false) {
    const errorType = isSizeError ? messages.errors.tooBig : messages.errors.generic;
    const errorMessage = getRandomItem(errorType.messages);
    const errorImage = getRandomItem(errorType.images);
    
    return [
        errorMessage,
        `Failed files: ${failedFiles.join(', ')}`,
        '',
        `<${errorImage}|image>`
    ].join('\n');
}

function formatSuccessMessage(userId, files, failedFiles = [], sizeFailedFiles = []) {
    const messageLines = [];
    
    const baseMessage = files.length === 1 ? 
        messages.success.singleFile : 
        messages.success.multipleFiles;
    messageLines.push(baseMessage.replace('{userId}', userId), '');

    const fileGroups = new Map();
    files.forEach(file => {
        const ext = file.originalName.split('.').pop();
        const typeMessage = getFileTypeMessage(ext);
        const key = typeMessage || 'noType';
        
        if (!fileGroups.has(key)) {
            fileGroups.set(key, []);
        }
        fileGroups.get(key).push(file);
    });

    fileGroups.forEach((groupFiles, typeMessage) => {
        if (typeMessage !== 'noType') {
            messageLines.push('', typeMessage);
        }
        
        groupFiles.forEach(file => {
            messageLines.push(`• ${file.originalName}: ${file.url}`);
        });
    });

    if (sizeFailedFiles.length > 0) {
        messageLines.push(formatErrorMessage(sizeFailedFiles, true));
    }
    if (failedFiles.length > 0) {
        messageLines.push(formatErrorMessage(failedFiles, false));
    }

    if (files.length > 0) {
        messageLines.push('', `_${getRandomItem(messages.success.alternateSuccess)}_`);
    }

    return messageLines.join('\n');
}

module.exports = {
    messages,
    getFileTypeMessage,
    formatSuccessMessage,
    formatErrorMessage,
    getRandomItem
};
