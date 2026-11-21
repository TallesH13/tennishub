import type { FastifyError, FastifyInstance } from 'fastify';
import { ZodError } from 'zod';

/** Formato único de erro da API: `{ "error": { "code", "message", "details"? } }`. */
export type ErrorBody = {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
};

/** Erro de negócio esperado. Vira resposta com o status e o código informados. */
export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = 'AppError';
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Recurso não encontrado.') {
    super(404, 'NOT_FOUND', message);
  }
}

export class ConflictError extends AppError {
  constructor(code: string, message: string) {
    super(409, code, message);
  }
}

export type FieldError = { field: string; message: string };

export function zodToFieldErrors(error: ZodError): FieldError[] {
  return error.issues.map((issue) => ({
    field: issue.path.join('.') || '(raiz)',
    message: issue.message,
  }));
}

function body(code: string, message: string, details?: unknown): ErrorBody {
  return details === undefined
    ? { error: { code, message } }
    : { error: { code, message, details } };
}

/** Registra o tratamento centralizado de erros e de rota inexistente. */
export function registerErrorHandling(app: FastifyInstance): void {
  app.setErrorHandler((error: FastifyError | Error, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send(body(error.code, error.message, error.details));
    }

    if (error instanceof ZodError) {
      return reply
        .status(422)
        .send(body('VALIDATION_ERROR', 'Dados inválidos.', zodToFieldErrors(error)));
    }

    const fastifyError = error as FastifyError;
    // Erros do próprio Fastify (JSON malformado, corpo grande demais etc.) já trazem status 4xx.
    if (
      fastifyError.statusCode &&
      fastifyError.statusCode >= 400 &&
      fastifyError.statusCode < 500
    ) {
      return reply
        .status(fastifyError.statusCode)
        .send(body(fastifyError.code ?? 'BAD_REQUEST', fastifyError.message));
    }

    request.log.error({ err: error }, 'erro não tratado');
    // Nunca devolve detalhes internos (stack, SQL) para o cliente.
    return reply.status(500).send(body('INTERNAL_ERROR', 'Erro interno do servidor.'));
  });

  app.setNotFoundHandler((request, reply) => {
    return reply
      .status(404)
      .send(body('NOT_FOUND', `Rota ${request.method} ${request.url} não encontrada.`));
  });
}
