// Module global pour accès facile à Socket.IO
let io = null;

function setIO(ioInstance) {
    io = ioInstance;
}

function getIO() {
    if (!io) {
        throw new Error('Socket.IO non initialisé. Appeler setIO() d\'abord.');
    }
    return io;
}

module.exports = { setIO, getIO };
