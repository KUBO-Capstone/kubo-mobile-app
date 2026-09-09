import { ErrorRequestHandler } from "express";

type ErrorWithStatus = {
	status?: number;
	statusCode?: number;
	message?: string;
};

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next): void => {
	const normalizedError = error as ErrorWithStatus;
	const statusCode = normalizedError.statusCode ?? normalizedError.status ?? 500;
	const message = normalizedError.message ?? "Internal server error";

	console.error(error);

	res.status(statusCode).json({
		success: false,
		message,
	});
};
