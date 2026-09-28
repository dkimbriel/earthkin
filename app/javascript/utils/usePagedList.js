import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";

export const DEFAULT_PER_PAGE = 25;
const SEARCH_DEBOUNCE_MS = 300;

// A server-searched, server-paginated list for the admin list pages. Search
// (q), page, and per_page live in the URL, so they survive refresh and Back
// from a detail page. `fetchPage` is an api list function (e.g.
// familiesApi.list); it's called with { ...filters, q, page, per_page } and
// must return { data, meta } (see PaginatedList on the server).
//
//   const list = usePagedList(familiesApi.list);
//   <SearchField value={list.query} onChange={list.setQuery} total={list.total} ... />
//   <DataTable data={list.rows} loading={list.initialLoading} ... />
//   <ListPagination list={list} />
export default function usePagedList(fetchPage, { filters = {} } = {}) {
	const [searchParams, setSearchParams] = useSearchParams();
	const query = searchParams.get("q") || "";
	const page = Math.max(1, parseInt(searchParams.get("page"), 10) || 1);
	const perPage = parseInt(searchParams.get("per_page"), 10) || DEFAULT_PER_PAGE;

	const [debouncedQuery, setDebouncedQuery] = useState(query);
	const [result, setResult] = useState({ rows: [], total: 0, loaded: false });
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [reloadKey, setReloadKey] = useState(0);
	const filtersKey = JSON.stringify(filters);

	useEffect(() => {
		const timer = setTimeout(() => setDebouncedQuery(query), SEARCH_DEBOUNCE_MS);
		return () => clearTimeout(timer);
	}, [query]);

	// `replace` for typing and page size (no history entry per keystroke);
	// page changes push, so Back steps through pages.
	const updateParams = (changes, { replace = true } = {}) => {
		const next = new URLSearchParams(searchParams);
		Object.entries(changes).forEach(([key, value]) => {
			if (value === null || value === undefined || value === "") next.delete(key);
			else next.set(key, value);
		});
		setSearchParams(next, { replace });
	};

	const setQuery = (value) => updateParams({ q: value, page: null });
	const setPage = (value) => updateParams({ page: value > 1 ? value : null }, { replace: false });
	const setPerPage = (value) => updateParams({ per_page: value === DEFAULT_PER_PAGE ? null : value, page: null });

	useEffect(() => {
		let cancelled = false;
		setLoading(true);
		fetchPage({ ...filters, q: debouncedQuery, page, per_page: perPage })
			.then((response) => {
				if (cancelled) return;
				setResult({ rows: response.data, total: response.meta.total, loaded: true });
				setError(null);
				// The server clamps a page past the end (e.g. after deleting the
				// last row on it); follow it so the pager and URL agree.
				if (response.meta.page !== page) updateParams({ page: response.meta.page > 1 ? response.meta.page : null });
			})
			.catch((err) => !cancelled && setError(err.message))
			.finally(() => !cancelled && setLoading(false));
		return () => {
			cancelled = true;
		};
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [debouncedQuery, page, perPage, filtersKey, reloadKey]);

	return {
		rows: result.rows,
		total: result.total,
		loading,
		// Only the first load shows a spinner; later searches keep the old rows
		// on screen until the new ones arrive.
		initialLoading: loading && !result.loaded,
		error,
		query,
		setQuery,
		page,
		setPage,
		perPage,
		setPerPage,
		reload: () => setReloadKey((key) => key + 1),
	};
}
