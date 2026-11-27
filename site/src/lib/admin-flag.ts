// Remembers in this browser whether the signed-in user is an admin, so the static header can show
// admin-only links (Debug) without loading Firebase on every page. Only a convenience: the pages
// and firestore.rules check admin rights themselves.
export const ADMIN_FLAG = 'fm-admin';

export function rememberAdmin(admin: boolean) {
  try { if (admin) localStorage.setItem(ADMIN_FLAG, '1'); else localStorage.removeItem(ADMIN_FLAG); } catch { /* private mode */ }
}
