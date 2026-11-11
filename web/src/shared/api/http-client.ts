import { messages } from '@/shared/i18n/messages';
import { getStoredLocale } from '@/shared/i18n/use-locale';
import { readStorage, removeStorage, writeStorage } from '@/shared/storage/safe-storage';

export class ApiClientError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: Record<string, string> | undefined;

  constructor(status: number, code: string, message: string, details?: Record<string, string>) {
    super(message);
    this.name = 'ApiClientError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

const TOKEN_KEY = 'algorithm-garden-token';

export function getStoredToken(): string | null {
  return readStorage(TOKEN_KEY);
}

export function setStoredToken(token: string | null): void {
  if (token === null) {
    removeStorage(TOKEN_KEY);
  } else {
    writeStorage(TOKEN_KEY, token);
  }
}

const BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') ?? '';

export async function apiRequest<T>(
  path: string,
  options: {
    method?: string;
    body?: unknown;
    token?: string | null;
    signal?: AbortSignal;
  } = {},
): Promise<T> {
  const activeLocale = getStoredLocale();
  const localeMsgs = messages[activeLocale];
  const headers: Record<string, string> = {
    'Accept-Language': activeLocale,
  };
  const token = options.token !== undefined ? options.token : getStoredToken();
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  const init: RequestInit = {
    method: options.method ?? 'GET',
    headers,
  };
  if (options.signal !== undefined) {
    init.signal = options.signal;
  }
  if (options.body !== undefined) {
    init.body = JSON.stringify(options.body);
  }

  const res = await fetch(`${BASE_URL}${path}`, init);

  const json = (await res.json().catch(() => null)) as {
    data?: T;
    error?: { code?: string; message?: string; details?: Record<string, string> };
  } | null;

  if (!res.ok) {
    const err = json?.error;
    throw new ApiClientError(
      res.status,
      err?.code ?? 'http_error',
      err?.message ?? `${localeMsgs.common.httpError} (${res.status})`,
      err?.details,
    );
  }

  if (!json || json.data === undefined) {
    throw new ApiClientError(res.status, 'invalid_response', localeMsgs.common.unexpectedResponse);
  }
  return json.data;
}
