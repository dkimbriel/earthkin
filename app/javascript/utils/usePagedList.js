import { useEffect, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";

export const DEFAULT_PER_PAGE = 25;
// Matches PaginatedList::MAX_PER_PAGE on the server.
const MAX_PER_PAGE = 100;
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
	const urlQuery = searchParams.get("q") || "";
	const page = Math.max(1, parseInt(searchParams.get("page"), 10) || 1);
	const perPage = Math.min(MAX_PER_PAGE, Math.max(1, parseInt(searchParams.get("per_page"), 10) || DEFAULT_PER_PAGE));

	// What's in the search box. It reaches the URL (and resets to page 1) only
	// once typing pauses, so each search is a single request.
	const [inputQuery, setInputQuery] = useState(urlQuery);
	const [result, setResult] = useState({ rows: [], total: 0, loaded: false });
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [reloadKey, setReloadKey] = useState(0);
	const filtersKey = JSON.stringify(filters);

	// `replace` for search and page size (no history entry per search); page
	// changes push, so Back steps through pages.
	const updateParams = (changes, { replace = true } = {}) => {
		setSearchParams(
			(current) => {
				const next = new URLSearchParams(current);
				Object.entries(changes).forEach(([key, value]) => {
					if (value === null || value === undefined || value === "") next.delete(key);
					else next.set(key, value);
				});
				return next;
			},
			{ replace }
		);
	};

	// Follow the URL when it changes underneath us (Back/Forward, a link), but
	// not when the change is our own debounced write, which could otherwise
	// clobber a character typed in the meantime.
	const pushedQuery = useRef(urlQuery);
	useEffect(() => {
		if (urlQuery !== pushedQuery.current) {
			pushedQuery.current = urlQuery;
			setInputQuery(urlQuery);
		}
	}, [urlQuery]);

	useEffect(() => {
		if (inputQuery === urlQuery) return undefined;
		const timer = setTimeout(() => {
			pushedQuery.current = inputQuery;
			updateParams({ q: inputQuery, page: null });
		}, SEARCH_DEBOUNCE_MS);
		return () => clearTimeout(timer);
		// eslint-disable-next-line react-hooks/exhaustive-deps
	}, [inputQuery, urlQuery]);

	useEffect(() => {
		let cancelled = false;
		setLoading(true);
		fetchPage({ ...filters, q: urlQuery, page, per_page: perPage })
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
	}, [urlQuery, page, perPage, filtersKey, reloadKey]);

	return {
		rows: result.rows,
		total: result.total,
		loading,
		// Only the first load shows a spinner; later searches keep the old rows
		// on screen until the new ones arrive.
		initialLoading: loading && !result.loaded,
		error,
		query: inputQuery,
		setQuery: setInputQuery,
		page,
		setPage: (value) => updateParams({ page: value > 1 ? value : null }, { replace: false }),
		perPage,
		setPerPage: (value) => updateParams({ per_page: value === DEFAULT_PER_PAGE ? null : value, page: null }),
		reload: () => setReloadKey((key) => key + 1),
	};
}
