export function readStorage(key: string): string | null {
  if (typeof window === 'undefined') {
    return null;
  }
  try {
    return typeof window.localStorage?.getItem === 'function'
      ? window.localStorage.getItem(key)
      : null;
  } catch {
    return null;
  }
}

export function writeStorage(key: string, value: string): void {
  if (typeof window === 'undefined') {
    return;
  }
  try {
    window.localStorage?.setItem?.(key, value);
  } catch {
    // Ignore storage quota / private-browsing security errors cleanly.
  }
}

export function removeStorage(key: string): void {
  if (typeof window === 'undefined') {
    return;
  }
  try {
    window.localStorage?.removeItem?.(key);
  } catch {
    // Ignore storage security errors cleanly.
  }
}
