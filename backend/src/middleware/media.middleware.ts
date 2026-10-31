import { RequestHandler } from "express";
import { mediaKeyOf, viewableMediaUrl } from "#controllers/upload.controller";

// Photos are stored as plain S3 URLs, which a private bucket will not serve.
// Before a JSON response goes out, each such URL anywhere in it is swapped
// for one the app can load (see viewableMediaUrl). Only plain objects and
// arrays are walked; every other value is sent as is.

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
    value !== null && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype;

const collectMediaUrls = (value: unknown, found: Set<string>): void => {
    if (typeof value === 'string') {
        if (mediaKeyOf(value)) found.add(value);
    } else if (Array.isArray(value)) {
        for (const item of value) collectMediaUrls(item, found);
    } else if (isPlainObject(value)) {
        for (const item of Object.values(value)) collectMediaUrls(item, found);
    }
};

const replaceStrings = (value: unknown, urls: Map<string, string>): unknown => {
    if (typeof value === 'string') return urls.get(value) ?? value;
    if (Array.isArray(value)) return value.map((item) => replaceStrings(item, urls));
    if (isPlainObject(value)) {
        return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, replaceStrings(item, urls)]));
    }
    return value;
};

export const exposeMediaUrls: RequestHandler = (_req, res, next) => {
    const send = res.json.bind(res);
    res.json = ((body?: unknown) => {
        const found = new Set<string>();
        collectMediaUrls(body, found);
        if (found.size === 0) return send(body);
        Promise.all([...found].map(async (url) => [url, await viewableMediaUrl(url)] as const))
            .then((pairs) => send(replaceStrings(body, new Map(pairs))))
            .catch((error) => {
                // Better a response with unloadable photos than none at all.
                console.error('Could not sign photo URLs:', error);
                send(body);
            });
        return res;
    }) as typeof res.json;
    next();
};
