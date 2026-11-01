import { ErrorRequestHandler } from "express";

type ErrorWithStatus = {
	status?: number;
	statusCode?: number;
	message?: string;
};

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next): void => {
	// Postgres refuses text longer than its varchar column (SQLSTATE 22001).
	// Controllers check the limits they know about; this turns any they miss
	// into a 400 instead of a 500.
	if ((error as { code?: unknown } | null)?.code === '22001') {
		res.status(400).json({ success: false, message: "One of the fields is too long" });
		return;
	}

	const normalizedError = error as ErrorWithStatus;
	const statusCode = normalizedError.statusCode ?? normalizedError.status ?? 500;
	const message = normalizedError.message ?? "Internal server error";

	console.error(error);

	res.status(statusCode).json({
		success: false,
		message,
	});
};
