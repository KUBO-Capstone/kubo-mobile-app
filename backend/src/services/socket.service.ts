import { Server as HttpServer } from "http";
import { Server } from "socket.io";
import { verifyToken } from "#utils/token";
import { UserModel } from "#models/user.model";

// Push channel only: clients never send chat over the socket (that goes
// through REST so there is one write path with normal HTTP errors). Each
// connection joins exactly one room, user:<id>, and the server picks the
// recipients of every event, so there are no per-room permissions to check.

let io: Server | undefined;

const userRoom = (userId: number): string => `user:${userId}`;

export function initSocket(httpServer: HttpServer): Server {
    io = new Server(httpServer, { cors: { origin: '*' } });

    // The token comes in the handshake `auth` field, not the URL, so it never
    // lands in access logs.
    io.use((socket, next) => {
        const token = socket.handshake.auth?.token;
        const payload = typeof token === 'string' ? verifyToken(token) : undefined;
        if (!payload || !UserModel.isActive(payload.sub)) {
            next(new Error('unauthorized'));
            return;
        }
        socket.data.userId = payload.sub;
        next();
    });

    io.on('connection', (socket) => {
        socket.join(userRoom(socket.data.userId as number));
    });

    return io;
}

/** Emits to every connected device of each user. No-op before initSocket(). */
export function emitToUsers(userIds: number[], event: string, payload: unknown): void {
    if (!io) return;
    io.to([...new Set(userIds)].map(userRoom)).emit(event, payload);
}
