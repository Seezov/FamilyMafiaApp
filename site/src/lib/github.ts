// The few GitHub REST calls the Debug page needs: read a file, write several
// files as one commit on a branch.

export interface Repo { owner: string; name: string; branch: string }

const API = 'https://api.github.com';

async function gh<T>(path: string, token: string | null, init: RequestInit = {}, raw = false): Promise<T> {
  const res = await fetch(`${API}${path}`, {
    ...init,
    cache: 'no-store',
    headers: {
      Accept: raw ? 'application/vnd.github.raw+json' : 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
    },
  });
  if (!res.ok) {
    let msg = res.statusText;
    try { msg = (await res.json()).message ?? msg; } catch { /* not JSON */ }
    throw new Error(`GitHub ${res.status}: ${msg}`);
  }
  return (raw ? res.text() : res.json()) as Promise<T>;
}

const enc = (p: string) => p.split('/').map(encodeURIComponent).join('/');

export const whoAmI = (token: string) => gh<{ login: string }>('/user', token).then((u) => u.login);

export const headSha = (repo: Repo, token: string | null) =>
  gh<{ object: { sha: string } }>(`/repos/${repo.owner}/${repo.name}/git/ref/heads/${enc(repo.branch)}`, token)
    .then((r) => r.object.sha);

/** [path] as of [ref] (a branch or commit sha). */
export const readFile = (repo: Repo, path: string, ref: string, token: string | null) =>
  gh<string>(`/repos/${repo.owner}/${repo.name}/contents/${enc(path)}?ref=${encodeURIComponent(ref)}`, token, {}, true);

/** Commits [files] on top of [parent] and moves the branch there. Fails
 * (without writing) when the branch has moved past [parent]. */
export async function commitFiles(
  repo: Repo, token: string, parent: string, files: { path: string; content: string }[], message: string,
): Promise<string> {
  const base = `/repos/${repo.owner}/${repo.name}/git`;
  const parentCommit = await gh<{ tree: { sha: string } }>(`${base}/commits/${parent}`, token);
  const tree = await gh<{ sha: string }>(`${base}/trees`, token, {
    method: 'POST',
    body: JSON.stringify({
      base_tree: parentCommit.tree.sha,
      tree: files.map((f) => ({ path: f.path, mode: '100644', type: 'blob', content: f.content })),
    }),
  });
  const commit = await gh<{ sha: string }>(`${base}/commits`, token, {
    method: 'POST',
    body: JSON.stringify({ message, tree: tree.sha, parents: [parent] }),
  });
  await gh(`${base}/refs/heads/${enc(repo.branch)}`, token, {
    method: 'PATCH',
    body: JSON.stringify({ sha: commit.sha, force: false }),
  });
  return commit.sha;
}
